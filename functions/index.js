const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const { sendExpenseNotifications } = require('./notifications');
const {
  groupAllocationsByExpense,
  subtractAllocations,
  canRevert,
  settlementAllocationTargets,
  balancesByCounterparty,
} = require('./settlement_log');

// Initialize Firebase Admin
admin.initializeApp();

// Initialize Gemini AI (API key from environment variable or functions config)
const apiKey = process.env.GEMINI_API_KEY || (functions.config().gemini && functions.config().gemini.api_key) || '';
const genAI = new GoogleGenerativeAI(apiKey);

// Firestore instance
const db = admin.firestore();
const { normalizeLookupPhone } = require('./phone_lookup');
const {
  ExpenseValidationError,
  normalizeExpenseInput,
  validateExpensePeople,
  assertInitialSettledBy,
  normalizeSettledByUpdate,
  assertCoveredSharesUnchanged,
} = require('./expense_validation');

// App Check enforcement for every callable. Off by default so existing builds
// keep working; once the apps send App Check tokens (see lib/main.dart) set
// ENFORCE_APP_CHECK=true in functions/.env and redeploy.
const enforceAppCheck = process.env.ENFORCE_APP_CHECK === 'true';
const callable = functions.runWith({ enforceAppCheck });

async function assertAccountActive(uid) {
  const userSnap = await db.collection('users').doc(uid).get();
  if (userSnap.exists && userSnap.data().accountDeletionInProgress === true) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'This account is being deleted and can no longer make changes.',
    );
  }
}

// Gemini AI Service Function
exports.parseBillWithAI = callable.https.onCall(async (data, context) => {
  // Check authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'The function must be called while authenticated.'
    );
  }
  await assertAccountActive(context.auth.uid);

  const { imageBase64, instructions, memberNames } = data;

  // Bound untrusted input before sending it to a paid external model.
  if (typeof instructions !== 'string' || instructions.trim().length === 0 ||
      instructions.length > 4000 ||
      !Array.isArray(memberNames) || memberNames.length < 1 ||
      memberNames.length > 50 ||
      memberNames.some((name) => typeof name !== 'string' ||
        name.trim().length === 0 || name.length > 80) ||
      (imageBase64 != null && (typeof imageBase64 !== 'string' ||
        imageBase64.length > 8 * 1024 * 1024))) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Provide instructions (up to 4,000 characters), 1–50 valid member names, and an optional image under 8 MB.'
    );
  }

  try {
    // Prepare content for Gemini
    const model = genAI.getGenerativeModel({ model: 'gemini-3.6-flash' });

    let prompt = `
---
USER INSTRUCTIONS: ${instructions}
MEMBER LIST: ${memberNames.join(', ')}
---

STRICT CALCULATION RULES:
1. OVERRIDE DEFAULT LOGIC: Use specific percentages or amounts if provided.
2. SUM INTEGRITY: Sum of splitMap MUST equal amount.

EXAMPLE 1 (Exclusion):
Instructions: "Total 100. Person A paid. Split between all except Person B."
Result: {"description": "...", "amount": 100, "payerName": "Person A", "splitMap": {"Person A": 50, "Person C": 50}}

JSON Schema:
{
  "description": "string",
  "amount": number,
  "payerName": "string",
  "splitMap": { "MemberName": number }
}
`;

    // Generate content
    const parts = [];
    if (imageBase64) {
      parts.push({ inlineData: { data: imageBase64, mimeType: 'image/jpeg' } });
    }
    parts.push(prompt);
    const result = await model.generateContent(parts);

    const response = await result.response;
    const text = response.text();

    // Clean up potential markdown formatting from AI response
    let cleanJson = text.trim();
    if (cleanJson.startsWith('```json')) {
      cleanJson = cleanJson.substring(7);
    }
    if (cleanJson.endsWith('```')) {
      cleanJson = cleanJson.substring(0, cleanJson.length - 3);
    }
    cleanJson = cleanJson.trim();

    // Parse JSON response
    const parsedResult = JSON.parse(cleanJson);

    // Validate response structure
    if (typeof parsedResult.description !== 'string' ||
        parsedResult.description.trim().length === 0 ||
        parsedResult.description.length > 200 ||
        typeof parsedResult.amount !== 'number' ||
        !Number.isFinite(parsedResult.amount) ||
        parsedResult.amount <= 0 ||
        parsedResult.amount > 100000000 ||
        typeof parsedResult.payerName !== 'string' ||
        !memberNames.some((name) => name.toLowerCase() === parsedResult.payerName.trim().toLowerCase()) ||
        !parsedResult.splitMap ||
        typeof parsedResult.splitMap !== 'object' ||
        Array.isArray(parsedResult.splitMap)) {
      throw new Error('AI response contains invalid expense fields or an unknown payer');
    }

    const normalizedSplits = {};
    let splitTotal = 0;
    const validNames = new Map(memberNames.map((name) => [name.toLowerCase(), name]));
    for (const [rawName, rawAmount] of Object.entries(parsedResult.splitMap)) {
      const canonicalName = validNames.get(rawName.trim().toLowerCase());
      if (!canonicalName || typeof rawAmount !== 'number' ||
          !Number.isFinite(rawAmount) || rawAmount < 0 || rawAmount > parsedResult.amount) {
        throw new Error('AI response contains an unknown member or invalid split amount');
      }
      normalizedSplits[canonicalName] = (normalizedSplits[canonicalName] || 0) + rawAmount;
      splitTotal += rawAmount;
    }
    if (Object.keys(normalizedSplits).length === 0 ||
        !Object.values(normalizedSplits).some((amount) => amount > 0) ||
        Math.abs(splitTotal - parsedResult.amount) > 0.02) {
      throw new Error('AI split amounts do not add up to the receipt total');
    }

    return {
      description: parsedResult.description.trim(),
      amount: parsedResult.amount,
      payerName: memberNames.find((name) => name.toLowerCase() === parsedResult.payerName.trim().toLowerCase()),
      splitMap: normalizedSplits
    };
  } catch (error) {
    console.error('Error in parseBillWithAI:', error);
    if (error.message.includes('quota')) {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        'AI service quota exceeded. Please try again later.'
      );
    }
    throw new functions.https.HttpsError(
      'internal',
      'Failed to parse bill with AI. Please try again.'
    );
  }
});

// Query App State with AI Function
exports.queryAppState = callable.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'The function must be called while authenticated.'
    );
  }
  await assertAccountActive(context.auth.uid);

  const { userQuery, appContext } = data;

  if (!userQuery) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing required field: userQuery'
    );
  }

  try {
    const model = genAI.getGenerativeModel({ model: 'gemini-3.6-flash' });

    const prompt = `
You are a helpful AI assistant for the Nus·Nus app (a bill splitting application).
Answer the user's questions based on the provided app context (groups, expenses, member balances).
Be friendly, clear, and concise.

APP CONTEXT:
${appContext || 'No context available.'}

USER QUERY:
${userQuery}
`;

    const result = await model.generateContent(prompt);
    const response = await result.response;
    const text = response.text();

    return {
      response: text || "I couldn't process your query."
    };
  } catch (error) {
    console.error('Error in queryAppState:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to query app state with AI.'
    );
  }
});

// Push notification to the people included in a newly created expense.
// Targeting, message text and token cleanup live in ./notifications.js (unit
// tested). Tokens live in users/{uid}/private/push as { tokens: [..] }.
exports.onExpenseCreated = functions.firestore
  .document('groups/{groupId}/expenses/{expenseId}')
  .onCreate(async (snapshot, context) => {
    try {
      const stats = await sendExpenseNotifications({
        db,
        messaging: admin.messaging(),
        fieldValue: admin.firestore.FieldValue,
        groupId: context.params.groupId,
        expenseId: context.params.expenseId,
        expense: snapshot.data(),
      });
      console.log('onExpenseCreated', context.params.expenseId, JSON.stringify(stats));
    } catch (error) {
      // Never fail/retry the trigger over a notification problem.
      console.error('Error sending expense notification:', error);
    }
    return null;
  });

