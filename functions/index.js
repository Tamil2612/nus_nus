const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { GoogleGenerativeAI } = require('@google/generative-ai');

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

// Send push notification when a new expense/split is created.
// Tokens live in users/{uid}/private/push as { tokens: [..] }.
exports.onExpenseCreated = functions.firestore
  .document('groups/{groupId}/expenses/{expenseId}')
  .onCreate(async (snapshot, context) => {
    const groupId = context.params.groupId;
    const expense = snapshot.data();
    if (expense.isSettlement) return null;

    const desc = expense.desc || 'New split';
    const amount = expense.amount || 0;

    try {
      const groupDoc = await db.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) return null;
      const group = groupDoc.data();
      if (group.isPersonal) return null;

      const recipients = (group.memberUids || []).filter((uid) => uid !== expense.addedBy);
      const pushRef = (uid) => db.collection('users').doc(uid).collection('private').doc('push');
      const docs = await Promise.all(recipients.map((uid) => pushRef(uid).get()));

      const targets = []; // { uid, token }
      docs.forEach((doc, i) => {
        if (!doc.exists) return;
        (doc.data().tokens || []).forEach((token) => targets.push({ uid: recipients[i], token }));
      });
      if (targets.length === 0) return null;

      const res = await admin.messaging().sendEachForMulticast({
        tokens: targets.map((t) => t.token),
        notification: {
          title: `New split in ${group.name || 'Group'}`,
          body: `${desc} (${amount}) was added.`
        },
        data: { groupId, expenseId: context.params.expenseId },
        android: { notification: { sound: 'default' } },
        apns: { payload: { aps: { sound: 'default' } } }
      });

      // Prune tokens that are no longer valid.
      const dead = {};
      res.responses.forEach((r, i) => {
        const code = r.error && r.error.code;
        if (!r.success && (code === 'messaging/registration-token-not-registered' ||
                           code === 'messaging/invalid-registration-token')) {
          (dead[targets[i].uid] = dead[targets[i].uid] || []).push(targets[i].token);
        }
      });
      await Promise.all(Object.entries(dead).map(([uid, tokens]) =>
        pushRef(uid).update({ tokens: admin.firestore.FieldValue.arrayRemove(...tokens) })));
      return null;
    } catch (error) {
      console.error('Error sending expense notification:', error);
      return null;
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
      const docs = expensesSnap.docs
        .filter((doc) => doc.data().isSettlement !== true)
        .sort((a, b) => {
          const at = a.data().createdAt && a.data().createdAt.toMillis
            ? a.data().createdAt.toMillis() : 0;
          const bt = b.data().createdAt && b.data().createdAt.toMillis
            ? b.data().createdAt.toMillis() : 0;
          return at - bt || a.id.localeCompare(b.id);
        });

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
      for (const doc of docs) {
        const expense = doc.data();
        const payerId = Number(expense.payerId);
        if (payerId === toId) forwardCents += outstandingFor(expense, fromId);
        if (payerId === fromId) reverseCents += outstandingFor(expense, toId);
      }
      const netCents = forwardCents - reverseCents;
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
        for (const doc of docs) {
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
      allocate(toId, fromId, reverseCents + requestedCents);
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
