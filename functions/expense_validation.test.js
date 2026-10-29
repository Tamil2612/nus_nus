'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  ExpenseValidationError,
  normalizeExpenseInput,
  validateExpensePeople,
  assertInitialSettledBy,
  normalizeSettledByUpdate,
  isShareCoveredByPairSettlement,
  assertCoveredSharesUnchanged,
} = require('./expense_validation');

const group = {
  members: [
    { id: 1, name: 'Me', linkedUserId: 'uid-me' },
    { id: 2, name: 'Sam', linkedUserId: 'uid-sam' },
    { id: 3, name: 'Guest' }, // not linked to an account
  ],
};

const base = (overrides = {}) => ({
  desc: 'Dinner',
  amount: 90,
  payerId: 1,
  splitMap: { 1: 30, 2: 30, 3: 30 },
  settledBy: [1],
  isSettlement: false,
  ...overrides,
});

const throwsValidation = (fn, code, pattern) =>
  assert.throws(fn, (error) => {
    assert.ok(error instanceof ExpenseValidationError);
    if (code) assert.equal(error.code, code);
    if (pattern) assert.match(error.message, pattern);
    return true;
  });

test('normalizes a valid expense to whole cents and string ids', () => {
  const result = normalizeExpenseInput(base());
  assert.equal(result.amountCents, 9000);
  assert.deepEqual(result.splitMap, { 1: 30, 2: 30, 3: 30 });
  assert.deepEqual(result.settledBy, ['1']);
});

test('shares must add up exactly to the amount', () => {
  throwsValidation(
    () => normalizeExpenseInput(base({ splitMap: { 1: 30, 2: 30, 3: 29.99 } })),
    'invalid-argument', /add up exactly/);
});

test('rejects bad fields, legacy settlements, negative shares and sub-cent amounts', () => {
  throwsValidation(() => normalizeExpenseInput(null));
  throwsValidation(() => normalizeExpenseInput(base({ desc: '   ' })));
  throwsValidation(() => normalizeExpenseInput(base({ isSettlement: true })));
  throwsValidation(() => normalizeExpenseInput(base({ amount: 0 })));
  throwsValidation(() => normalizeExpenseInput(base({ amount: 10.123, splitMap: { 1: 10.123 } })));
  throwsValidation(() => normalizeExpenseInput(base({ splitMap: { 1: -10, 2: 100 } })));
  throwsValidation(() => normalizeExpenseInput(base({ splitMap: { a: 90 } })));
});

test('tolerates floating-point noise but not sub-cent amounts', () => {
  const noisy = normalizeExpenseInput(base({
    amount: 0.1 + 0.2, splitMap: { 1: 0.1, 2: 0.2 }, settledBy: [],
  }));
  assert.equal(noisy.amountCents, 30);
  throwsValidation(() => normalizeExpenseInput(base({
    amount: 10.004, splitMap: { 1: 10.004 }, settledBy: [],
  })), 'invalid-argument', /whole cents/);
});

test('payer and participants must belong to the group', () => {
  const ok = normalizeExpenseInput(base());
  assert.doesNotThrow(() => validateExpensePeople(ok, group));
  throwsValidation(() => validateExpensePeople(
    normalizeExpenseInput(base({ payerId: 99 })), group), 'invalid-argument', /belong to this group/);
  throwsValidation(() => validateExpensePeople(
    normalizeExpenseInput(base({ splitMap: { 1: 45, 99: 45 } })), group), 'invalid-argument');
});

test('regression: payer who is not in the split can still be marked paid', () => {
  // "I paid for Sam and Guest and I'm not sharing the cost."
  const expense = normalizeExpenseInput(base({ splitMap: { 2: 45, 3: 45 }, settledBy: [1] }));
  assert.doesNotThrow(() => validateExpensePeople(expense, group, { creatorUid: 'uid-me' }));
  assert.doesNotThrow(() => assertInitialSettledBy(expense));
});

test('settledBy may not contain anyone else outside the split', () => {
  const expense = normalizeExpenseInput(base({ splitMap: { 1: 45, 2: 45 }, settledBy: [1, 3] }));
  throwsValidation(() => validateExpensePeople(expense, group), 'invalid-argument', /marked as settled/);
});

test('server-side payer lock: only the payer can log the expense', () => {
  const expense = normalizeExpenseInput(base());
  assert.doesNotThrow(() => validateExpensePeople(expense, group, { creatorUid: 'uid-me' }));
  // Sam tries to log an expense claiming Me paid.
  throwsValidation(() => validateExpensePeople(expense, group, { creatorUid: 'uid-sam' }),
    'permission-denied', /you paid/);
  // Nobody can log on behalf of a person who has no account.
  const guestPaid = normalizeExpenseInput(base({ payerId: 3, settledBy: [3] }));
  throwsValidation(() => validateExpensePeople(guestPaid, group, { creatorUid: 'uid-me' }),
    'permission-denied');
});

