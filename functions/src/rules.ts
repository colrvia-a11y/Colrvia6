import {Answers, PaintColor} from './types.js';

export type Target = {
  brand: 'SherwinWilliams'|'BenjaminMoore'|'Behr';
  anchorLRV: [number, number];
  secondaryLRV: [number, number];
  accentLRV: [number, number];
  undertoneBias: 'warm'|'cool'|'neutral'|'green-gray'|null;
  contrast: 'verySoft'|'medium'|'crisp';
};

export function computeTarget(a: Answers): Target {
  // Brand
  const brand = a.brandPreference === 'pickForMe' ? pickBrandByContext(a) : a.brandPreference;

  // Lighting to anchor LRV window
  const baseLRV: Record<Answers['daytimeBrightness'], [number, number]> = {
    veryBright: [55, 75], // bright rooms can handle lower LRV without feeling dim
    kindaBright: [63, 80],
    dim: [70, 88],
  };

  let anchorLRV = baseLRV[a.daytimeBrightness];

  // Bulb color tweaks: warmer bulbs read darker → nudge up a bit
  if (a.bulbColor === 'cozyYellow_2700K') anchorLRV = [anchorLRV[0] + 2, anchorLRV[1] + 2];
  if (a.bulbColor === 'brightWhite_4000KPlus') anchorLRV = [anchorLRV[0] - 2, anchorLRV[1] - 2];

  // Contrast preference
  const contrast = a.colorComfort?.contrastLevel ?? 'medium';

  // Secondary LRV relative to anchor
  const secondaryLRV: [number, number] = contrast === 'crisp'
    ? [85, 96]
    : contrast === 'verySoft'
      ? [anchorLRV[1] - 5, 95]
      : [80, 95];

  // Accent depth per appetite + bold spot
  const wantsBold = a.boldDarkerSpot === 'loveIt' || a.colorComfort?.overallVibe === 'confidentColorMoments';
  const accentLRV: [number, number] = wantsBold ? [3, 18] : [18, 35];

  // Undertone bias from floors/metals/warmCoolFeel
  const warmCool = a.colorComfort?.warmCoolFeel ?? 'inBetween';
  let undertoneBias: Target['undertoneBias'] = null;
  if (warmCool === 'warmer') undertoneBias = 'warm';
  if (warmCool === 'cooler') undertoneBias = 'cool';

  switch (a.existingElements?.floorLook) {
    case 'yellowGoldWood': undertoneBias = 'warm'; break;
    case 'grayBrown': undertoneBias = 'cool'; break;
    case 'redBrownWood': undertoneBias = 'warm'; break;
  }

  return { brand, anchorLRV, secondaryLRV, accentLRV, undertoneBias, contrast };
}

function pickBrandByContext(a: Answers): Target['brand'] {
  // Simple deterministic pick for now based on hash of usage
  const brands: Target['brand'][] = ['SherwinWilliams','BenjaminMoore','Behr'];
  const idx = Math.abs(Array.from(a.usage).reduce((s,c)=>s+c.charCodeAt(0),0)) % brands.length;
  return brands[idx];
}

export function fitsLRV(c: PaintColor, [lo, hi]: [number, number]) {
  if (c.LRV == null) return true; // allow if missing metadata
  return c.LRV >= lo && c.LRV <= hi;
}

export function fitsUndertone(c: PaintColor, bias: Target['undertoneBias']) {
  if (!bias) return true;
  return (c.undertone ?? 'neutral') === bias || (bias === 'warm' && c.undertone === 'green-gray');
}

export function avoidColor(c: PaintColor, avoid: string[] = []) {
  const lc = `${c.name} ${c.undertone ?? ''}`.toLowerCase();
  return avoid.some((w) => lc.includes(w.toLowerCase()));
}
