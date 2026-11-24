// Family Call — Cloud Functions.
//
// Callable functions (the app calls them like normal functions; Firebase
// passes along who is signed in as request.auth):
//   createInvite   parent → a single-use code for one contact tile
//   redeemInvite   relative → joins the family as that contact
//   livekitToken   either side → a short-lived token to join the call room
//   deleteFamily   parent → erases everything (privacy: the right to delete)
//
// Triggers (run automatically when a document is created):
//   onCallCreated     → push "ringing" to the person being called
//   onMessageCreated  → push "new message" to the other side
import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore, Timestamp } from 'firebase-admin/firestore';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { CallableRequest, HttpsError, onCall } from 'firebase-functions/v2/https';
import { defineSecret, defineString } from 'firebase-functions/params';
import { AccessToken } from 'livekit-server-sdk';

import { generateInviteCode, INVITE_TTL_MS, isId, isQuietAt, normaliseCode, QuietSettings, roomName } from './logic.js';
import { pushToUser } from './push.js';

initializeApp();
const db = getFirestore();

// Secrets live in Google Secret Manager, never in the app or the repo:
//   firebase functions:secrets:set LIVEKIT_API_KEY
const LIVEKIT_API_KEY = defineSecret('LIVEKIT_API_KEY');
const LIVEKIT_API_SECRET = defineSecret('LIVEKIT_API_SECRET');
const LIVEKIT_URL = defineString('LIVEKIT_URL', { default: 'wss://example.livekit.cloud' });

const REGION = { region: 'europe-west1' };

function requireUid(req: CallableRequest): string {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  return req.auth.uid;
}

async function memberOf(familyId: string, uid: string) {
  const snap = await db.doc(`families/${familyId}/members/${uid}`).get();
  return snap.exists ? (snap.data() as { role: 'owner' | 'relative'; contactId?: string }) : null;
}

async function requireOwner(familyId: unknown, uid: string): Promise<string> {
  if (!isId(familyId)) throw new HttpsError('invalid-argument', 'Bad familyId.');
  const m = await memberOf(familyId, uid);
  if (m?.role !== 'owner') throw new HttpsError('permission-denied', 'Only the parent can do this.');
  return familyId;
}

// ---------------------------------------------------------------------------
// Invites
// ---------------------------------------------------------------------------

export const createInvite = onCall(REGION, async (req) => {
  const uid = requireUid(req);
  const familyId = await requireOwner(req.data?.familyId, uid);
  const contactId = req.data?.contactId;
  if (!isId(contactId)) throw new HttpsError('invalid-argument', 'Bad contactId.');

  const contact = await db.doc(`families/${familyId}/contacts/${contactId}`).get();
  if (!contact.exists) throw new HttpsError('not-found', 'No such contact.');
  if (contact.get('uid')) throw new HttpsError('failed-precondition', 'This person already joined.');

  const expiresAt = Timestamp.fromMillis(Date.now() + INVITE_TTL_MS);
  // create() fails if the code already exists, so a collision just means "try another".
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = generateInviteCode();
    try {
      await db.doc(`invites/${code}`).create({
        familyId, contactId, createdBy: uid, createdAt: FieldValue.serverTimestamp(), expiresAt, usedBy: null,
      });
      return { code, expiresAt: expiresAt.toMillis() };
    } catch (e) {
      if ((e as { code?: number }).code !== 6 /* ALREADY_EXISTS */) throw e;
    }
  }
  throw new HttpsError('resource-exhausted', 'Could not create a code, try again.');
});

export const redeemInvite = onCall(REGION, async (req) => {
  const uid = requireUid(req);
  const code = normaliseCode(req.data?.code);
  if (!code) throw new HttpsError('invalid-argument', 'That code is not valid.');
  const displayName = typeof req.data?.name === 'string' ? req.data.name.trim().slice(0, 20) : '';

  // A transaction: either every write below happens, or none does. Two people
  // racing to use the same code can't both win.
  return db.runTransaction(async (tx) => {
    const inviteRef = db.doc(`invites/${code}`);
    const invite = await tx.get(inviteRef);
    if (!invite.exists || invite.get('usedBy') || (invite.get('expiresAt') as Timestamp).toMillis() < Date.now()) {
      throw new HttpsError('failed-precondition', 'That code is not valid or was already used.');
    }
    const familyId: string = invite.get('familyId');
    const contactId: string = invite.get('contactId');

    const familyRef = db.doc(`families/${familyId}`);
    const contactRef = db.doc(`families/${familyId}/contacts/${contactId}`);
    const memberRef = db.doc(`families/${familyId}/members/${uid}`);
    const [family, contact, existing] = await Promise.all([tx.get(familyRef), tx.get(contactRef), tx.get(memberRef)]);
    if (!family.exists || !contact.exists) throw new HttpsError('not-found', 'This family no longer exists.');
    if (existing.exists) throw new HttpsError('already-exists', 'You are already in this family.');
    if (contact.get('uid')) throw new HttpsError('failed-precondition', 'Someone already joined as this person.');

    tx.update(inviteRef, { usedBy: uid, usedAt: FieldValue.serverTimestamp() });
    tx.set(memberRef, { role: 'relative', contactId, displayName });
    tx.update(contactRef, { uid });
    tx.set(db.doc(`users/${uid}`), { familyId }, { merge: true });
    tx.set(db.collection(`families/${familyId}/activity`).doc(), {
      text: `${contact.get('name')} joined`, at: FieldValue.serverTimestamp(),
    });

    return { familyId, contactId, childName: family.get('childName'), contactName: contact.get('name'), color: contact.get('color') };
  });
});