test('edits do not re-check the payer lock (payer is fixed server-side)', () => {
  const expense = normalizeExpenseInput(base({ payerId: 3, settledBy: [3] }));
  assert.doesNotThrow(() => validateExpensePeople(expense, group));
});

test('a new expense may start with only the payer marked paid', () => {
  assert.doesNotThrow(() => assertInitialSettledBy(normalizeExpenseInput(base({ settledBy: [] }))));
  assert.doesNotThrow(() => assertInitialSettledBy(normalizeExpenseInput(base({ settledBy: [1] }))));
  throwsValidation(() => assertInitialSettledBy(normalizeExpenseInput(base({ settledBy: [1, 2] }))),
    'invalid-argument', /initially/);
});

test('paid/pending toggle: participants and the payer are allowed', () => {
  const current = { payerId: 1, splitMap: { 2: 45, 3: 45 } }; // payer not in split
  assert.deepEqual(normalizeSettledByUpdate([1, 2], current), ['1', '2']);
  assert.deepEqual(normalizeSettledByUpdate(['1'], current), ['1']);
  assert.deepEqual(normalizeSettledByUpdate([2, 2, '2'], current), ['2']);
});

test('paid/pending toggle rejects outsiders and non-lists', () => {
  const current = { payerId: 1, splitMap: { 1: 45, 2: 45 } };
  throwsValidation(() => normalizeSettledByUpdate([1, 3], current), 'invalid-argument', /participants/);
  throwsValidation(() => normalizeSettledByUpdate('1', current), 'invalid-argument');
  throwsValidation(() => normalizeSettledByUpdate(undefined, current), 'invalid-argument');
});

// ---- Shares covered by a recorded pair settlement ---------------------------
//
// Bug being guarded: if the author could mark a fully pair-settled share paid
// by hand, undoing the settlement would restore settledAmounts but leave the
// settledBy entry behind, keeping the balance wrongly closed.

const settled = (settledAmounts, settledBy = [1]) => ({
  payerId: 1,
  splitMap: { 1: 50, 2: 50, 3: 0 },
  settledBy,
  settledAmounts,
});

test('a fully pair-settled share cannot be marked paid by hand', () => {
  const current = settled({ 2: 50 });
  throwsValidation(() => normalizeSettledByUpdate([1, 2], current),
    'failed-precondition', /Undo the settlement/);
});

test('a fully pair-settled share cannot be marked pending by hand either', () => {
  const current = settled({ 2: 50 }, [1, 2]);
  throwsValidation(() => normalizeSettledByUpdate([1], current), 'failed-precondition');
});

test('toggling someone else is fine while a different share is covered', () => {
  const current = settled({ 2: 50 });
  // Person 3 (share 0) is not covered, and person 2's membership is unchanged.
  assert.deepEqual(normalizeSettledByUpdate([1, 3], current), ['1', '3']);
});

test('re-sending an unchanged list is allowed even when a share is covered', () => {
  const current = settled({ 2: 50 }, [1, 2]);
  assert.deepEqual(normalizeSettledByUpdate([1, 2], current), ['1', '2']);
});

test('a partly settled share can still be marked paid to forgive the rest', () => {
  const current = settled({ 2: 20 });
  assert.deepEqual(normalizeSettledByUpdate([1, 2], current), ['1', '2']);
});

test('coverage uses half a cent of slack and ignores zero shares', () => {
  const current = { splitMap: { 2: 50, 3: 0 }, settledAmounts: { 2: 49.996 } };
  assert.equal(isShareCoveredByPairSettlement(current, 2), true);
  assert.equal(isShareCoveredByPairSettlement({ ...current, settledAmounts: { 2: 49.99 } }, 2), false);
  assert.equal(isShareCoveredByPairSettlement(current, 3), false); // zero share is never "covered"
  assert.equal(isShareCoveredByPairSettlement(current, 99), false); // not in the split
  assert.equal(isShareCoveredByPairSettlement({}, 2), false);
});

test('the edit path gets the same guard (an edit also writes settledBy)', () => {
  const current = settled({ 2: 50 });
  throwsValidation(() => assertCoveredSharesUnchanged(current, ['1', '2']), 'failed-precondition');
  assert.doesNotThrow(() => assertCoveredSharesUnchanged(current, ['1']));
  assert.doesNotThrow(() => assertCoveredSharesUnchanged(settled({}), ['1', '2']));
});

test('after the settlement is undone the share can be toggled again', () => {
  const afterUndo = settled({}); // settledAmounts restored to nothing
  assert.deepEqual(normalizeSettledByUpdate([1, 2], afterUndo), ['1', '2']);
});