const assert = require('node:assert/strict');

const bookingService = require('../src/services/booking.service');
const bookingRepository = require('../src/repositories/booking.repository');
const paymentService = require('../src/services/payment.service');
const fixedScheduleService = require('../src/services/fixed-schedule.service');
const notificationHelper = require('../src/services/notification.helper');
const userScheduleConflictService = require('../src/services/user-schedule-conflict.service');
const User = require('../src/models/user.model');
const Facility = require('../src/models/facility.model');
const Court = require('../src/models/court.model');
const CourtBlock = require('../src/models/court-block.model');
const Booking = require('../src/models/booking.model');
const MatchingSession = require('../src/models/matching.model');

const ids = {
  customerA: '111111111111111111111111',
  customerB: '222222222222222222222222',
  staffA: '333333333333333333333333',
  staffNoScope: '444444444444444444444444',
  facilityA: 'aaaaaaaaaaaaaaaaaaaaaaaa',
  facilityB: 'bbbbbbbbbbbbbbbbbbbbbbbb',
  courtA: 'cccccccccccccccccccccccc',
  courtB: 'dddddddddddddddddddddddd',
  bookingA: 'eeeeeeeeeeeeeeeeeeeeeeee',
  bookingB: 'ffffffffffffffffffffffff',
  sport: '999999999999999999999999'
};

const populatedId = (id, fields = {}) => ({ _id: id, ...fields });
const bookingA = {
  _id: ids.bookingA,
  user_id: populatedId(ids.customerA, {
    email: 'customer.a@example.com',
    profile: { name: 'Customer A', phone: '0901234123' }
  }),
  guest_name: null,
  guest_phone: null,
  court_id: populatedId(ids.courtA, {
    name: 'Court A',
    facility_id: populatedId(ids.facilityA, { name: 'Facility A' })
  }),
  booking_date: '2026-06-11',
  start_minutes: 600,
  end_minutes: 660,
  total_price: 100000,
  status: 'CONFIRMED'
};
const bookingB = {
  ...bookingA,
  _id: ids.bookingB,
  user_id: populatedId(ids.customerB, {
    email: 'customer.b@example.com',
    profile: { name: 'Customer B', phone: '0919999888' }
  }),
  court_id: populatedId(ids.courtB, {
    name: 'Court B',
    facility_id: populatedId(ids.facilityB, { name: 'Facility B' })
  })
};

const userFacilities = new Map([
  [ids.staffA, ids.facilityA],
  [ids.staffNoScope, null]
]);
const facilityStaff = new Map();
const courtIdsByFacility = new Map([
  [ids.facilityA, [ids.courtA]],
  [ids.facilityB, [ids.courtB]]
]);
const courtsById = new Map([
  [ids.courtA, {
    _id: ids.courtA,
    name: 'Court A',
    facility_id: ids.facilityA,
    sport_id: ids.sport,
    status: 'ACTIVE',
    price_per_hour: 100000,
    slot_config: {
      opening_minutes: 0,
      closing_minutes: 1440,
      slots: []
    }
  }],
  [ids.courtB, {
    _id: ids.courtB,
    name: 'Court B',
    facility_id: ids.facilityB,
    sport_id: ids.sport,
    status: 'ACTIVE',
    price_per_hour: 100000,
    slot_config: {
      opening_minutes: 0,
      closing_minutes: 1440,
      slots: []
    }
  }]
]);
const createdBookings = new Map();

function queryResult(value) {
  return {
    select() {
      return this;
    },
    session() {
      return this;
    },
    then(resolve, reject) {
      return Promise.resolve(value).then(resolve, reject);
    }
  };
}

User.findById = (id) => ({
  select: async () => ({ facility_id: userFacilities.get(String(id)) || null })
});
Facility.find = ({ staff_ids: staffId }) => ({
  select: async () => (facilityStaff.get(String(staffId)) || []).map(
    facilityId => ({ _id: facilityId })
  )
});
Court.find = ({ facility_id: facilityFilter }) => ({
  distinct: async () => facilityFilter.$in.flatMap(
    facilityId => courtIdsByFacility.get(String(facilityId)) || []
  )
});
Court.findById = id => queryResult(courtsById.get(String(id)) || null);
CourtBlock.findOne = () => queryResult(null);
Booking.findOne = () => queryResult(null);
MatchingSession.findOne = () => queryResult(null);
MatchingSession.find = () => queryResult([]);
fixedScheduleService.checkBookingConflict = async () => null;
notificationHelper.notifyBookingCreated = async () => {};
userScheduleConflictService.assertNoUserScheduleConflict = async () => {};

