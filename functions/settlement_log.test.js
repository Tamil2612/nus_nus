'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  groupAllocationsByExpense,
  subtractAllocations,
  canRevert,
  settlementAllocationTargets,
} = require('./settlement_log');

test('groups allocations per expense and person, ignoring junk entries', () => {
  const grouped = groupAllocationsByExpense([
    { expenseId: 'e1', personId: 2, cents: 4000 },
    { expenseId: 'e1', personId: 2, cents: 1000 },
    { expenseId: 'e1', personId: 3, cents: 500 },
    { expenseId: 'e2', personId: 2, cents: 2500 },
    { expenseId: 'e3', personId: 2, cents: 0 },
    { expenseId: '', personId: 2, cents: 100 },
    null,
  ]);
  assert.deepEqual(grouped, {
    e1: { 2: 5000, 3: 500 },
    e2: { 2: 2500 },
  });
});

test('handles a missing or malformed allocation list', () => {
  assert.deepEqual(groupAllocationsByExpense(undefined), {});
  assert.deepEqual(groupAllocationsByExpense('nope'), {});
});

test('undo subtracts exactly what was allocated and drops emptied entries', () => {
  const result = subtractAllocations({ 2: 50, 3: 10.5 }, { 2: 5000, 3: 500 });
  assert.equal(result.ok, true);
  assert.deepEqual(result.next, { 3: 5.5 });
});

test('undo of a partial settlement keeps the remainder', () => {
  const result = subtractAllocations({ 2: 80 }, { 2: 3000 });
  assert.equal(result.ok, true);
  assert.deepEqual(result.next, { 2: 50 });
});

test('undo refuses when stored amounts no longer cover the allocation', () => {
  assert.equal(subtractAllocations({ 2: 10 }, { 2: 5000 }).ok, false);
  assert.equal(subtractAllocations({}, { 2: 100 }).ok, false);
  assert.equal(subtractAllocations(undefined, { 2: 100 }).ok, false);
});

test('undo does not mutate its input', () => {
  const current = { 2: 50 };
  subtractAllocations(current, { 2: 5000 });
  assert.deepEqual(current, { 2: 50 });
});

test('only the two people in the settlement may undo it', () => {
  const log = { participantUids: ['debtor', 'creditor'] };
  assert.equal(canRevert(log, 'debtor'), true);
  assert.equal(canRevert(log, 'creditor'), true);
  assert.equal(canRevert(log, 'bystander'), false);
  assert.equal(canRevert(log, ''), false);
  assert.equal(canRevert({}, 'debtor'), false);
  assert.equal(canRevert(null, 'debtor'), false);
});


test('allocation targets include legacy forward settlements without over-allocating', () => {
  // Forward 150, reverse 40, legacy forward 20, legacy reverse 0 => net 90.
  // A full settlement must reconcile all 150 of the real forward shares.
  const targets = settlementAllocationTargets({
    reverseCents: 4000,
    legacyForwardCents: 2000,
    legacyReverseCents: 0,
    requestedCents: 9000,
  });
  assert.deepEqual(targets, {
    reverseAllocationCents: 4000,
    forwardTargetCents: 15000,
  });
});

test('allocation targets subtract legacy reverse entries only once', () => {
  const targets = settlementAllocationTargets({
    reverseCents: 5000,
    legacyForwardCents: 1000,
    legacyReverseCents: 2000,
    requestedCents: 3000,
  });
  assert.deepEqual(targets, {
    reverseAllocationCents: 3000,
    forwardTargetCents: 7000,
  });
});

test('allocation targets reject impossible legacy reverse totals', () => {
  assert.throws(() => settlementAllocationTargets({
    reverseCents: 100,
    legacyForwardCents: 0,
    legacyReverseCents: 200,
    requestedCents: 0,
  }), RangeError);
});
