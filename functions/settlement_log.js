'use strict';

// Pure helpers shared by the settlement callables. Nothing here touches
// Firestore, so the undo maths can be unit-tested without an emulator.

// Collapses a list of {expenseId, personId, cents} allocations into
// { expenseId: { personId: cents } }.
function groupAllocationsByExpense(allocations) {
  const byExpense = {};
  for (const item of Array.isArray(allocations) ? allocations : []) {
    const cents = Number(item && item.cents);
    if (!item || !item.expenseId || !Number.isSafeInteger(cents) || cents <= 0) {
      continue;
    }
    const expenseId = String(item.expenseId);
    const personId = String(item.personId);
    byExpense[expenseId] = byExpense[expenseId] || {};
    byExpense[expenseId][personId] = (byExpense[expenseId][personId] || 0) + cents;
  }
  return byExpense;
}

// Subtracts previously allocated cents from an expense's settledAmounts map.
// Returns { ok: true, next } or { ok: false } when the stored amounts no
// longer cover what the settlement allocated (data changed underneath it).
function subtractAllocations(currentAmounts, centsByPerson) {
  const next = { ...(currentAmounts || {}) };
  for (const [personId, cents] of Object.entries(centsByPerson)) {
    const currentCents = Math.round(Number(next[personId] || 0) * 100);
    if (currentCents < cents) return { ok: false };
    const remaining = currentCents - cents;
    if (remaining <= 0) {
      delete next[personId];
    } else {
      next[personId] = remaining / 100;
    }
  }
  return { ok: true, next };
}

// Computes how many cents must be allocated to real expense shares.
//
// Legacy settlement cards stay in the ledger as separate NEGATIVE entries
// (see SettlementCalculator.deriveLedgerEntries), so they already reduce the
// balance and must NOT also be allocated onto real shares, or the ledger
// would overshoot and show the creditor owing the debtor that amount.
//
//   net = forward - reverse - legacyForward + legacyReverse
//
// Reverse debt covered by legacy cards is skipped; the rest is offset. The
// forward target is that offset plus the cash actually paid, which leaves
// the ledger balance at exactly (net - requested).
function settlementAllocationTargets({ reverseCents, legacyForwardCents, legacyReverseCents, requestedCents }) {
  const values = [reverseCents, legacyForwardCents, legacyReverseCents, requestedCents];
  if (!values.every(Number.isSafeInteger) || values.some((value) => value < 0) ||
      legacyReverseCents > reverseCents) {
    throw new RangeError('Invalid or unreconcilable settlement allocation inputs.');
  }
  const reverseAllocationCents = reverseCents - legacyReverseCents;
  return {
    reverseAllocationCents,
    forwardTargetCents: reverseAllocationCents + requestedCents,
  };
}

// Returns a person's signed group balance in major currency units: positive
// means the group owes them, negative means they owe the group. This mirrors
// SettlementCalculator's ledger rules, including partial settlements and
// legacy negative settlement cards.
function netBalanceForPerson(expenses, personId) {
  const targetId = String(personId);
  let balanceCents = 0;

  const outstandingCents = (expense, id) => {
    const key = String(id);
    const splits = expense && expense.splitMap || {};
    const share = Number(splits[key] ?? splits[id] ?? 0);
    if (!Number.isFinite(share) || share <= 0) return 0;

    const settledBy = expense.settledBy;
    const fullySettled = Array.isArray(settledBy)
      ? settledBy.map(String).includes(key)
      : !!(settledBy && settledBy[key] === true);
    if (fullySettled) return 0;

    const settledAmounts = expense.settledAmounts || {};
    const already = Number(settledAmounts[key] ?? 0);
    const outstanding = Math.max(0, Math.round((share - (Number.isFinite(already) ? already : 0)) * 100));
    return outstanding;
  };

  for (const expense of Array.isArray(expenses) ? expenses : []) {
    if (!expense || typeof expense !== 'object') continue;
    const payerId = String(expense.payerId);
    const splits = expense.splitMap || {};

    if (expense.isSettlement === true) {
      // Legacy settlement cards represent a negative ledger entry from the
      // payer (debtor) to each person in splitMap (creditor).
      for (const [creditorId, amount] of Object.entries(splits)) {
        const cents = Math.round(Number(amount) * 100);
        if (creditorId === payerId || !Number.isFinite(cents) || cents <= 0) continue;
        if (payerId === targetId) balanceCents += cents;
        if (creditorId === targetId) balanceCents -= cents;
      }
      continue;
    }

    if (payerId === targetId) {
      for (const [debtorId] of Object.entries(splits)) {
        if (debtorId === payerId) continue;
        balanceCents += outstandingCents(expense, debtorId);
      }
    } else {
      balanceCents -= outstandingCents(expense, targetId);
    }
  }

  return Math.round(balanceCents) / 100;
}

// Either person in the debtor/creditor pair may undo a settlement.
function canRevert(log, uid) {
  if (!log || !uid) return false;
  const uids = Array.isArray(log.participantUids) ? log.participantUids : [];
  return uids.includes(uid);
}

module.exports = {
  groupAllocationsByExpense,
  subtractAllocations,
  canRevert,
  settlementAllocationTargets,
  netBalanceForPerson,
};
