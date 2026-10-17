'use strict';

function digitsOnly(value) {
  return String(value || '').replace(/\D/g, '');
}

// Canonicalize UAE and Indian mobile formats for comparison. UAE examples:
// 0501234567, 501234567, +971501234567. India examples:
// 9876543210, +919876543210, 00919876543210. For other countries retain
// international digits after stripping punctuation and the 00 prefix.
function normalizeLookupPhone(value) {
  let digits = digitsOnly(value);
  if (digits.startsWith('00')) digits = digits.slice(2);

  if (digits.startsWith('971')) {
    const national = digits.slice(3);
    return national.startsWith('0') ? national : '0' + national;
  }

  // India: compare the 10-digit national mobile number regardless of +91.
  if (digits.startsWith('91') && digits.length === 12 &&
      /^[6-9]\d{9}$/.test(digits.slice(2))) {
    return digits.slice(2);
  }
  if (/^[6-9]\d{9}$/.test(digits)) return digits;

  // UAE local mobile numbers are commonly stored with or without the trunk 0.
  if (/^5\d{8}$/.test(digits)) return '0' + digits;
  if (/^05\d{8}$/.test(digits)) return digits;

  return digits;
}

module.exports = { digitsOnly, normalizeLookupPhone };
