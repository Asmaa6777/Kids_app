// Security rules tests. Run with: npm run emulate
//
// Each test acts as a specific user (owner = parent/child device, a relative,
// a stranger, or signed-out) and checks that the rules allow or refuse it.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  addDoc, collection, deleteDoc, doc, getDoc, getDocs, serverTimestamp, setDoc, updateDoc, writeBatch,
} from 'firebase/firestore';
import { getBytes, ref, uploadBytes } from 'firebase/storage';

const FID = 'fam1';
const settings = { typingAllowed: false, filtersAllowed: true, quietOn: false, quietFrom: 1200, quietTo: 420, utcOffsetMinutes: 0 };

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-familycall',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
    storage: { rules: readFileSync('../storage.rules', 'utf8'), host: '127.0.0.1', port: 9199 },
  });
});

after(() => env.cleanup());

// A family with: owner "parent", relative "grandma" bound to contact "g",
// a second contact "u" (not joined yet), and one message in each thread.
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, `families/${FID}`), { childName: 'Mia', ownerUid: 'parent', settings, createdAt: new Date() });
    await setDoc(doc(db, `families/${FID}/members/parent`), { role: 'owner' });
    await setDoc(doc(db, `families/${FID}/members/grandma`), { role: 'relative', contactId: 'g' });
    await setDoc(doc(db, `families/${FID}/contacts/g`), { name: 'Grandma', color: 'coral', order: 0, uid: 'grandma' });
    await setDoc(doc(db, `families/${FID}/contacts/u`), { name: 'Uncle Omar', color: 'blue', order: 1 });
    await setDoc(doc(db, `families/${FID}/threads/g/messages/m1`), { from: 'child', type: 'sticker', data: 'heart', sentAt: new Date() });
    await setDoc(doc(db, `families/${FID}/threads/u/messages/m1`), { from: 'child', type: 'sticker', data: 'star', sentAt: new Date() });
  });
});

const as = (uid) => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).firestore();
const msg = (from, type = 'sticker', data = 'star') => ({ from, type, data, sentAt: serverTimestamp() });

describe('creating a family', () => {
  test('a signed-in user can create a family as its owner, with their member doc in the same batch', async () => {
    const db = as('newparent');
    const b = writeBatch(db);
    b.set(doc(db, 'families/fam2'), { childName: 'Sara', ownerUid: 'newparent', settings, createdAt: serverTimestamp() });
    b.set(doc(db, 'families/fam2/members/newparent'), { role: 'owner' });
    await assertSucceeds(b.commit());
  });

  test('cannot create a family owned by someone else', async () => {
    const db = as('mallory');
    const b = writeBatch(db);
    b.set(doc(db, 'families/fam2'), { childName: 'Sara', ownerUid: 'parent', settings, createdAt: serverTimestamp() });
    b.set(doc(db, 'families/fam2/members/mallory'), { role: 'owner' });
    await assertFails(b.commit());
  });

  test('cannot make yourself owner of an existing family', async () => {
    await assertFails(setDoc(doc(as('mallory'), `families/${FID}/members/mallory`), { role: 'owner' }));
  });

  test('cannot add yourself as a relative (only the invite function can)', async () => {
    await assertFails(setDoc(doc(as('mallory'), `families/${FID}/members/mallory`), { role: 'relative', contactId: 'u' }));
  });

  test('signed-out users can do nothing', async () => {
    await assertFails(getDoc(doc(as(null), `families/${FID}`)));
  });
});

describe('reading the family', () => {
  test('members can read the family and its contacts', async () => {
    await assertSucceeds(getDoc(doc(as('parent'), `families/${FID}`)));
    await assertSucceeds(getDocs(collection(as('grandma'), `families/${FID}/contacts`)));
  });

  test('strangers cannot read anything', async () => {
    await assertFails(getDoc(doc(as('mallory'), `families/${FID}`)));
    await assertFails(getDocs(collection(as('mallory'), `families/${FID}/contacts`)));
    await assertFails(getDocs(collection(as('mallory'), `families/${FID}/threads/g/messages`)));
  });
});

