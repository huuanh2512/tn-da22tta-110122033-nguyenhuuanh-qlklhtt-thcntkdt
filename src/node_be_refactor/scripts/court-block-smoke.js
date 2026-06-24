const assert = require('node:assert/strict');

const courtBlockService = require('../src/services/court-block.service');
const reportService = require('../src/services/report.service');
const CourtBlock = require('../src/models/court-block.model');
const User = require('../src/models/user.model');
const Facility = require('../src/models/facility.model');
const Court = require('../src/models/court.model');

const ids = {
  staff: '111111111111111111111111',
  admin: '222222222222222222222222',
  facilityA: 'aaaaaaaaaaaaaaaaaaaaaaaa',
  facilityB: 'bbbbbbbbbbbbbbbbbbbbbbbb',
  courtA: 'cccccccccccccccccccccccc',
  courtB: 'dddddddddddddddddddddddd',
  courtOutside: 'eeeeeeeeeeeeeeeeeeeeeeee',
  block: 'ffffffffffffffffffffffff'
};

const courts = [
  {
    _id: ids.courtA,
    name: 'Court A',
    facility_id: ids.facilityA,
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
    facility_id: ids.facilityA,
    status: 'ACTIVE',
    slot_config: {
      opening_minutes: 600,
      closing_minutes: 1200,
      slots: []
    }
  },
  {
    _id: ids.courtOutside,
    name: 'Outside Court',
    facility_id: ids.facilityB,
    status: 'ACTIVE',
    slot_config: {
      opening_minutes: 600,
      closing_minutes: 1200,
      slots: []
    }
  }
];

User.findById = id => ({
  select: async () => ({
    facility_id: String(id) === ids.staff ? ids.facilityA : null
  })
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
      return !query._id || String(query._id) === String(court._id);
    })
  })
});

let createdPayload = null;
CourtBlock.create = async payload => {
  createdPayload = payload;
  return {
    _id: ids.block,
    ...payload,
    created_at: new Date('2026-06-01T00:00:00Z'),
    updated_at: new Date('2026-06-01T00:00:00Z')
  };
};

async function expectReject(promise, statusCode, code) {
  await assert.rejects(promise, error => {
    assert.equal(error.statusCode, statusCode);
    assert.equal(error.code, code);
    return true;
  });
}

