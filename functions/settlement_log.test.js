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


test('legacy forward settlements are not allocated onto real shares again', () => {
  // Forward 150, reverse 40, legacy forward 20 => net 90. Paying the full 90
  // offsets the 40 and settles 130 of the 150 forward; the other 20 is already
  // covered by the legacy card, which stays in the ledger as a negative entry.
  const targets = settlementAllocationTargets({
    reverseCents: 4000,
    legacyForwardCents: 2000,
    legacyReverseCents: 0,
    requestedCents: 9000,
  });
  assert.deepEqual(targets, {
    reverseAllocationCents: 4000,
    forwardTargetCents: 13000,
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
    forwardTargetCents: 6000,
  });
});

test('ledger invariant: balance after settling is exactly net minus requested', () => {
  // ledger balance = (forward - fwdAlloc - legacyForward) - (reverse - revAlloc - legacyReverse)
  const cases = [
    { F: 10000, R: 0, lf: 3000, lr: 0, pay: 7000 },
    { F: 10000, R: 4000, lf: 3000, lr: 1000, pay: 4000 },
    { F: 15000, R: 4000, lf: 2000, lr: 0, pay: 9000 },
    { F: 15000, R: 4000, lf: 2000, lr: 0, pay: 2500 },
    { F: 8000, R: 5000, lf: 0, lr: 5000, pay: 3000 },
  ];
  for (const c of cases) {
    const netBefore = c.F - c.R - c.lf + c.lr;
    const t = settlementAllocationTargets({
      reverseCents: c.R, legacyForwardCents: c.lf,
      legacyReverseCents: c.lr, requestedCents: c.pay,
    });
    // Allocations must fit inside the real outstanding shares.
    assert.ok(t.forwardTargetCents <= c.F, 'forward allocation within real shares');
    assert.ok(t.reverseAllocationCents <= c.R, 'reverse allocation within real shares');
    const netAfter = (c.F - t.forwardTargetCents - c.lf) - (c.R - t.reverseAllocationCents - c.lr);
    assert.equal(netAfter, netBefore - c.pay, JSON.stringify(c));
  }
});

test('allocation targets reject impossible legacy reverse totals', () => {
  assert.throws(() => settlementAllocationTargets({
    reverseCents: 100,
    legacyForwardCents: 0,
    legacyReverseCents: 200,
    requestedCents: 0,
  }), RangeError);
});