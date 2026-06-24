const jobs = {};

const clone = (value) => JSON.parse(JSON.stringify(value));

const ensureJob = (name) => {
  if (!jobs[name]) {
    jobs[name] = {
      enabled: false,
      running: false,
      schedule: null,
      timezone: null,
      lastRunAt: null,
      lastSuccessAt: null,
      lastError: null,
      durationMs: null,
      lastResult: null,
      runCount: 0,
      successCount: 0,
      errorCount: 0,
      skippedCount: 0,
      lastSkippedAt: null,
      lastSkipReason: null
    };
  }
  return jobs[name];
};

const registerJob = (name, metadata = {}) => {
  const job = ensureJob(name);
  Object.assign(job, metadata, {
    enabled: metadata.enabled !== undefined ? metadata.enabled : true
  });
};

const startRun = (name, startedAt = new Date()) => {
  const job = ensureJob(name);
  job.enabled = true;
  job.running = true;
  job.lastRunAt = startedAt.toISOString();
  job.runCount += 1;
};

const finishSuccess = (name, result = {}, durationMs = null, finishedAt = new Date()) => {
  const job = ensureJob(name);
  job.running = false;
  job.lastSuccessAt = finishedAt.toISOString();
  job.lastError = null;
  job.durationMs = durationMs;
  job.lastResult = result;
  job.successCount += 1;
};

const finishError = (name, error, durationMs = null) => {
  const job = ensureJob(name);
  job.running = false;
  job.lastError = {
    message: error?.message || String(error),
    at: new Date().toISOString()
  };
  job.durationMs = durationMs;
  job.errorCount += 1;
};

const skipRun = (name, reason) => {
  const job = ensureJob(name);
  job.lastSkippedAt = new Date().toISOString();
  job.lastSkipReason = reason;
  job.skippedCount += 1;
};

const getStatus = () => clone(jobs);

module.exports = {
  registerJob,
  startRun,
  finishSuccess,
  finishError,
  skipRun,
  getStatus
};
