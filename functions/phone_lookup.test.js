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

test('normalizes Indian mobile formats with or without +91', () => {
  const expected = '9876543210';
  for (const input of [
    '9876543210',
    '09876543210',
    '+919876543210',
    '+91 98765 43210',
    '919876543210',
    '00919876543210',
  ]) {
    assert.equal(normalizeLookupPhone(input), expected, input);
  }
});

test('does not treat arbitrary numbers beginning with 91 as Indian mobile numbers', () => {
  assert.equal(normalizeLookupPhone('911234567890'), '911234567890');
});

test('does not convert arbitrary long numeric strings to UAE numbers', () => {
  assert.equal(normalizeLookupPhone('1234567890123'), '1234567890123');
});
