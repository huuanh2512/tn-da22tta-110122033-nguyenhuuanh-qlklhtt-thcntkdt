const assert = require('node:assert/strict');

const courtAvailabilityService =
  require('../src/services/court-availability.service');
const bookingService = require('../src/services/booking.service');
const courtService = require('../src/services/court.service');
const courtRepository = require('../src/repositories/court.repository');
const bookingRepository = require('../src/repositories/booking.repository');
const fixedScheduleRepository = require('../src/repositories/fixed-schedule.repository');
const Court = require('../src/models/court.model');
const CourtBlock = require('../src/models/court-block.model');
const Booking = require('../src/models/booking.model');
const User = require('../src/models/user.model');
const Facility = require('../src/models/facility.model');

const ids = {
  facilityA: 'aaaaaaaaaaaaaaaaaaaaaaaa',
  actor: 'bbbbbbbbbbbbbbbbbbbbbbbb',
  courtA: 'cccccccccccccccccccccccc',
  courtB: 'dddddddddddddddddddddddd'
};

const courts = {
  [ids.courtA]: {
    _id: ids.courtA,
    facility_id: ids.facilityA,
    status: 'ACTIVE',
    slot_config: {
      opening_minutes: 600,
      closing_minutes: 1200,
      slots: [
        {
          start_minutes: 600,
          end_minutes: 660,
          is_available: true,
          mode: 'AVAILABLE'
        },
        {
          start_minutes: 660,
          end_minutes: 720,
          is_available: false,
          mode: 'UNAVAILABLE'
        },
        {
          start_minutes: 720,
          end_minutes: 780,
          is_available: true,
          mode: 'AVAILABLE'
        }
      ]
    }
  },
  [ids.courtB]: {
    _id: ids.courtB,
    facility_id: ids.facilityA,
    status: 'ACTIVE',
    slot_config: {
      opening_minutes: 600,
      closing_minutes: 1200,
      slots: []
    }
  }
};

let activeBlocks = [];
let bookingConflictQueryCount = 0;

function queryResult(value) {
  return {
    session() {
      return this;
    },
    then(resolve, reject) {
      return Promise.resolve(value).then(resolve, reject);
    }
  };
}

function interval(date, minutes) {
  const value = new Date(`${date}T00:00:00`);
  value.setMinutes(minutes);
  return value;
}

Court.findById = id => queryResult(courts[String(id)] || null);
User.findById = () => ({
  select: async () => ({ facility_id: ids.facilityA })
});
Facility.find = () => ({
  select: async () => []
});
CourtBlock.findOne = query => {
  const block = activeBlocks.find(item => (
    item.facility_id === String(query.facility_id)
    && item.status === query.status
    && item.start_time < query.start_time.$lt
    && item.end_time > query.end_time.$gt
    && (
      item.court_id === null
      || item.court_id === String(query.$or[1].court_id)
    )
  ));
  return queryResult(block || null);
};
Booking.findOne = () => {
  bookingConflictQueryCount += 1;
  return queryResult(null);
};
courtRepository.findById = async id => courts[String(id)] || null;
bookingRepository.findBlockingBookingsForCourtDate = async () => [];
fixedScheduleRepository.findActiveForCourtDate = async () => [];
CourtBlock.find = query => queryResult(activeBlocks.filter(item => (
  item.facility_id === String(query.facility_id)
  && item.status === query.status
  && item.start_time < query.start_time.$lt
  && item.end_time > query.end_time.$gt
  && (
    item.court_id === null
    || item.court_id === String(query.$or[1].court_id)
  )
)));

async function expectCode(promise, code) {
  await assert.rejects(promise, error => {
    assert.equal(error.code, code);
    return true;
  });
}

async function assertAvailable(courtId, startMinutes, endMinutes) {
  return await courtAvailabilityService.assertAvailable({
    courtId,
    bookingDate: '2026-06-11',
    startMinutes,
    endMinutes
  });
}

async function run() {
  courts[ids.courtA].status = 'INACTIVE';
  await expectCode(assertAvailable(ids.courtA, 600, 660), 'COURT_INACTIVE');

  courts[ids.courtA].status = 'MAINTENANCE';
  await expectCode(
    assertAvailable(ids.courtA, 600, 660),
    'COURT_MAINTENANCE'
  );

  courts[ids.courtA].status = 'ACTIVE';
  await expectCode(
    assertAvailable(ids.courtA, 660, 720),
    'SLOT_NOT_AVAILABLE'
  );
  await expectCode(
    assertAvailable(ids.courtA, 540, 600),
    'OUTSIDE_OPERATING_HOURS'
  );

  activeBlocks = [{
    facility_id: ids.facilityA,
    court_id: null,
    status: 'ACTIVE',
    start_time: interval('2026-06-11', 630),
    end_time: interval('2026-06-11', 690)
  }];
  await expectCode(assertAvailable(ids.courtA, 600, 660), 'COURT_BLOCKED');
  await expectCode(assertAvailable(ids.courtB, 600, 660), 'COURT_BLOCKED');

  activeBlocks = [{
    facility_id: ids.facilityA,
    court_id: ids.courtA,
    status: 'ACTIVE',
    start_time: interval('2026-06-11', 660),
    end_time: interval('2026-06-11', 720)
  }];
  await assertAvailable(ids.courtA, 600, 660);
  await assertAvailable(ids.courtA, 720, 780);
  await assertAvailable(ids.courtB, 660, 720);

  activeBlocks[0].start_time = interval('2026-06-11', 650);
  await expectCode(assertAvailable(ids.courtA, 600, 660), 'COURT_BLOCKED');

  activeBlocks[0].status = 'CANCELLED';
  await assertAvailable(ids.courtA, 600, 660);

  courts[ids.courtA].status = 'MAINTENANCE';
  bookingConflictQueryCount = 0;
  await expectCode(
    bookingService.createBooking({
      courtId: ids.courtA,
      bookingDate: '2026-06-11',
      startMinutes: 600,
      endMinutes: 660
    }, ids.actor, { id: ids.actor, role: 'STAFF' }),
    'COURT_MAINTENANCE'
  );
  assert.equal(
    bookingConflictQueryCount,
    0,
    'Availability must run before booking conflict queries'
  );

  courts[ids.courtA].status = 'ACTIVE';
  activeBlocks = [{
    facility_id: ids.facilityA,
    court_id: ids.courtA,
    status: 'ACTIVE',
    start_time: interval('2026-06-11', 720),
    end_time: interval('2026-06-11', 780)
  }];
  const blockedSlotConfig = await courtService.getCourtSlotConfig(
    ids.courtA,
    '2026-06-11'
  );
  assert.equal(blockedSlotConfig.config.slots[2].isAvailable, false);
  assert.equal(blockedSlotConfig.config.slots[2].blockType, 'COURT_BLOCK');

  courts[ids.courtA].status = 'MAINTENANCE';
  const maintenanceSlotConfig = await courtService.getCourtSlotConfig(
    ids.courtA,
    '2026-06-11'
  );
  assert.equal(maintenanceSlotConfig.config.slots[0].isAvailable, false);
  assert.equal(
    maintenanceSlotConfig.config.slots[0].blockType,
    'COURT_MAINTENANCE'
  );

  console.log('Booking availability smoke tests passed.');
}

run().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
