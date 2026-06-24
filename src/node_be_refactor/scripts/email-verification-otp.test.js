const test = require('node:test');
const assert = require('node:assert/strict');

process.env.EMAIL_OTP_PEPPER = 'test-pepper';
const service = require('../src/services/user-auth.service');

test('email verification OTP is six digits and HMAC-hashed with the configured pepper', () => {
  const { otp, hash, expiresAt } = service._otpData();
  assert.match(otp, /^\d{6}$/);
  assert.equal(hash, service._hashOtp(otp));
  assert.notEqual(hash, otp);
  assert.ok(expiresAt.getTime() > Date.now());
});

test('different OTP values do not share a hash', () => {
  assert.notEqual(service._hashOtp('123456'), service._hashOtp('654321'));
});
