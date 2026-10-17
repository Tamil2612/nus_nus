const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const { sendExpenseNotifications } = require('./notifications');

// Initialize Firebase Admin
admin.initializeApp();

// Initialize Gemini AI (API key from environment variable or functions config)
const apiKey = process.env.GEMINI_API_KEY || (functions.config().gemini && functions.config().gemini.api_key) || '';
const genAI = new GoogleGenerativeAI(apiKey);

// Firestore instance
const db = admin.firestore();

// Gemini AI Service Function
exports.parseBillWithAI = functions.https.onCall(async (data, context) => {
  // Check authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'The function must be called while authenticated.'
    );
  }

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
exports.queryAppState = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'The function must be called while authenticated.'
    );
  }

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

// Owner-only group deletion callable. The client cannot delete expenses added
// by other members, so recursive deletion must run with Admin privileges.
exports.deleteGroup = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in to delete this group.');
  }
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
    const [objects] = await admin.storage().bucket().getFiles({
      prefix: `groups/${groupId}/chat/`
    });
    await Promise.all(objects.map((object) => object.delete()));
    await db.recursiveDelete(groupRef);
    return { deleted: true };
  } catch (error) {
    console.error('deleteGroup failed:', error);
    throw new functions.https.HttpsError('internal', 'Could not completely delete the group. Please try again.');
  }
});

// Health check function
exports.healthCheck = functions.https.onRequest((req, res) => {
  res.status(200).send({ status: 'OK', timestamp: new Date().toISOString() });
});

// Record an external pairwise settlement against existing expense shares.
// This does not move money and never creates a synthetic expense/payment record.
exports.recordPairSettlement = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in to record a settlement.');
  }

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
      if (!fromPerson || !toPerson ||
          (fromPerson.linkedUserId !== context.auth.uid &&
           toPerson.linkedUserId !== context.auth.uid)) {
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
      const allocate = (payerId, debtorId, centsToAllocate) => {
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
      allocate(fromId, toId, reverseCents);
      allocate(toId, fromId, reverseCents + requestedCents + legacyForwardCents - legacyReverseCents);
      const writes = [...writesByPath.values()];
      for (const write of writes) {
        tx.update(write.ref, { settledAmounts: write.settledAmounts });
      }
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
exports.recordCrossGroupPairSettlement = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in to record a settlement.');
  }

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
        if (!fromPerson || !toPerson ||
            (fromPerson.linkedUserId !== context.auth.uid &&
             toPerson.linkedUserId !== context.auth.uid)) {
          throw new functions.https.HttpsError('permission-denied', 'Only one of the two people in this debt can confirm it.');
        }
        const expensesRef = groupRef.collection('expenses');
        const expensesSnap = await tx.get(expensesRef);
        const docs = expensesSnap.docs.slice().sort((a, b) => {
          const at = a.data().createdAt && a.data().createdAt.toMillis ? a.data().createdAt.toMillis() : 0;
          const bt = b.data().createdAt && b.data().createdAt.toMillis ? b.data().createdAt.toMillis() : 0;
          return at - bt || a.id.localeCompare(b.id);
        });
        snapshots.push({ ...item, group, docs, expenseDocs: docs.filter((doc) => doc.data().isSettlement !== true) });
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
      let reverseRemaining = reverseCents;
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
          reverseRemaining -= applyCents;
        }
      }
      if (reverseRemaining > 0) {
        throw new functions.https.HttpsError('failed-precondition', 'Could not reconcile all opposing debts safely.');
      }

      const forwardTarget = reverseCents + requestedCents + legacyForwardCents - legacyReverseCents;
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
          forwardRemaining -= applyCents;
        }
      }
      if (forwardRemaining > 0) {
        throw new functions.https.HttpsError('failed-precondition', 'Could not allocate the full net settlement safely.');
      }

      for (const write of writesByPath.values()) {
        tx.update(write.ref, { settledAmounts: write.settledAmounts });
      }
    });
    return { success: true };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    console.error('recordCrossGroupPairSettlement failed:', error);
    throw new functions.https.HttpsError('internal', 'Could not record cross-group settlement. Refresh and try again.');
  }
});