describe('parent controls', () => {
  test('the owner can add, edit and remove contacts', async () => {
    const db = as('parent');
    await assertSucceeds(setDoc(doc(db, `families/${FID}/contacts/s`), { name: 'Cousin Sara', color: 'green', order: 2 }));
    await assertSucceeds(updateDoc(doc(db, `families/${FID}/contacts/s`), { order: 0 }));
    await assertSucceeds(deleteDoc(doc(db, `families/${FID}/contacts/s`)));
  });

  test('the owner cannot bind a contact to an account (only redeemInvite can)', async () => {
    await assertFails(updateDoc(doc(as('parent'), `families/${FID}/contacts/u`), { uid: 'mallory' }));
  });

  test('contact fields are validated', async () => {
    const db = as('parent');
    await assertFails(setDoc(doc(db, `families/${FID}/contacts/x`), { name: '', color: 'green', order: 0 }));
    await assertFails(setDoc(doc(db, `families/${FID}/contacts/x`), { name: 'X', color: 'black', order: 0 }));
    await assertFails(setDoc(doc(db, `families/${FID}/contacts/x`), { name: 'X', color: 'green', order: 0, admin: true }));
  });

  test('relatives cannot change contacts or settings', async () => {
    const db = as('grandma');
    await assertFails(setDoc(doc(db, `families/${FID}/contacts/x`), { name: 'Stranger', color: 'green', order: 9 }));
    await assertFails(updateDoc(doc(db, `families/${FID}`), { 'settings.typingAllowed': true }));
  });

  test('the owner can change settings but not hand the family to someone else', async () => {
    const db = as('parent');
    await assertSucceeds(updateDoc(doc(db, `families/${FID}`), { 'settings.quietOn': true }));
    await assertFails(updateDoc(doc(db, `families/${FID}`), { ownerUid: 'mallory' }));
    await assertFails(updateDoc(doc(db, `families/${FID}`), { 'settings.quietFrom': 5000 }));
  });

  test('the owner can remove a relative but not themselves', async () => {
    const db = as('parent');
    await assertFails(deleteDoc(doc(db, `families/${FID}/members/parent`)));
    await assertSucceeds(deleteDoc(doc(db, `families/${FID}/members/grandma`)));
  });

  test('only the owner sees the activity log', async () => {
    await assertSucceeds(addDoc(collection(as('parent'), `families/${FID}/activity`), { text: 'x', at: serverTimestamp() }));
    await assertFails(getDocs(collection(as('grandma'), `families/${FID}/activity`)));
  });
});

describe('chat', () => {
  test('a relative reads and writes only their own thread with the child', async () => {
    const db = as('grandma');
    await assertSucceeds(getDocs(collection(db, `families/${FID}/threads/g/messages`)));
    await assertSucceeds(addDoc(collection(db, `families/${FID}/threads/g/messages`), msg('contact')));
    await assertFails(getDocs(collection(db, `families/${FID}/threads/u/messages`))); // Uncle's thread
    await assertFails(addDoc(collection(db, `families/${FID}/threads/u/messages`), msg('contact')));
  });

  test('nobody can pretend to be the other side', async () => {
    await assertFails(addDoc(collection(as('grandma'), `families/${FID}/threads/g/messages`), msg('child')));
    await assertFails(addDoc(collection(as('parent'), `families/${FID}/threads/g/messages`), msg('contact')));
  });

  test('the server sets the time: a fake timestamp is refused', async () => {
    const fake = { from: 'contact', type: 'sticker', data: 'star', sentAt: new Date(2000, 0, 1) };
    await assertFails(addDoc(collection(as('grandma'), `families/${FID}/threads/g/messages`), fake));
  });

  test('messages cannot be edited or deleted', async () => {
    const m = doc(as('parent'), `families/${FID}/threads/g/messages/m1`);
    await assertFails(updateDoc(m, { data: 'changed' }));
    await assertFails(deleteDoc(m));
  });

  test('the child can only type when the parent allows it; relatives always can', async () => {
    const childDb = as('parent');
    await assertFails(addDoc(collection(childDb, `families/${FID}/threads/g/messages`), msg('child', 'text', 'hi')));
    await assertSucceeds(addDoc(collection(as('grandma'), `families/${FID}/threads/g/messages`), msg('contact', 'text', 'hi')));
    await updateDoc(doc(childDb, `families/${FID}`), { 'settings.typingAllowed': true });
    await assertSucceeds(addDoc(collection(childDb, `families/${FID}/threads/g/messages`), msg('child', 'text', 'hi')));
  });

  test('unknown message types and extra fields are refused', async () => {
    const col = collection(as('grandma'), `families/${FID}/threads/g/messages`);
    await assertFails(addDoc(col, msg('contact', 'link', 'http://example.com')));
    await assertFails(addDoc(col, { ...msg('contact'), url: 'http://example.com' }));
  });
});

