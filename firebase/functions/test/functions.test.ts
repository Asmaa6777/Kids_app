// End-to-end tests of the Cloud Functions on the emulators (auth + firestore + functions).
// Real client SDK calls, as the app makes them, with real security rules.
import assert from 'node:assert/strict';
import { after, before, describe, test } from 'node:test';

import { getApps as adminApps, initializeApp as initAdmin } from 'firebase-admin/app';
import { getFirestore as adminDb, Timestamp } from 'firebase-admin/firestore';
import { deleteApp, FirebaseApp, initializeApp } from 'firebase/app';
import { connectAuthEmulator, getAuth, signInAnonymously } from 'firebase/auth';
import {
  addDoc, collection, connectFirestoreEmulator, doc, getFirestore, serverTimestamp, setDoc, updateDoc, writeBatch,
} from 'firebase/firestore';
import { connectFunctionsEmulator, getFunctions, httpsCallable } from 'firebase/functions';

const PROJECT = 'demo-familycall';
if (!adminApps().length) initAdmin({ projectId: PROJECT });
const admin = adminDb();

/** One signed-in "phone": its own app instance, auth user, Firestore and functions client. */
async function phone(name: string) {
  const app = initializeApp({ projectId: PROJECT, apiKey: 'demo-key', appId: 'demo' }, name);
  const auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
  const db = getFirestore(app);
  connectFirestoreEmulator(db, '127.0.0.1', 8080);
  const fns = getFunctions(app, 'europe-west1');
  connectFunctionsEmulator(fns, '127.0.0.1', 5001);
  const { user } = await signInAnonymously(auth);
  const call = <T = any>(fn: string, data: object) => httpsCallable(fns, fn)(data).then((r) => r.data as T);
  return { app, uid: user.uid, db, call };
}
type Phone = Awaited<ReturnType<typeof phone>>;

async function rejects(p: Promise<unknown>, code: string) {
  await assert.rejects(p, (e: any) => {
    assert.equal(e.code, `functions/${code}`, e.message);
    return true;
  });
}

/** Wait until a background trigger has written something. */
async function waitFor<T>(fn: () => Promise<T | undefined>, ms = 15000): Promise<T> {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    const v = await fn();
    if (v !== undefined) return v;
    await new Promise((r) => setTimeout(r, 250));
  }
  throw new Error('timed out waiting for trigger');
}

const outboxFor = (uid: string, type: string) =>
  waitFor(async () => {
    const s = await admin.collection('_pushOutbox').where('uid', '==', uid).get();
    return s.docs.map((d) => d.data()).find((d) => d.data.type === type);
  });

const settings = { typingAllowed: false, filtersAllowed: true, quietOn: false, quietFrom: 1200, quietTo: 420, utcOffsetMinutes: 0 };
const FID = `fam${Date.now()}`;
let parent: Phone, grandma: Phone, stranger: Phone;
let grandmaCode = '';

before(async () => {
  parent = await phone('parent');
  grandma = await phone('grandma');
  stranger = await phone('stranger');

  // The parent's app creates the family exactly as the Flutter app will.
  const b = writeBatch(parent.db);
  b.set(doc(parent.db, `families/${FID}`), { childName: 'Mia', ownerUid: parent.uid, settings, createdAt: serverTimestamp() });
  b.set(doc(parent.db, `families/${FID}/members/${parent.uid}`), { role: 'owner' });
  await b.commit();
  await setDoc(doc(parent.db, `families/${FID}/contacts/g`), { name: 'Grandma', color: 'coral', order: 0 });
  await setDoc(doc(parent.db, `families/${FID}/contacts/u`), { name: 'Uncle Omar', color: 'blue', order: 1 });
  await setDoc(doc(parent.db, `users/${parent.uid}`), { familyId: FID, fids: ['parent-fid'] });
});

after(async () => {
  await Promise.all([parent, grandma, stranger].map((p) => deleteApp(p.app as FirebaseApp)));
});

