import {generatePalette, hashSeed} from '../src/generator.js';

const base = {
  roomType: 'kitchen',
  usage: 'Cook daily',
  moodWords: ['calm','fresh'],
  daytimeBrightness: 'kindaBright',
  bulbColor: 'neutral_3000_3500K',
  boldDarkerSpot: 'maybe',
  brandPreference: 'SherwinWilliams',
};

test('deterministic seed', () => {
  const s1 = hashSeed(base);
  const s2 = hashSeed(base);
  expect(s1).toBe(s2);
});

test('generates roles', () => {
  const out = generatePalette(base as any);
  expect(out.roles.anchor).toBeTruthy();
  expect(out.roles.secondary).toBeTruthy();
  expect(out.roles.accent).toBeTruthy();
});

test('respects avoid list', () => {
  const out = generatePalette({ ...base, colorsToAvoid: ['navy','iron'] } as any);
  expect(out.roles.accent.name.toLowerCase()).not.toContain('naval');
});
