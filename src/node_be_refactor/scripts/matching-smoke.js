const http = require('http');
const https = require('https');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');

const User = require('../src/models/user.model');
const Sport = require('../src/models/sport.model');
const Facility = require('../src/models/facility.model');
const Court = require('../src/models/court.model');
const Booking = require('../src/models/booking.model');
const Payment = require('../src/models/payment.model');
const MatchingSession = require('../src/models/matching.model');
const MatchQueue = require('../src/models/match-queue.model');
const FixedSchedule = require('../src/models/fixed-schedule.model');
const matchingService = require('../src/services/matching.service');

const API_BASE_URL = (process.env.API_BASE_URL || 'http://127.0.0.1:3000/api/v1').replace(/\/$/, '');
const MONGODB_URI = process.env.MONGODB_URI;
const JWT_SECRET = process.env.JWT_SECRET;
const KEEP_SMOKE_DATA = process.env.KEEP_SMOKE_DATA === '1';
const RUN_ID = `matching-smoke-${Date.now()}`;

const state = {
  users: [],
  sport: null,
  facility: null,
  courts: [],
  createdBookingIds: []
};

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function request(method, path, { token, body } = {}) {
  const url = new URL(`${API_BASE_URL}${path}`);
  const payload = body === undefined ? null : JSON.stringify(body);
  const transport = url.protocol === 'https:' ? https : http;

  return new Promise((resolve, reject) => {
    const req = transport.request({
      protocol: url.protocol,
      hostname: url.hostname,
      port: url.port,
      path: `${url.pathname}${url.search}`,
      method,
      headers: {
        Accept: 'application/json',
        ...(payload ? { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(payload) } : {}),
        ...(token ? { Authorization: `Bearer ${token}` } : {})
      }
    }, (res) => {
      let raw = '';
      res.setEncoding('utf8');
      res.on('data', chunk => { raw += chunk; });
      res.on('end', () => {
        let json = null;
        try {
          json = raw ? JSON.parse(raw) : null;
        } catch (error) {
          return reject(new Error(`${method} ${path} returned non-JSON response: ${raw.slice(0, 200)}`));
        }
        resolve({ status: res.statusCode, body: json });
      });
    });

    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

function tokenFor(user) {
  return jwt.sign({ id: user._id.toString(), role: user.role }, JWT_SECRET, { expiresIn: '2h' });
}

function vietnamDatePlusDays(days) {
  const now = new Date();
  now.setUTCDate(now.getUTCDate() + days);
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }).formatToParts(now);
  const map = Object.fromEntries(parts.map(part => [part.type, part.value]));
  return `${map.year}-${map.month}-${map.day}`;
}

async function waitUntil(label, fn, { timeoutMs = 6000, intervalMs = 250 } = {}) {
  const startedAt = Date.now();
  let lastError = null;

  while (Date.now() - startedAt < timeoutMs) {
    try {
      const result = await fn();
      if (result) return result;
    } catch (error) {
      lastError = error;
    }
    await new Promise(resolve => setTimeout(resolve, intervalMs));
  }

  throw new Error(`${label} timed out${lastError ? `: ${lastError.message}` : ''}`);
}

async function cleanup() {
  const userIds = state.users.map(user => user._id);
  const courtIds = state.courts.map(court => court._id);

  const bookings = await Booking.find({
    $or: [
      { user_id: { $in: userIds } },
      { court_id: { $in: courtIds } }
    ]
  }).select('_id');
  const bookingIds = bookings.map(booking => booking._id);

  await Payment.deleteMany({
    $or: [
      { user_id: { $in: userIds } },
      { booking_id: { $in: bookingIds } }
    ]
  });
  await MatchingSession.deleteMany({
    $or: [
      { host_id: { $in: userIds } },
      { 'members.user_id': { $in: userIds } },
      { booking_id: { $in: bookingIds } }
    ]
  });
  await MatchQueue.deleteMany({ user_id: { $in: userIds } });
  await FixedSchedule.deleteMany({ user_id: { $in: userIds } });
  await Booking.deleteMany({ _id: { $in: bookingIds } });
  await Court.deleteMany({ _id: { $in: courtIds } });
  if (state.facility?._id) await Facility.deleteOne({ _id: state.facility._id });
  if (state.sport?._id) await Sport.deleteOne({ _id: state.sport._id });
  await User.deleteMany({ email: { $regex: /^matching-smoke-\d+-user-\d+@example\.test$/ } });
}

async function seed() {
  state.sport = await Sport.create({
    name: `${RUN_ID} sport`,
    description: 'Smoke test sport',
    team_size: 4,
    active: true
  });
  state.facility = await Facility.create({
    name: `${RUN_ID} facility`,
    address: { city: 'Smoke', full: 'Smoke test facility' },
    active: true
  });
  state.courts = await Court.create([
    {
      name: `${RUN_ID} court A`,
      facility_id: state.facility._id,
      sport_id: state.sport._id,
      code: `${RUN_ID}-A`,
      status: 'ACTIVE',
      price_per_hour: 100001
    },
    {
      name: `${RUN_ID} court B`,
      facility_id: state.facility._id,
      sport_id: state.sport._id,
      code: `${RUN_ID}-B`,
      status: 'ACTIVE',
      price_per_hour: 100003
    }
  ]);

  for (let i = 0; i < 12; i += 1) {
    state.users.push(await User.create({
      email: `${RUN_ID}-user-${i}@example.test`,
      password: 'smoke-test-password',
      role: 'CUSTOMER',
      status: 'ACTIVE',
      emailVerifiedAt: new Date(),
      profile: { name: `Smoke User ${i}`, phone: '', avatar_url: '' }
    }));
  }
}

async function createManualSession({
  token,
  hostIndex,
  courtIndex = 0,
  bookingDate,
  startMinutes = 540,
  endMinutes = 600,
  totalPlayersNeeded,
  paymentPolicy,
  autoApprove = true,
  teamMode,
  teamSize,
  hostTeamCode,
  hostRepresentedCount
}) {
  const response = await request('POST', '/matching', {
    token,
    body: {
      sportId: state.sport._id.toString(),
      facilityId: state.facility._id.toString(),
      courtId: state.courts[courtIndex]._id.toString(),
      bookingDate,
      startMinutes,
      endMinutes,
      totalPlayersNeeded,
      paymentPolicy,
      autoApprove,
      ...(teamMode ? { teamMode } : {}),
      ...(teamSize ? { teamSize } : {}),
      ...(hostTeamCode ? { hostTeamCode } : {}),
      ...(hostRepresentedCount ? { hostRepresentedCount } : {}),
      description: `${RUN_ID} manual session by user ${hostIndex}`
    }
  });
  assert(response.status === 200, `create session failed: ${response.status} ${JSON.stringify(response.body)}`);
  return await MatchingSession.findById(response.body.data.id);
}

async function joinSession(sessionId, token, body) {
  const response = await request('POST', `/matching/${sessionId}/join`, {
    token,
    body
  });
  assert(response.status === 200, `join session failed: ${response.status} ${JSON.stringify(response.body)}`);
  return response;
}

async function getCalendarItem(token, bookingId) {
  const response = await request('GET', '/booking?limit=100', { token });
  assert(response.status === 200, `booking calendar failed: ${response.status} ${JSON.stringify(response.body)}`);
  return response.body.items.find(item => item.id === bookingId.toString()) || null;
}

function paymentSnapshot(payments) {
  return payments
    .map(payment => ({
      id: payment._id.toString(),
      userId: payment.user_id.toString(),
      amount: payment.amount,
      status: payment.status,
      transactionId: payment.transaction_id || ''
    }))
    .sort((a, b) => a.id.localeCompare(b.id));
}

function sessionMemberIds(session) {
  return session.members
    .map(member => member.user_id._id?.toString() || member.user_id.toString())
    .sort();
}

async function step(name, fn) {
  process.stdout.write(`- ${name} ... `);
  await fn();
  process.stdout.write('PASS\n');
}

async function main() {
  assert(MONGODB_URI, 'Missing MONGODB_URI in environment. This script does not read .env.');
  assert(JWT_SECRET, 'Missing JWT_SECRET in environment. This script does not read .env.');

  await mongoose.connect(MONGODB_URI);
  await seed();

  const tokens = state.users.map(tokenFor);
  const expectedSuccessMessage =
    'Trận đã có người thanh toán, bạn không thể rời riêng lẻ. Vui lòng liên hệ chủ trận hoặc quản trị viên.';

  try {
    await step('A. manual HOST_PAY_ALL creates only the host payment and calendar access', async () => {
      const session = await createManualSession({
        token: tokens[0],
        hostIndex: 0,
        bookingDate: vietnamDatePlusDays(7),
        totalPlayersNeeded: 1,
        paymentPolicy: 'HOST_PAY_ALL'
      });
      await joinSession(session._id, tokens[1]);

      const [updatedSession, booking, payments] = await Promise.all([
        MatchingSession.findById(session._id),
        Booking.findById(session.booking_id),
        Payment.find({ booking_id: session.booking_id })
      ]);
      assert(updatedSession.status === 'FULL', `expected FULL, got ${updatedSession.status}`);
      assert(payments.length === 1, `expected one host payment, got ${payments.length}`);
      assert(payments[0].user_id.toString() === state.users[0]._id.toString(), 'HOST_PAY_ALL payment does not belong to host');
      assert(payments[0].status === 'PENDING', `expected PENDING host payment, got ${payments[0].status}`);
      assert(payments[0].amount === booking.total_price, `host amount ${payments[0].amount} != booking total ${booking.total_price}`);

      const [hostItem, memberItem, outsiderItem] = await Promise.all([
        getCalendarItem(tokens[0], booking._id),
        getCalendarItem(tokens[1], booking._id),
        getCalendarItem(tokens[11], booking._id)
      ]);
      assert(hostItem?.isMatching && hostItem.isHost, 'host calendar matching metadata is missing');
      assert(memberItem?.isMatching && !memberItem.isHost, 'member calendar matching metadata is missing');
      assert(hostItem.paymentPolicy === 'HOST_PAY_ALL', `unexpected host paymentPolicy ${hostItem.paymentPolicy}`);
      assert(memberItem.paymentPolicy === 'HOST_PAY_ALL', `unexpected member paymentPolicy ${memberItem.paymentPolicy}`);
      assert(hostItem.myPaymentStatus === 'PENDING', `host myPaymentStatus expected PENDING, got ${hostItem.myPaymentStatus}`);
      assert(hostItem.myPaymentAmount === booking.total_price, 'host myPaymentAmount does not equal booking total');
      assert(memberItem.myPaymentStatus === null && memberItem.myPaymentAmount === null, 'member should not have HOST_PAY_ALL payment');
      assert(!outsiderItem, 'non-participant can see matching booking');
    });

    await step('B-C. manual SPLIT_EQUALLY creates no payment before FULL, then splits exactly once', async () => {
      const session = await createManualSession({
        token: tokens[2],
        hostIndex: 2,
        bookingDate: vietnamDatePlusDays(8),
        totalPlayersNeeded: 2,
        paymentPolicy: 'SPLIT_EQUALLY'
      });
      await joinSession(session._id, tokens[3]);
      const beforeFull = await MatchingSession.findById(session._id);
      const beforePayments = await Payment.find({ booking_id: session.booking_id });
      assert(beforeFull.status === 'OPEN', `session should stay OPEN before full, got ${beforeFull.status}`);
      assert(beforePayments.length === 0, `split payments created before FULL: ${beforePayments.length}`);

      await joinSession(session._id, tokens[4]);
      const [fullSession, booking, payments] = await Promise.all([
        MatchingSession.findById(session._id),
        Booking.findById(session.booking_id),
        Payment.find({ booking_id: session.booking_id, status: 'PENDING' })
      ]);
      assert(fullSession.status === 'FULL', `expected FULL, got ${fullSession.status}`);
      assert(payments.length === 3, `expected 3 split payments, got ${payments.length}`);
      assert(payments.reduce((sum, payment) => sum + payment.amount, 0) === booking.total_price, 'split payment sum does not equal booking total');

      const baseAmount = Math.floor(booking.total_price / 3);
      const remainder = booking.total_price - baseAmount * 3;
      const hostPayment = payments.find(payment => payment.user_id.toString() === state.users[2]._id.toString());
      assert(hostPayment?.amount === baseAmount + remainder, `host remainder mismatch: ${hostPayment?.amount}`);
      assert(payments.filter(payment => payment.user_id.toString() !== state.users[2]._id.toString()).every(payment => payment.amount === baseAmount), 'member split amount mismatch');

      const matchingService = require('../src/services/matching.service');
      await matchingService._syncFullSessionPayments(await MatchingSession.findById(session._id));
      const activeAfterResync = await Payment.find({
        booking_id: session.booking_id,
        status: { $in: ['PENDING', 'SUCCESS'] }
      });
      assert(activeAfterResync.length === 3, `resync created duplicate payments: ${activeAfterResync.length}`);
    });

    await step('D. member leaves OPEN session without payment mutation', async () => {
      const session = await createManualSession({
        token: tokens[5],
        hostIndex: 5,
        bookingDate: vietnamDatePlusDays(9),
        totalPlayersNeeded: 2,
        paymentPolicy: 'SPLIT_EQUALLY'
      });
      await joinSession(session._id, tokens[6]);
      const beforePayments = paymentSnapshot(await Payment.find({ booking_id: session.booking_id }));

      const leave = await request('POST', `/matching/${session._id}/leave`, { token: tokens[6] });
      assert(leave.status === 200, `OPEN member leave failed: ${leave.status} ${JSON.stringify(leave.body)}`);

      const [afterSession, afterPayments] = await Promise.all([
        MatchingSession.findById(session._id),
        Payment.find({ booking_id: session.booking_id })
      ]);
      assert(afterSession.status === 'OPEN', `session should remain OPEN, got ${afterSession.status}`);
      assert(!sessionMemberIds(afterSession).includes(state.users[6]._id.toString()), 'departed member remains in OPEN session');
      assert(JSON.stringify(paymentSnapshot(afterPayments)) === JSON.stringify(beforePayments), 'payments changed when leaving before FULL');
    });

    await step('E. member leaves FULL session with PENDING payments and split is recalculated', async () => {
      const session = await createManualSession({
        token: tokens[5],
        hostIndex: 5,
        courtIndex: 1,
        bookingDate: vietnamDatePlusDays(10),
        totalPlayersNeeded: 2,
        paymentPolicy: 'SPLIT_EQUALLY'
      });
      await joinSession(session._id, tokens[6]);
      await joinSession(session._id, tokens[7]);

      const leave = await request('POST', `/matching/${session._id}/leave`, { token: tokens[7] });
      assert(leave.status === 200, `FULL member leave failed: ${leave.status} ${JSON.stringify(leave.body)}`);

      const [afterSession, booking, payments] = await Promise.all([
        MatchingSession.findById(session._id),
        Booking.findById(session.booking_id),
        Payment.find({ booking_id: session.booking_id })
      ]);
      assert(afterSession.status === 'OPEN', `FULL session should return OPEN, got ${afterSession.status}`);
      assert(booking.status === 'PENDING', `booking should stay PENDING, got ${booking.status}`);
      assert(!sessionMemberIds(afterSession).includes(state.users[7]._id.toString()), 'departed member remains in session');

      const departedPayment = payments.find(payment => payment.user_id.toString() === state.users[7]._id.toString());
      const remaining = payments.filter(payment => (
        payment.status === 'PENDING'
        && payment.user_id.toString() !== state.users[7]._id.toString()
      ));
      assert(departedPayment?.status === 'CANCELLED', `departed payment expected CANCELLED, got ${departedPayment?.status}`);
      assert(remaining.length === 2, `expected two remaining pending payments, got ${remaining.length}`);
      assert(remaining.reduce((sum, payment) => sum + payment.amount, 0) === booking.total_price, 'recalculated pending sum does not equal booking total');
      const baseAmount = Math.floor(booking.total_price / 2);
      const remainder = booking.total_price - baseAmount * 2;
      const hostPayment = remaining.find(payment => payment.user_id.toString() === state.users[5]._id.toString());
      assert(hostPayment?.amount === baseAmount + remainder, 'recalculated remainder was not assigned to host');
    });

    let successSession = null;
    let successBooking = null;
    await step('F. member cannot leave FULL session after any SUCCESS payment', async () => {
      successSession = await createManualSession({
        token: tokens[0],
        hostIndex: 0,
        bookingDate: vietnamDatePlusDays(11),
        totalPlayersNeeded: 2,
        paymentPolicy: 'SPLIT_EQUALLY'
      });
      await joinSession(successSession._id, tokens[1]);
      await joinSession(successSession._id, tokens[2]);
      successBooking = await Booking.findById(successSession.booking_id);
      await Payment.findOneAndUpdate(
        { booking_id: successBooking._id, user_id: state.users[1]._id, status: 'PENDING' },
        { status: 'SUCCESS', transaction_id: `${RUN_ID}-paid` }
      );

      const beforeSession = await MatchingSession.findById(successSession._id);
      const beforePayments = paymentSnapshot(await Payment.find({ booking_id: successBooking._id }));
      const leave = await request('POST', `/matching/${successSession._id}/leave`, { token: tokens[2] });
      assert(leave.status === 409, `expected 409, got ${leave.status}: ${JSON.stringify(leave.body)}`);
      assert(leave.body?.code === 'MATCHING_PAYMENT_ALREADY_SUCCESS', `unexpected error code: ${JSON.stringify(leave.body)}`);
      assert(leave.body?.message === expectedSuccessMessage, `unexpected Vietnamese message: ${leave.body?.message}`);

      const [afterSession, afterPayments] = await Promise.all([
        MatchingSession.findById(successSession._id),
        Payment.find({ booking_id: successBooking._id })
      ]);
      assert(JSON.stringify(sessionMemberIds(afterSession)) === JSON.stringify(sessionMemberIds(beforeSession)), 'member list changed after blocked leave');
      assert(afterSession.status === beforeSession.status, 'session status changed after blocked leave');
      assert(JSON.stringify(paymentSnapshot(afterPayments)) === JSON.stringify(beforePayments), 'payments changed after blocked leave');
    });

    await step('G. host cannot use member leave endpoint', async () => {
      const beforeSession = await MatchingSession.findById(successSession._id);
      const beforeBooking = await Booking.findById(successBooking._id);
      const beforePayments = paymentSnapshot(await Payment.find({ booking_id: successBooking._id }));
      const leave = await request('POST', `/matching/${successSession._id}/leave`, { token: tokens[0] });
      assert(leave.status === 400, `expected host leave 400, got ${leave.status}: ${JSON.stringify(leave.body)}`);
      assert(leave.body?.code === 'HOST_MUST_CANCEL_SESSION', `unexpected host leave code: ${JSON.stringify(leave.body)}`);

      const [afterSession, afterBooking, afterPayments] = await Promise.all([
        MatchingSession.findById(successSession._id),
        Booking.findById(successBooking._id),
        Payment.find({ booking_id: successBooking._id })
      ]);
      assert(JSON.stringify(sessionMemberIds(afterSession)) === JSON.stringify(sessionMemberIds(beforeSession)), 'host leave changed members');
      assert(afterSession.status === beforeSession.status, 'host leave changed session');
      assert(afterBooking.status === beforeBooking.status, 'host leave changed booking');
      assert(JSON.stringify(paymentSnapshot(afterPayments)) === JSON.stringify(beforePayments), 'host leave changed payments');
    });

    await step('H. cancelling session cancels PENDING booking/payments and does not refund SUCCESS', async () => {
      const session = await createManualSession({
        token: tokens[8],
        hostIndex: 8,
        bookingDate: vietnamDatePlusDays(12),
        totalPlayersNeeded: 2,
        paymentPolicy: 'SPLIT_EQUALLY'
      });
      await joinSession(session._id, tokens[9]);
      await joinSession(session._id, tokens[10]);
      const successPayment = await Payment.findOneAndUpdate(
        { booking_id: session.booking_id, user_id: state.users[9]._id, status: 'PENDING' },
        { status: 'SUCCESS', transaction_id: `${RUN_ID}-cancel-success` },
        { new: true }
      );

      const cancel = await request('PUT', `/matching/${session._id}/status`, {
        token: tokens[8],
        body: { status: 'CANCELLED' }
      });
      assert(cancel.status === 200, `cancel session failed: ${cancel.status} ${JSON.stringify(cancel.body)}`);

      const [afterSession, booking, payments] = await Promise.all([
        MatchingSession.findById(session._id),
        Booking.findById(session.booking_id),
        Payment.find({ booking_id: session.booking_id })
      ]);
      assert(afterSession && booking && payments.length === 3, 'cancel deleted session, booking, or payments');
      assert(afterSession.status === 'CANCELLED', `session expected CANCELLED, got ${afterSession.status}`);
      assert(booking.status === 'CANCELLED', `booking expected CANCELLED, got ${booking.status}`);
      assert(payments.find(payment => payment._id.toString() === successPayment._id.toString())?.status === 'SUCCESS', 'SUCCESS payment was changed or refunded');
      assert(payments.filter(payment => payment._id.toString() !== successPayment._id.toString()).every(payment => payment.status === 'CANCELLED'), 'PENDING payments were not cancelled');
    });

    await step('I. calendar response exposes all matching/payment fields', async () => {
      const hostItem = await getCalendarItem(tokens[0], successBooking._id);
      const memberItem = await getCalendarItem(tokens[1], successBooking._id);
      const outsiderItem = await getCalendarItem(tokens[11], successBooking._id);
      for (const [label, item] of [['host', hostItem], ['member', memberItem]]) {
        assert(item, `${label} cannot see matching booking`);
        for (const field of [
          'isMatching',
          'matchingSessionId',
          'isHost',
          'paymentPolicy',
          'myPaymentStatus',
          'myPaymentAmount'
        ]) {
          assert(Object.prototype.hasOwnProperty.call(item, field), `${label} calendar item missing ${field}`);
        }
        assert(item.isMatching === true, `${label} isMatching should be true`);
        assert(item.matchingSessionId === successSession._id.toString(), `${label} matchingSessionId mismatch`);
        assert(item.paymentPolicy === 'SPLIT_EQUALLY', `${label} paymentPolicy mismatch`);
      }
      assert(hostItem.isHost === true && memberItem.isHost === false, 'calendar isHost flags are incorrect');
      assert(memberItem.myPaymentStatus === 'SUCCESS', `paid member status expected SUCCESS, got ${memberItem.myPaymentStatus}`);
      assert(!outsiderItem, 'outsider can see matching booking');
    });

    await step('J. auto matching SPLIT_EQUALLY creates one FULL session, one booking, payments, and calendars', async () => {
      const bookingDate = vietnamDatePlusDays(13);
      const queueBody = {
        sportId: state.sport._id.toString(),
        facilityId: state.facility._id.toString(),
        bookingDate,
        startMinutes: 720,
        endMinutes: 780,
        groupSize: 4,
        paymentPolicy: 'SPLIT_EQUALLY'
      };
      for (let i = 4; i < 8; i += 1) {
        const response = await request('POST', '/matching/queue/join', { token: tokens[i], body: queueBody });
        assert(response.status === 200, `auto queue user ${i} failed: ${response.status} ${JSON.stringify(response.body)}`);
      }

      const session = await waitUntil('auto matching session', async () => MatchingSession.findOne({
        booking_date: bookingDate,
        start_minutes: 720,
        end_minutes: 780,
        status: 'FULL'
      }));
      const [booking, payments, matchingBookings, matchedQueues] = await Promise.all([
        Booking.findById(session.booking_id),
        Payment.find({ booking_id: session.booking_id, status: 'PENDING' }),
        Booking.countDocuments({ _id: session.booking_id }),
        MatchQueue.countDocuments({
          user_id: { $in: state.users.slice(4, 8).map(user => user._id) },
          status: 'MATCHED'
        })
      ]);
      assert(session.payment_policy === 'SPLIT_EQUALLY', `auto payment policy mismatch: ${session.payment_policy}`);
      assert(booking?.status === 'PENDING', `auto booking expected PENDING, got ${booking?.status}`);
      assert(matchingBookings === 1, `expected one booking, got ${matchingBookings}`);
      assert(matchedQueues === 4, `expected four MATCHED queues, got ${matchedQueues}`);
      assert(payments.length === 4, `expected four auto split payments, got ${payments.length}`);
      assert(payments.reduce((sum, payment) => sum + payment.amount, 0) === booking.total_price, 'auto split sum does not equal booking total');

      for (let i = 4; i < 8; i += 1) {
        const item = await getCalendarItem(tokens[i], booking._id);
        assert(item?.isMatching, `auto user ${i} cannot see matching calendar`);
        assert(item.matchingSessionId === session._id.toString(), `auto user ${i} matchingSessionId mismatch`);
        assert(item.paymentPolicy === 'SPLIT_EQUALLY', `auto user ${i} paymentPolicy mismatch`);
        assert(item.myPaymentStatus === 'PENDING', `auto user ${i} payment status mismatch`);
      }
    });

    await step('K. manual TEAM_VS_TEAM 5v5 tracks occupancy, capacity, leave, and payment lock', async () => {
      const session = await createManualSession({
        token: tokens[8],
        hostIndex: 8,
        courtIndex: 1,
        bookingDate: vietnamDatePlusDays(14),
        totalPlayersNeeded: 5,
        paymentPolicy: 'SPLIT_EQUALLY',
        teamMode: 'TEAM_VS_TEAM',
        teamSize: 5,
        hostTeamCode: 'A',
        hostRepresentedCount: 5
      });

      let current = await MatchingSession.findById(session._id);
      let detail = await request('GET', `/matching/${session._id}`, {
        token: tokens[8]
      });
      assert(current.status === 'OPEN', `team session expected OPEN, got ${current.status}`);
      assert(detail.body?.data?.teamAOccupancy === 5, 'Team A expected 5/5');
      assert(detail.body?.data?.teamBOccupancy === 0, 'Team B expected 0/5');

      await joinSession(session._id, tokens[9], {
        joinMode: 'TEAM_REPRESENTATIVE',
        teamName: 'Smoke Team B',
        memberCount: 5
      });
      current = await MatchingSession.findById(session._id);
      detail = await request('GET', `/matching/${session._id}`, {
        token: tokens[8]
      });
      assert(current.status === 'FULL', `team session expected FULL, got ${current.status}`);
      assert(detail.body?.data?.teamAOccupancy === 5, 'FULL Team A expected 5/5');
      assert(detail.body?.data?.teamBOccupancy === 5, 'FULL Team B expected 5/5');

      current.status = 'OPEN';
      await current.save();
      const overflow = await request('POST', `/matching/${session._id}/join`, {
        token: tokens[10],
        body: { joinMode: 'INDIVIDUAL' }
      });
      assert(overflow.status === 409, `expected team capacity 409, got ${overflow.status}`);
      assert(
        overflow.body?.code === 'TEAM_B_ALREADY_HAS_REPRESENTATIVE',
        `unexpected capacity error: ${JSON.stringify(overflow.body)}`
      );
      current.status = 'FULL';
      await current.save();

      const leave = await request('POST', `/matching/${session._id}/leave`, {
        token: tokens[9]
      });
      assert(leave.status === 200, `team member leave failed: ${leave.status} ${JSON.stringify(leave.body)}`);
      detail = await request('GET', `/matching/${session._id}`, {
        token: tokens[8]
      });
      assert(detail.body?.data?.status === 'OPEN', 'team session did not return OPEN');
      assert(detail.body?.data?.teamBOccupancy === 0, 'represented_count was not removed from Team B occupancy');

      await joinSession(session._id, tokens[9], {
        joinMode: 'TEAM_REPRESENTATIVE',
        teamName: 'Smoke Team B',
        memberCount: 5
      });
      const successPayment = await Payment.findOneAndUpdate(
        { booking_id: session.booking_id, user_id: state.users[8]._id, status: 'PENDING' },
        { status: 'SUCCESS', transaction_id: `${RUN_ID}-team-paid` },
        { new: true }
      );
      assert(successPayment, 'team session host payment was not found');

      const blockedLeave = await request('POST', `/matching/${session._id}/leave`, {
        token: tokens[9]
      });
      assert(blockedLeave.status === 409, `team paid leave expected 409, got ${blockedLeave.status}`);
      assert(blockedLeave.body?.code === 'MATCHING_PAYMENT_ALREADY_SUCCESS', 'team paid leave returned wrong error');

      const hostLeave = await request('POST', `/matching/${session._id}/leave`, {
        token: tokens[8]
      });
      assert(hostLeave.status === 400, `team host leave expected 400, got ${hostLeave.status}`);
      assert(hostLeave.body?.code === 'HOST_MUST_CANCEL_SESSION', 'team host leave returned wrong error');
    });

    await step('L. TEAM_REPRESENTATIVES_SPLIT creates two payments and clears stale pending invoices', async () => {
      const session = await createManualSession({
        token: tokens[4],
        hostIndex: 4,
        courtIndex: 0,
        bookingDate: vietnamDatePlusDays(15),
        totalPlayersNeeded: 5,
        paymentPolicy: 'TEAM_REPRESENTATIVES_SPLIT',
        teamMode: 'TEAM_VS_TEAM',
        teamSize: 5,
        hostTeamCode: 'A',
        hostRepresentedCount: 5
      });
      assert(
        await Payment.countDocuments({ booking_id: session.booking_id }) === 0,
        'representative payments were created before FULL'
      );

      await joinSession(session._id, tokens[5], {
        joinMode: 'TEAM_REPRESENTATIVE',
        teamName: 'Representative Smoke FC',
        memberCount: 5
      });
      const booking = await Booking.findById(session.booking_id);
      let activePayments = await Payment.find({
        booking_id: session.booking_id,
        status: 'PENDING'
      });
      assert(activePayments.length === 2, `expected two representative payments, got ${activePayments.length}`);
      assert(
        activePayments.reduce((sum, payment) => sum + payment.amount, 0) === booking.total_price,
        'representative payment sum does not equal booking total'
      );

      const baseAmount = Math.floor(booking.total_price / 2);
      const remainder = booking.total_price - baseAmount * 2;
      const hostPayment = activePayments.find(
        payment => payment.user_id.toString() === state.users[4]._id.toString()
      );
      const teamBPayment = activePayments.find(
        payment => payment.user_id.toString() === state.users[5]._id.toString()
      );
      assert(hostPayment?.amount === baseAmount + remainder, 'representative remainder was not assigned to host');
      assert(teamBPayment?.amount === baseAmount, 'Team B representative amount is incorrect');

      const leave = await request('POST', `/matching/${session._id}/leave`, {
        token: tokens[5]
      });
      assert(leave.status === 200, `representative leave failed: ${leave.status} ${JSON.stringify(leave.body)}`);
      const [afterLeaveSession, stalePendingCount, cancelledCount] = await Promise.all([
        MatchingSession.findById(session._id),
        Payment.countDocuments({
          booking_id: session.booking_id,
          status: 'PENDING'
        }),
        Payment.countDocuments({
          booking_id: session.booking_id,
          status: 'CANCELLED'
        })
      ]);
      assert(afterLeaveSession.status === 'OPEN', 'representative session did not return OPEN');
      assert(stalePendingCount === 0, `stale representative payments remain active: ${stalePendingCount}`);
      assert(cancelledCount === 2, `expected two cancelled representative payments, got ${cancelledCount}`);

      await joinSession(session._id, tokens[5], {
        joinMode: 'TEAM_REPRESENTATIVE',
        teamName: 'Representative Smoke FC',
        memberCount: 5
      });
      activePayments = await Payment.find({
        booking_id: session.booking_id,
        status: 'PENDING'
      });
      assert(activePayments.length === 2, `expected two recreated representative payments, got ${activePayments.length}`);
      await Payment.findByIdAndUpdate(activePayments[0]._id, {
        status: 'SUCCESS',
        transaction_id: `${RUN_ID}-representative-success`
      });

      const blockedLeave = await request('POST', `/matching/${session._id}/leave`, {
        token: tokens[5]
      });
      assert(blockedLeave.status === 409, `paid representative leave expected 409, got ${blockedLeave.status}`);
      assert(
        blockedLeave.body?.code === 'MATCHING_PAYMENT_ALREADY_SUCCESS',
        'paid representative leave returned wrong error'
      );
    });

    await step('M. auto TEAM_VS_TEAM 5v5 creates teams, one booking, two representative payments, and stable queue claims', async () => {
      const bookingDate = vietnamDatePlusDays(16);
      const baseQueueBody = {
        sportId: state.sport._id.toString(),
        facilityId: state.facility._id.toString(),
        bookingDate,
        startMinutes: 840,
        endMinutes: 900,
        teamMode: 'TEAM_VS_TEAM',
        memberCount: 5,
        teamSize: 5,
        paymentPolicy: 'TEAM_REPRESENTATIVES_SPLIT'
      };

      const teamAJoin = await request('POST', '/matching/queue/join', {
        token: tokens[0],
        body: { ...baseQueueBody, preferredTeam: 'A' }
      });
      assert(teamAJoin.status === 200, `auto Team A join failed: ${JSON.stringify(teamAJoin.body)}`);
      const teamBJoin = await request('POST', '/matching/queue/join', {
        token: tokens[1],
        body: { ...baseQueueBody, preferredTeam: 'B' }
      });
      assert(teamBJoin.status === 200, `auto Team B join failed: ${JSON.stringify(teamBJoin.body)}`);

      const session = await waitUntil('auto team session', async () =>
        MatchingSession.findOne({
          booking_date: bookingDate,
          team_mode: 'TEAM_VS_TEAM',
          status: 'FULL'
        })
      );
      const [booking, payments, queues] = await Promise.all([
        Booking.findById(session.booking_id),
        Payment.find({ booking_id: session.booking_id, status: 'PENDING' }),
        MatchQueue.find({
          user_id: { $in: [state.users[0]._id, state.users[1]._id] }
        })
      ]);

      assert(session.host_team_code === 'A', `auto team host expected Team A, got ${session.host_team_code}`);
      assert(session.host_represented_count === 5, 'auto team host represented_count mismatch');
      assert(session.teams.length === 2, `expected two team definitions, got ${session.teams.length}`);
      assert(session.teams.every(team => team.max_players === 5), 'auto team max_players mismatch');
      const teamBOccupancy = session.members
        .filter(member => member.team_code === 'B')
        .reduce((sum, member) => sum + member.represented_count, 0);
      assert(teamBOccupancy === 5, `auto Team B expected 5/5, got ${teamBOccupancy}/5`);
      assert(booking?.status === 'PENDING', `auto team booking expected PENDING, got ${booking?.status}`);
      assert(payments.length === 2, `expected two representative payments, got ${payments.length}`);
      assert(
        payments.reduce((sum, payment) => sum + payment.amount, 0) === booking.total_price,
        'auto representative payment sum does not equal booking total'
      );
      const hostPayment = payments.find(
        payment => payment.user_id.toString() === session.host_id.toString()
      );
      assert(
        hostPayment?.amount === Math.ceil(booking.total_price / 2),
        'auto representative remainder was not assigned to the host'
      );
      assert(queues.every(queue => queue.status === 'MATCHED'), 'auto team queues were not both MATCHED');
      assert(
        queues.every(queue => queue.matching_session_id?.toString() === session._id.toString()),
        'auto team queue matching_session_id mismatch'
      );

      const sessionCountBefore = await MatchingSession.countDocuments({
        booking_date: bookingDate,
        team_mode: 'TEAM_VS_TEAM'
      });
      await matchingService.runMatchmakerAlgorithm(
        state.sport._id.toString(),
        state.facility._id.toString(),
        bookingDate
      );
      const sessionCountAfter = await MatchingSession.countDocuments({
        booking_date: bookingDate,
        team_mode: 'TEAM_VS_TEAM'
      });
      assert(sessionCountAfter === sessionCountBefore, 'MATCHED queues were matched again');

      const extraJoin = await request('POST', '/matching/queue/join', {
        token: tokens[2],
        body: { ...baseQueueBody, preferredTeam: 'B', memberCount: 1 }
      });
      assert(extraJoin.status === 200, `extra Team B queue failed: ${JSON.stringify(extraJoin.body)}`);
      const extraQueue = await MatchQueue.findById(extraJoin.body.data.id);
      assert(extraQueue.status === 'SEARCHING', 'extra queue was incorrectly added to the completed session');
      await request('POST', '/matching/queue/leave', { token: tokens[2] });
    });

    await step('N. auto TEAM_FILL assigns AUTO to the team missing more slots', async () => {
      const bookingDate = vietnamDatePlusDays(17);
      const queueSpecs = [
        { userIndex: 3, preferredTeam: 'A', memberCount: 3 },
        { userIndex: 4, preferredTeam: 'B', memberCount: 4 },
        { userIndex: 5, preferredTeam: 'AUTO', memberCount: 2 },
        { userIndex: 6, preferredTeam: 'B', memberCount: 1 }
      ];
      for (const spec of queueSpecs) {
        const response = await request('POST', '/matching/queue/join', {
          token: tokens[spec.userIndex],
          body: {
            sportId: state.sport._id.toString(),
            facilityId: state.facility._id.toString(),
            bookingDate,
            startMinutes: 960,
            endMinutes: 1020,
            teamMode: 'TEAM_FILL',
            preferredTeam: spec.preferredTeam,
            memberCount: spec.memberCount,
            teamSize: 5,
            paymentPolicy: 'SPLIT_EQUALLY'
          }
        });
        assert(response.status === 200, `TEAM_FILL queue failed: ${JSON.stringify(response.body)}`);
      }

      const session = await waitUntil('auto TEAM_FILL session', async () =>
        MatchingSession.findOne({
          booking_date: bookingDate,
          team_mode: 'TEAM_FILL',
          status: 'FULL'
        })
      );
      const autoMember = session.members.find(
        member => member.user_id.toString() === state.users[5]._id.toString()
      );
      assert(autoMember?.team_code === 'A', `AUTO queue expected Team A, got ${autoMember?.team_code}`);
      assert(autoMember?.represented_count === 2, 'AUTO represented_count mismatch');
      assert(
        await Payment.countDocuments({ booking_id: session.booking_id, status: 'PENDING' }) === 4,
        'TEAM_FILL SPLIT_EQUALLY should create one payment per app user'
      );
    });

    await step('O. auto team rejects overflow and does not match a common window below 60 minutes', async () => {
      const invalid = await request('POST', '/matching/queue/join', {
        token: tokens[7],
        body: {
          sportId: state.sport._id.toString(),
          facilityId: state.facility._id.toString(),
          bookingDate: vietnamDatePlusDays(18),
          startMinutes: 600,
          endMinutes: 720,
          teamMode: 'TEAM_VS_TEAM',
          preferredTeam: 'A',
          memberCount: 6,
          teamSize: 5
        }
      });
      assert(invalid.status === 400, `overflow queue expected 400, got ${invalid.status}`);
      assert(invalid.body?.code === 'INVALID_TEAM_QUEUE_SIZE', 'overflow queue returned wrong error');

      const bookingDate = vietnamDatePlusDays(19);
      const first = await request('POST', '/matching/queue/join', {
        token: tokens[7],
        body: {
          sportId: state.sport._id.toString(),
          facilityId: state.facility._id.toString(),
          bookingDate,
          startMinutes: 600,
          endMinutes: 720,
          teamMode: 'TEAM_VS_TEAM',
          preferredTeam: 'A',
          memberCount: 5,
          teamSize: 5
        }
      });
      const second = await request('POST', '/matching/queue/join', {
        token: tokens[8],
        body: {
          sportId: state.sport._id.toString(),
          facilityId: state.facility._id.toString(),
          bookingDate,
          startMinutes: 680,
          endMinutes: 800,
          teamMode: 'TEAM_VS_TEAM',
          preferredTeam: 'B',
          memberCount: 5,
          teamSize: 5
        }
      });
      assert(first.status === 200 && second.status === 200, 'overlap test queues failed to join');
      await new Promise(resolve => setTimeout(resolve, 500));
      const [sessionCount, searchingCount] = await Promise.all([
        MatchingSession.countDocuments({ booking_date: bookingDate }),
        MatchQueue.countDocuments({
          user_id: { $in: [state.users[7]._id, state.users[8]._id] },
          status: 'SEARCHING'
        })
      ]);
      assert(sessionCount === 0, 'team queues with a common window below 60 minutes were matched');
      assert(searchingCount === 2, `expected two SEARCHING queues, got ${searchingCount}`);
      await request('POST', '/matching/queue/leave', { token: tokens[7] });
      await request('POST', '/matching/queue/leave', { token: tokens[8] });
    });

    await step('P. occurrence join modes stay isolated from fixed schedule templates and other days', async () => {
      const fixedSchedule = await FixedSchedule.create({
        user_id: state.users[0]._id,
        type: 'MATCHING',
        sport_id: state.sport._id,
        facility_id: state.facility._id,
        court_id: state.courts[0]._id,
        start_minutes: 1080,
        end_minutes: 1140,
        frequency: 'DAILY',
        start_date: vietnamDatePlusDays(20),
        status: 'ACTIVE',
        matching_config: {
          team_mode: 'TEAM_VS_TEAM',
          team_size: 5,
          payment_policy: 'SPLIT_EQUALLY',
          host_team_code: 'A',
          host_represented_count: 5,
          readiness: 'READY',
          teams: [
            {
              team_code: 'A',
              max_players: 5,
              representative_user_id: state.users[0]._id
            },
            { team_code: 'B', max_players: 5 }
          ],
          members: []
        }
      });
      const templateBefore = JSON.stringify(fixedSchedule.matching_config.toObject());

      const dayA = await createManualSession({
        token: tokens[0],
        hostIndex: 0,
        courtIndex: 0,
        bookingDate: vietnamDatePlusDays(20),
        startMinutes: 1080,
        endMinutes: 1140,
        totalPlayersNeeded: 5,
        paymentPolicy: 'SPLIT_EQUALLY',
        teamMode: 'TEAM_VS_TEAM',
        teamSize: 5,
        hostTeamCode: 'A',
        hostRepresentedCount: 5
      });
      const dayB = await createManualSession({
        token: tokens[0],
        hostIndex: 0,
        courtIndex: 0,
        bookingDate: vietnamDatePlusDays(21),
        startMinutes: 1080,
        endMinutes: 1140,
        totalPlayersNeeded: 5,
        paymentPolicy: 'SPLIT_EQUALLY',
        teamMode: 'TEAM_VS_TEAM',
        teamSize: 5,
        hostTeamCode: 'A',
        hostRepresentedCount: 5
      });
      await MatchingSession.updateMany(
        { _id: { $in: [dayA._id, dayB._id] } },
        { fixed_schedule_id: fixedSchedule._id }
      );

      const individualJoin = await request('POST', `/matching/${dayA._id}/join`, {
        token: tokens[1],
        body: { joinMode: 'INDIVIDUAL' }
      });
      assert(individualJoin.status === 200, `individual join failed: ${JSON.stringify(individualJoin.body)}`);
      assert(individualJoin.body?.data?.teamB?.joinType === 'INDIVIDUALS', 'Team B joinType is not INDIVIDUALS');
      assert(individualJoin.body?.data?.teamBOccupancy === 1, 'individual join did not add exactly one player');
      assert(individualJoin.body?.data?.fixedScheduleId === fixedSchedule._id.toString(), 'fixed_schedule_id was lost');

      const duplicate = await request('POST', `/matching/${dayA._id}/join`, {
        token: tokens[1],
        body: { joinMode: 'INDIVIDUAL' }
      });
      assert(duplicate.status === 409 && duplicate.body?.code === 'MEMBER_EXISTS', 'duplicate occurrence join was not blocked');

      const mixedRepresentative = await request('POST', `/matching/${dayA._id}/join`, {
        token: tokens[2],
        body: {
          joinMode: 'TEAM_REPRESENTATIVE',
          teamName: 'Mixed Team',
          memberCount: 4
        }
      });
      assert(
        mixedRepresentative.status === 409
          && mixedRepresentative.body?.code === 'TEAM_B_ALREADY_HAS_MEMBERS',
        'representative join was not blocked when Team B already had individuals'
      );

      const [dayBAfter, templateAfter, dayAPaymentCount] = await Promise.all([
        MatchingSession.findById(dayB._id),
        FixedSchedule.findById(fixedSchedule._id),
        Payment.countDocuments({ booking_id: dayA.booking_id })
      ]);
      assert(dayBAfter.members.length === 0, 'joining day A changed day B members');
      assert(
        JSON.stringify(templateAfter.matching_config.toObject()) === templateBefore,
        'joining an occurrence changed the FixedSchedule template'
      );
      assert(dayAPaymentCount === 0, 'individual occurrence join created payment before the session was full');

      const representativeSession = await createManualSession({
        token: tokens[3],
        hostIndex: 3,
        courtIndex: 1,
        bookingDate: vietnamDatePlusDays(22),
        startMinutes: 1080,
        endMinutes: 1140,
        totalPlayersNeeded: 5,
        paymentPolicy: 'TEAM_REPRESENTATIVES_SPLIT',
        teamMode: 'TEAM_VS_TEAM',
        teamSize: 5,
        hostTeamCode: 'A',
        hostRepresentedCount: 5
      });
      const hostJoin = await request('POST', `/matching/${representativeSession._id}/join`, {
        token: tokens[3],
        body: { joinMode: 'INDIVIDUAL' }
      });
      assert(hostJoin.status === 400 && hostJoin.body?.code === 'HOST_CANNOT_JOIN', 'host joined their own Team B');

      const representativeJoin = await request('POST', `/matching/${representativeSession._id}/join`, {
        token: tokens[4],
        body: {
          joinMode: 'TEAM_REPRESENTATIVE',
          teamName: 'FC Sinh Vien',
          memberCount: 5,
          note: 'Du quan so'
        }
      });
      assert(representativeJoin.status === 200, `representative join failed: ${JSON.stringify(representativeJoin.body)}`);
      assert(representativeJoin.body?.data?.teamB?.joinType === 'TEAM_REPRESENTATIVE', 'Team B representative joinType missing');
      assert(representativeJoin.body?.data?.teamB?.teamName === 'FC Sinh Vien', 'Team B name was not returned');
      assert(representativeJoin.body?.data?.teamB?.memberCount === 5, 'Team B representative memberCount mismatch');
      assert(representativeJoin.body?.data?.readiness === 'READY', 'full representative team did not become READY');

      await MatchingSession.findByIdAndUpdate(representativeSession._id, { status: 'OPEN' });
      const secondRepresentative = await request('POST', `/matching/${representativeSession._id}/join`, {
        token: tokens[5],
        body: {
          joinMode: 'TEAM_REPRESENTATIVE',
          teamName: 'Another FC',
          memberCount: 5
        }
      });
      assert(
        secondRepresentative.status === 409
          && secondRepresentative.body?.code === 'TEAM_B_ALREADY_HAS_REPRESENTATIVE',
        'second Team B representative was not blocked'
      );

      const invalidCountSession = await createManualSession({
        token: tokens[6],
        hostIndex: 6,
        courtIndex: 0,
        bookingDate: vietnamDatePlusDays(23),
        startMinutes: 1080,
        endMinutes: 1140,
        totalPlayersNeeded: 5,
        paymentPolicy: 'SPLIT_EQUALLY',
        teamMode: 'TEAM_VS_TEAM',
        teamSize: 5,
        hostTeamCode: 'A',
        hostRepresentedCount: 5
      });
      const invalidCount = await request('POST', `/matching/${invalidCountSession._id}/join`, {
        token: tokens[7],
        body: {
          joinMode: 'TEAM_REPRESENTATIVE',
          teamName: 'Too Large FC',
          memberCount: 6
        }
      });
      assert(
        invalidCount.status === 400
          && invalidCount.body?.code === 'INVALID_TEAM_REPRESENTATIVE_COUNT',
        'representative memberCount above team size was not blocked'
      );
      await MatchingSession.findByIdAndUpdate(invalidCountSession._id, { status: 'CANCELLED' });
      const cancelledJoin = await request('POST', `/matching/${invalidCountSession._id}/join`, {
        token: tokens[8],
        body: { joinMode: 'INDIVIDUAL' }
      });
      assert(cancelledJoin.status === 400 && cancelledJoin.body?.code === 'SESSION_NOT_OPEN', 'cancelled session accepted a join');
    });

    console.log('\nMatching/payment smoke test completed successfully.');
  } finally {
    if (KEEP_SMOKE_DATA) {
      console.warn(`KEEP_SMOKE_DATA=1, smoke data kept with prefix: ${RUN_ID}`);
    } else {
      await cleanup();
    }
    await mongoose.disconnect();
  }
}

main().catch(async (error) => {
  console.error('\nMatching smoke test failed.');
  console.error(error.stack || error.message);
  try {
    if (!KEEP_SMOKE_DATA && mongoose.connection.readyState === 1) await cleanup();
    if (mongoose.connection.readyState !== 0) await mongoose.disconnect();
  } catch (cleanupError) {
    console.error(`Cleanup failed: ${cleanupError.message}`);
  }
  process.exit(1);
});
