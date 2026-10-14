'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {
  formatMoney,
  expenseRecipients,
  buildMessage,
  sendExpenseNotifications,
} = require('./notifications');

// Group: Amina (owner, uid A), Sara (uid S), Zayed (uid Z), Omar (no account),
// Lina (uid L, removed/archived).
const group = {
  name: 'Dubai Trip',
  currency: 'AED',
  isPersonal: false,
  memberUids: ['A', 'S', 'Z'],
  members: [
    { id: 1, name: 'Amina', linkedUserId: 'A' },
    { id: 2, name: 'Sara', linkedUserId: 'S' },
    { id: 3, name: 'Zayed', linkedUserId: 'Z' },
    { id: 4, name: 'Omar' },
    { id: 5, name: 'Lina', linkedUserId: 'L', archived: true },
  ],
};

// ---- fakes -----------------------------------------------------------------
function fakeDb(docs) {
  const updates = [];
  const ref = (path) => ({
    get: async () => ({ exists: path in docs, data: () => docs[path] }),
    update: async (patch) => updates.push({ path, patch }),
    collection: (name) => ({ doc: (id) => ref(`${path}/${name}/${id}`) }),
  });
  return {
    updates,
    collection: (name) => ({ doc: (id) => ref(`${name}/${id}`) }),
  };
}
const fieldValue = { arrayRemove: (...items) => ({ remove: items }) };
function fakeMessaging(failures = {}) {
  const sent = [];
  return {
    sent,
    sendEach: async (messages) => {
      sent.push(...messages);
      return {
        responses: messages.map((m) =>
          failures[m.token]
            ? { success: false, error: { code: failures[m.token] } }
            : { success: true }
        ),
      };
    },
  };
}
const push = (...tokens) => ({ tokens });

// ---- recipients --------------------------------------------------------------
test('only people included in the split are notified, minus the payer', () => {
  const expense = { payerId: 1, addedBy: 'A', splitMap: { 1: 30, 2: 30 } }; // Zayed not in split
  const { shares, payerName } = expenseRecipients(expense, group);
  assert.deepEqual([...shares], [['S', 30]]);
  assert.equal(payerName, 'Amina');
});

test('group members who are not in the split get nothing', () => {
  const expense = { payerId: 1, addedBy: 'A', splitMap: { 1: 50, 3: 50 } };
  const { shares } = expenseRecipients(expense, group);
  assert.deepEqual([...shares.keys()], ['Z']);
});

test('people without an account, removed people and zero shares are skipped', () => {
  const expense = {
    payerId: 1,
    addedBy: 'A',
    splitMap: { 2: 0, 3: 20, 4: 20, 5: 20 }, // Sara owes 0, Omar has no account, Lina archived
  };
  const { shares } = expenseRecipients(expense, group);
  assert.deepEqual([...shares], [['Z', 20]]);
});

test('the person who logged the expense is never notified', () => {
  // Sara logs an expense (payer = Sara) and includes herself and Zayed.
  const expense = { payerId: 2, addedBy: 'S', splitMap: { 2: 25, 3: 25 } };
  const { shares } = expenseRecipients(expense, group);
  assert.deepEqual([...shares.keys()], ['Z']);
});

test('a user who left the group (not in memberUids) is skipped', () => {
  const g = { ...group, memberUids: ['A', 'S'] };
  const expense = { payerId: 1, addedBy: 'A', splitMap: { 2: 10, 3: 10 } };
  assert.deepEqual([...expenseRecipients(expense, g).shares.keys()], ['S']);
});

test('malformed data does not throw', () => {
  assert.equal(expenseRecipients({}, {}).shares.size, 0);
  assert.equal(expenseRecipients({ splitMap: null }, group).shares.size, 0);
});

// ---- text ---------------------------------------------------------------------
test('money uses the group currency and its real decimals', () => {
  assert.equal(formatMoney(30, 'AED'), 'AED 30.00');
  assert.equal(formatMoney(1234.5, 'USD'), 'USD 1,234.50');
  assert.equal(formatMoney(5, 'KWD'), 'KWD 5.000');
  assert.equal(formatMoney(5, 'not-a-currency'), 'AED 5.00');
  assert.equal(formatMoney(5, undefined), 'AED 5.00');
});

test('message is high priority, per-device and carries what the app needs to open it', () => {
  const m = buildMessage({ token: 't1', title: 'T', body: 'B', groupId: 'g1', expenseId: 'e1' });
  assert.equal(m.token, 't1');
  assert.deepEqual(m.data, { type: 'expense_created', groupId: 'g1', expenseId: 'e1' });
  assert.ok(Object.values(m.data).every((v) => typeof v === 'string'));
  assert.equal(m.android.priority, 'high');
  assert.equal(m.android.notification.channelId, 'expenses');
  assert.equal(m.apns.headers['apns-priority'], '10');
});

