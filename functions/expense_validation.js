'use strict';

// Pure validation for the saveExpense callable. Nothing here touches Firestore
// or firebase-functions, so every rule can be unit-tested without emulators.

class ExpenseValidationError extends Error {
  constructor(message, code = 'invalid-argument') {
    super(message);
    this.name = 'ExpenseValidationError';
    this.code = code;
  }
}

function fail(message, code) {
  throw new ExpenseValidationError(message, code);
}

// Rounding to the nearest cent always lands within half a cent, so a tolerance
// of 0.005 would accept anything. Only floating-point noise is tolerated.
const CENT_TOLERANCE = 1e-6;

const hasKey = (object, key) => Object.prototype.hasOwnProperty.call(object, key);

function normalizeExpenseInput(raw) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    fail('Invalid expense data.');
  }
  const desc = typeof raw.desc === 'string' ? raw.desc.trim() : '';
  const amount = Number(raw.amount);
  const payerId = Number(raw.payerId);
  const splitMap = raw.splitMap;
  const settledBy = raw.settledBy;
  const isSettlement = raw.isSettlement;
  if (!desc || desc.length > 200 || !Number.isFinite(amount) || amount <= 0 ||
      amount > 100000000 || !Number.isSafeInteger(payerId) ||
      !splitMap || typeof splitMap !== 'object' || Array.isArray(splitMap) ||
      !Array.isArray(settledBy) || isSettlement !== false) {
    fail('Invalid expense fields.');
  }

  const amountCents = Math.round(amount * 100);
  if (Math.abs(amountCents / 100 - amount) > CENT_TOLERANCE) {
    fail('Expense amounts must be in whole cents.');
  }
  const normalizedSplits = {};
  let splitTotalCents = 0;
  for (const [rawId, rawShare] of Object.entries(splitMap)) {
    const personId = String(rawId);
    const share = Number(rawShare);
    const shareCents = Math.round(share * 100);
    if (!/^\d+$/.test(personId) || !Number.isFinite(share) || share < 0 ||
        share > amount || Math.abs(shareCents / 100 - share) > CENT_TOLERANCE) {
      fail('Expense shares must be valid non-negative amounts.');
    }
    normalizedSplits[personId] = shareCents / 100;
    splitTotalCents += shareCents;
  }
  if (Object.keys(normalizedSplits).length === 0 ||
      splitTotalCents !== amountCents) {
    fail('Expense shares must add up exactly to the expense amount.');
  }

  return {
    desc,
    amount: amountCents / 100,
    amountCents,
    payerId,
    splitMap: normalizedSplits,
    settledBy: [...new Set(settledBy.map(String))],
  };
}

// Everyone named in the expense must be a person in the group. The payer is
// the one person who may appear in settledBy without being in the split: when
// someone pays for others and isn't sharing the cost, the app still marks the
// payer as paid.
//
// When [creatorUid] is given (creating an expense), the payer must be that
// user's own member entry. This is the server-side half of the payer lock, so
// a modified client can't log an expense as if someone else paid.
function validateExpensePeople(expense, group, { creatorUid } = {}) {
  const people = Array.isArray(group && group.members) ? group.members : [];
  const validPeople = people.filter((person) =>
    person && Number.isSafeInteger(Number(person.id)));
  const personIds = new Set(validPeople.map((person) => String(Number(person.id))));
  const payerKey = String(expense.payerId);

  if (!personIds.has(payerKey) ||
      Object.keys(expense.splitMap).some((id) => !personIds.has(id))) {
    fail('The payer and every split participant must belong to this group.');
  }
  if (expense.settledBy.some((id) => id !== payerKey && !hasKey(expense.splitMap, id))) {
    fail('Only split participants (or the payer) can be marked as settled.');
  }
  if (creatorUid) {
    const payer = validPeople.find((person) => String(Number(person.id)) === payerKey);
    if (!payer || payer.linkedUserId !== creatorUid) {
      fail('You can only log expenses that you paid.', 'permission-denied');
    }
  }
}

// A brand-new expense may only start with the payer marked as paid.
function assertInitialSettledBy(expense) {
  if (expense.settledBy.some((id) => id !== String(expense.payerId))) {
    fail('Only the payer may be initially marked as settled.');
  }
}

// True when pair settlements already cover this person's whole share. Mirrors
// Expense.isShareCoveredByPairSettlement in the app: a zero share is never
// "covered", and half a cent of slack absorbs floating-point noise.
function isShareCoveredByPairSettlement(current, personId) {
  const key = String(personId);
  const share = Number(((current && current.splitMap) || {})[key] ?? 0);
  const settled = Number(((current && current.settledAmounts) || {})[key] ?? 0);
  return Number.isFinite(share) && share > 0.005 &&
    Number.isFinite(settled) && settled >= share - 0.005;
}

// A share covered by a recorded pair settlement is owned by the settlement
// callables. Marking it paid or pending by hand would desynchronize the two:
// after the settlement is undone, settledAmounts would be restored while a
// leftover settledBy entry kept the balance wrongly closed. Rejects any
// change in settledBy membership for such a share, on both the toggle and the
// edit path (an edit also writes settledBy).
function assertCoveredSharesUnchanged(current, nextSettledBy) {
  const before = new Set(
    (Array.isArray(current && current.settledBy) ? current.settledBy : []).map(String));
  const after = new Set(nextSettledBy.map(String));
  const changed = [...new Set([...before, ...after])]
    .filter((id) => before.has(id) !== after.has(id));
  if (changed.some((id) => isShareCoveredByPairSettlement(current, id))) {
    fail(
      'A share covered by a recorded settlement cannot be marked paid or pending ' +
      'manually. Undo the settlement first.',
      'failed-precondition',
    );
  }
}

// Validates a paid/pending toggle against the stored expense and returns the
// normalized list to write.
function normalizeSettledByUpdate(settledBy, current) {
  if (!Array.isArray(settledBy)) fail('Invalid settlement status.');
  const normalized = [...new Set(settledBy.map(String))];
  const payerKey = String(current && current.payerId);
  const splitMap = (current && current.splitMap) || {};
  if (normalized.some((id) => id !== payerKey && !hasKey(splitMap, id))) {
    fail('Only participants in the expense can be marked as settled.');
  }
  assertCoveredSharesUnchanged(current, normalized);
  return normalized;
}

module.exports = {
  ExpenseValidationError,
  normalizeExpenseInput,
  validateExpensePeople,
  assertInitialSettledBy,
  normalizeSettledByUpdate,
  isShareCoveredByPairSettlement,
  assertCoveredSharesUnchanged,
};