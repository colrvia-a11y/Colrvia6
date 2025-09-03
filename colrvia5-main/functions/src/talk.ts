import { onCall, HttpsError, setGlobalOptions } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';

try { admin.initializeApp(); } catch {}
setGlobalOptions({ region: 'us-central1' });

// Create a talk session (schedule or start-now)
export const createTalkSession = onCall({ enforceAppCheck: true }, async (req) => {
  const uid = req.auth?.uid; if (!uid) throw new HttpsError('unauthenticated', 'Sign in.');
  const when: string|undefined = req.data?.scheduledAt; // ISO or undefined
  const now = admin.firestore.Timestamp.now();

  const doc = await admin.firestore().collection('talkSessions').add({
    uid,
    status: when ? 'scheduled' : 'ready',
    scheduledAt: when ? admin.firestore.Timestamp.fromDate(new Date(when)) : null,
    answersSnapshot: req.data?.answers ?? {},
    createdAt: now,
    progress: 0,
  });
  return { sessionId: doc.id };
});

// Issue an ephemeral gateway token (for WebRTC WS auth)
export const issueVoiceGatewayToken = onCall({ enforceAppCheck: true }, async (req) => {
  const uid = req.auth?.uid; if (!uid) throw new HttpsError('unauthenticated', 'Sign in.');
  const sessionId: string = req.data?.sessionId; if (!sessionId) throw new HttpsError('invalid-argument', 'sessionId');

  // TODO: replace with your signed JWT from the Voice Gateway.
  // For now we return a short-lived opaque token generated server-side.
  const token = Buffer.from(JSON.stringify({ uid, sessionId, exp: Date.now() + 1000 * 60 * 5 })).toString('base64url');
  return { token };
});
