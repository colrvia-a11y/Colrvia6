// functions-visualizer/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const JOBS = new Map();
const RATE = new Map();

function checkRate(uid, name, ms) {
  const key = `${uid}_${name}`;
  const now = Date.now();
  const last = RATE.get(key) || 0;
  if (now - last < ms) {
    functions.logger.warn('rate_limited', { uid, name });
    throw new functions.https.HttpsError('resource-exhausted', 'Too many requests');
  }
  RATE.set(key, now);
}

exports.renderFast = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Auth required');
  if (!context.app) throw new functions.https.HttpsError('failed-precondition', 'App Check required');
  checkRate(context.auth.uid, 'renderFast', 1000);
  const jobId = 'job_' + Date.now();
  const previewUrl = 'https://picsum.photos/seed/' + Math.random().toString(36).slice(2) + '/800/450';
  JOBS.set(jobId, { jobId, status: 'preview', previewUrl, resultUrl: null });
  return JOBS.get(jobId);
});

exports.renderHq = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Auth required');
  if (!context.app) throw new functions.https.HttpsError('failed-precondition', 'App Check required');
  checkRate(context.auth.uid, 'renderHq', 2000);
  const jobId = 'job_' + Date.now();
  JOBS.set(jobId, { jobId, status: 'queued', previewUrl: null, resultUrl: null });
  // Simulate async completion
  setTimeout(() => {
    JOBS.set(jobId, { jobId, status: 'complete', previewUrl: null, resultUrl: 'https://picsum.photos/seed/' + Math.random().toString(36).slice(2) + '/1600/900' });
    admin.messaging().send({
      topic: `user_${context.auth.uid}`,
      data: {
        type: 'viz_hq_complete',
        projectId: data.projectId || '',
        jobId: jobId,
      }
    }).catch(console.error);
  }, 8000);
  return JOBS.get(jobId);
});

exports.getJob = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Auth required');
  if (!context.app) throw new functions.https.HttpsError('failed-precondition', 'App Check required');
  const { jobId } = data || {};
  if (typeof jobId !== 'string') {
    functions.logger.info('function_input_invalid', { name: 'getJob' });
    throw new functions.https.HttpsError('invalid-argument', 'jobId required');
  }
  checkRate(context.auth.uid, 'getJob', 500);
  return JOBS.get(jobId) || { jobId, status: 'unknown' };
});

exports.maskAssist = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Auth required');
  if (!context.app) throw new functions.https.HttpsError('failed-precondition', 'App Check required');
  const { imageUrl } = data || {};
  if (typeof imageUrl !== 'string') {
    functions.logger.info('function_input_invalid', { name: 'maskAssist' });
    throw new functions.https.HttpsError('invalid-argument', 'imageUrl required');
  }
  checkRate(context.auth.uid, 'maskAssist', 1000);
  // Stubbed response: simple rectangle mask for walls
  return {
    walls: [
      [
        { x: 0.1, y: 0.1 },
        { x: 0.9, y: 0.1 },
        { x: 0.9, y: 0.9 },
        { x: 0.1, y: 0.9 }
      ]
    ]
  };
});

