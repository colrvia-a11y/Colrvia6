import * as admin from 'firebase-admin';
import { onCall, HttpsError, setGlobalOptions } from 'firebase-functions/v2/https';
import { generatePalette } from './generator.js';
import { z } from 'zod';

try { admin.initializeApp(); } catch {}

setGlobalOptions({ region: 'us-central1', maxInstances: 10 });

const AnswersSchema = z.object({
  roomType: z.string(),
  usage: z.string().min(1),
  moodWords: z.array(z.string()).min(1).max(3),
  daytimeBrightness: z.enum(['veryBright','kindaBright','dim']),
  bulbColor: z.enum(['cozyYellow_2700K','neutral_3000_3500K','brightWhite_4000KPlus']),
  boldDarkerSpot: z.enum(['loveIt','maybe','noThanks']),
  colorsToAvoid: z.array(z.string()).optional(),
  brandPreference: z.enum(['SherwinWilliams','BenjaminMoore','Behr','pickForMe']),
}).passthrough(); // allow extra keys

export const generatePaletteOnCall = onCall({
  enforceAppCheck: true,
  cors: false,
}, async (req) => {
  const uid = req.auth?.uid ?? 'anon';
  if (!req.data) throw new HttpsError('invalid-argument', 'Missing data');

  let answers;
  try { answers = AnswersSchema.parse(req.data.answers); }
  catch (e:any) { throw new HttpsError('invalid-argument', 'Invalid answers: '+ e.message); }

  try {
    const out = generatePalette(answers);
    await admin.firestore().collection('paletteJobs').add({ uid, createdAt: admin.firestore.FieldValue.serverTimestamp(), answers, output: out });
    return { ok: true, palette: out };
  } catch (e:any) {
      throw new HttpsError('failed-precondition', e.message);
    }
  });

export { createTalkSession, issueVoiceGatewayToken } from './talk.js';
