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

/**
 * issueVoiceGatewayToken
 * Callable that mints an OpenAI Realtime ephemeral session so the client never sees OPENAI_API_KEY.
 *
 * Required env var: OPENAI_API_KEY
 * Body (data): { sessionId: string }
 * Auth: Verifies Firebase ID token (either Callable auth context or Authorization: Bearer <idToken>)
 * Returns: The JSON from OpenAI Realtime sessions endpoint (contains client_secret.value)
 */
export const issueVoiceGatewayToken = onCall({ enforceAppCheck: true }, async (req) => {
  // Accept auth from callable context or Authorization header
  let uid = req.auth?.uid;
  try {
    if (!uid) {
      const hdr = (req.rawRequest?.headers?.authorization ?? req.rawRequest?.headers?.Authorization) as string | undefined;
      if (hdr && hdr.startsWith('Bearer ')) {
        const idToken = hdr.substring('Bearer '.length).trim();
        const decoded = await admin.auth().verifyIdToken(idToken);
        uid = decoded.uid;
      }
    }
  } catch (e: any) {
    throw new HttpsError('unauthenticated', `Invalid ID token: ${e?.message ?? e}`);
  }
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in.');

  const sessionId: string = req.data?.sessionId;
  if (!sessionId) throw new HttpsError('invalid-argument', 'sessionId missing');

  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) throw new HttpsError('failed-precondition', 'OPENAI_API_KEY not configured');

  const endpoint = 'https://api.openai.com/v1/realtime/sessions';
  const body = {
    model: 'gpt-realtime-nano',
    voice: 'alloy',
    modalities: ['audio', 'text'],
  } as const;

  const res = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const text = await res.text().catch(() => '');
    throw new HttpsError('internal', `OpenAI session error: ${res.status} ${res.statusText} ${text}`);
  }

  const json = await res.json();
  // Optionally, you may want to log the session creation against the user and sessionId
  await admin.firestore().collection('talkSessions').doc(sessionId).set({
    uid,
    lastIssuedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  return json;
});
