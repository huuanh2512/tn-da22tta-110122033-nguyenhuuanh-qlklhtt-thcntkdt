const assert = require('node:assert/strict');

const reportService = require('../src/services/report.service');
const bookingService = require('../src/services/booking.service');
const User = require('../src/models/user.model');
const Facility = require('../src/models/facility.model');
const Court = require('../src/models/court.model');

const ids = {
  staff: '111111111111111111111111',
  staffNoScope: '222222222222222222222222',
  facilityA: 'aaaaaaaaaaaaaaaaaaaaaaaa',
  facilityB: 'bbbbbbbbbbbbbbbbbbbbbbbb',
  sportA: '333333333333333333333333',
  sportB: '444444444444444444444444',
  courtA: 'cccccccccccccccccccccccc',
  courtB: 'dddddddddddddddddddddddd'
};

const sports = {
  [ids.sportA]: { _id: ids.sportA, name: 'Football' },
  [ids.sportB]: { _id: ids.sportB, name: 'Tennis' }
};

const courts = [
  {
    _id: ids.courtA,
    name: 'Court A',
    facility_id: ids.facilityA,
    sport_id: sports[ids.sportA],
    status: 'ACTIVE',
    slot_config: {
      opening_minutes: 600,
      closing_minutes: 1200,
      slots: []
    }
  },
  {
    _id: ids.courtB,
    name: 'Court B',
    facility_id: ids.facilityB,
    sport_id: sports[ids.sportB],
    status: 'ACTIVE',
    slot_config: {
      opening_minutes: 600,
      closing_minutes: 1200,
      slots: []
    }
  }
];

const userFacility = new Map([
  [ids.staff, ids.facilityA],
  [ids.staffNoScope, null]
]);

User.findById = id => ({
  select: async () => ({ facility_id: userFacility.get(String(id)) || null })
});
Facility.find = () => ({
  select: async () => []
});
Court.find = query => ({
  select: () => ({
    lean: async () => courts.filter(court => {
      if (
        query.facility_id?.$in
        && !query.facility_id.$in.map(String).includes(String(court.facility_id))
      ) {
        return false;
      }
      if (query._id && String(query._id) !== String(court._id)) return false;
      if (query.sport_id && String(query.sport_id) !== String(court.sport_id._id)) return false;
      return true;
    }),
    populate: () => ({
      lean: async () => courts.filter(court => {
        if (
          query.facility_id?.$in
          && !query.facility_id.$in.map(String).includes(String(court.facility_id))
        ) {
          return false;
        }
        if (query._id && String(query._id) !== String(court._id)) return false;
        if (query.sport_id && String(query.sport_id) !== String(court.sport_id._id)) return false;
        return true;
      })
    })
  })
});

const booking = (
  id,
  status,
  courtId = ids.courtA,
  userId = null,
  extra = {}
) => ({
  _id: id,
  user_id: userId,
  guest_name: userId ? null : 'Sensitive Guest Name',
  guest_phone: null,
  court_id: courtId,
  booking_date: '2026-06-11',
  start_minutes: 600,
  end_minutes: 660,
  status,
  ...extra
});