// Notify active group members about chat messages; exclude the sender.
exports.onGroupMessageCreated = functions.firestore
  .document('groups/{groupId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data() || {};
    const senderUid = typeof message.senderUid === 'string' ? message.senderUid : '';
    if (!senderUid || (!String(message.text || '').trim() && !message.imagePath)) return null;
    try {
      const groupSnap = await db.collection('groups').doc(context.params.groupId).get();
      if (!groupSnap.exists) return null;
      const group = groupSnap.data() || {};
      if (group.isPersonal === true) return null;
      const recipients = [...new Set((Array.isArray(group.memberUids) ? group.memberUids : [])
        .filter((uid) => typeof uid === 'string' && uid && uid !== senderUid))];
      const pushDocs = await Promise.all(recipients.map((uid) =>
        db.collection('users').doc(uid).collection('private').doc('push').get()));
      const title = String(group.name || 'Group chat').slice(0, 60);
      const preview = message.imagePath ? 'Shared a photo' : String(message.text || '').trim().slice(0, 100);
      const payloads = [];
      const owners = [];
      pushDocs.forEach((doc, index) => {
        if (!doc.exists) return;
        const tokens = Array.isArray((doc.data() || {}).tokens)
          ? doc.data().tokens.filter((token) => typeof token === 'string' && token)
          : [];
        tokens.forEach((token) => {
          payloads.push({
            token,
            notification: { title, body: `${String(message.senderName || 'A member').slice(0, 40)}: ${preview}` },
            data: { type: 'group_message', groupId: context.params.groupId, messageId: context.params.messageId },
            android: { priority: 'high', notification: { channelId: 'expenses', sound: 'default' } },
            apns: { payload: { aps: { sound: 'default', 'thread-id': context.params.groupId } } }
          });
          owners.push({ uid: recipients[index], token });
        });
      });
      for (let start = 0; start < payloads.length; start += 500) {
        const response = await admin.messaging().sendEach(payloads.slice(start, start + 500));
        const removals = new Map();
        response.responses.forEach((result, index) => {
          if (result.success) return;
          const code = result.error && result.error.code;
          if (code === 'messaging/registration-token-not-registered' ||
              code === 'messaging/invalid-registration-token') {
            const owner = owners[start + index];
            if (!removals.has(owner.uid)) removals.set(owner.uid, []);
            removals.get(owner.uid).push(owner.token);
          } else {
            console.warn('Group message notification failed:', code || result.error);
          }
        });
        await Promise.all([...removals].map(([uid, tokens]) =>
          db.collection('users').doc(uid).collection('private').doc('push')
            .update({ tokens: admin.firestore.FieldValue.arrayRemove(...tokens) })));
      }
    } catch (error) {
      console.error('Error sending group chat notification:', error);
    }
    return null;
  });

// Expense financial fields are validated server-side because Firestore rules
// cannot safely sum a dynamic map of shares. Clients must use this callable;
// Admin SDK writes bypass the client rules after all checks have passed.
exports.saveExpense = callable.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in to save an expense.');
  }
  await assertAccountActive(context.auth.uid);
  const groupId = typeof data.groupId === 'string' ? data.groupId.trim() : '';
  const expenseId = typeof data.expenseId === 'string' ? data.expenseId.trim() : '';
  const operation = data.operation;
  if (!groupId || groupId.includes('/') || groupId.length > 200 ||
      !expenseId || expenseId.includes('/') || expenseId.length > 200 ||
      !['create', 'update', 'toggleSettledBy'].includes(operation)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid expense request.');
  }

  const groupRef = db.collection('groups').doc(groupId);
  const expenseRef = groupRef.collection('expenses').doc(expenseId);
  try {
    return await db.runTransaction(async (tx) => {
      const groupSnap = await tx.get(groupRef);
      if (!groupSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'Group not found.');
      }
      const group = groupSnap.data();
      if (!Array.isArray(group.memberUids) || !group.memberUids.includes(context.auth.uid)) {
        throw new functions.https.HttpsError('permission-denied', 'You are not a member of this group.');
      }

      if (operation === 'create') {
        const expense = normalizeExpenseInput(data.expense);
        validateExpensePeople(expense, group, { creatorUid: context.auth.uid });
        assertInitialSettledBy(expense);
        tx.create(expenseRef, {
          desc: expense.desc,
          amount: expense.amount,
          payerId: expense.payerId,
          splitMap: expense.splitMap,
          isSettlement: false,
          settledBy: expense.settledBy,
          settledAmounts: {},
          addedBy: context.auth.uid,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return { success: true };
      }

      const currentSnap = await tx.get(expenseRef);
      if (!currentSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'Expense not found.');
      }
      const current = currentSnap.data();
      if (current.addedBy !== context.auth.uid) {
        throw new functions.https.HttpsError('permission-denied', 'Only the expense author can edit it.');
      }
      if (current.isSettlement === true) {
        throw new functions.https.HttpsError('failed-precondition', 'Legacy settlement expenses cannot be edited.');
      }

      if (operation === 'toggleSettledBy') {
        const normalized = normalizeSettledByUpdate(data.settledBy, current);
        tx.update(expenseRef, { settledBy: normalized });
        return { success: true };
      }

      const expense = normalizeExpenseInput(data.expense);
      validateExpensePeople(expense, group);
      // An edit also writes settledBy, so it gets the same guard as a toggle.
      assertCoveredSharesUnchanged(current, expense.settledBy);
      const currentSettledAmounts = current.settledAmounts || {};
      const hasPairSettlement = Object.values(currentSettledAmounts)
        .some((value) => Number(value) > 0.005);
      if (hasPairSettlement &&
          (expense.amountCents !== Math.round(Number(current.amount) * 100) ||
            JSON.stringify(expense.splitMap) !== JSON.stringify(current.splitMap))) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'This expense has a recorded pair settlement and its amount or split cannot change.',
        );
      }
      tx.update(expenseRef, {
        desc: expense.desc,
        amount: expense.amount,
        payerId: current.payerId,
        splitMap: expense.splitMap,
        isSettlement: false,
        settledBy: expense.settledBy,
      });
      return { success: true };
    });
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    if (error instanceof ExpenseValidationError) {
      throw new functions.https.HttpsError(error.code, error.message);
    }
    // Firestore ALREADY_EXISTS: the expense was already saved (a retried create).
    if (error && error.code === 6) {
      throw new functions.https.HttpsError('already-exists', 'This expense was already saved.');
    }
    console.error('saveExpense failed:', error);
    throw new functions.https.HttpsError('internal', 'Could not save the expense.');
  }
});

// Owner-only group deletion callable. The client cannot delete expenses added
// by other members, so recursive deletion must run with Admin privileges.
exports.deleteGroup = callable.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in to delete this group.');
  }
  await assertAccountActive(context.auth.uid);
  const groupId = typeof data.groupId === 'string' ? data.groupId.trim() : '';
  if (!groupId || groupId.length > 200 || groupId.includes('/')) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid group ID.');
  }
  const groupRef = db.collection('groups').doc(groupId);
  const groupSnap = await groupRef.get();
  if (!groupSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Group not found.');
  }
  if (groupSnap.data().ownerId !== context.auth.uid) {
    throw new functions.https.HttpsError('permission-denied', 'Only the group owner can delete this group.');
  }
  try {
    await deleteGroupData(groupId);
    return { deleted: true };
  } catch (error) {
    console.error('deleteGroup failed:', error);
    throw new functions.https.HttpsError('internal', 'Could not completely delete the group. Please try again.');
  }
});

