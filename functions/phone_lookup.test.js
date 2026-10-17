'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { normalizeLookupPhone } = require('./phone_lookup');

test('normalizes common UAE mobile formats to the same canonical number', () => {
  const expected = '0501234567';
  for (const input of [
    '0501234567',
    '501234567',
    '+971501234567',
    '+971 50 123 4567',
    '00971501234567',
    '971 50-123-4567',
  ]) {
    assert.equal(normalizeLookupPhone(input), expected, input);
  }
});

test('keeps non-UAE international numbers comparable after punctuation removal', () => {
  assert.equal(normalizeLookupPhone('+1 (415) 555-0134'), '14155550134');
});

test('does not convert arbitrary long numeric strings to UAE numbers', () => {
  assert.equal(normalizeLookupPhone('1234567890123'), '1234567890123');
});
