'use strict';

// Push notifications for "a new expense was added to a group".
//
// Kept free of firebase imports (Firestore / Messaging are passed in) so the
// whole flow can be unit-tested with plain fakes — see notifications.test.js.
//
// Who is told: only people who are *included in the split* and have an
// account — not every member of the group. Never the person who logged the
// expense, and never the person who paid (they fronted the money; the
// notification is "you owe", which doesn't apply to them).

const NOTIFICATION_CHANNEL_ID = 'expenses'; // must match MainActivity.kt / AndroidManifest.xml
const MAX_BATCH = 500; // FCM sendEach limit
const MAX_DESC_LENGTH = 80;
const DEAD_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

function truncate(text, max) {
  const s = String(text == null ? '' : text).trim();
  return s.length > max ? `${s.slice(0, max - 1)}…` : s;
}

// "AED 30.00" — uses the group's own currency (and its real decimal places,
// e.g. 3 for KWD/BHD/OMR). Falls back to a plain format for unknown codes.
function formatMoney(amount, currency) {
  const code =
    typeof currency === 'string' && /^[A-Za-z]{3}$/.test(currency)
      ? currency.toUpperCase()
      : 'AED';
  try {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: code,
      currencyDisplay: 'code',
    })
      .format(amount)
      .replace(/ /g, ' ');
  } catch (_) {
    return `${code} ${Number(amount).toFixed(2)}`;
  }
}

// Works out who to notify and how much each of them owes.
// Returns { shares: Map<uid, amountOwed>, payerName: string|null }.
function expenseRecipients(expense, group) {
  const people = Array.isArray(group.members) ? group.members : [];
  const activeUids = new Set(Array.isArray(group.memberUids) ? group.memberUids : []);
  const byId = new Map(people.map((p) => [String(p.id), p]));

  const payer = byId.get(String(expense.payerId)) || null;
  const skipUids = new Set();
  if (expense.addedBy) skipUids.add(expense.addedBy);
  if (payer && payer.linkedUserId) skipUids.add(payer.linkedUserId);

  const splitMap =
    expense.splitMap && typeof expense.splitMap === 'object' ? expense.splitMap : {};
  const shares = new Map();
  Object.entries(splitMap).forEach(([personId, rawShare]) => {
    const person = byId.get(String(personId));
    const share = Number(rawShare);
    if (!person || person.archived === true || !person.linkedUserId) return; // no account / removed
    const uid = person.linkedUserId;
    if (skipUids.has(uid)) return; // the one who logged / paid
    if (!activeUids.has(uid)) return; // no longer a member of the group
    if (!(share > 0)) return; // nothing owed
    shares.set(uid, (shares.get(uid) || 0) + share);
  });

  return { shares, payerName: payer && payer.name ? String(payer.name) : null };
}

// One FCM message for one device. Sent per device (not multicast) because the
// text contains that person's own share.
function buildMessage({ token, title, body, groupId, expenseId }) {
  return {
    token,
    notification: { title, body },
    // Data values must all be strings. The app reads these to open the expense.
    data: { type: 'expense_created', groupId, expenseId },
    android: {
      priority: 'high',
      ttl: 24 * 60 * 60 * 1000, // drop it if the phone has been offline for a day
      notification: {
        channelId: NOTIFICATION_CHANNEL_ID,
        tag: expenseId, // a retried delivery replaces the earlier one
        sound: 'default',
      },
    },
    apns: {
      headers: { 'apns-priority': '10', 'apns-collapse-id': String(expenseId).slice(0, 64) },
      payload: { aps: { sound: 'default', 'thread-id': groupId } },
    },
  };
}

// Full flow for one newly created expense. Returns a small stats object.
async function sendExpenseNotifications({ db, messaging, fieldValue, groupId, expenseId, expense }) {
  const stats = { recipients: 0, devices: 0, sent: 0, failed: 0, pruned: 0 };
  if (!expense || expense.isSettlement === true) return stats;

  const groupSnap = await db.collection('groups').doc(groupId).get();
  if (!groupSnap.exists) return stats;
  const group = groupSnap.data() || {};
  if (group.isPersonal === true) return stats;

  const { shares, payerName } = expenseRecipients(expense, group);
  if (shares.size === 0) return stats;
  stats.recipients = shares.size;

  const pushRef = (uid) => db.collection('users').doc(uid).collection('private').doc('push');
  const uids = [...shares.keys()];
  const pushDocs = await Promise.all(uids.map((uid) => pushRef(uid).get()));

  const title = `New split in ${truncate(group.name || 'your group', 40)}`;
  const what = truncate(expense.desc || 'an expense', MAX_DESC_LENGTH);
  const who = payerName ? truncate(payerName, 30) : 'Someone';

  const messages = [];
  const owners = []; // owners[i] is who messages[i] was sent to
  pushDocs.forEach((doc, i) => {
    if (!doc.exists) return;
    const uid = uids[i];
    const data = doc.data() || {};
    const tokens = (Array.isArray(data.tokens) ? data.tokens : []).filter(
      (t) => typeof t === 'string' && t.length > 0
    );
    const body = `${who} paid for "${what}" — your share is ${formatMoney(shares.get(uid), group.currency)}.`;
    tokens.forEach((token) => {
      messages.push(buildMessage({ token, title, body, groupId, expenseId }));
      owners.push({ uid, token });
    });
  });
  stats.devices = messages.length;
  if (messages.length === 0) return stats;

  const dead = new Map(); // uid -> tokens FCM says are gone
  for (let start = 0; start < messages.length; start += MAX_BATCH) {
    const res = await messaging.sendEach(messages.slice(start, start + MAX_BATCH));
    res.responses.forEach((r, j) => {
      if (r.success) {
        stats.sent += 1;
        return;
      }
      stats.failed += 1;
      const code = r.error && r.error.code;
      if (DEAD_TOKEN_CODES.has(code)) {
        const owner = owners[start + j];
        if (!dead.has(owner.uid)) dead.set(owner.uid, []);
        dead.get(owner.uid).push(owner.token);
      } else {
        console.warn('Push failed for one device:', code || r.error);
      }
    });
  }

  // Stop trying tokens that no longer exist (app uninstalled, token rotated).
  await Promise.all(
    [...dead].map(([uid, tokens]) => {
      stats.pruned += tokens.length;
      return pushRef(uid).update({ tokens: fieldValue.arrayRemove(...tokens) });
    })
  );
  return stats;
}

module.exports = {
  NOTIFICATION_CHANNEL_ID,
  formatMoney,
  expenseRecipients,
  buildMessage,
  sendExpenseNotifications,
};