// Allows a group member to leave while preserving ledger history. Owners must
// atomically transfer ownership to an active registered member before leaving.
exports.leaveGroup = callable.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in to leave this group.');
  }
  const uid = context.auth.uid;
  await assertAccountActive(uid);
  const groupId = typeof data.groupId === 'string' ? data.groupId.trim() : '';
  const transferToUid = typeof data.transferToUid === 'string'
    ? data.transferToUid.trim() : '';
  if (!groupId || groupId.length > 200 || groupId.includes('/') ||
      (transferToUid && (transferToUid === uid || transferToUid.length > 128))) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid group leave request.');
  }

  const groupRef = db.collection('groups').doc(groupId);
  let ownerName = '';
  try {
    await db.runTransaction(async (tx) => {
      const snapshot = await tx.get(groupRef);
      if (!snapshot.exists) {
        throw new functions.https.HttpsError('not-found', 'Group not found.');
      }
      const group = snapshot.data();
      if (group.isPersonal === true) {
        throw new functions.https.HttpsError('failed-precondition', 'Your personal ledger cannot be left.');
      }
      const memberUids = Array.isArray(group.memberUids) ? group.memberUids : [];
      const members = Array.isArray(group.members) ? group.members : [];
      const isOwner = group.ownerId === uid;

      if (!isOwner && !memberUids.includes(uid)) {
        throw new functions.https.HttpsError('permission-denied', 'You are not an active member of this group.');
      }
      if (isOwner && !transferToUid) {
        throw new functions.https.HttpsError('failed-precondition', 'Transfer ownership before leaving the group.');
      }
      if (!isOwner && transferToUid) {
        throw new functions.https.HttpsError('invalid-argument', 'Only the owner can transfer ownership.');
      }

      const person = members.find((member) => member && member.linkedUserId === uid) ||
        (isOwner ? members.find((member) => member && Number(member.id) === 1) : null);
      const expensesSnap = await tx.get(groupRef.collection('expenses'));
      const pairBalances = person
        ? Object.values(balancesByCounterparty(
          expensesSnap.docs.map((doc) => doc.data()), person.id))
        : [];
      if (pairBalances.some((balance) => balance < -0.005)) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          `Settle every amount you owe to other members before leaving this group.`,
        );
      }
      if (pairBalances.some((balance) => balance > 0.005) &&
          (!data || data.acknowledgeUnsettled !== true)) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Acknowledge the unsettled balance owed to you before leaving this group.',
        );
      }

      let nextOwner = null;
      if (isOwner) {
        nextOwner = members.find((member) => member &&
          member.linkedUserId === transferToUid && member.archived !== true &&
          memberUids.includes(transferToUid));
        if (!nextOwner) {
          throw new functions.https.HttpsError('failed-precondition', 'Choose an active registered member of this group.');
        }
        ownerName = String(nextOwner.name || 'Member').slice(0, 80);
      }

      const updatedMembers = members.map((member) =>
        member && member.linkedUserId === uid
          ? { ...member, name: 'Former member', linkedUserId: null, archived: true }
          : member);
      tx.update(groupRef, {
        ...(isOwner ? { ownerId: transferToUid, ownerName } : {}),
        memberUids: memberUids.filter((memberUid) => memberUid !== uid),
        members: updatedMembers,
      });
    });

    // Keep chat content while removing the departed account's display name.
    // Membership has already been safely changed, so message cleanup is best
    // effort and cannot turn a completed leave into a misleading failure.
    try {
      const messages = await groupRef.collection('messages')
        .where('senderUid', '==', uid).get();
      for (let start = 0; start < messages.docs.length; start += 400) {
        const batch = db.batch();
        for (const message of messages.docs.slice(start, start + 400)) {
          batch.update(message.ref, { senderName: 'Former member' });
        }
        await batch.commit();
      }
    } catch (error) {
      console.error('leaveGroup chat anonymization failed:', error);
    }
    return { left: true, ownershipTransferred: Boolean(transferToUid) };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    console.error('leaveGroup failed:', error);
    throw new functions.https.HttpsError('internal', 'Could not leave the group. Please try again.');
  }
});

async function getGroupsForAccount(uid) {
  const [memberGroups, ownedGroups, personalGroup] = await Promise.all([
    db.collection('groups').where('memberUids', 'array-contains', uid).get(),
    db.collection('groups').where('ownerId', '==', uid).get(),
    db.collection('groups').doc(`personal_${uid}`).get(),
  ]);
  const byId = new Map();
  for (const snapshot of [memberGroups, ownedGroups]) {
    for (const doc of snapshot.docs) byId.set(doc.id, doc);
  }
  if (personalGroup.exists) byId.set(personalGroup.id, personalGroup);
  return [...byId.values()];
}

async function getGroupPairBalances(groupDoc, uid) {
  const group = groupDoc.data();
  const members = Array.isArray(group.members) ? group.members : [];
  const person = members.find((member) => member && member.linkedUserId === uid) ||
    (group.ownerId === uid
      ? members.find((member) => member && Number(member.id) === 1)
      : null);
  if (!person) return [];
  const expenses = await groupDoc.ref.collection('expenses').get();
  const balances = balancesByCounterparty(
    expenses.docs.map((doc) => doc.data()), person.id);
  return Object.entries(balances).map(([personId, balance]) => {
    const counterparty = members.find((member) =>
      member && String(member.id) === personId);
    return {
      personId,
      personName: String(counterparty && counterparty.name || 'Former member'),
      balance,
    };
  });
}

// Returns the owner handoff choices before the UI asks the user to confirm
// account deletion. Only active, registered group members are valid owners.
exports.getAccountDeletionPlan = callable.https.onCall(async (_data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in to review account deletion.');
  }
  try {
    const uid = context.auth.uid;
    const groups = await getGroupsForAccount(uid);
    const sharedGroups = groups.filter((doc) => doc.data().isPersonal !== true);
    const groupBalances = await Promise.all(sharedGroups.map(async (doc) => {
      const group = doc.data();
      const counterpartyBalances = await getGroupPairBalances(doc, uid);
      return {
        groupId: doc.id,
        name: String(group.name || 'Untitled group').slice(0, 100),
        currency: String(group.currency || 'AED').toUpperCase(),
        balance: counterpartyBalances.reduce((sum, item) => sum + item.balance, 0),
        counterpartyBalances,
      };
    }));
    const balanceById = new Map(groupBalances.map((item) => [item.groupId, item]));
    const ownedGroups = sharedGroups
      .filter((doc) => doc.data().ownerId === uid)
      .map((doc) => {
        const group = doc.data();
        const memberUids = Array.isArray(group.memberUids) ? group.memberUids : [];
        const candidates = (Array.isArray(group.members) ? group.members : [])
          .filter((member) => member && member.archived !== true &&
            typeof member.linkedUserId === 'string' &&
            member.linkedUserId !== uid && memberUids.includes(member.linkedUserId))
          .map((member) => ({
            uid: member.linkedUserId,
            name: String(member.name || 'Member').slice(0, 80),
          }))
          .filter((candidate, index, all) =>
            all.findIndex((item) => item.uid === candidate.uid) === index);
        return {
          groupId: doc.id,
          name: String(group.name || 'Untitled group').slice(0, 100),
          candidates,
          balance: balanceById.get(doc.id)?.balance || 0,
          currency: balanceById.get(doc.id)?.currency || String(group.currency || 'AED').toUpperCase(),
        };
      });
    return { ownedGroups, groupBalances };
  } catch (error) {
    console.error('getAccountDeletionPlan failed:', error);
    throw new functions.https.HttpsError('internal', 'Could not load the account deletion plan. Please try again.');
  }
});

