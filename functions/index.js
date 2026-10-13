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