const cron = require('node-cron');
const bookingService = require('../services/booking.service');
const cronStatus = require('./cron-status');

const JOB_NAME = 'autoCancelBookings';
const TIMEZONE = 'Asia/Ho_Chi_Minh';
let isRunning = false;

cronStatus.registerJob(JOB_NAME, {
  schedule: '*/1 * * * *',
  timezone: TIMEZONE
});

const runAutoCancelPendingBookings = async () => {
  if (isRunning) {
    console.warn('[CRON][AUTO_CANCEL] skipped because previous run is still running');
    cronStatus.skipRun(JOB_NAME, 'previous_run_still_running');
    return { skipped: true };
  }

  isRunning = true;
  const startedAt = new Date();
  const startedMs = Date.now();
  cronStatus.startRun(JOB_NAME, startedAt);
  console.log('[CRON][AUTO_CANCEL] started at', startedAt.toISOString());

  try {
    const result = await bookingService.autoCancelPendingBookings();
    const durationMs = Date.now() - startedMs;
    const summary = {
      scannedBookings: result.scannedCount,
      cancelledBookings: result.cancelledCount,
      durationMs
    };
    console.log('[CRON][AUTO_CANCEL] finished', summary);
    cronStatus.finishSuccess(JOB_NAME, summary, durationMs);
    return summary;
  } catch (error) {
    const durationMs = Date.now() - startedMs;
    console.error('[CRON][AUTO_CANCEL] failed', {
      message: error.message,
      durationMs
    });
    cronStatus.finishError(JOB_NAME, error, durationMs);
    return { error: error.message, durationMs };
  } finally {
    isRunning = false;
  }
};

cron.schedule('*/1 * * * *', runAutoCancelPendingBookings, { timezone: TIMEZONE });

module.exports = { runAutoCancelPendingBookings };