async function deleteGroupData(groupId) {
  const groupRef = db.collection('groups').doc(groupId);
  const groupSnap = await groupRef.get();
  if (!groupSnap.exists) return;
  const [objects] = await admin.storage().bucket().getFiles({
    prefix: `groups/${groupId}/chat/`,
  });
  for (let i = 0; i < objects.length; i += 100) {
    await Promise.all(objects.slice(i, i + 100).map((object) => object.delete()));
  }
  await db.recursiveDelete(groupRef);
}

// Account deletion is deliberately server-owned: the client cannot transfer
// group ownership, unlink members, or recursively remove another user's data.
exports.deleteAccountData = functions.runWith({ timeoutSeconds: 540, memory: '1GB', enforceAppCheck })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Sign in again before deleting your account.');
    }
    const uid = context.auth.uid;
    const authTime = Number(context.auth.token && context.auth.token.auth_time);
    if (!Number.isFinite(authTime) || Date.now() / 1000 - authTime > 5 * 60) {
      throw new functions.https.HttpsError('failed-precondition', 'Please confirm your password again and retry.');
    }

    const transfers = data && data.transfers && typeof data.transfers === 'object' &&
      !Array.isArray(data.transfers) ? data.transfers : {};
    const deleteGroupIds = Array.isArray(data && data.deleteGroupIds)
      ? data.deleteGroupIds : [];
    if (data && data.acknowledgeUnsettled != null &&
        typeof data.acknowledgeUnsettled !== 'boolean') {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid unsettled-balance acknowledgement.');
    }
    if (deleteGroupIds.length > 100 ||
        deleteGroupIds.some((id) => typeof id !== 'string' || !id || id.length > 200 || id.includes('/')) ||
        Object.keys(transfers).length > 100 ||
        Object.entries(transfers).some(([groupId, targetUid]) =>
          !groupId || groupId.length > 200 || groupId.includes('/') ||
          typeof targetUid !== 'string' || !targetUid || targetUid === uid)) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid group ownership choices.');
    }
    const deleteIds = new Set(deleteGroupIds);
    const transferEntries = Object.entries(transfers);
    if (deleteIds.size !== deleteGroupIds.length ||
        transferEntries.some(([groupId]) => deleteIds.has(groupId))) {
      throw new functions.https.HttpsError('invalid-argument', 'Choose one action for each group.');
    }

    try {
      // Re-read all owned groups before changing anything. Newly created or
      // newly acquired groups must also receive an explicit user decision.
      const ownedSnapshot = await db.collection('groups').where('ownerId', '==', uid).get();
      const ownedShared = ownedSnapshot.docs.filter((doc) => doc.data().isPersonal !== true);
      for (const doc of ownedShared) {
        if (!deleteIds.has(doc.id) && !Object.prototype.hasOwnProperty.call(transfers, doc.id)) {
          throw new functions.https.HttpsError('failed-precondition', 'Review every shared group you own before deleting your account.');
        }
      }

      // Validate every transfer before performing any deletion or transfer.
      for (const [groupId, targetUid] of transferEntries) {
        const groupRef = db.collection('groups').doc(groupId);
        const groupSnap = await groupRef.get();
        if (!groupSnap.exists) {
          throw new functions.https.HttpsError('failed-precondition', 'A group selected for transfer no longer exists. Refresh the plan and try again.');
        }
        const group = groupSnap.data();
        if (group.isPersonal === true) {
          throw new functions.https.HttpsError('invalid-argument', 'Personal ledgers cannot be transferred.');
        }
        if (group.ownerId === targetUid) continue; // completed during a retry
        if (group.ownerId !== uid) {
          throw new functions.https.HttpsError('failed-precondition', 'A group owner changed. Refresh the plan and try again.');
        }
        const memberUids = Array.isArray(group.memberUids) ? group.memberUids : [];
        const recipient = (Array.isArray(group.members) ? group.members : []).find((member) =>
          member && member.linkedUserId === targetUid && member.archived !== true &&
          memberUids.includes(targetUid));
        if (!recipient) {
          throw new functions.https.HttpsError('failed-precondition', 'Every new owner must be an active, registered member of that group.');
        }
      }

      for (const groupId of deleteIds) {
        const groupSnap = await db.collection('groups').doc(groupId).get();
        if (!groupSnap.exists) continue; // completed during a retry
        const group = groupSnap.data();
        if (group.ownerId !== uid || group.isPersonal === true) {
          throw new functions.https.HttpsError('permission-denied', 'Only a shared group you own can be deleted here.');
        }
      }

      // Check all shared group balances before any deletion or ownership
      // transfer starts. Debtors must settle first; creditors must explicitly
      // acknowledge unsettled receivables before account deletion.
      const accountGroups = await getGroupsForAccount(uid);
      for (const groupDoc of accountGroups) {
        const group = groupDoc.data();
        if (group.isPersonal === true) continue;
        const pairBalances = await getGroupPairBalances(groupDoc, uid);
        if (pairBalances.some((item) => item.balance < -0.005)) {
          throw new functions.https.HttpsError(
            'failed-precondition',
            `Settle every amount you owe to other members in “${group.name || 'this group'}” before deleting your account.`,
          );
        }
        if (pairBalances.some((item) => item.balance > 0.005) &&
            (!data || data.acknowledgeUnsettled !== true)) {
          throw new functions.https.HttpsError(
            'failed-precondition',
            'Acknowledge the unsettled balances owed to you before deleting your account.',
          );
        }
      }

      // Block writes from other signed-in devices before starting cleanup.
      // This callable remains allowed so a failed cleanup can be retried.
      await db.collection('users').doc(uid).set({
        accountDeletionInProgress: true,
        accountDeletionStartedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      for (const groupId of deleteIds) await deleteGroupData(groupId);

      const transferredGroupIds = [];
      for (const [groupId, targetUid] of transferEntries) {
        const groupRef = db.collection('groups').doc(groupId);
        await db.runTransaction(async (tx) => {
          const groupSnap = await tx.get(groupRef);
          if (!groupSnap.exists) {
            throw new functions.https.HttpsError('failed-precondition', 'A group selected for transfer no longer exists.');
          }
          const group = groupSnap.data();
          if (group.ownerId === targetUid) return; // completed during a retry
          if (group.ownerId !== uid) {
            throw new functions.https.HttpsError('failed-precondition', 'A group owner changed. Refresh the plan and try again.');
          }
          const memberUids = Array.isArray(group.memberUids) ? group.memberUids : [];
          const recipient = (Array.isArray(group.members) ? group.members : []).find((member) =>
            member && member.linkedUserId === targetUid && member.archived !== true &&
            memberUids.includes(targetUid));
          if (!recipient) {
            throw new functions.https.HttpsError('failed-precondition', 'The selected new owner is no longer an active group member.');
          }
          tx.update(groupRef, {
            ownerId: targetUid,
            ownerName: String(recipient.name || 'Member').slice(0, 80),
            memberUids: [...new Set([...memberUids, targetUid])],
          });
        });
        transferredGroupIds.push(groupId);
      }

      // Delete all personal ledgers. The deterministic path also catches
      // legacy personal documents that are missing ownerId/memberUids.
      const personalIds = new Set([`personal_${uid}`]);
      const currentOwned = await db.collection('groups').where('ownerId', '==', uid).get();
      for (const doc of currentOwned.docs) {
        if (doc.data().isPersonal === true) personalIds.add(doc.id);
      }
      for (const groupId of personalIds) await deleteGroupData(groupId);

      // Remove account access while retaining shared ledger rows. Historical
      // participant IDs and amounts remain stable; identifying labels become
      // “Former member” so the remaining group history stays understandable.
      const memberGroupSnapshot = await db.collection('groups')
        .where('memberUids', 'array-contains', uid).get();
      const groupsToUpdate = new Map(memberGroupSnapshot.docs.map((doc) => [doc.id, doc]));
      for (const groupId of transferredGroupIds) {
        const groupDoc = await db.collection('groups').doc(groupId).get();
        if (groupDoc.exists) groupsToUpdate.set(groupId, groupDoc);
      }
      let messageBatch = db.batch();
      let messageWrites = 0;
      // Query each retained group's messages separately. A collection-group
      // query requires a manually-created index in this project, and would
      // otherwise fail after destructive cleanup had already started.
      for (const groupDoc of groupsToUpdate.values()) {
        // Chat images are private to the sender's account path. Re-list the
        // prefix after each deletion batch so retries safely resume even if a
        // previous attempt stopped partway through.
        const imagePrefix = `groups/${groupDoc.id}/chat/${uid}/`;
        const bucket = admin.storage().bucket();
        while (true) {
          const [files] = await bucket.getFiles({ prefix: imagePrefix, maxResults: 100 });
          if (files.length === 0) break;
          await Promise.all(files.map((file) => file.delete({ ignoreNotFound: true })));
        }

        const messages = groupDoc.ref.collection('messages');
        const [senderMessages, imageMessages] = await Promise.all([
          messages.where('senderUid', '==', uid).get(),
          // Also catch legacy message records that have the sender's Storage
          // path but no senderUid field.
          messages.where('imagePath', '>=', imagePrefix)
            .where('imagePath', '<', `${imagePrefix}\uf8ff`).get(),
        ]);
        const messageDocs = new Map();
        for (const doc of [...senderMessages.docs, ...imageMessages.docs]) {
          messageDocs.set(doc.id, doc);
        }
        for (const messageDoc of messageDocs.values()) {
          const message = messageDoc.data();
          const update = {};
          if (message.senderUid === uid ||
              (typeof message.imagePath === 'string' && message.imagePath.startsWith(imagePrefix))) {
            update.senderName = 'Former member';
          }
          if (typeof message.imagePath === 'string' && message.imagePath.startsWith(imagePrefix)) {
            update.imagePath = admin.firestore.FieldValue.delete();
          }
          // Older clients stored a download URL rather than imagePath. These
          // URLs are still account-owned chat images and must not outlive them.
          if (message.senderUid === uid && typeof message.imageUrl === 'string') {
            update.imageUrl = admin.firestore.FieldValue.delete();
          }
          if ((Object.prototype.hasOwnProperty.call(update, 'imagePath') ||
              Object.prototype.hasOwnProperty.call(update, 'imageUrl')) &&
              !String(message.text || '').trim()) update.text = '[image removed]';
          messageBatch.update(messageDoc.ref, update);
          messageWrites++;
          if (messageWrites === 400) {
            await messageBatch.commit();
            messageBatch = db.batch();
            messageWrites = 0;
          }
        }
      }
      if (messageWrites > 0) await messageBatch.commit();

      // Keep membership discoverable until image and message cleanup finish,
      // so a retry after a partial failure can still find every retained group.
      let groupBatch = db.batch();
      let groupWrites = 0;
      for (const doc of groupsToUpdate.values()) {
        const group = doc.data();
        if (group.ownerId === uid) {
          throw new functions.https.HttpsError('failed-precondition', 'A shared group still belongs to this account. No account data was removed.');
        }
        const members = (Array.isArray(group.members) ? group.members : []).map((member) =>
          member && member.linkedUserId === uid
            ? { ...member, name: 'Former member', linkedUserId: null, archived: true }
            : member);
        groupBatch.update(doc.ref, {
          memberUids: (Array.isArray(group.memberUids) ? group.memberUids : []).filter((id) => id !== uid),
          members,
        });
        groupWrites++;
        if (groupWrites === 400) {
          await groupBatch.commit();
          groupBatch = db.batch();
          groupWrites = 0;
        }
      }
      if (groupWrites > 0) await groupBatch.commit();

      // Replace the profile with a non-PII tombstone and remove private push
      // tokens. The marker blocks writes if Auth deletion needs to be retried.
      const userRef = db.collection('users').doc(uid);
      await userRef.set({
        accountDeletionInProgress: true,
        accountDeletionStartedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      await db.recursiveDelete(userRef.collection('private'));
      // Contact lookup rate limits are stored separately from the profile and
      // must also be removed when the account is deleted.
      await db.collection('phoneLookupRateLimits').doc(uid).delete();
      try {
        await admin.auth().deleteUser(uid);
      } catch (error) {
        if (error.code !== 'auth/user-not-found') throw error;
      }
      try {
        await userRef.delete();
      } catch (error) {
        // Account and private profile data are already gone. This leaves only
        // a non-PII tombstone, which is safe to remove operationally later.
        console.error('Could not remove account-deletion tombstone:', error);
      }
      return { deleted: true };
    } catch (error) {
      if (error instanceof functions.https.HttpsError) throw error;
      console.error('deleteAccountData failed:', error);
      throw new functions.https.HttpsError('internal', 'Account cleanup did not finish. Sign in and retry; completed steps are safe to repeat.');
    }
  });

// Health check function
exports.healthCheck = functions.https.onRequest((req, res) => {
  res.status(200).send({ status: 'OK', timestamp: new Date().toISOString() });
});

// Record an external pairwise settlement against existing expense shares.
// This does not move money and never creates a synthetic expense/payment record.
exports.recordPairSettlement = callable.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in to record a settlement.');
  }
  await assertAccountActive(context.auth.uid);

  const groupId = typeof data.groupId === 'string' ? data.groupId.trim() : '';
  const fromId = Number(data.fromId);
  const toId = Number(data.toId);
  const amount = Number(data.amount);
  if (!groupId || !Number.isSafeInteger(fromId) || !Number.isSafeInteger(toId) ||
      fromId === toId || !Number.isFinite(amount) || amount <= 0 ||
      amount > 100000000) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid settlement details.');
  }
  const requestedCents = Math.round(amount * 100);
  if (Math.abs(requestedCents / 100 - amount) > 0.005) {
    throw new functions.https.HttpsError('invalid-argument', 'Settlement must be in whole cents.');
  }

  const groupRef = db.collection('groups').doc(groupId);
  const expensesRef = groupRef.collection('expenses');

  try {
    await db.runTransaction(async (tx) => {
      const groupSnap = await tx.get(groupRef);
      if (!groupSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'Group not found.');
      }
      const group = groupSnap.data();
      const memberUids = Array.isArray(group.memberUids) ? group.memberUids : [];
      if (!memberUids.includes(context.auth.uid)) {
        throw new functions.https.HttpsError('permission-denied', 'You are not a member of this group.');
      }
      const people = Array.isArray(group.members) ? group.members : [];
      const fromPerson = people.find((p) => Number(p.id) === fromId);
      const toPerson = people.find((p) => Number(p.id) === toId);
      const fromIsMe = !!fromPerson && fromPerson.linkedUserId === context.auth.uid;
      const toIsMe = !!toPerson && toPerson.linkedUserId === context.auth.uid;
      if (!fromPerson || !toPerson || fromIsMe === toIsMe) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'Only one of the two people in this debt can confirm it.'
        );
      }

      const expensesSnap = await tx.get(expensesRef);
      const docs = expensesSnap.docs.slice().sort((a, b) => {
        const at = a.data().createdAt && a.data().createdAt.toMillis
          ? a.data().createdAt.toMillis() : 0;
        const bt = b.data().createdAt && b.data().createdAt.toMillis
          ? b.data().createdAt.toMillis() : 0;
        return at - bt || a.id.localeCompare(b.id);
      });
      // Legacy settlement cards remain part of the ledger but must never be
      // mutated by the new allocator, which only reconciles real expense shares.
      const expenseDocs = docs.filter((doc) => doc.data().isSettlement !== true);

      const outstandingFor = (expense, personId) => {
        const splits = expense.splitMap || {};
        const share = Number(splits[String(personId)] ?? splits[personId] ?? 0);
        if (!Number.isFinite(share) || share <= 0) return 0;
        const rawSettled = expense.settledBy;
        const settled = Array.isArray(rawSettled)
          ? rawSettled.map(String).includes(String(personId))
          : !!(rawSettled && rawSettled[String(personId)] === true);
        if (settled) return 0;
        const rawAmounts = expense.settledAmounts || {};
        const already = Number(rawAmounts[String(personId)] ?? 0);
        return Math.max(0, Math.round((share - already) * 100));
      };

      let forwardCents = 0;
      let reverseCents = 0;
      let legacyForwardCents = 0;
      let legacyReverseCents = 0;
      for (const doc of expenseDocs) {
        const expense = doc.data();
        const payerId = Number(expense.payerId);
        if (payerId === toId) forwardCents += outstandingFor(expense, fromId);
        if (payerId === fromId) reverseCents += outstandingFor(expense, toId);
      }
      // Old releases wrote settlement cards as negative ledger entries. Count
      // them when validating the current net, but do not allocate against them.
      for (const doc of docs) {
        const settlement = doc.data();
        if (settlement.isSettlement !== true) continue;
        const payerId = Number(settlement.payerId);
        const splits = settlement.splitMap || {};
        if (payerId === fromId) {
          legacyForwardCents += Math.round(Number(splits[String(toId)] ?? splits[toId] ?? 0) * 100);
        }
        if (payerId === toId) {
          legacyReverseCents += Math.round(Number(splits[String(fromId)] ?? splits[fromId] ?? 0) * 100);
        }
      }
      const netCents = forwardCents - reverseCents - legacyForwardCents + legacyReverseCents;
      if (legacyReverseCents > reverseCents) {
        throw new functions.https.HttpsError('failed-precondition', 'Legacy settlement history cannot be reconciled safely. Please review the affected group.');
      }
      const { reverseAllocationCents, forwardTargetCents } = settlementAllocationTargets({ reverseCents, legacyForwardCents, legacyReverseCents, requestedCents });
      if (netCents <= 0) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'The debt direction changed. Refresh balances and try again.'
        );
      }
      if (requestedCents > netCents) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Settlement amount exceeds the current net balance. Refresh and try again.'
        );
      }

      // Opposing debts are netted first. If B owes A 100 and A owes B 40,
      // then a net settlement of 60 reconciles B's full 100 share and A's
      // 40 share, while only 60 represents the external amount paid.
      const writesByPath = new Map();
      const allocations = [];
      const allocate = (payerId, debtorId, centsToAllocate) => {
        if (!Number.isSafeInteger(centsToAllocate) || centsToAllocate < 0) {
          throw new functions.https.HttpsError(
            'failed-precondition',
            'Legacy settlement history cannot be reconciled safely. Please review the affected group.'
          );
        }
        let remaining = centsToAllocate;
        for (const doc of expenseDocs) {
          if (remaining <= 0) break;
          const expense = doc.data();
          if (Number(expense.payerId) !== payerId) continue;
          const shareCents = outstandingFor(expense, debtorId);
          if (shareCents <= 0) continue;
          const applyCents = Math.min(remaining, shareCents);
          const priorWrite = writesByPath.get(doc.ref.path);
          const rawAmounts = priorWrite
            ? priorWrite.settledAmounts
            : (expense.settledAmounts || {});
          const nextAmounts = { ...rawAmounts };
          const previousCents = Math.round(Number(rawAmounts[String(debtorId)] || 0) * 100);
          nextAmounts[String(debtorId)] = (previousCents + applyCents) / 100;
          writesByPath.set(doc.ref.path, { ref: doc.ref, settledAmounts: nextAmounts });
          allocations.push({ expenseId: doc.id, personId: debtorId, cents: applyCents });
          remaining -= applyCents;
        }
        if (remaining > 0) {
          throw new functions.https.HttpsError(
            'failed-precondition',
            'Could not allocate the full settlement to existing shares.'
          );
        }
      };

      // Reconcile all reverse-direction debt as an offset, then apply the
      // user's actual settlement amount to the forward debt. This preserves
      // the net balance after partial settlements and avoids fake payments.
      allocate(fromId, toId, reverseAllocationCents);
      allocate(toId, fromId, forwardTargetCents);
      const writes = [...writesByPath.values()];
      for (const write of writes) {
        tx.update(write.ref, { settledAmounts: write.settledAmounts });
      }

      const logRef = groupRef.collection('settlements').doc();
      tx.set(logRef, {
        batchId: logRef.id,
        groupIds: [groupId],
        groupId,
        fromId,
        toId,
        amountCents: requestedCents,
        offsetCents: reverseAllocationCents,
        currency: String(group.currency || 'AED').toUpperCase(),
        recordedBy: context.auth.uid,
        participantUids: [fromPerson.linkedUserId, toPerson.linkedUserId].filter(Boolean),
        allocations,
        status: 'active',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    return { success: true };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    console.error('recordPairSettlement failed:', error);
    throw new functions.https.HttpsError('internal', 'Could not record settlement. Refresh and try again.');
  }
});


