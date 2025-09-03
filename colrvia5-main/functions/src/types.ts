export type Answers = {
  roomType: string;
  usage: string;
  moodWords: string[]; // 1..3
  daytimeBrightness: 'veryBright'|'kindaBright'|'dim';
  bulbColor: 'cozyYellow_2700K'|'neutral_3000_3500K'|'brightWhite_4000KPlus';
  boldDarkerSpot: 'loveIt'|'maybe'|'noThanks';
  colorsToAvoid?: string[];
  brandPreference: 'SherwinWilliams'|'BenjaminMoore'|'Behr'|'pickForMe';
  existingElements?: {
    floorLook?: 'yellowGoldWood'|'orangeWood'|'redBrownWood'|'brownNeutral'|'grayBrown'|'tileOrStone'|'other';
    floorLookOtherNote?: string;
    bigThingsToMatch?: string[];
    metals?: 'black'|'silver'|'goldWarm'|'mixed'|'none';
    mustStaySame?: string;
  };
  colorComfort?: {
    overallVibe?: 'mostlySoftNeutrals'|'neutralsPlusGentleColors'|'confidentColorMoments';
    warmCoolFeel?: 'warmer'|'cooler'|'inBetween';
    contrastLevel?: 'verySoft'|'medium'|'crisp';
    popColor?: 'yes'|'maybe'|'no';
  };
  finishes?: {
    wallsFinishPriority?: 'easierToWipeClean'|'softerFlatterLook';
    trimDoorsFinish?: 'aLittleShiny'|'softerShine';
    specialNeeds?: ('kids'|'pets'|'steamyShowers'|'greaseHeavyCooking'|'rentalRules')[];
  };
  roomSpecific?: Record<string, unknown>;
  guardrails?: { mustHaves?: string[]; hardNos?: string[] };
  photos?: string[];
};

export type PaintColor = {
  name: string;
  hex: string; // #RRGGBB
  LRV?: number; // 0..100
  undertone?: 'warm'|'cool'|'neutral'|'green-gray'|'blue-gray'|'red-brown'|'gold';
  tags?: string[]; // e.g., ['trim','cabinet','door','best-seller']
};

export type BrandCatalog = Record<string, PaintColor[]>; // brand -> list

export type PaletteRoles = {
  anchor: PaintColor; // walls
  secondary: PaintColor; // trim/cabinets/ceiling
  accent: PaintColor; // pop
};

export type PaletteOutput = {
  brand: 'SherwinWilliams'|'BenjaminMoore'|'Behr';
  roles: PaletteRoles;
  rationale: Record<string, string>;
  id?: string;
  seed: string; // deterministic
  rule_trace?: string[]; // debugging breadcrumbs
};