const bookings = [
  booking('000000000000000000000001', 'CONFIRMED', ids.courtA, ids.staff),
  booking('000000000000000000000002', 'COMPLETED', ids.courtA, null, {
    guest_name: 'Sensitive Guest Name',
    guest_phone: '090 123-4567',
    start_minutes: 660,
    end_minutes: 720
  }),
  booking('000000000000000000000003', 'PENDING'),
  booking('000000000000000000000004', 'CANCELLED'),
  booking('000000000000000000000005', 'CANCELLED'),
  booking('000000000000000000000006', 'CANCELLED'),
  booking('000000000000000000000007', 'CONFIRMED', ids.courtA, null, {
    guest_name: 'Sensitive Guest Name',
    guest_phone: '090-123-4567',
    start_minutes: 720,
    end_minutes: 780
  }),
  booking('000000000000000000000008', 'CONFIRMED', ids.courtA, null, {
    guest_name: '',
    guest_email: 'GUEST@Example.COM',
    start_minutes: 780,
    end_minutes: 840
  }),
  booking('000000000000000000000009', 'COMPLETED', ids.courtA, null, {
    guest_name: '',
    guest_email: 'guest@example.com',
    start_minutes: 840,
    end_minutes: 900
  }),
  booking('000000000000000000000010', 'CONFIRMED', ids.courtA, null, {
    guest_name: '  Nguyen   Van   A  ',
    start_minutes: 900,
    end_minutes: 960
  }),
  booking('000000000000000000000011', 'COMPLETED', ids.courtA, null, {
    guest_name: 'nguyen van a',
    start_minutes: 960,
    end_minutes: 1020
  }),
  booking('000000000000000000000012', 'CONFIRMED', ids.courtA, null, {
    guest_name: '',
    start_minutes: 1020,
    end_minutes: 1080
  }),
  booking('000000000000000000000013', 'CONFIRMED', ids.courtA, null, {
    guest_name: '',
    start_minutes: 1080,
    end_minutes: 1140
  }),
  booking('000000000000000000000014', 'CONFIRMED', ids.courtA, null, {
    guest_name: 'Customer',
    guest_phone: '0901234567',
    start_minutes: 1140,
    end_minutes: 1200
  })
];
const payments = [
  {
    booking_id: bookings[0]._id,
    amount: 100,
    status: 'SUCCESS'
  },
  {
    booking_id: bookings[1]._id,
    amount: 70,
    status: 'PENDING'
  },
  {
    booking_id: bookings[2]._id,
    amount: 999,
    status: 'SUCCESS'
  },
  {
    booking_id: bookings[3]._id,
    amount: 50,
    status: 'SUCCESS'
  },
  {
    booking_id: bookings[4]._id,
    amount: 40,
    status: 'REFUND_PENDING'
  },
  {
    booking_id: bookings[5]._id,
    amount: 30,
    status: 'REFUNDED'
  },
  {
    booking_id: bookings[6]._id,
    amount: 30,
    status: 'SUCCESS'
  },
  {
    booking_id: bookings[7]._id,
    amount: 20,
    status: 'SUCCESS'
  },
  {
    booking_id: bookings[8]._id,
    amount: 25,
    status: 'SUCCESS'
  },
  {
    booking_id: bookings[9]._id,
    amount: 10,
    status: 'SUCCESS'
  },
  {
    booking_id: bookings[10]._id,
    amount: 15,
    status: 'SUCCESS'
  },
  {
    booking_id: bookings[11]._id,
    amount: 5,
    status: 'SUCCESS'
  },
  {
    booking_id: bookings[12]._id,
    amount: 6,
    status: 'SUCCESS'
  },
  {
    booking_id: bookings[13]._id,
    amount: 7,
    status: 'SUCCESS'
  }
];

reportService._loadBookings = async query => bookings.filter(item => (
  query.court_id.$in.map(String).includes(String(item.court_id))
));
reportService._loadPayments = async () => payments;
reportService._loadCourtBlocks = async () => [];

async function expectReject(promise, statusCode, code) {
  await assert.rejects(promise, error => {
    assert.equal(error.statusCode, statusCode);
    assert.equal(error.code, code);
    return true;
  });
}

