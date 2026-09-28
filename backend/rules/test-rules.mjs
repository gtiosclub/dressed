import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, deleteDoc, doc, getDoc, getDocs, setDoc } from 'firebase/firestore';
import { deleteObject, getMetadata, ref, uploadBytes } from 'firebase/storage';

const env = await initializeTestEnvironment({
  projectId: 'demo-dressed',
  firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  storage: { rules: readFileSync('storage.rules', 'utf8') },
});

const alice = env.authenticatedContext('alice');
const bob = env.authenticatedContext('bob');
const guest = env.unauthenticatedContext();
const itemPath = 'users/alice/items/item_001';
const imagePath = 'users/alice/items/item_001/original.jpg';
const bucket = 'gs://demo-dressed.appspot.com';
const createdAt = new Date('2026-09-28T19:00:00Z');
const item = {
  id: 'item_001', ownerId: 'alice', name: 'Blue shirt', category: 'tops',
  imagePath, createdAt,
};
const outfit = {
  id: 'outfit_001', schemaVersion: 1, ownerId: 'alice', name: 'Monday',
  placementSchemaVersion: 1, placements: [], createdAt, updatedAt: createdAt,
};
const jpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);

try {
  await test('an owner can save, read, update, list, and delete a clothing item', async () => {
    await env.clearFirestore();
    const own = doc(alice.firestore(), itemPath);
    await assertSucceeds(setDoc(own, item));
    assert.equal((await assertSucceeds(getDoc(own))).data().name, 'Blue shirt');
    await assertSucceeds(getDocs(collection(alice.firestore(), 'users/alice/items')));
    await assertSucceeds(setDoc(own, { ...item, name: 'Navy shirt' }));
    await assertSucceeds(deleteDoc(own));
  });

  await test('another user and a guest cannot access private clothing', async () => {
    await env.clearFirestore();
    await assertSucceeds(setDoc(doc(alice.firestore(), itemPath), item));
    await assertFails(getDoc(doc(bob.firestore(), itemPath)));
    await assertFails(getDocs(collection(bob.firestore(), 'users/alice/items')));
    await assertFails(setDoc(doc(bob.firestore(), itemPath), item));
    await assertFails(deleteDoc(doc(bob.firestore(), itemPath)));
    await assertFails(getDoc(doc(guest.firestore(), itemPath)));
  });

  await test('clothing writes reject wrong IDs, fields, categories, paths, and changed creation time', async () => {
    await env.clearFirestore();
    const own = doc(alice.firestore(), itemPath);
    await assertFails(setDoc(own, { ...item, ownerId: 'bob' }));
    await assertFails(setDoc(own, { ...item, id: 'other' }));
    await assertFails(setDoc(own, { ...item, category: 'hats' }));
    await assertFails(setDoc(own, { ...item, imagePath: 'posts/alice/post_001/photo.jpg' }));
    await assertFails(setDoc(own, { ...item, extra: 'unexpected' }));
    await assertSucceeds(setDoc(own, item));
    await assertFails(setDoc(own, { ...item, createdAt: new Date('2026-09-29T19:00:00Z') }));
  });

  await test('outfits are private and tied to the owner and document ID', async () => {
    await env.clearFirestore();
    const path = 'users/alice/outfits/outfit_001';
    await assertSucceeds(setDoc(doc(alice.firestore(), path), outfit));
    await assertSucceeds(getDoc(doc(alice.firestore(), path)));
    await assertFails(getDoc(doc(bob.firestore(), path)));
    await assertFails(setDoc(doc(bob.firestore(), path), outfit));
    await assertFails(setDoc(doc(alice.firestore(), path), { ...outfit, ownerId: 'bob' }));
  });

  await test('only signed-in users read posts; publication and legacy paths stay closed', async () => {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (admin) => {
      await setDoc(doc(admin.firestore(), 'posts/post_001'), { authorId: 'alice' });
      await setDoc(doc(admin.firestore(), 'CLOTHING/legacy_001'), { id: 'legacy_001' });
    });
    await assertSucceeds(getDoc(doc(bob.firestore(), 'posts/post_001')));
    await assertFails(getDoc(doc(guest.firestore(), 'posts/post_001')));
    await assertFails(setDoc(doc(alice.firestore(), 'posts/post_002'), { authorId: 'alice' }));
    await assertFails(getDoc(doc(alice.firestore(), 'CLOTHING/legacy_001')));
  });

  await test('private JPEG media is owner-only and size/type-limited', async () => {
    await env.clearStorage();
    const own = ref(alice.storage(bucket), imagePath);
    const other = ref(bob.storage(bucket), imagePath);
    const anonymous = ref(guest.storage(bucket), imagePath);
    await assertFails(uploadBytes(other, jpeg, { contentType: 'image/jpeg' }));
    await assertFails(uploadBytes(anonymous, jpeg, { contentType: 'image/jpeg' }));
    await assertFails(uploadBytes(own, jpeg, { contentType: 'image/png' }));
    await assertFails(uploadBytes(own, new Uint8Array(0), { contentType: 'image/jpeg' }));
    await assertSucceeds(uploadBytes(own, jpeg, { contentType: 'image/jpeg' }));
    await assertSucceeds(getMetadata(own));
    await assertFails(getMetadata(other));
    await assertFails(deleteObject(other));
    await assertFails(uploadBytes(ref(alice.storage(bucket), 'posts/alice/post_001/photo.jpg'), jpeg, { contentType: 'image/jpeg' }));
    await assertSucceeds(deleteObject(own));
  });
} finally {
  await env.cleanup();
}
