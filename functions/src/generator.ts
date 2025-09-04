import {Answers, PaletteOutput, PaintColor} from './types.js';
import {CATALOG} from './catalog.js';
import {computeTarget, fitsLRV, fitsUndertone, avoidColor} from './rules.js';

// FNV-1a for reproducible tie-breaks
export function hashSeed(obj: unknown): string {
  const s = typeof obj === 'string' ? obj : JSON.stringify(obj);
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return (h >>> 0).toString(16);
}

function pick<T>(arr: T[], seed: string): T {
  if (arr.length === 0) throw new Error('Empty pick set');
  const n = parseInt(seed.slice(0, 8), 16) >>> 0;
  return arr[n % arr.length];
}

export function generatePalette(a: Answers): PaletteOutput {
  const seed = hashSeed(a);
  const t = computeTarget(a);
  const brand = t.brand;
  const catalog = CATALOG[brand] ?? [];
  if (catalog.length < 6) throw new Error(`Catalog for ${brand} is too small`);

  const avoid = a.colorsToAvoid ?? [];
  const hardNos = a.guardrails?.hardNos ?? [];
  const avoidAll = [...avoid, ...hardNos];

  // Anchor candidates (walls)
  const anchors = catalog.filter(c => (c.tags?.includes('wall') ?? true)
    && fitsLRV(c, t.anchorLRV) && fitsUndertone(c, t.undertoneBias) && !avoidColor(c, avoidAll));

  // Secondary candidates (trim/cabinets)
  const seconds = catalog.filter(c => (c.tags?.some(x => x==='trim' || x==='cabinet') ?? true)
    && fitsLRV(c, t.secondaryLRV) && !avoidColor(c, avoidAll));

  // Accent candidates (doors/built-ins)
  const accents = catalog.filter(c => (c.tags?.some(x => x==='accent' || x==='door' || x==='island') ?? true)
    && fitsLRV(c, t.accentLRV) && !avoidColor(c, avoidAll));

  if (!anchors.length) throw new Error('No anchor candidates match constraints');
  if (!seconds.length) throw new Error('No secondary candidates match constraints');
  if (!accents.length) throw new Error('No accent candidates match constraints');

  const anchor = pick(anchors, seed);
  // Pick secondary with max contrast preference to anchor
  const secondary = seconds.sort((a,b) => (b.LRV??0) - (a.LRV??0))[0];
  // Accent: deterministic pick among options farthest from anchor LRV (darker)
  const accentsRanked = accents.sort((a,b) => ((a.LRV??50) - (anchor.LRV??50)) - ((b.LRV??50) - (anchor.LRV??50)));
  const accent = accentsRanked[0];

  const rationale: Record<string,string> = {
    lighting: `Daylight ${a.daytimeBrightness} → anchor LRV in ${t.anchorLRV[0]}–${t.anchorLRV[1]}.`,
    mood: `Mood ${a.moodWords?.join(', ')}; contrast ${t.contrast}.`,
    floors: a.existingElements?.floorLook ? `Floors ${a.existingElements.floorLook} → undertone bias ${t.undertoneBias ?? 'neutral'}.` : 'No strong floor undertone. ',
  };

  return {
    brand,
    roles: { anchor, secondary, accent },
    rationale,
    seed,
    rule_trace: [
      `brand=${brand}`,
      `anchorLRV=${t.anchorLRV.join('-')}`,
      `secondaryLRV=${t.secondaryLRV.join('-')}`,
      `accentLRV=${t.accentLRV.join('-')}`,
      `undertoneBias=${t.undertoneBias}`,
      `contrast=${t.contrast}`,
    ],
  };
}