// ---------------------------------------------------------------------------
// Calls
// ---------------------------------------------------------------------------

export const livekitToken = onCall({ ...REGION, secrets: [LIVEKIT_API_KEY, LIVEKIT_API_SECRET] }, async (req) => {
  const uid = requireUid(req);
  const { familyId, contactId } = req.data ?? {};
  if (!isId(familyId) || !isId(contactId)) throw new HttpsError('invalid-argument', 'Bad ids.');

  const m = await memberOf(familyId, uid);
  if (!m || (m.role === 'relative' && m.contactId !== contactId)) {
    throw new HttpsError('permission-denied', 'Not your call.');
  }
  const family = await db.doc(`families/${familyId}`).get();
  if (isQuietAt(family.get('settings') as QuietSettings, new Date())) {
    throw new HttpsError('failed-precondition', 'Sleepy time — try again in the morning.');
  }

  const room = roomName(familyId, contactId);
  const at = new AccessToken(LIVEKIT_API_KEY.value(), LIVEKIT_API_SECRET.value(), { identity: uid, ttl: '1h' });
  at.addGrant({ roomJoin: true, room, canPublish: true, canSubscribe: true });
  return { token: await at.toJwt(), url: LIVEKIT_URL.value(), room };
});

/** A new call document → ring the other side, unless it's sleepy time for the child. */
export const onCallCreated = onDocumentCreated({ ...REGION, document: 'families/{fid}/calls/{callId}' }, async (event) => {
  const call = event.data?.data();
  if (!call) return;
  const { fid, callId } = event.params;
  const family = await db.doc(`families/${fid}`).get();

  if (call.from === 'contact' && isQuietAt(family.get('settings') as QuietSettings, new Date())) {
    await event.data!.ref.update({ status: 'declined' });
    return;
  }
  const callee = call.from === 'contact'
    ? (family.get('ownerUid') as string)
    : ((await db.doc(`families/${fid}/contacts/${call.contactId}`).get()).get('uid') as string | undefined);
  if (callee) await pushToUser(callee, { type: 'call', familyId: fid, contactId: call.contactId, callId });
});

/** A new chat message → tell the other side (the app shows a dot, not a loud alert). */
export const onMessageCreated = onDocumentCreated(
  { ...REGION, document: 'families/{fid}/threads/{cid}/messages/{mid}' },
  async (event) => {
    const msg = event.data?.data();
    if (!msg) return;
    const { fid, cid } = event.params;
    const callee = msg.from === 'contact'
      ? ((await db.doc(`families/${fid}`).get()).get('ownerUid') as string)
      : ((await db.doc(`families/${fid}/contacts/${cid}`).get()).get('uid') as string | undefined);
    if (callee) await pushToUser(callee, { type: 'message', familyId: fid, contactId: cid, kind: String(msg.type) });
  },
);

// ---------------------------------------------------------------------------
// Privacy
// ---------------------------------------------------------------------------

/** Deletes the family, every subcollection, its invites and its uploaded files. */
export const deleteFamily = onCall(REGION, async (req) => {
  const uid = requireUid(req);
  const familyId = await requireOwner(req.data?.familyId, uid);

  const invites = await db.collection('invites').where('familyId', '==', familyId).get();
  const batch = db.batch();
  invites.forEach((d) => batch.delete(d.ref));
  await batch.commit();

  await db.recursiveDelete(db.doc(`families/${familyId}`));
  const { getStorage } = await import('firebase-admin/storage');
  await getStorage().bucket().deleteFiles({ prefix: `families/${familyId}/` }).catch(() => undefined);
  return { deleted: true };
});
