'use strict';

function digitsOnly(value) {
  return String(value || '').replace(/\D/g, '');
}

// Canonicalize UAE phone numbers so 0501234567, 501234567,
// 971501234567 and +971 50 123 4567 can be compared consistently.
// For non-UAE numbers, retain the international digits after stripping 00.
function normalizeLookupPhone(value) {
  let digits = digitsOnly(value);
  if (digits.startsWith('00')) digits = digits.slice(2);

  if (digits.startsWith('971')) {
    const national = digits.slice(3);
    return national.startsWith('0') ? national : '0' + national;
  }

  // UAE local mobile numbers are commonly stored with or without the trunk 0.
  if (/^5\d{8}$/.test(digits)) return '0' + digits;
  if (/^05\d{8}$/.test(digits)) return digits;

  return digits;
}

module.exports = { digitsOnly, normalizeLookupPhone };