let lastListQuery = null;
bookingRepository.findMany = async (query) => {
  lastListQuery = query;
  if (!query.court_id) return [bookingA, bookingB];
  const allowed = query.court_id.$in
    ? query.court_id.$in.map(String)
    : [String(query.court_id)];
  return [bookingA, bookingB].filter(
    booking => allowed.includes(String(booking.court_id._id))
  );
};
bookingRepository.count = async (query) => {
  if (!query.court_id) return 2;
  const allowed = query.court_id.$in
    ? query.court_id.$in.map(String)
    : [String(query.court_id)];
  return [bookingA, bookingB].filter(
    booking => allowed.includes(String(booking.court_id._id))
  ).length;
};
bookingRepository.findById = async (id) => {
  if (String(id) === ids.bookingA) return bookingA;
  if (String(id) === ids.bookingB) return bookingB;
  if (createdBookings.has(String(id))) return createdBookings.get(String(id));
  return null;
};
bookingRepository.create = async (bookingData) => {
  const id = `created${createdBookings.size + 1}`;
  const court = courtsById.get(String(bookingData.court_id));
  const booking = {
    _id: id,
    ...bookingData,
    court_id: populatedId(bookingData.court_id, {
      name: court?.name || '',
      facility_id: populatedId(court?.facility_id || '', {
        name: court?.facility_id === ids.facilityA ? 'Facility A' : 'Facility B'
      })
    }),
    user_id: bookingData.user_id
      ? populatedId(bookingData.user_id, {
        email: 'created.customer@example.com',
        profile: { name: 'Created Customer', phone: '0900000000' }
      })
      : null,
    created_at: new Date('2026-06-11T00:00:00Z')
  };
  createdBookings.set(id, booking);
  return booking;
};
bookingRepository.updateById = async (id, updateData) => {
  const existing = await bookingRepository.findById(id);
  if (!existing) return null;
  const court = courtsById.get(String(updateData.court_id || existing.court_id?._id || existing.court_id));
  const updated = {
    ...existing,
    ...updateData,
    court_id: populatedId(updateData.court_id || existing.court_id?._id || existing.court_id, {
      name: court?.name || existing.court_id?.name || '',
      facility_id: populatedId(court?.facility_id || existing.court_id?.facility_id?._id || existing.court_id?.facility_id || '', {
        name: court?.facility_id === ids.facilityA ? 'Facility A' : 'Facility B'
      })
    })
  };
  if (String(id) === ids.bookingA) Object.assign(bookingA, updated);
  if (String(id) === ids.bookingB) Object.assign(bookingB, updated);
  if (createdBookings.has(String(id))) createdBookings.set(String(id), updated);
  return updated;
};
paymentService.queryPaymentByBookingId = async () => null;

async function expectReject(promise, statusCode, code) {
  await assert.rejects(promise, error => {
    assert.equal(error.statusCode, statusCode);
    assert.equal(error.code, code);
    return true;
  });
}

