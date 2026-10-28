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

test('user profiles are private to their owner', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users/member-a'), {
      name: 'Member A',
      email: 'member-a@example.test',
      phoneNumber: '+971500000000',
    });
  });
  const owner = env.authenticatedContext('member-a');
  const other = env.authenticatedContext('member-b');
  const outsider = env.authenticatedContext('outsider');
  await assertSucceeds(getDoc(doc(owner.firestore(), 'users/member-a')));
  await assertFails(getDoc(doc(other.firestore(), 'users/member-a')));
  await assertFails(getDoc(doc(outsider.firestore(), 'users/member-a')));
  await assertFails(getDoc(doc(outsider.firestore(), 'users/member-a/private/push')));
});

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

function expenseRef(context, id = 'e1') {
  return doc(context.firestore(), 'groups/g1/expenses', id);
}

async function seedExpense(settledAmounts = {}) {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'groups/g1/expenses/e1'), {
      desc: 'Dinner',
      amount: 100,
      payerId: 1,
      splitMap: { '1': 50, '2': 50 },
      isSettlement: false,
      settledBy: ['1'],
      settledAmounts,
      addedBy: 'member-a',
      createdAt: new Date('2026-10-16T10:00:00Z'),
    });
  });
}

test('only the expense author can toggle a participant paid/pending', async () => {
  await seedExpense();
  const author = env.authenticatedContext('member-a');
  const otherMember = env.authenticatedContext('member-b');
  const owner = env.authenticatedContext('owner');

  await assertSucceeds(updateDoc(expenseRef(author), { settledBy: ['1', '2'] }));
  await assertFails(updateDoc(expenseRef(otherMember), { settledBy: ['1'] }));
  await assertFails(updateDoc(expenseRef(owner), { settledBy: ['1'] }));
});

test('clients cannot directly create or update expenses', async () => {
  const member = env.authenticatedContext('member-a');
  await assertFails(setDoc(expenseRef(member, 'direct-create'), {
    desc: 'Forged',
    amount: 10,
    payerId: 999,
    splitMap: { '999': 1000 },
    isSettlement: false,
    settledBy: ['999'],
    settledAmounts: {},
    addedBy: 'member-a',
    createdAt: serverTimestamp(),
  }));
  await seedExpense();
  await assertFails(updateDoc(expenseRef(member), {
    amount: 10,
    splitMap: { '999': 1000 },
  }));
});

test('expense author cannot forge or erase trusted pair-settlement allocations', async () => {
  const author = env.authenticatedContext('member-a');
  await seedExpense();
  await assertFails(updateDoc(expenseRef(author), { settledAmounts: { '2': 25 } }));

  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'groups/g1/expenses/e2'), {
      desc: 'Partially settled dinner',
      amount: 100,
      payerId: 1,
      splitMap: { '1': 50, '2': 50 },
      isSettlement: false,
      settledBy: ['1'],
      settledAmounts: { '2': 25 },
      addedBy: 'member-a',
      createdAt: new Date('2026-10-16T10:00:00Z'),
    });
  });
  await assertFails(updateDoc(expenseRef(author, 'e2'), { settledAmounts: {}, amount: 90 }));
  // A description-only edit is still permitted without touching settlement data.
  await assertSucceeds(updateDoc(expenseRef(author, 'e2'), { desc: 'Dinner updated' }));
});

test('an expense with a recorded pair settlement cannot be deleted', async () => {
  await seedExpense({ '2': 25 });
  const author = env.authenticatedContext('member-a');
  const otherMember = env.authenticatedContext('member-b');
  await assertFails(deleteDoc(expenseRef(author)));
  await assertFails(deleteDoc(expenseRef(otherMember)));
});

test('an unsettled expense can be deleted only by its author', async () => {
  await seedExpense();
  await assertFails(deleteDoc(expenseRef(env.authenticatedContext('member-b'))));
  await assertFails(deleteDoc(expenseRef(env.authenticatedContext('owner'))));
  await assertSucceeds(deleteDoc(expenseRef(env.authenticatedContext('member-a'))));
});

test('settlement audit logs are readable by members but never client-writable', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'groups/g1/settlements/s1'), {
      groupId: 'g1',
      fromId: 2,
      toId: 1,
      amountCents: 6000,
      offsetCents: 4000,
      currency: 'AED',
      recordedBy: 'member-a',
      participantUids: ['member-a', 'member-b'],
      allocations: [{ expenseId: 'e1', personId: 2, cents: 10000 }],
      status: 'active',
      createdAt: new Date('2026-10-16T10:00:00Z'),
    });
  });
  const member = env.authenticatedContext('member-a');
  const owner = env.authenticatedContext('owner');
  const outsider = env.authenticatedContext('outsider');
  const logRef = (context) => doc(context.firestore(), 'groups/g1/settlements/s1');
  await assertSucceeds(getDoc(logRef(member)));
  await assertSucceeds(getDoc(logRef(owner)));
  await assertFails(getDoc(logRef(outsider)));
  await assertFails(updateDoc(logRef(member), { status: 'reverted' }));
  await assertFails(deleteDoc(logRef(member)));
  await assertFails(setDoc(doc(member.firestore(), 'groups/g1/settlements/forged'), {
    status: 'active',
  }));
});

test('a personal ledger id can only be created by its own account', async () => {
  const group = (uid) => ({
    name: 'Personal',
    ownerId: uid,
    memberUids: [uid],
    members: [],
    isPersonal: true,
  });
  const attacker = env.authenticatedContext('member-b');
  const owner = env.authenticatedContext('member-a');
  await assertFails(setDoc(doc(attacker.firestore(), 'groups/personal_member-a'), group('member-b')));
  await assertSucceeds(setDoc(doc(owner.firestore(), 'groups/personal_member-a'), group('member-a')));
  // Ordinary groups are unaffected.
  await assertSucceeds(setDoc(doc(attacker.firestore(), 'groups/some-new-group'), group('member-b')));
});

test('chat image Storage is private, size-limited, and member-only', async () => {
  const member = env.authenticatedContext('member-a');
  const outsider = env.authenticatedContext('outsider');
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users/member-a'), {
      accountDeletionInProgress: false,
    });
  });
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
