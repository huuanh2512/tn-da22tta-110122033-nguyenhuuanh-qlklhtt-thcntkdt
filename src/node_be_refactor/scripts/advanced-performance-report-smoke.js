const assert = require('node:assert/strict');

const reportService = require('../src/services/report.service');
const User = require('../src/models/user.model');
const Court = require('../src/models/court.model');

const ids = {
  staffA: '111111111111111111111111',
  staffNoScope: '222222222222222222222222',
  facilityA: 'aaaaaaaaaaaaaaaaaaaaaaaa',
  facilityB: 'bbbbbbbbbbbbbbbbbbbbbbbb',
  sportPadel: '333333333333333333333333',
  sportTennis: '444444444444444444444444',
  courtA1: 'ccccccccccccccccccccccc1',
  courtA2: 'ccccccccccccccccccccccc2',
  courtB1: 'ddddddddddddddddddddddd1'
};

const facilities = {
  [ids.facilityA]: { _id: ids.facilityA, name: 'Facility A' },
  [ids.facilityB]: { _id: ids.facilityB, name: 'Facility B' }
};
const sports = {
  [ids.sportPadel]: { _id: ids.sportPadel, name: 'Padel' },
  [ids.sportTennis]: { _id: ids.sportTennis, name: 'Tennis' }
};
const courts = [
  {
    _id: ids.courtA1,
    name: 'A1',
    facility_id: facilities[ids.facilityA],
    sport_id: sports[ids.sportPadel],
    status: 'ACTIVE',
    slot_config: { opening_minutes: 600, closing_minutes: 720, slots: [] }
  },
  {
    _id: ids.courtA2,
    name: 'A2',
    facility_id: facilities[ids.facilityA],
    sport_id: sports[ids.sportTennis],
    status: 'MAINTENANCE',
    slot_config: { opening_minutes: 600, closing_minutes: 720, slots: [] }
  },
  {
    _id: ids.courtB1,
    name: 'B1',
    facility_id: facilities[ids.facilityB],
    sport_id: sports[ids.sportPadel],
    status: 'ACTIVE',
    slot_config: { opening_minutes: 600, closing_minutes: 720, slots: [] }
  }
];

const users = new Map([
  [ids.staffA, { facility_id: ids.facilityA }],
  [ids.staffNoScope, { facility_id: null }]
]);

User.findById = id => ({
  select: async () => users.get(String(id)) || null
});

Court.find = query => {
  const matches = courts.filter(court => {
    const facilityId = court.facility_id._id;
    const sportId = court.sport_id._id;
    if (
      query.facility_id?.$in
      && !query.facility_id.$in.map(String).includes(facilityId)
    ) {
      return false;
    }
    if (query._id && String(query._id) !== String(court._id)) return false;
    if (query.sport_id && String(query.sport_id) !== sportId) return false;
    return true;
  });

  const chain = {
    select: () => chain,
    populate: () => chain,
    lean: async () => matches
  };
  return chain;
};

const booking = (id, status, courtId, extra = {}) => ({
  _id: id,
  user_id: null,
  guest_name: 'Sensitive Guest',
  guest_phone: '0901234567',
  guest_email: 'guest@example.com',
  court_id: courtId,
  booking_date: '2026-06-10',
  start_minutes: 600,
  end_minutes: 660,
  status,
  ...extra
});

const bookings = [
  booking('000000000000000000000001', 'CONFIRMED', ids.courtA1),
  booking('000000000000000000000002', 'COMPLETED', ids.courtA1, {
    start_minutes: 660,
    end_minutes: 720,
    guest_phone: '090 123 4567'
  }),
  booking('000000000000000000000003', 'PENDING', ids.courtA1),
  booking('000000000000000000000004', 'CANCELLED', ids.courtA1),
  booking('000000000000000000000005', 'CONFIRMED', ids.courtA2),
  booking('000000000000000000000006', 'CONFIRMED', ids.courtB1, {
    booking_date: '2026-06-11',
    guest_phone: '',
    guest_email: 'another@example.com',
    guest_name: ''
  })
];

const payments = [
  { booking_id: bookings[0]._id, amount: 100, status: 'SUCCESS' },
  { booking_id: bookings[1]._id, amount: 80, status: 'SUCCESS' },
  { booking_id: bookings[2]._id, amount: 999, status: 'SUCCESS' },
  { booking_id: bookings[3]._id, amount: 40, status: 'SUCCESS' },
  { booking_id: bookings[3]._id, amount: 10, status: 'REFUND_PENDING' },
  { booking_id: bookings[4]._id, amount: 70, status: 'PENDING' },
  { booking_id: bookings[5]._id, amount: 120, status: 'SUCCESS' }
];

reportService._loadBookings = async query => bookings.filter(item => {
  if (!query.court_id.$in.map(String).includes(String(item.court_id))) {
    return false;
  }
  if (item.booking_date < query.booking_date.$gte) return false;
  if (item.booking_date > query.booking_date.$lte) return false;
  if (query.status && item.status !== query.status) return false;
  return true;
});
reportService._loadPayments = async bookingIds => payments.filter(payment => (
  bookingIds.map(String).includes(String(payment.booking_id))
));
reportService._loadCourtBlocks = async () => [
  {
    _id: 'eeeeeeeeeeeeeeeeeeeeeeee',
    facility_id: ids.facilityA,
    court_id: ids.courtA1,
    status: 'ACTIVE',
    start_time: new Date('2026-06-10T10:30:00'),
    end_time: new Date('2026-06-10T11:00:00'),
    type: 'MAINTENANCE'
  }
];