describe('calls', () => {
  const call = (contactId, from) => ({ contactId, from, status: 'ringing', createdAt: serverTimestamp() });

  test('a relative can ring the child; the child can ring a relative', async () => {
    await assertSucceeds(addDoc(collection(as('grandma'), `families/${FID}/calls`), call('g', 'contact')));
    await assertSucceeds(addDoc(collection(as('parent'), `families/${FID}/calls`), call('u', 'child')));
  });

  test('a relative cannot start a call on someone else\'s line', async () => {
    await assertFails(addDoc(collection(as('grandma'), `families/${FID}/calls`), call('u', 'contact')));
  });

  test('answering may only change the status', async () => {
    const ref1 = await addDoc(collection(as('grandma'), `families/${FID}/calls`), call('g', 'contact'));
    const childSide = doc(as('parent'), ref1.path);
    await assertSucceeds(updateDoc(childSide, { status: 'answered' }));
    await assertFails(updateDoc(childSide, { contactId: 'u' }));
    await assertFails(updateDoc(childSide, { status: 'hacked' }));
  });
});

describe('private user docs and invites', () => {
  test('users read/write only their own doc', async () => {
    await assertSucceeds(setDoc(doc(as('grandma'), 'users/grandma'), { fids: ['t'] }));
    await assertFails(getDoc(doc(as('mallory'), 'users/grandma')));
  });

  test('invites are invisible to the app (Cloud Functions only)', async () => {
    await assertFails(getDoc(doc(as('parent'), 'invites/ABCDEF')));
    await assertFails(setDoc(doc(as('parent'), 'invites/ABCDEF'), { familyId: FID }));
  });
});

describe('storage (voice notes, photos)', () => {
  const st = (uid) => env.authenticatedContext(uid).storage();
  const bytes = new Uint8Array([1, 2, 3]);

  test('a relative uploads a voice note to their own thread and reads it back', async () => {
    const r = ref(st('grandma'), `families/${FID}/threads/g/v1.m4a`);
    await assertSucceeds(uploadBytes(r, bytes, { contentType: 'audio/mp4' }));
    await assertSucceeds(getBytes(r));
  });

  test('but not to another thread, not as a stranger, and not other file types', async () => {
    await assertFails(uploadBytes(ref(st('grandma'), `families/${FID}/threads/u/v1.m4a`), bytes, { contentType: 'audio/mp4' }));
    await assertFails(uploadBytes(ref(st('mallory'), `families/${FID}/threads/g/v2.m4a`), bytes, { contentType: 'audio/mp4' }));
    await assertFails(uploadBytes(ref(st('grandma'), `families/${FID}/threads/g/x.exe`), bytes, { contentType: 'application/octet-stream' }));
  });

  test('the owner can read every thread', async () => {
    await uploadBytes(ref(st('grandma'), `families/${FID}/threads/g/v3.m4a`), bytes, { contentType: 'audio/mp4' });
    await assertSucceeds(getBytes(ref(st('parent'), `families/${FID}/threads/g/v3.m4a`)));
  });
});