async function run() {
  const validPayload = {
    facilityId: ids.facilityA,
    courtId: ids.courtA,
    startTime: '2026-06-11T10:00:00+07:00',
    endTime: '2026-06-11T12:00:00+07:00',
    type: 'MAINTENANCE',
    reason: 'Surface repair'
  };

  await expectReject(
    courtBlockService.create(
      validPayload,
      { id: ids.staff, role: 'CUSTOMER' }
    ),
    403,
    'FORBIDDEN'
  );

  await expectReject(
    courtBlockService.create(
      {
        ...validPayload,
        facilityId: ids.facilityB,
        courtId: ids.courtOutside
      },
      { id: ids.staff, role: 'STAFF' }
    ),
    403,
    'FORBIDDEN'
  );

  const staffBlock = await courtBlockService.create(
    validPayload,
    { id: ids.staff, role: 'STAFF' }
  );
  assert.equal(staffBlock.facilityId, ids.facilityA);
  assert.equal(staffBlock.courtId, ids.courtA);
  assert.equal(createdPayload.status, 'ACTIVE');

  const adminBlock = await courtBlockService.create(
    {
      ...validPayload,
      facilityId: ids.facilityB,
      courtId: ids.courtOutside
    },
    { id: ids.admin, role: 'ADMIN' }
  );
  assert.equal(adminBlock.facilityId, ids.facilityB);

  const dateRange = {
    dateFrom: '2026-06-11',
    dateTo: '2026-06-11',
    dayCount: 1
  };
  const operatingA = reportService._operatingIntervals(courts[0], dateRange);
  const facilityBlock = {
    _id: '100000000000000000000001',
    facility_id: ids.facilityA,
    court_id: null,
    start_time: new Date('2026-06-11T10:00:00'),
    end_time: new Date('2026-06-11T11:00:00')
  };
  const courtABlock = {
    _id: '100000000000000000000002',
    facility_id: ids.facilityA,
    court_id: ids.courtA,
    start_time: new Date('2026-06-11T10:30:00'),
    end_time: new Date('2026-06-11T12:00:00')
  };
  const cancelledBlock = {
    _id: '100000000000000000000003',
    facility_id: ids.facilityA,
    court_id: ids.courtA,
    start_time: new Date('2026-06-11T12:00:00'),
    end_time: new Date('2026-06-11T14:00:00'),
    status: 'CANCELLED'
  };

  const courtASummary = reportService._unavailableSummary(
    courts[0],
    operatingA,
    [facilityBlock, courtABlock]
  );
  assert.equal(courtASummary.unavailableMinutes, 120);
  assert.equal(courtASummary.blockCount, 2);

  const courtBSummary = reportService._unavailableSummary(
    courts[1],
    reportService._operatingIntervals(courts[1], dateRange),
    [facilityBlock, courtABlock]
  );
  assert.equal(courtBSummary.unavailableMinutes, 60);
  assert.equal(courtBSummary.blockCount, 1);

  const partialBlock = {
    _id: '100000000000000000000004',
    facility_id: ids.facilityA,
    court_id: ids.courtA,
    start_time: new Date('2026-06-10T23:00:00'),
    end_time: new Date('2026-06-11T10:30:00')
  };
  const partialSummary = reportService._unavailableSummary(
    courts[0],
    operatingA,
    [partialBlock]
  );
  assert.equal(partialSummary.unavailableMinutes, 30);

  let blockQuery = null;
  CourtBlock.find = query => ({
    select: () => ({
      lean: async () => {
        blockQuery = query;
        return [];
      }
    })
  });
  await reportService._loadCourtBlocks(
    [ids.facilityA],
    [ids.courtA],
    {
      start: new Date('2026-06-11T00:00:00'),
      end: new Date('2026-06-12T00:00:00')
    }
  );
  assert.equal(blockQuery.status, 'ACTIVE');
  assert.notEqual(cancelledBlock.status, blockQuery.status);

  const activeBlocks = [facilityBlock, courtABlock];
  reportService._loadBookings = async () => [
    {
      _id: '200000000000000000000001',
      user_id: ids.staff,
      guest_name: null,
      court_id: ids.courtA,
      booking_date: '2026-06-11',
      start_minutes: 600,
      end_minutes: 660,
      status: 'CONFIRMED'
    }
  ];
  reportService._loadPayments = async () => [];
  reportService._loadCourtBlocks = async () => activeBlocks;

  const report = await reportService.getCourtPerformance(
    { dateFrom: '2026-06-11', dateTo: '2026-06-11' },
    { id: ids.staff, role: 'STAFF' }
  );
  const courtAStats = report.courtStats.find(
    item => item.courtId === ids.courtA
  );
  const courtBStats = report.courtStats.find(
    item => item.courtId === ids.courtB
  );
  assert.equal(courtAStats.baseAvailableMinutes, 600);
  assert.equal(courtAStats.unavailableMinutes, 120);
  assert.equal(courtAStats.availableMinutes, 480);
  assert.equal(courtAStats.bookedMinutes, 60);
  assert.equal(courtAStats.utilizationRate, 0.125);
  assert.equal(courtBStats.unavailableMinutes, 60);
  assert.equal(courtBStats.availableMinutes, 540);

  const fullBlock = {
    _id: '100000000000000000000005',
    facility_id: ids.facilityA,
    court_id: ids.courtA,
    start_time: new Date('2026-06-11T00:00:00'),
    end_time: new Date('2026-06-12T00:00:00')
  };
  reportService._loadCourtBlocks = async () => [fullBlock];
  const zeroReport = await reportService.getCourtPerformance(
    {
      facilityId: ids.facilityA,
      courtId: ids.courtA,
      dateFrom: '2026-06-11',
      dateTo: '2026-06-11'
    },
    { id: ids.staff, role: 'STAFF' }
  );
  assert.equal(zeroReport.courtStats[0].availableMinutes, 0);
  assert.equal(zeroReport.courtStats[0].utilizationRate, 0);

  courts[1].status = 'MAINTENANCE';
  reportService._loadCourtBlocks = async () => [];
  const maintenanceReport = await reportService.getCourtPerformance(
    {
      facilityId: ids.facilityA,
      courtId: ids.courtB,
      dateFrom: '2026-06-11',
      dateTo: '2026-06-11'
    },
    { id: ids.staff, role: 'STAFF' }
  );
  assert.equal(maintenanceReport.courtStats[0].baseAvailableMinutes, 600);
  assert.equal(maintenanceReport.courtStats[0].unavailableMinutes, 600);
  assert.equal(maintenanceReport.courtStats[0].availableMinutes, 0);
  assert.match(
    maintenanceReport.courtStats[0].utilizationNote,
    /MAINTENANCE/
  );
  courts[1].status = 'ACTIVE';

  console.log('Court block smoke tests passed.');
}

run().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
