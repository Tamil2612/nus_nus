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

// Either person in the debtor/creditor pair may undo a settlement.
function canRevert(log, uid) {
  if (!log || !uid) return false;
  const uids = Array.isArray(log.participantUids) ? log.participantUids : [];
  return uids.includes(uid);
}

module.exports = { groupAllocationsByExpense, subtractAllocations, canRevert, settlementAllocationTargets };