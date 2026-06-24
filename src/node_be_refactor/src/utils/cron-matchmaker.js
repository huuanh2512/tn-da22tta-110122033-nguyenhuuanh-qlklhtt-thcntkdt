const cron = require('node-cron');
const matchingService = require('../services/matching.service');
const cronStatus = require('./cron-status');

const JOB_NAME = 'matchmaker';
const TIMEZONE = 'Asia/Ho_Chi_Minh';
let isRunning = false;

cronStatus.registerJob(JOB_NAME, {
  schedule: '*/1 * * * *',
  timezone: TIMEZONE
});

const getVietnamDateString = (date = new Date()) => {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  });
  return formatter.format(date);
};

const getSearchingQueueGroups = async (today) => {
  const MatchQueue = require('../models/match-queue.model');
  const queues = await MatchQueue.find({
    status: 'SEARCHING',
    booking_date: { $gte: today }
  }).select('sport_id facility_id booking_date').lean();

  const groups = new Map();
  for (const queue of queues) {
    const sportId = queue.sport_id?.toString();
    const facilityId = queue.facility_id?.toString();
    if (!sportId || !facilityId || !queue.booking_date) continue;
    const key = `${sportId}:${facilityId}:${queue.booking_date}`;
    groups.set(key, { sportId, facilityId, bookingDate: queue.booking_date });
  }
  return { queueCount: queues.length, groups: [...groups.values()] };
};

const runMatchmaker = async () => {
  if (isRunning) {
    console.warn('[CRON][MATCHMAKER] skipped because previous run is still running');
    cronStatus.skipRun(JOB_NAME, 'previous_run_still_running');
    return { skipped: true };
  }

  isRunning = true;
  const startedAt = new Date();
  const startedMs = Date.now();
  cronStatus.startRun(JOB_NAME, startedAt);
  console.log('[CRON][MATCHMAKER] started at', startedAt.toISOString());

  try {
    const expirationResult = await matchingService.autoCancelUnmatched();
    console.log(
      `[Cron Matching Expiration] Cancelled ${expirationResult.cancelledSessionCount} sessions, expired ${expirationResult.expiredQueueCount} queues.`
    );

    const today = getVietnamDateString();
    const { queueCount, groups } = await getSearchingQueueGroups(today);
    let scannedGroups = 0;
    let matchedCount = 0;
    let groupErrorCount = 0;

    for (const group of groups) {
      scannedGroups += 1;
      try {
        const result = await matchingService.runMatchmakerAlgorithm(
          group.sportId,
          group.facilityId,
          group.bookingDate
        );
        if (result?.matched) matchedCount += 1;
      } catch (error) {
        groupErrorCount += 1;
        console.error('[CRON][MATCHMAKER] group failed', {
          sportId: group.sportId,
          facilityId: group.facilityId,
          bookingDate: group.bookingDate,
          message: error.message
        });
      }
    }

    const durationMs = Date.now() - startedMs;
    const summary = {
      scannedGroups,
      matchedCount,
      queueCount,
      groupErrorCount,
      expiredQueueCount: expirationResult.expiredQueueCount,
      cancelledSessionCount: expirationResult.cancelledSessionCount,
      durationMs
    };
    console.log('[CRON][MATCHMAKER] finished', summary);
    cronStatus.finishSuccess(JOB_NAME, summary, durationMs);
    return summary;
  } catch (error) {
    const durationMs = Date.now() - startedMs;
    console.error('[CRON][MATCHMAKER] failed', {
      message: error.message,
      durationMs
    });
    cronStatus.finishError(JOB_NAME, error, durationMs);
    return { error: error.message, durationMs };
  } finally {
    isRunning = false;
  }
};

cron.schedule('*/1 * * * *', runMatchmaker, { timezone: TIMEZONE });

module.exports = { runMatchmaker };
