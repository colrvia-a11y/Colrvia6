import {BrandCatalog, PaintColor} from './types.js';

const sw: PaintColor[] = [
  { name: 'Pure White', hex: '#F5F5F1', LRV: 84, undertone: 'neutral', tags: ['trim','wall'] },
  { name: 'Snowbound', hex: '#ECEBE6', LRV: 83, undertone: 'cool', tags: ['trim','wall'] },
  { name: 'Alabaster', hex: '#EDEAE0', LRV: 82, undertone: 'warm', tags: ['trim','wall'] },
  { name: 'Agreeable Gray', hex: '#D1CCC4', LRV: 60, undertone: 'warm', tags: ['wall'] },
  { name: 'Repose Gray', hex: '#D4D1CB', LRV: 58, undertone: 'cool', tags: ['wall'] },
  { name: 'Accessible Beige', hex: '#D5C9B9', LRV: 58, undertone: 'warm', tags: ['wall'] },
  { name: 'Dovetail', hex: '#9A948C', LRV: 26, undertone: 'cool', tags: ['accent','cabinet'] },
  { name: 'Iron Ore', hex: '#434343', LRV: 6,  undertone: 'neutral', tags: ['accent','door'] },
  { name: 'Urbane Bronze', hex: '#635A52', LRV: 8,  undertone: 'warm', tags: ['accent','door'] },
  { name: 'Sea Salt', hex: '#CBD6CF', LRV: 63, undertone: 'green-gray', tags: ['wall'] },
  { name: 'Evergreen Fog', hex: '#969C8B', LRV: 30, undertone: 'green-gray', tags: ['accent','cabinet'] },
  { name: 'Naval', hex: '#2F3A4A', LRV: 4, undertone: 'cool', tags: ['accent','island'] },
];

const bm: PaintColor[] = [
  { name: 'Chantilly Lace', hex: '#F5F6F4', LRV: 90, undertone: 'neutral', tags: ['trim','wall'] },
  { name: 'White Dove', hex: '#ECEBE3', LRV: 85, undertone: 'warm', tags: ['trim','wall'] },
  { name: 'Swiss Coffee', hex: '#ECE7DA', LRV: 83, undertone: 'warm', tags: ['trim','wall'] },
  { name: 'Pale Oak', hex: '#E2DBCF', LRV: 70, undertone: 'warm', tags: ['wall'] },
  { name: 'Edgecomb Gray', hex: '#DCD6CA', LRV: 63, undertone: 'warm', tags: ['wall'] },
  { name: 'Classic Gray', hex: '#E5E3DB', LRV: 74, undertone: 'cool', tags: ['wall'] },
  { name: 'Hale Navy', hex: '#3B4A59', LRV: 6, undertone: 'cool', tags: ['accent','door'] },
  { name: 'Kendall Charcoal', hex: '#6D6B65', LRV: 12, undertone: 'neutral', tags: ['accent','cabinet'] },
  { name: 'Hunter Green', hex: '#4C5A49', LRV: 8, undertone: 'green-gray', tags: ['accent','door'] }
];

const behr: PaintColor[] = [
  { name: 'Ultra Pure White', hex: '#F7F7F5', LRV: 94, undertone: 'neutral', tags: ['trim','ceiling'] },
  { name: 'Swiss Coffee', hex: '#EEE9DE', LRV: 84, undertone: 'warm', tags: ['trim','wall'] },
  { name: 'Blank Canvas', hex: '#ECE7DA', LRV: 84, undertone: 'warm', tags: ['trim','wall'] },
  { name: 'Silver Drop', hex: '#DCDAD2', LRV: 70, undertone: 'cool', tags: ['wall'] },
  { name: 'Greige', hex: '#CFC7BC', LRV: 60, undertone: 'warm', tags: ['wall'] },
  { name: 'Cracked Pepper', hex: '#4A4A4A', LRV: 8, undertone: 'neutral', tags: ['accent','door'] },
  { name: 'Admiral Blue', hex: '#2E3A57', LRV: 5, undertone: 'cool', tags: ['accent'] },
  { name: 'Back to Nature', hex: '#A9B38B', LRV: 41, undertone: 'green-gray', tags: ['accent'] }
];

export const CATALOG: BrandCatalog = {
  SherwinWilliams: sw,
  BenjaminMoore: bm,
  Behr: behr,
};