async function run() {
  const originalCustomerCalendar =
    bookingService._queryCustomerBookingCalendar.bind(bookingService);
  let customerFilters = null;
  bookingService._queryCustomerBookingCalendar = async filters => {
    customerFilters = filters;
    return { items: [bookingA], total: 1 };
  };

  await bookingService.queryBookings(
    { userId: ids.customerB },
    0,
    20,
    { id: ids.customerA, role: 'CUSTOMER' }
  );
  assert.equal(customerFilters.userId, ids.customerA);
  bookingService._queryCustomerBookingCalendar = originalCustomerCalendar;

  const customerDetail = await bookingService.getBookingDetail(
    ids.bookingA,
    { id: ids.customerA, role: 'CUSTOMER' }
  );
  assert.equal(customerDetail.booking.id, ids.bookingA);

  await expectReject(
    bookingService.getBookingDetail(
      ids.bookingB,
      { id: ids.customerA, role: 'CUSTOMER' }
    ),
    403,
    'FORBIDDEN'
  );

  const staffList = await bookingService.queryBookings(
    {},
    0,
    20,
    { id: ids.staffA, role: 'STAFF' }
  );
  assert.deepEqual(lastListQuery.court_id.$in.map(String), [ids.courtA]);
  assert.equal(staffList.items.length, 1);
  assert.equal(staffList.items[0].user.email, 'cus***@example.com');
  assert.equal(staffList.items[0].user.phone, '090****123');

  await expectReject(
    bookingService.queryBookings(
      { facilityId: ids.facilityB },
      0,
      20,
      { id: ids.staffA, role: 'STAFF' }
    ),
    403,
    'FORBIDDEN'
  );

  await expectReject(
    bookingService.queryBookings(
      {},
      0,
      20,
      { id: ids.staffNoScope, role: 'STAFF' }
    ),
    403,
    'STAFF_FACILITY_SCOPE_REQUIRED'
  );

  const adminList = await bookingService.queryBookings(
    {},
    0,
    20,
    { id: ids.staffA, role: 'ADMIN' }
  );
  assert.equal(adminList.items.length, 2);
  assert.equal(lastListQuery.court_id, undefined);

  const staffDetail = await bookingService.getBookingDetail(
    ids.bookingA,
    { id: ids.staffA, role: 'STAFF' }
  );
  assert.equal(staffDetail.booking.id, ids.bookingA);
  await expectReject(
    bookingService.getBookingDetail(
      ids.bookingB,
      { id: ids.staffA, role: 'STAFF' }
    ),
    403,
    'FORBIDDEN'
  );

  const reportList = await bookingService.queryBookings(
    { facilityId: ids.facilityA, view: 'report' },
    0,
    20,
    { id: ids.staffA, role: 'STAFF' }
  );
  assert.equal(reportList.items[0].user.email, '');
  assert.equal(reportList.items[0].user.phone, '');
  assert.equal(reportList.items[0].user.name, 'Cus***');

  const staffCreateInScope = await bookingService.createBooking(
    {
      courtId: ids.courtA,
      bookingDate: '2099-06-11',
      startMinutes: 600,
      endMinutes: 660,
      guestName: 'Walk In',
      guestPhone: '0900000001',
      totalPrice: 0
    },
    null,
    { id: ids.staffA, role: 'STAFF' }
  );
  assert.equal(staffCreateInScope.booking.court.id, ids.courtA);
  assert.equal(staffCreateInScope.booking.guestPhone, '0900000001');
  assert.equal(staffCreateInScope.booking.totalPrice, 100000);

  const staffCreateLowClientPrice = await bookingService.createBooking(
    {
      courtId: ids.courtA,
      bookingDate: '2099-06-11',
      startMinutes: 900,
      endMinutes: 990,
      guestName: 'Low Price',
      guestPhone: '0900000004',
      totalPrice: 1
    },
    null,
    { id: ids.staffA, role: 'STAFF' }
  );
  assert.equal(staffCreateLowClientPrice.booking.totalPrice, 150000);

  const staffCreateHighClientPrice = await bookingService.createBooking(
    {
      courtId: ids.courtA,
      bookingDate: '2099-06-11',
      startMinutes: 990,
      endMinutes: 1050,
      guestName: 'High Price',
      guestPhone: '0900000005',
      totalPrice: 999999999
    },
    null,
    { id: ids.staffA, role: 'STAFF' }
  );
  assert.equal(staffCreateHighClientPrice.booking.totalPrice, 100000);

  await expectReject(
    bookingService.createBooking(
      {
        courtId: ids.courtA,
        bookingDate: '2099-06-11',
        startMinutes: 600,
        endMinutes: 600,
        guestName: 'Invalid Time',
        guestPhone: '0900000006',
        totalPrice: 100000
      },
      null,
      { id: ids.staffA, role: 'STAFF' }
    ),
    400,
    'INVALID_BOOKING_TIME'
  );

  const originalCourtAPrice = courtsById.get(ids.courtA).price_per_hour;
  courtsById.get(ids.courtA).price_per_hour = 0;
  await expectReject(
    bookingService.createBooking(
      {
        courtId: ids.courtA,
        bookingDate: '2099-06-11',
        startMinutes: 1050,
        endMinutes: 1110,
        guestName: 'No Price',
        guestPhone: '0900000007',
        totalPrice: 100000
      },
      null,
      { id: ids.staffA, role: 'STAFF' }
    ),
    400,
    'COURT_PRICE_NOT_CONFIGURED'
  );
  courtsById.get(ids.courtA).price_per_hour = originalCourtAPrice;

  await expectReject(
    bookingService.createBooking(
      {
        courtId: ids.courtB,
        bookingDate: '2099-06-11',
        startMinutes: 600,
        endMinutes: 660,
        guestName: 'Out Of Scope',
        guestPhone: '0900000002',
        totalPrice: 100000
      },
      null,
      { id: ids.staffA, role: 'STAFF' }
    ),
    403,
    'BOOKING_CREATE_FORBIDDEN_OUT_OF_SCOPE'
  );

  await expectReject(
    bookingService.createBooking(
      {
        courtId: ids.courtA,
        bookingDate: '2099-06-11',
        startMinutes: 600,
        endMinutes: 660,
        guestName: 'No Scope',
        guestPhone: '0900000003',
        totalPrice: 100000
      },
      null,
      { id: ids.staffNoScope, role: 'STAFF' }
    ),
    403,
    'STAFF_FACILITY_SCOPE_REQUIRED'
  );

  const customerCreateOwn = await bookingService.createBooking(
    {
      courtId: ids.courtA,
      bookingDate: '2099-06-11',
      startMinutes: 660,
      endMinutes: 720,
      totalPrice: 100000
    },
    ids.customerA,
    { id: ids.customerA, role: 'CUSTOMER' }
  );
  assert.equal(customerCreateOwn.booking.user.id, ids.customerA);

  const customerRescheduleOwn = await bookingService.updateBooking(
    customerCreateOwn.booking.id,
    {
      courtId: ids.courtA,
      bookingDate: '2099-06-12',
      startMinutes: 780,
      endMinutes: 840
    },
    { id: ids.customerA, role: 'CUSTOMER' }
  );
  assert.equal(customerRescheduleOwn.booking.bookingDate, '2099-06-12');
  assert.equal(customerRescheduleOwn.booking.startMinutes, 780);

  await expectReject(
    bookingService.updateBooking(
      customerCreateOwn.booking.id,
      {
        courtId: ids.courtA,
        bookingDate: '2099-06-13',
        startMinutes: 840,
        endMinutes: 900
      },
      { id: ids.customerB, role: 'CUSTOMER' }
    ),
    403,
    'FORBIDDEN'
  );

  await expectReject(
    bookingService.createBooking(
      {
        courtId: ids.courtA,
        bookingDate: '2099-06-11',
        startMinutes: 720,
        endMinutes: 780,
        totalPrice: 100000
      },
      ids.customerB,
      { id: ids.customerA, role: 'CUSTOMER' }
    ),
    403,
    'BOOKING_CREATE_USER_FORBIDDEN'
  );

  const adminCreate = await bookingService.createBooking(
    {
      courtId: ids.courtB,
      bookingDate: '2099-06-11',
      startMinutes: 780,
      endMinutes: 840,
      totalPrice: 100000
    },
    ids.customerB,
    { id: ids.staffA, role: 'ADMIN' }
  );
  assert.equal(adminCreate.booking.court.id, ids.courtB);

  const superAdminCreate = await bookingService.createBooking(
    {
      courtId: ids.courtB,
      bookingDate: '2099-06-11',
      startMinutes: 840,
      endMinutes: 900,
      totalPrice: 100000
    },
    ids.customerB,
    { id: ids.staffA, role: 'SUPER_ADMIN' }
  );
  assert.equal(superAdminCreate.booking.court.id, ids.courtB);

  console.log('Booking access smoke tests passed.');
}

run().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