// ---- end to end ------------------------------------------------------------------
test('end to end: each included person gets their own share on every device', async () => {
  const db = fakeDb({
    'groups/g1': group,
    'users/S/private/push': push('s-phone', 's-tablet'),
    'users/Z/private/push': push('z-phone'),
    'users/A/private/push': push('a-phone'), // the payer: must not be messaged
  });
  const messaging = fakeMessaging();
  const expense = {
    desc: 'Dinner',
    amount: 90,
    payerId: 1,
    addedBy: 'A',
    splitMap: { 1: 30, 2: 30, 3: 30 },
  };
  const stats = await sendExpenseNotifications({
    db, messaging, fieldValue, groupId: 'g1', expenseId: 'e1', expense,
  });
  assert.deepEqual(messaging.sent.map((m) => m.token).sort(), ['s-phone', 's-tablet', 'z-phone']);
  assert.match(messaging.sent[0].notification.body, /Amina paid for "Dinner" — your share is AED 30\.00\./);
  assert.equal(messaging.sent[0].notification.title, 'New split in Dubai Trip');
  assert.equal(stats.recipients, 2);
  assert.equal(stats.sent, 3);
});

test('uneven custom splits each show the right amount', async () => {
  const db = fakeDb({
    'groups/g1': group,
    'users/S/private/push': push('s'),
    'users/Z/private/push': push('z'),
  });
  const messaging = fakeMessaging();
  await sendExpenseNotifications({
    db, messaging, fieldValue, groupId: 'g1', expenseId: 'e1',
    expense: { desc: 'Taxi', payerId: 1, addedBy: 'A', splitMap: { 1: 10, 2: 15.5, 3: 74.5 } },
  });
  const bodyFor = (t) => messaging.sent.find((m) => m.token === t).notification.body;
  assert.match(bodyFor('s'), /AED 15\.50/);
  assert.match(bodyFor('z'), /AED 74\.50/);
});

test('dead tokens are removed, other failures are kept', async () => {
  const db = fakeDb({
    'groups/g1': group,
    'users/S/private/push': push('s-old', 's-new'),
    'users/Z/private/push': push('z-flaky'),
  });
  const messaging = fakeMessaging({
    's-old': 'messaging/registration-token-not-registered',
    'z-flaky': 'messaging/internal-error',
  });
  const stats = await sendExpenseNotifications({
    db, messaging, fieldValue, groupId: 'g1', expenseId: 'e1',
    expense: { desc: 'x', payerId: 1, addedBy: 'A', splitMap: { 2: 5, 3: 5 } },
  });
  assert.equal(stats.pruned, 1);
  assert.deepEqual(db.updates, [
    { path: 'users/S/private/push', patch: { tokens: { remove: ['s-old'] } } },
  ]);
});

test('no messages for settlements, personal groups, missing groups or users without tokens', async () => {
  const messaging = fakeMessaging();
  const base = { messaging, fieldValue, groupId: 'g1', expenseId: 'e1' };
  const expense = { desc: 'x', payerId: 1, addedBy: 'A', splitMap: { 2: 5 } };
  const withTokens = { 'users/S/private/push': push('s') };

  await sendExpenseNotifications({ ...base, db: fakeDb({ 'groups/g1': group, ...withTokens }),
    expense: { ...expense, isSettlement: true } });
  await sendExpenseNotifications({ ...base, db: fakeDb({ 'groups/g1': { ...group, isPersonal: true }, ...withTokens }), expense });
  await sendExpenseNotifications({ ...base, db: fakeDb({ ...withTokens }), expense });
  await sendExpenseNotifications({ ...base, db: fakeDb({ 'groups/g1': group }), expense });
  assert.equal(messaging.sent.length, 0);
});

test('large groups are sent in batches of at most 500', async () => {
  const members = [{ id: 1, name: 'Payer', linkedUserId: 'P' }];
  const docs = {};
  const splitMap = {};
  const memberUids = ['P'];
  for (let i = 2; i <= 301; i++) {
    members.push({ id: i, name: `U${i}`, linkedUserId: `u${i}` });
    memberUids.push(`u${i}`);
    docs[`users/u${i}/private/push`] = push(`t${i}a`, `t${i}b`); // 2 devices each = 600
    splitMap[i] = 1;
  }
  docs['groups/g1'] = { name: 'Big', currency: 'USD', memberUids, members };
  let largest = 0;
  const messaging = {
    sendEach: async (batch) => {
      largest = Math.max(largest, batch.length);
      return { responses: batch.map(() => ({ success: true })) };
    },
  };
  const stats = await sendExpenseNotifications({
    db: fakeDb(docs), messaging, fieldValue, groupId: 'g1', expenseId: 'e1',
    expense: { desc: 'x', payerId: 1, addedBy: 'P', splitMap },
  });
  assert.equal(stats.sent, 600);
  assert.ok(largest <= 500);
});