// Atomically settles one person's combined net balance with another across
// several groups in the same currency. Opposing debts are reconciled first;
// only the net amount is treated as paid outside Nus·Nus.
exports.recordCrossGroupPairSettlement = callable.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in to record a settlement.');
  }
  await assertAccountActive(context.auth.uid);

  const amount = Number(data.amount);
  const groupsInput = data.groups;
  if (!Number.isFinite(amount) || amount < 0 || amount > 100000000 ||
      !Array.isArray(groupsInput) || groupsInput.length < 1 || groupsInput.length > 50) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid cross-group settlement details.');
  }
  const requestedCents = Math.round(amount * 100);
  if (Math.abs(requestedCents / 100 - amount) > 0.005) {
    throw new functions.https.HttpsError('invalid-argument', 'Settlement must be in whole cents.');
  }

  const normalizedGroups = [];
  const seenGroupIds = new Set();
  for (const item of groupsInput) {
    const groupId = item && typeof item.groupId === 'string' ? item.groupId.trim() : '';
    const fromId = Number(item && item.fromId);
    const toId = Number(item && item.toId);
    if (!groupId || !Number.isSafeInteger(fromId) || !Number.isSafeInteger(toId) ||
        fromId === toId || seenGroupIds.has(groupId)) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid group or participant in settlement.');
    }
    seenGroupIds.add(groupId);
    normalizedGroups.push({ groupId, fromId, toId });
  }

  try {
    await db.runTransaction(async (tx) => {
      const snapshots = [];
      // All reads are completed before any writes, as required by Firestore transactions.
      for (const item of normalizedGroups) {
        const groupRef = db.collection('groups').doc(item.groupId);
        const groupSnap = await tx.get(groupRef);
        if (!groupSnap.exists) {
          throw new functions.https.HttpsError('not-found', 'A group in this settlement no longer exists.');
        }
        const group = groupSnap.data();
        const memberUids = Array.isArray(group.memberUids) ? group.memberUids : [];
        if (!memberUids.includes(context.auth.uid)) {
          throw new functions.https.HttpsError('permission-denied', 'You are not a member of every group in this settlement.');
        }
        const people = Array.isArray(group.members) ? group.members : [];
        const fromPerson = people.find((p) => Number(p.id) === item.fromId);
        const toPerson = people.find((p) => Number(p.id) === item.toId);
        const fromIsMe = !!fromPerson && fromPerson.linkedUserId === context.auth.uid;
        const toIsMe = !!toPerson && toPerson.linkedUserId === context.auth.uid;
        if (!fromPerson || !toPerson || fromIsMe === toIsMe) {
          throw new functions.https.HttpsError('permission-denied', 'The authenticated user must be exactly one side of each pair.');
        }
        const counterpart = fromIsMe ? toPerson : fromPerson;
        // People who left or deleted their account all share the display name
        // "Former member", so they must never be merged by name across groups.
        const isFormerMember = counterpart.archived === true &&
          String(counterpart.name || '') === 'Former member';
        const counterpartKey = counterpart.linkedUserId
          ? 'uid:' + counterpart.linkedUserId
          : isFormerMember
            ? 'former:' + item.groupId + ':' + counterpart.id
            : 'name:' + String(counterpart.name || '').trim().toLowerCase();
        const expensesRef = groupRef.collection('expenses');
        const expensesSnap = await tx.get(expensesRef);
        const docs = expensesSnap.docs.slice().sort((a, b) => {
          const at = a.data().createdAt && a.data().createdAt.toMillis ? a.data().createdAt.toMillis() : 0;
          const bt = b.data().createdAt && b.data().createdAt.toMillis ? b.data().createdAt.toMillis() : 0;
          return at - bt || a.id.localeCompare(b.id);
        });
        snapshots.push({ ...item, group, docs, expenseDocs: docs.filter((doc) => doc.data().isSettlement !== true), counterpartKey, fromIsMe, fromPerson, toPerson, allocations: [] });
      }
      const expectedCounterpart = snapshots[0].counterpartKey;
      const expectedDirection = snapshots[0].fromIsMe;
      if (snapshots.some((item) => item.counterpartKey !== expectedCounterpart || item.fromIsMe !== expectedDirection)) {
        throw new functions.https.HttpsError('invalid-argument', 'All groups must refer to the same person and settlement direction.');
      }

      const outstandingFor = (expense, personId) => {
        const splits = expense.splitMap || {};
        const share = Number(splits[String(personId)] ?? splits[personId] ?? 0);
        if (!Number.isFinite(share) || share <= 0) return 0;
        const rawSettled = expense.settledBy;
        const settled = Array.isArray(rawSettled)
          ? rawSettled.map(String).includes(String(personId))
          : !!(rawSettled && rawSettled[String(personId)] === true);
        if (settled) return 0;
        const rawAmounts = expense.settledAmounts || {};
        const already = Number(rawAmounts[String(personId)] ?? 0);
        return Math.max(0, Math.round((share - already) * 100));
      };

      const currencySet = new Set(snapshots.map((item) => String(item.group.currency || 'AED').toUpperCase()));
      if (currencySet.size !== 1) {
        throw new functions.https.HttpsError('invalid-argument', 'Only groups using the same currency can be settled together.');
      }

      let forwardCents = 0;
      let reverseCents = 0;
      let legacyForwardCents = 0;
      let legacyReverseCents = 0;
      for (const item of snapshots) {
        for (const doc of item.expenseDocs) {
          const expense = doc.data();
          const payerId = Number(expense.payerId);
          if (payerId === item.toId) forwardCents += outstandingFor(expense, item.fromId);
          if (payerId === item.fromId) reverseCents += outstandingFor(expense, item.toId);
        }
        for (const doc of item.docs) {
          const settlement = doc.data();
          if (settlement.isSettlement !== true) continue;
          const payerId = Number(settlement.payerId);
          const splits = settlement.splitMap || {};
          if (payerId === item.fromId) {
            legacyForwardCents += Math.round(Number(splits[String(item.toId)] ?? splits[item.toId] ?? 0) * 100);
          }
          if (payerId === item.toId) {
            legacyReverseCents += Math.round(Number(splits[String(item.fromId)] ?? splits[item.fromId] ?? 0) * 100);
          }
        }
      }

      const netCents = forwardCents - reverseCents - legacyForwardCents + legacyReverseCents;
      if (legacyReverseCents > reverseCents) {
        throw new functions.https.HttpsError('failed-precondition', 'Legacy settlement history cannot be reconciled safely. Please review the affected groups.');
      }
      const { reverseAllocationCents, forwardTargetCents } = settlementAllocationTargets({ reverseCents, legacyForwardCents, legacyReverseCents, requestedCents });
      if (netCents < 0) {
        throw new functions.https.HttpsError('failed-precondition', 'The debt direction changed. Refresh balances and try again.');
      }
      if (requestedCents === 0 && netCents !== 0) {
        throw new functions.https.HttpsError('failed-precondition', 'A zero-amount settlement is only valid when opposite debts cancel out.');
      }
      if (requestedCents > netCents) {
        throw new functions.https.HttpsError('failed-precondition', 'Settlement amount exceeds the current combined net balance.');
      }

      const writesByPath = new Map();
      // Reconcile opposite debts across all included groups first, then the
      // requested net amount. The direction IDs are consistent per group.
      // Allocate reverse shares per group; this callback keeps IDs group-local.
      let reverseRemaining = reverseAllocationCents;
      for (const item of snapshots) {
        for (const doc of item.expenseDocs) {
          if (reverseRemaining <= 0) break;
          const expense = doc.data();
          if (Number(expense.payerId) !== item.fromId) continue;
          const shareCents = outstandingFor(expense, item.toId);
          if (shareCents <= 0) continue;
          const applyCents = Math.min(reverseRemaining, shareCents);
          const priorWrite = writesByPath.get(doc.ref.path);
          const rawAmounts = priorWrite ? priorWrite.settledAmounts : (expense.settledAmounts || {});
          const nextAmounts = { ...rawAmounts };
          const previousCents = Math.round(Number(rawAmounts[String(item.toId)] || 0) * 100);
          nextAmounts[String(item.toId)] = (previousCents + applyCents) / 100;
          writesByPath.set(doc.ref.path, { ref: doc.ref, settledAmounts: nextAmounts });
          item.allocations.push({ expenseId: doc.id, personId: item.toId, cents: applyCents });
          reverseRemaining -= applyCents;
        }
      }
      if (reverseRemaining > 0) {
        throw new functions.https.HttpsError('failed-precondition', 'Could not reconcile all opposing debts safely.');
      }

      const forwardTarget = forwardTargetCents;
      if (forwardTarget < 0) {
        throw new functions.https.HttpsError('failed-precondition', 'Legacy settlement history cannot be reconciled safely.');
      }
      let forwardRemaining = forwardTarget;
      for (const item of snapshots) {
        for (const doc of item.expenseDocs) {
          if (forwardRemaining <= 0) break;
          const expense = doc.data();
          if (Number(expense.payerId) !== item.toId) continue;
          const shareCents = outstandingFor(expense, item.fromId);
          if (shareCents <= 0) continue;
          const applyCents = Math.min(forwardRemaining, shareCents);
          const priorWrite = writesByPath.get(doc.ref.path);
          const rawAmounts = priorWrite ? priorWrite.settledAmounts : (expense.settledAmounts || {});
          const nextAmounts = { ...rawAmounts };
          const previousCents = Math.round(Number(rawAmounts[String(item.fromId)] || 0) * 100);
          nextAmounts[String(item.fromId)] = (previousCents + applyCents) / 100;
          writesByPath.set(doc.ref.path, { ref: doc.ref, settledAmounts: nextAmounts });
          item.allocations.push({ expenseId: doc.id, personId: item.fromId, cents: applyCents });
          forwardRemaining -= applyCents;
        }
      }
      if (forwardRemaining > 0) {
        throw new functions.https.HttpsError('failed-precondition', 'Could not allocate the full net settlement safely.');
      }

      for (const write of writesByPath.values()) {
        tx.update(write.ref, { settledAmounts: write.settledAmounts });
      }

      // One audit-log entry per group, tied together by a shared batchId so
      // the whole cross-group settlement can be undone in one step.
      const batchId = db.collection('groups').doc().id;
      const batchGroupIds = snapshots.map((item) => item.groupId);
      for (const item of snapshots) {
        const logRef = db.collection('groups').doc(item.groupId).collection('settlements').doc();
        tx.set(logRef, {
          batchId,
          groupIds: batchGroupIds,
          groupId: item.groupId,
          fromId: item.fromId,
          toId: item.toId,
          amountCents: requestedCents,
          offsetCents: reverseAllocationCents,
          currency: [...currencySet][0],
          recordedBy: context.auth.uid,
          participantUids: [item.fromPerson.linkedUserId, item.toPerson.linkedUserId].filter(Boolean),
          allocations: item.allocations,
          status: 'active',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    });
    return { success: true };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    console.error('recordCrossGroupPairSettlement failed:', error);
    throw new functions.https.HttpsError('internal', 'Could not record cross-group settlement. Refresh and try again.');
  }
});


// Undoes a recorded settlement (and every other group's part of the same
// cross-group batch) by subtracting exactly what it allocated. Either person
// in the pair may undo, which gives a creditor a way to dispute a payment the
// debtor recorded. The log entry is kept, marked 'reverted'.
exports.revertSettlement = callable.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in to undo a settlement.');
  }
  await assertAccountActive(context.auth.uid);
  const groupId = typeof data.groupId === 'string' ? data.groupId.trim() : '';
  const settlementId = typeof data.settlementId === 'string' ? data.settlementId.trim() : '';
  if (!groupId || !settlementId) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid settlement reference.');
  }
  const uid = context.auth.uid;

  try {
    await db.runTransaction(async (tx) => {
      const requestedRef = db.collection('groups').doc(groupId).collection('settlements').doc(settlementId);
      const requestedSnap = await tx.get(requestedRef);
      if (!requestedSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'Settlement not found.');
      }
      const requested = requestedSnap.data();
      if (requested.status !== 'active') {
        throw new functions.https.HttpsError('failed-precondition', 'This settlement was already undone.');
      }
      if (!canRevert(requested, uid)) {
        throw new functions.https.HttpsError('permission-denied', 'Only the two people in this settlement can undo it.');
      }

      const batchGroupIds = Array.isArray(requested.groupIds) && requested.groupIds.length > 0
        ? requested.groupIds : [groupId];
      const logs = [];
      for (const gid of batchGroupIds) {
        const groupRef = db.collection('groups').doc(gid);
        const groupSnap = await tx.get(groupRef);
        if (!groupSnap.exists) {
          throw new functions.https.HttpsError('failed-precondition', 'A group in this settlement no longer exists.');
        }
        const memberUids = groupSnap.data().memberUids || [];
        if (!memberUids.includes(uid)) {
          throw new functions.https.HttpsError('permission-denied', 'You are not a member of every group in this settlement.');
        }
        const logSnap = await tx.get(groupRef.collection('settlements').where('batchId', '==', requested.batchId));
        for (const doc of logSnap.docs) {
          if (doc.data().status === 'active') logs.push({ gid, ref: doc.ref, data: doc.data() });
        }
      }

      const plans = [];
      for (const log of logs) {
        if (!canRevert(log.data, uid)) {
          throw new functions.https.HttpsError('permission-denied', 'Only the two people in every settlement batch can undo it.');
        }
        const byExpense = groupAllocationsByExpense(log.data.allocations);
        for (const [expenseId, centsByPerson] of Object.entries(byExpense)) {
          const expenseRef = db.collection('groups').doc(log.gid).collection('expenses').doc(expenseId);
          const expenseSnap = await tx.get(expenseRef);
          if (!expenseSnap.exists) {
            throw new functions.https.HttpsError('failed-precondition', 'An expense covered by this settlement no longer exists.');
          }
          const result = subtractAllocations(expenseSnap.data().settledAmounts, centsByPerson);
          if (!result.ok) {
            throw new functions.https.HttpsError('failed-precondition', 'This settlement can no longer be undone because the expenses changed. Contact support.');
          }
          plans.push({ ref: expenseRef, next: result.next });
        }
      }
      if (logs.length === 0) {
        throw new functions.https.HttpsError('failed-precondition', 'No active settlement entries remain in this batch.');
      }
      for (const plan of plans) {
        tx.update(plan.ref, { settledAmounts: plan.next });
      }
      for (const log of logs) {
        tx.update(log.ref, {
          status: 'reverted',
          revertedBy: uid,
          revertedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    });
    return { success: true };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    console.error('revertSettlement failed:', error);
    throw new functions.https.HttpsError('internal', 'Could not undo the settlement. Refresh and try again.');
  }
});