async function expectReject(promise, statusCode, code) {
  await assert.rejects(promise, error => {
    assert.equal(error.statusCode, statusCode);
    assert.equal(error.code, code);
    return true;
  });
}

async function run() {
  const filters = { dateFrom: '2026-06-10', dateTo: '2026-06-11' };

  await expectReject(
    reportService.getAdvancedPerformance(filters, { id: ids.staffA, role: 'CUSTOMER' }),
    403,
    'FORBIDDEN'
  );
  await expectReject(
    reportService.getAdvancedPerformance(filters, { id: ids.staffNoScope, role: 'STAFF' }),
    403,
    'STAFF_FACILITY_SCOPE_REQUIRED'
  );
  await expectReject(
    reportService.getAdvancedPerformance(
      { ...filters, facilityId: ids.facilityB },
      { id: ids.staffA, role: 'STAFF' }
    ),
    403,
    'FORBIDDEN'
  );
  await expectReject(
    reportService.getAdvancedPerformance(
      { ...filters, facilityIds: `${ids.facilityA},${ids.facilityB}` },
      { id: ids.staffA, role: 'STAFF' }
    ),
    403,
    'FORBIDDEN'
  );
  await expectReject(
    reportService.getAdvancedPerformance(
      { ...filters, courtId: ids.courtB1 },
      { id: ids.staffA, role: 'STAFF' }
    ),
    403,
    'FORBIDDEN'
  );

  const staffReport = await reportService.getAdvancedPerformance(
    filters,
    { id: ids.staffA, role: 'STAFF' }
  );
  assert.equal(staffReport.scope.type, 'STAFF');
  assert.deepEqual(staffReport.scope.facilityIds, [ids.facilityA]);
  assert.equal(staffReport.summary.totalBookings, 5);
  assert.equal(staffReport.summary.activeBookings, 3);
  assert.equal(staffReport.summary.pendingBookings, 1);
  assert.equal(staffReport.summary.cancelledBookings, 1);
  assert.equal(staffReport.summary.paidRevenue, 180);
  assert.equal(staffReport.summary.pendingRevenue, 70);
  assert.equal(staffReport.summary.paidCancelledAmount, 40);
  assert.equal(staffReport.summary.refundPendingAmount, 10);
  assert.equal(staffReport.summary.bookedMinutes, 180);
  assert.equal(staffReport.summary.availableMinutes, 210);
  assert.equal(staffReport.courtStats.find(item => item.courtId === ids.courtA2).availableMinutes, 0);
  assert.equal(staffReport.facilityStats.length, 1);
  assert.equal(staffReport.sportStats.length, 2);
  assert.equal(staffReport.dailyStats.length, 2);
  assert.equal(staffReport.weekdayStats.length, 7);
  assert.equal(staffReport.peakHours.length, 2);
  assert.equal(staffReport.customerStats.length, 1);
  assert.equal(staffReport.customerStats[0].bookingCount, 3);

  const serializedStaff = JSON.stringify(staffReport);
  assert.equal(serializedStaff.includes('Sensitive Guest'), false);
  assert.equal(serializedStaff.includes('0901234567'), false);
  assert.equal(serializedStaff.includes('guest@example.com'), false);

  const includedReport = await reportService.getAdvancedPerformance(
    { ...filters, include: 'summary,courtStats' },
    { id: ids.staffA, role: 'STAFF' }
  );
  assert.ok(includedReport.summary);
  assert.ok(includedReport.courtStats);
  assert.equal(Object.prototype.hasOwnProperty.call(includedReport, 'customerStats'), false);

  const staffSportFilter = await reportService.getAdvancedPerformance(
    { ...filters, sportId: ids.sportPadel },
    { id: ids.staffA, role: 'STAFF' }
  );
  assert.deepEqual(staffSportFilter.courtStats.map(item => item.courtId), [ids.courtA1]);

  const adminReport = await reportService.getAdvancedPerformance(
    filters,
    { id: ids.staffA, role: 'ADMIN' }
  );
  assert.equal(adminReport.scope.type, 'ADMIN');
  assert.equal(adminReport.scope.isSystemWide, true);
  assert.equal(adminReport.summary.totalBookings, 6);
  assert.equal(adminReport.summary.activeBookings, 4);
  assert.equal(adminReport.summary.paidRevenue, 300);
  assert.equal(adminReport.facilityStats.length, 2);
  assert.equal(adminReport.sportStats.find(item => item.sportId === ids.sportPadel).activeBookings, 3);

  const adminFacilityFilter = await reportService.getAdvancedPerformance(
    { ...filters, facilityIds: `${ids.facilityA},${ids.facilityB}` },
    { id: ids.staffA, role: 'SUPER_ADMIN' }
  );
  assert.equal(adminFacilityFilter.facilityStats.length, 2);

  const adminStatusFilter = await reportService.getAdvancedPerformance(
    { ...filters, status: 'PENDING' },
    { id: ids.staffA, role: 'ADMIN' }
  );
  assert.equal(adminStatusFilter.summary.totalBookings, 1);
  assert.equal(adminStatusFilter.summary.activeBookings, 0);
  assert.equal(adminStatusFilter.summary.paidRevenue, 0);

  console.log('Advanced performance report smoke tests passed.');
}

run().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
