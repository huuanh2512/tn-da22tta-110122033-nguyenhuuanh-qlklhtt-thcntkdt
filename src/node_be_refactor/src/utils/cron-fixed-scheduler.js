const cron = require('node-cron');
const fixedScheduleRepository = require('../repositories/fixed-schedule.repository');
const fixedScheduleService = require('../services/fixed-schedule.service');
const cronStatus = require('./cron-status');

const JOB_NAME = 'fixedScheduler';
const TIMEZONE = 'Asia/Ho_Chi_Minh';
let isRunning = false;

cronStatus.registerJob(JOB_NAME, {
  schedule: '5 0 * * *',
  timezone: TIMEZONE
});

const runScheduler = async () => {
  if (isRunning) {
    console.warn('[CRON][FIXED_SCHEDULER] skipped because previous run is still running');
    cronStatus.skipRun(JOB_NAME, 'previous_run_still_running');
    return { skipped: true };
  }

  isRunning = true;
  const startedAt = new Date();
  const startedMs = Date.now();
  cronStatus.startRun(JOB_NAME, startedAt);
  console.log('[CRON][FIXED_SCHEDULER] started at', startedAt.toISOString());

  try {
    const activeSchedules = await fixedScheduleRepository.findActiveSchedules();
    let generatedBookings = 0;
    let skippedSchedules = 0;
    let failedSchedules = 0;

    if (activeSchedules.length === 0) {
      const durationMs = Date.now() - startedMs;
      const summary = {
        activeSchedules: 0,
        generatedBookings,
        skippedSchedules,
        failedSchedules,
        durationMs
      };
      console.log('[CRON][FIXED_SCHEDULER] finished', summary);
      cronStatus.finishSuccess(JOB_NAME, summary, durationMs);
      return summary;
    }

    // Self-healing scan uses the generation range configured in fixed-schedule.service.
    const { fromDateStr: todayStr, toDateStr: targetDateStr } =
      fixedScheduleService.getAdvanceGenerationRange();

    console.log(`[CRON][FIXED_SCHEDULER] generating range ${todayStr} -> ${targetDateStr}`);

    for (const schedule of activeSchedules) {
      try {
        const generated = await fixedScheduleService.generateBookingsForRange(schedule, todayStr, targetDateStr);
        generatedBookings += generated.length;
        if (generated.length > 0) {
          console.log(`[CRON][FIXED_SCHEDULER] schedule ${schedule._id} generated dates: ${generated.join(', ')}`);
        } else {
          skippedSchedules += 1;
        }
      } catch (error) {
        failedSchedules += 1;
        console.error('[CRON][FIXED_SCHEDULER] schedule failed', {
          scheduleId: schedule._id?.toString(),
          message: error.message
        });
      }
    }

    const durationMs = Date.now() - startedMs;
    const summary = {
      activeSchedules: activeSchedules.length,
      generatedBookings,
      skippedSchedules,
      failedSchedules,
      fromDate: todayStr,
      toDate: targetDateStr,
      durationMs
    };
    console.log('[CRON][FIXED_SCHEDULER] finished', summary);
    cronStatus.finishSuccess(JOB_NAME, summary, durationMs);
    return summary;
  } catch (error) {
    const durationMs = Date.now() - startedMs;
    console.error('[CRON][FIXED_SCHEDULER] failed', {
      message: error.message,
      durationMs
    });
    cronStatus.finishError(JOB_NAME, error, durationMs);
    return { error: error.message, durationMs };
  } finally {
    isRunning = false;
  }
};

// Chạy vào lúc 00:05 hàng ngày
cron.schedule('5 0 * * *', runScheduler, { timezone: TIMEZONE });

// Chạy thử ngay khi khởi động sau 5 giây để cập nhật lịch chơi ngay lập tức
setTimeout(() => {
  console.log('[CRON][FIXED_SCHEDULER] startup scan scheduled');
  runScheduler().catch(err => console.error('[Cron Fixed Scheduler Startup Error]:', err.message));
}, 5000);

module.exports = { runScheduler };
