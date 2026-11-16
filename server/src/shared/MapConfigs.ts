export interface Rect {
  x: number;
  y: number;
  w: number;
  h: number;
}

export interface Bush {
  x: number;
  y: number;
  r: number;
}

export interface MapConfig {
  id: string;
  name: string;
  desc: string;
  width: number;
  height: number;
  size: number;
  walls: Rect[];
  bushes: Bush[];
}

export const WORLD_W = 1360;
export const WORLD_H = 1040;
export const BOUNDARY_PAD = 42;

export const MAPS: Record<string, MapConfig> = {
  temple: {
    id: 'temple',
    name: 'Tapınak Arenası',
    desc: 'Sütun siperlikleri, gizlilik çalıları ve 2.5D taş bloklar.',
    width: WORLD_W,
    height: WORLD_H,
    size: Math.max(WORLD_W, WORLD_H),
    walls: [
      { x: 260, y: 220, w: 136, h: 68 },
      { x: 964, y: 220, w: 136, h: 68 },
      { x: 260, y: 752, w: 136, h: 68 },
      { x: 964, y: 752, w: 136, h: 68 },
      { x: 476, y: 452, w: 68, h: 136 },
      { x: 816, y: 452, w: 68, h: 136 },
    ],
    bushes: [
      { x: 680, y: 230, r: 62 },
      { x: 680, y: 810, r: 62 },
      { x: 240, y: 520, r: 66 },
      { x: 1120, y: 520, r: 66 },
      { x: 540, y: 340, r: 44 },
      { x: 820, y: 700, r: 44 },
    ],
  },
  maze: {
    id: 'maze',
    name: 'Taş Labirent',
    desc: 'Bıçakları sektiren koridorlar ve dar pusu noktaları.',
    width: WORLD_W,
    height: WORLD_H,
    size: Math.max(WORLD_W, WORLD_H),
    walls: [
      { x: 300, y: 200, w: 68, h: 240 },
      { x: 300, y: 600, w: 68, h: 240 },
      { x: 992, y: 200, w: 68, h: 240 },
      { x: 992, y: 600, w: 68, h: 240 },
      { x: 520, y: 260, w: 320, h: 68 },
      { x: 520, y: 712, w: 320, h: 68 },
    ],
    bushes: [
      { x: 440, y: 520, r: 58 },
      { x: 920, y: 520, r: 58 },
      { x: 680, y: 150, r: 52 },
      { x: 680, y: 890, r: 52 },
    ],
  },
  forest: {
    id: 'forest',
    name: 'Zümrüt Orman',
    desc: 'Yoğun yapraklı çalılar ve açık alan çatışmaları.',
    width: WORLD_W,
    height: WORLD_H,
    size: Math.max(WORLD_W, WORLD_H),
    walls: [
      { x: 420, y: 320, w: 96, h: 96 },
      { x: 844, y: 320, w: 96, h: 96 },
      { x: 420, y: 624, w: 96, h: 96 },
      { x: 844, y: 624, w: 96, h: 96 },
    ],
    bushes: [
      { x: 680, y: 340, r: 74 },
      { x: 680, y: 700, r: 74 },
      { x: 300, y: 520, r: 78 },
      { x: 1060, y: 520, r: 78 },
      { x: 520, y: 520, r: 54 },
      { x: 840, y: 520, r: 54 },
    ],
  },
};

export function getMapConfig(id: string): MapConfig {
  return MAPS[id] || MAPS['temple'];
}

// Circle-vs-AABB & Boundary Collision for Players
export function resolveWallCollisions(
  ent: { x: number; y: number; radius: number },
  map: MapConfig
): void {
  const pad = BOUNDARY_PAD;
  if (ent.x - ent.radius < pad) ent.x = pad + ent.radius;
  if (ent.x + ent.radius > map.width - pad) ent.x = map.width - pad - ent.radius;
  if (ent.y - ent.radius < pad) ent.y = pad + ent.radius;
  if (ent.y + ent.radius > map.height - pad) ent.y = map.height - pad - ent.radius;

  for (const w of map.walls) {
    const cx = Math.max(w.x, Math.min(ent.x, w.x + w.w));
    const cy = Math.max(w.y, Math.min(ent.y, w.y + w.h));
    const dx = ent.x - cx;
    const dy = ent.y - cy;
    const distSq = dx * dx + dy * dy;
    if (distSq < ent.radius * ent.radius) {
      const d = Math.sqrt(distSq) || 0.001;
      const overlap = ent.radius - d;
      ent.x += (dx / d) * overlap;
      ent.y += (dy / d) * overlap;
    }
  }
}

// Circle-vs-AABB Collision for Flying Blades
export function bladeHitsWall(
  bx: number,
  by: number,
  map: MapConfig,
  bladeRadius = 12
): boolean {
  const pad = BOUNDARY_PAD;
  if (
    bx - bladeRadius < pad ||
    bx + bladeRadius > map.width - pad ||
    by - bladeRadius < pad ||
    by + bladeRadius > map.height - pad
  ) {
    return true;
  }
  for (const w of map.walls) {
    const cx = Math.max(w.x, Math.min(bx, w.x + w.w));
    const cy = Math.max(w.y, Math.min(by, w.y + w.h));
    const dx = bx - cx;
    const dy = by - cy;
    if (dx * dx + dy * dy < bladeRadius * bladeRadius) {
      return true;
    }
  }
  return false;
}

// Stealth Bush Check
export function isInsideBush(x: number, y: number, map: MapConfig): boolean {
  for (const b of map.bushes) {
    if (Math.hypot(x - b.x, y - b.y) < b.r * 0.85) {
      return true;
    }
  }
  return false;
}

export function findSafeSpawn(avoidX: number, avoidY: number): { x: number; y: number } {
  const spots = [
    { x: 180, y: 180 },
    { x: WORLD_W - 180, y: 180 },
    { x: WORLD_W / 2, y: 160 },
    { x: 180, y: WORLD_H - 180 },
    { x: WORLD_W - 180, y: WORLD_H - 180 },
  ];
  let best = spots[0];
  let bestDist = -1;
  for (const s of spots) {
    const d = Math.hypot(s.x - avoidX, s.y - avoidY);
    if (d > bestDist) {
      bestDist = d;
      best = s;
    }
  }
  return {
    x: best.x + (Math.random() - 0.5) * 40,
    y: best.y + (Math.random() - 0.5) * 40,
  };
}