async function run() {
  const dateFilters = {
    dateFrom: '2026-06-01',
    dateTo: '2026-06-30'
  };

  await expectReject(
    reportService.getCourtPerformance(
      dateFilters,
      { id: ids.staff, role: 'CUSTOMER' }
    ),
    403,
    'FORBIDDEN'
  );

  const staffReport = await reportService.getCourtPerformance(
    dateFilters,
    { id: ids.staff, role: 'STAFF' }
  );
  assert.deepEqual(
    staffReport.courtStats.map(item => item.courtId),
    [ids.courtA]
  );
  assert.equal(staffReport.totalActiveBookings, 10);
  assert.equal(staffReport.pendingBookings, 1);
  assert.equal(staffReport.paidRevenue, 218);
  assert.equal(staffReport.pendingRevenue, 70);
  assert.equal(staffReport.paidCancelledAmount, 50);
  assert.equal(staffReport.refundPendingAmount, 40);
  assert.equal(staffReport.refundedAmount, 30);
  assert.equal(staffReport.courtStats[0].bookedMinutes, 600);
  assert.equal(staffReport.courtStats[0].availableMinutes, 18000);
  assert.equal(staffReport.courtStats[0].sportId, ids.sportA);
  assert.equal(staffReport.courtStats[0].sportName, 'Football');
  assert.equal(staffReport.customerStats.length, 6);
  assert.equal(
    staffReport.customerStats.every(item => item.customerKey.length === 16),
    true
  );

  const customerByBookings = new Map(
    staffReport.customerStats.map(item => [item.bookingCount, item])
  );
  const phoneGuest = staffReport.customerStats.find(
    item => item.customerType === 'GUEST'
      && item.bookingCount === 3
      && item.paidRevenue === 37
  );
  assert.ok(phoneGuest);
  assert.equal(phoneGuest.bookedMinutes, 180);
  assert.equal(phoneGuest.displayName.includes('0901234567'), false);

  const emailGuest = staffReport.customerStats.find(
    item => item.customerType === 'GUEST'
      && item.bookingCount === 2
      && item.paidRevenue === 45
  );
  assert.ok(emailGuest);
  assert.equal(emailGuest.displayName.includes('guest@example.com'), false);

  const nameGuest = staffReport.customerStats.find(
    item => item.customerType === 'GUEST'
      && item.bookingCount === 2
      && item.paidRevenue === 25
  );
  assert.ok(nameGuest);

  const fallbackGuests = staffReport.customerStats.filter(
    item => item.customerType === 'GUEST'
      && item.bookingCount === 1
      && [5, 6].includes(item.paidRevenue)
  );
  assert.equal(fallbackGuests.length, 2);
  assert.notEqual(fallbackGuests[0].customerKey, fallbackGuests[1].customerKey);
  assert.equal(customerByBookings.has(10), false);

  const serialized = JSON.stringify(staffReport);
  assert.equal(serialized.includes('email'), false);
  assert.equal(serialized.includes('phone'), false);
  assert.equal(serialized.includes('Sensitive Guest Name'), false);
  assert.equal(serialized.includes('0901234567'), false);
  assert.equal(serialized.includes('guest@example.com'), false);

  await expectReject(
    reportService.getCourtPerformance(
      { ...dateFilters, facilityId: ids.facilityB },
      { id: ids.staff, role: 'STAFF' }
    ),
    403,
    'FORBIDDEN'
  );

  await expectReject(
    reportService.getCourtPerformance(
      dateFilters,
      { id: ids.staffNoScope, role: 'STAFF' }
    ),
    403,
    'STAFF_FACILITY_SCOPE_REQUIRED'
  );

  const adminReport = await reportService.getCourtPerformance(
    dateFilters,
    { id: ids.staff, role: 'ADMIN' }
  );
  assert.deepEqual(
    adminReport.courtStats.map(item => item.courtId),
    [ids.courtA, ids.courtB]
  );

  const sportReport = await reportService.getCourtPerformance(
    { ...dateFilters, sportId: ids.sportA },
    { id: ids.staff, role: 'ADMIN' }
  );
  assert.deepEqual(
    sportReport.courtStats.map(item => item.courtId),
    [ids.courtA]
  );
  assert.equal(sportReport.appliedFilters.sportId, ids.sportA);

  console.log('Court performance report smoke tests passed.');
}

run().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
