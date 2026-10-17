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

// Either person in the debtor/creditor pair may undo a settlement.
function canRevert(log, uid) {
  if (!log || !uid) return false;
  const uids = Array.isArray(log.participantUids) ? log.participantUids : [];
  return uids.includes(uid);
}

module.exports = { groupAllocationsByExpense, subtractAllocations, canRevert };
