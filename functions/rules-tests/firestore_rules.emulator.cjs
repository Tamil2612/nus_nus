const fs = require('node:fs');
const path = require('node:path');
const { after, before, beforeEach, test } = require('node:test');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  collection,
  doc,
  getDoc,
  setDoc,
  serverTimestamp,
  updateDoc,
  deleteDoc,
} = require('firebase/firestore');
const {
  ref,
  uploadBytes,
  getBytes,
  deleteObject,
} = require('firebase/storage');

const projectId = 'demo-nus-nus';
let env;
let storagePath;

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8'),
    },
    storage: {
      rules: fs.readFileSync(path.join(__dirname, '../../storage.rules'), 'utf8'),
    },
  });
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'groups/g1'), {
      ownerId: 'owner',
      memberUids: ['owner', 'member-a', 'member-b'],
      name: 'Test group',
    });
  });
});

after(async () => {
  if (env) await env.cleanup();
});

function messageRef(context, id = 'm1') {
  return doc(context.firestore(), 'groups/g1/messages', id);
}

test('only group members can read and create messages', async () => {
  const member = env.authenticatedContext('member-a');
  const outsider = env.authenticatedContext('outsider');
  await assertSucceeds(getDoc(doc(member.firestore(), 'groups/g1')));
  await assertFails(getDoc(doc(outsider.firestore(), 'groups/g1/messages/m1')));
  await assertSucceeds(setDoc(messageRef(member), {
    senderUid: 'member-a',
    senderName: 'Member A',
    text: 'Hello',
    createdAt: serverTimestamp(),
  }));
  await assertFails(setDoc(messageRef(outsider), {
    senderUid: 'outsider',
    senderName: 'Outsider',
    text: 'Hello',
    createdAt: serverTimestamp(),
  }));
});

test('rejects sender spoofing, extra fields, and oversized text', async () => {
  const member = env.authenticatedContext('member-a');
  await assertFails(setDoc(messageRef(member, 'spoof'), {
    senderUid: 'member-b',
    senderName: 'Member B',
    text: 'Spoofed',
    createdAt: serverTimestamp(),
  }));
  await assertFails(setDoc(messageRef(member, 'extra'), {
    senderUid: 'member-a',
    senderName: 'Member A',
    text: 'Hello',
    createdAt: serverTimestamp(),
    arbitrary: true,
  }));
  await assertFails(setDoc(messageRef(member, 'long'), {
    senderUid: 'member-a',
    senderName: 'Member A',
    text: 'x'.repeat(1001),
    createdAt: serverTimestamp(),
  }));
});

test('message authors may edit text but cannot rewrite identity or timestamp', async () => {
  const member = env.authenticatedContext('member-a');
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'groups/g1/messages/m1'), {
      senderUid: 'member-a',
      senderName: 'Member A',
      text: 'Before',
      createdAt: new Date('2026-10-16T10:00:00Z'),
    });
  });
  await assertSucceeds(updateDoc(messageRef(member), { text: 'After', isEdited: true }));
  // Editing a message a second time must fail, even for its original author.
  await assertFails(updateDoc(messageRef(member), { text: 'Edited again', isEdited: true }));
  await assertFails(updateDoc(messageRef(member), { text: 'After', isEdited: true }));
  await assertFails(updateDoc(messageRef(member), { senderName: 'Admin', isEdited: true }));
  await assertFails(updateDoc(messageRef(member), {
    text: 'Reordered',
    createdAt: new Date('2020-01-01T00:00:00Z'),
    isEdited: true,
  }));
  await assertFails(updateDoc(messageRef(env.authenticatedContext('member-b')), {
    text: 'Not mine',
    isEdited: true,
  }));
});

test('only author or group owner can delete a message', async () => {
  const member = env.authenticatedContext('member-a');
  const otherMember = env.authenticatedContext('member-b');
  const owner = env.authenticatedContext('owner');
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'groups/g1/messages/m1'), {
      senderUid: 'member-a',
      senderName: 'Member A',
      text: 'Hello',
      createdAt: new Date('2026-10-16T10:00:00Z'),
    });
  });
  await assertFails(deleteDoc(messageRef(otherMember)));
  await assertSucceeds(deleteDoc(messageRef(member)));
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'groups/g1/messages/m2'), {
      senderUid: 'member-a',
      senderName: 'Member A',
      text: 'Hello again',
      createdAt: new Date('2026-10-16T10:00:00Z'),
    });
  });
  await assertSucceeds(deleteDoc(messageRef(owner, 'm2')));
});

test('chat image Storage is private, size-limited, and member-only', async () => {
  const member = env.authenticatedContext('member-a');
  const outsider = env.authenticatedContext('outsider');
  storagePath = 'groups/g1/chat/member-a/rules-test.jpg';
  const bytes = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);
  await assertSucceeds(uploadBytes(ref(member.storage(), storagePath), bytes, {
    contentType: 'image/jpeg',
  }));
  await assertSucceeds(getBytes(ref(member.storage(), storagePath)));
  await assertFails(getBytes(ref(outsider.storage(), storagePath)));
  await assertFails(uploadBytes(ref(outsider.storage(), 'groups/g1/chat/outsider/bad.jpg'), bytes, {
    contentType: 'image/jpeg',
  }));
  await assertSucceeds(deleteObject(ref(member.storage(), storagePath)));
});