// Indexed batch lookup used by both contact matching and typed-number search.
// Only canonical keys are queried; input phone numbers are never persisted.
exports.lookupRegisteredUsersByPhones = callable.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in to match phone numbers.');
  }
  await assertAccountActive(context.auth.uid);
  const rawPhones = data && data.phoneNumbers;
  if (!Array.isArray(rawPhones) || rawPhones.length < 1 || rawPhones.length > 100 ||
      rawPhones.some((phone) => typeof phone !== 'string' || phone.length > 40)) {
    throw new functions.https.HttpsError('invalid-argument', 'Send between 1 and 100 phone numbers.');
  }
  const phoneKeys = [...new Set(rawPhones.map(normalizeLookupPhone)
    .filter((phone) => phone.length >= 7 && phone.length <= 15))];
  if (phoneKeys.length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'No valid phone numbers were provided.');
  }

  const uid = context.auth.uid;
  const limitRef = db.collection('phoneLookupRateLimits').doc(uid);
  const now = Date.now();
  const today = new Date(now).toISOString().slice(0, 10);
  try {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(limitRef);
      const prior = snap.exists ? snap.data() : {};
      const minuteStart = Number(prior.minuteWindowStart || 0);
      const minuteCount = minuteStart > now - 60000
        ? Number(prior.minuteCount || 0)
        : 0;
      const dailyCount = prior.dailyDate === today
        ? Number(prior.dailyCount || 0)
        : 0;
      if (minuteCount >= 10) {
        throw new functions.https.HttpsError(
          'resource-exhausted',
          'Too many phone searches. Please wait a minute and try again.',
        );
      }
      if (dailyCount + phoneKeys.length > 2000) {
        throw new functions.https.HttpsError(
          'resource-exhausted',
          'Daily phone search limit reached. Try again tomorrow.',
        );
      }
      tx.set(limitRef, {
        minuteWindowStart: minuteCount === 0 ? now : minuteStart,
        minuteCount: minuteCount + 1,
        dailyDate: today,
        dailyCount: dailyCount + phoneKeys.length,
      });
    });

    const matchesByPhone = new Map();
    const ambiguous = new Set();
    const users = db.collection('users');
    // Firestore supports at most 30 values in an `in` query. `phoneKey` has a
    // single-field index, so each query reads only profiles with a requested key.
    for (let start = 0; start < phoneKeys.length; start += 30) {
      const chunk = phoneKeys.slice(start, start + 30);
      const snap = await users.where('phoneKey', 'in', chunk).get();
      for (const doc of snap.docs) {
        if (doc.id === uid || doc.get('discoverableByPhone') === false) continue;
        // Do not trust a client-written index key unless it still agrees with
        // the profile's phone number.
        if (normalizeLookupPhone(doc.get('phoneNumber') || '') !== doc.get('phoneKey')) continue;
        const phone = doc.get('phoneKey');
        if (matchesByPhone.has(phone)) {
          matchesByPhone.delete(phone);
          ambiguous.add(phone);
        } else if (!ambiguous.has(phone)) {
          matchesByPhone.set(phone, {
            uid: doc.id,
            name: typeof doc.get('name') === 'string' && doc.get('name').trim()
              ? doc.get('name').trim()
              : 'Nus·Nus user',
          });
        }
      }
    }
    const matches = Object.fromEntries(matchesByPhone);
    return { matches, ambiguous: [...ambiguous] };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    console.error('lookupRegisteredUsersByPhones failed:', error);
    throw new functions.https.HttpsError('internal', 'Could not match phone numbers. Please try again.');
  }
});