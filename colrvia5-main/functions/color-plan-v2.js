exports.generateColorPlanV2 = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Auth required');
  }
  const { projectId, paletteColorIds, vibe, context: ctx } = data;
  if (!projectId || !Array.isArray(paletteColorIds) || paletteColorIds.length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing inputs');
  }

  // Fake AI synthesis for scaffolding. Replace with real AI call.
  const placementMap = [
    { area: 'walls', colorId: paletteColorIds[0], sheen: 'eggshell' },
    { area: 'trim', colorId: paletteColorIds[1] || paletteColorIds[0], sheen: 'semi-gloss' },
    { area: 'ceiling', colorId: paletteColorIds[2] || paletteColorIds[0], sheen: 'matte' },
  ];
  const cohesionTips = [
    'Repeat trim color on doors for cohesion.',
    'Maintain consistent LRV deltas between adjacent rooms.',
  ];
  const accentRules = [
    { context: 'north-facing room', guidance: 'Prefer warmer undertones to balance cool light.' },
    { context: 'small room', guidance: 'Use lighter LRV on walls to expand perceived space.' }
  ];
  const doDont = [
    { do: 'Cut in with trim color after two wall coats.', dont: 'Don\'t mix sheens within the same surface.' }
  ];
  const sampleSequence = [ 'Order peel-and-stick for top 3 wall contenders', 'Evaluate in morning/evening', 'Commit to final set' ];
  const roomPlaybook = [
    { roomType: 'living', placements: [ placementMap[0], placementMap[1] ], notes: 'Feature wall optional.' },
    { roomType: 'kitchen', placements: [ { area: 'cabinets', colorId: paletteColorIds[1] || paletteColorIds[0], sheen: 'satin' } ], notes: 'Use scrub-resistant sheen.' },
  ];

  return {
    name: vibe || 'Balanced, cohesive home palette',
    vibe: vibe || 'Warm-modern comfort',
    paletteColorIds,
    placementMap,
    cohesionTips,
    accentRules,
    doDont,
    sampleSequence,
    roomPlaybook,
  };
});