describe('invites', () => {
  test('only the parent can create a code', async () => {
    await rejects(stranger.call('createInvite', { familyId: FID, contactId: 'g' }), 'permission-denied');
    const res = await parent.call<{ code: string; expiresAt: number }>('createInvite', { familyId: FID, contactId: 'g' });
    assert.match(res.code, /^[A-Z2-9]{6}$/);
    assert.ok(res.expiresAt > Date.now() + 47 * 3600_000);
    grandmaCode = res.code;
  });

  test('a relative redeems the code and becomes that contact', async () => {
    const res = await grandma.call<any>('redeemInvite', { code: grandmaCode.toLowerCase(), name: 'Nana' });
    assert.deepEqual(
      { familyId: res.familyId, contactId: res.contactId, childName: res.childName },
      { familyId: FID, contactId: 'g', childName: 'Mia' },
    );
    const member = await admin.doc(`families/${FID}/members/${grandma.uid}`).get();
    assert.deepEqual(member.data(), { role: 'relative', contactId: 'g', displayName: 'Nana' });
    assert.equal((await admin.doc(`families/${FID}/contacts/g`).get()).get('uid'), grandma.uid);
  });

  test('a used code cannot be used again', async () => {
    await rejects(stranger.call('redeemInvite', { code: grandmaCode }), 'failed-precondition');
  });

  test('a code for someone who already joined cannot be created', async () => {
    await rejects(parent.call('createInvite', { familyId: FID, contactId: 'g' }), 'failed-precondition');
  });

  test('an expired code is refused', async () => {
    await admin.doc('invites/ZZZZZZ').set({
      familyId: FID, contactId: 'u', usedBy: null, expiresAt: Timestamp.fromMillis(Date.now() - 1000),
    });
    await rejects(stranger.call('redeemInvite', { code: 'ZZZZZZ' }), 'failed-precondition');
  });

  test('garbage codes are refused before touching the database', async () => {
    await rejects(stranger.call('redeemInvite', { code: '../../x' }), 'invalid-argument');
  });

  test('after joining, the relative can chat in their own thread (security rules + membership together)', async () => {
    await addDoc(collection(grandma.db, `families/${FID}/threads/g/messages`), {
      from: 'contact', type: 'sticker', data: 'heart', sentAt: serverTimestamp(),
    });
  });
});

describe('call tokens', () => {
  test('the relative gets a token for their own room only', async () => {
    const res = await grandma.call<{ token: string; room: string; url: string }>('livekitToken', { familyId: FID, contactId: 'g' });
    assert.equal(res.room, `${FID}_g`);
    const claims = JSON.parse(Buffer.from(res.token.split('.')[1], 'base64url').toString());
    assert.equal(claims.sub, grandma.uid);
    assert.equal(claims.video.room, `${FID}_g`);
    assert.equal(claims.video.roomJoin, true);
    await rejects(grandma.call('livekitToken', { familyId: FID, contactId: 'u' }), 'permission-denied');
    await rejects(stranger.call('livekitToken', { familyId: FID, contactId: 'g' }), 'permission-denied');
  });

  test('the child (owner) can call anyone', async () => {
    const res = await parent.call<{ room: string }>('livekitToken', { familyId: FID, contactId: 'u' });
    assert.equal(res.room, `${FID}_u`);
  });

  test('no tokens during quiet hours', async () => {
    await updateDoc(doc(parent.db, `families/${FID}`), { settings: { ...settings, quietOn: true, quietFrom: 0, quietTo: 1439 } });
    await rejects(grandma.call('livekitToken', { familyId: FID, contactId: 'g' }), 'failed-precondition');
    await updateDoc(doc(parent.db, `families/${FID}`), { settings });
  });
});

describe('push notifications', () => {
  before(async () => {
    await setDoc(doc(grandma.db, `users/${grandma.uid}`), { fids: ['grandma-fid'] }, { merge: true });
  });

  test('grandma calls → the child device rings', async () => {
    const call = await addDoc(collection(grandma.db, `families/${FID}/calls`), {
      contactId: 'g', from: 'contact', status: 'ringing', createdAt: serverTimestamp(),
    });
    const push = await outboxFor(parent.uid, 'call');
    assert.deepEqual(push.data, { type: 'call', familyId: FID, contactId: 'g', callId: call.id });
    assert.deepEqual(push.fids, ['parent-fid']);
  });

  test('the child sends a sticker → grandma gets a message push', async () => {
    await addDoc(collection(parent.db, `families/${FID}/threads/g/messages`), {
      from: 'child', type: 'sticker', data: 'star', sentAt: serverTimestamp(),
    });
    const push = await outboxFor(grandma.uid, 'message');
    assert.equal(push.data.contactId, 'g');
    assert.equal(push.data.kind, 'sticker');
  });

  test('during quiet hours a call to the child is declined, not rung', async () => {
    await updateDoc(doc(parent.db, `families/${FID}`), { settings: { ...settings, quietOn: true, quietFrom: 0, quietTo: 1439 } });
    const call = await addDoc(collection(grandma.db, `families/${FID}/calls`), {
      contactId: 'g', from: 'contact', status: 'ringing', createdAt: serverTimestamp(),
    });
    const status = await waitFor(async () => {
      const s = (await admin.doc(call.path).get()).get('status');
      return s === 'declined' ? s : undefined;
    });
    assert.equal(status, 'declined');
    await updateDoc(doc(parent.db, `families/${FID}`), { settings });
  });
});

describe('deleting all data', () => {
  test('only the parent can, and afterwards nothing is left', async () => {
    const pending = await parent.call<{ code: string }>('createInvite', { familyId: FID, contactId: 'u' });
    await rejects(grandma.call('deleteFamily', { familyId: FID }), 'permission-denied');

    assert.deepEqual(await parent.call('deleteFamily', { familyId: FID }), { deleted: true });
    assert.equal((await admin.doc(`families/${FID}`).get()).exists, false);
    assert.equal((await admin.collection(`families/${FID}/contacts`).get()).size, 0);
    assert.equal((await admin.collection(`families/${FID}/threads/g/messages`).get()).size, 0);
    assert.equal((await admin.doc(`invites/${pending.code}`).get()).exists, false);
  });
});
