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

  // Validate input
  if (!instructions || !memberNames || !Array.isArray(memberNames)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing required fields: instructions and memberNames are required.'
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
    const result = await model.generateContent([
      {
        inlineData: {
          data: imageBase64,
          mimeType: "image/jpeg"
        }
      },
      prompt
    ]);

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
    if (!parsedResult.description ||
        typeof parsedResult.amount !== 'number' ||
        !parsedResult.payerName ||
        !parsedResult.splitMap ||
        typeof parsedResult.splitMap !== 'object') {
      throw new Error('Invalid response format from AI');
    }

    return {
      description: parsedResult.description,
      amount: parsedResult.amount,
      payerName: parsedResult.payerName,
      splitMap: parsedResult.splitMap
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

// Helper function to calculate settlements
function calculateSettlements(expenses, members) {
  const balances = {};

  // Initialize balances
  members.forEach(member => {
    balances[member] = 0;
  });

  // Calculate balances from expenses
  expenses.forEach(expense => {
    const { amount, payerName, splitMap } = expense;

    // Payer gets positive balance (they're owed money)
    balances[payerName] = (balances[payerName] || 0) + amount;

    // Split amounts are negative (they owe money)
    Object.entries(splitMap).forEach(([member, amount]) => {
      balances[member] = (balances[member] || 0) - amount;
    });
  });

  // Generate settlement transactions
  const settlements = [];
  const debtors = [];
  const creditors = [];

  // Separate debtors and creditors
  Object.entries(balances).forEach(([member, balance]) => {
    if (balance < -0.01) { // owes money (negative balance)
      debtors.push({ member, amount: Math.abs(balance) });
    } else if (balance > 0.01) { // is owed money (positive balance)
      creditors.push({ member, amount: balance });
    }
  });

  // Sort by amount (largest first)
  debtors.sort((a, b) => b.amount - a.amount);
  creditors.sort((a, b) => b.amount - a.amount);

  // Settle debts
  let debtorIndex = 0;
  let creditorIndex = 0;

  while (debtorIndex < debtors.length && creditorIndex < creditors.length) {
    const debtor = debtors[debtorIndex];
    const creditor = creditors[creditorIndex];

    const settlementAmount = Math.min(debtor.amount, creditor.amount);

    settlements.push({
      from: debtor.member,
      to: creditor.member,
      amount: parseFloat(settlementAmount.toFixed(2))
    });

    debtor.amount -= settlementAmount;
    creditor.amount -= settlementAmount;

    if (debtor.amount <= 0.01) debtorIndex++;
    if (creditor.amount <= 0.01) creditorIndex++;
  }

  return settlements;
}

// Settlement Calculation Function
exports.calculateSettlements = functions.https.onCall(async (data, context) => {
  // Check authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'The function must be called while authenticated.'
    );
  }

  const { groupId } = data;

  // Validate input
  if (!groupId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing required field: groupId'
    );
  }

  try {
    // Verify user is member of the group
    const groupDoc = await db.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Group not found'
      );
    }

    const groupData = groupDoc.data();
    const userId = context.auth.uid;

    if (!groupData.memberUids.includes(userId)) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'User is not a member of this group'
      );
    }

    // Fetch all expenses for the group
    const expensesSnapshot = await db.collection('groups')
      .doc(groupId)
      .collection('expenses')
      .get();

    const expenses = [];
    expensesSnapshot.forEach(doc => {
      const expenseData = doc.data();
      expenses.push({
        id: doc.id,
        amount: expenseData.amount,
        payerName: expenseData.addedByName || expenseData.addedBy,
        splitMap: expenseData.splitMap || {},
        description: expenseData.description || '',
        timestamp: expenseData.timestamp ? expenseData.timestamp.toDate() : null
      });
    });

    // Get member names
    const memberUids = groupData.memberUids || [];
    const memberNames = [];

    // In a real app, you'd fetch member names from user profiles
    // For now, we'll use the UIDs as names or fetch from MemberDirectory
    for (const uid of memberUids) {
      if (uid === userId) {
        // Try to get current user's display name
        memberNames.push('You'); // Placeholder
      } else {
        memberNames.push(`User ${uid.substring(0, 8)}`); // Placeholder
      }
    }

    // Calculate settlements
    const settlements = calculateSettlements(expenses, memberNames);

    return {
      settlements,
      expensesCount: expenses.length,
      memberCount: memberNames.length
    };
  } catch (error) {
    console.error('Error in calculateSettlements:', error);
    if (error.code === 'permission-denied' || error.code === 'not-found') {
      throw error;
    }
    throw new functions.https.HttpsError(
      'internal',
      'Failed to calculate settlements. Please try again.'
    );
  }
});

// Add member to group function
exports.addMemberToGroup = functions.https.onCall(async (data, context) => {
  // Check authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'The function must be called while authenticated.'
    );
  }

  const { groupId, memberUid } = data;

  // Validate input
  if (!groupId || !memberUid) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing required fields: groupId and memberUid'
    );
  }

  try {
    // Verify user is owner of the group
    const groupDoc = await db.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Group not found'
      );
    }

    const groupData = groupDoc.data();
    const userId = context.auth.uid;

    if (groupData.ownerId !== userId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only the group owner can add members'
      );
    }

    // Check if member is already in group
    if (groupData.memberUids.includes(memberUid)) {
      throw new functions.https.HttpsError(
        'already-exists',
        'Member is already in the group'
      );
    }

    // Add member to group
    await db.collection('groups').doc(groupId).update({
      memberUids: admin.firestore.FieldValue.arrayUnion(memberUid)
    });

    return { success: true };
  } catch (error) {
    console.error('Error in addMemberToGroup:', error);
    if (error.code === 'permission-denied' ||
        error.code === 'not-found' ||
        error.code === 'already-exists') {
      throw error;
    }
    throw new functions.https.HttpsError(
      'internal',
      'Failed to add member to group. Please try again.'
    );
  }
});

// Create group function
exports.createGroup = functions.https.onCall(async (data, context) => {
  // Check authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'The function must be called while authenticated.'
    );
  }

  const { name, currency, description } = data;

  // Validate input
  if (!name || !currency) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing required fields: name and currency'
    );
  }

  try {
    const userId = context.auth.uid;

    // Create group document
    const groupRef = await db.collection('groups').add({
      name: name,
      currency: currency,
      description: description || '',
      ownerId: userId,
      memberUids: [userId], // Owner is automatically a member
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return {
      groupId: groupRef.id,
      success: true
    };
  } catch (error) {
    console.error('Error in createGroup:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to create group. Please try again.'
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

// Health check function
exports.healthCheck = functions.https.onRequest((req, res) => {
  res.status(200).send({ status: 'OK', timestamp: new Date().toISOString() });
});