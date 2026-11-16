export interface BladeSpec {
  id: string;
  name: string;
  price: number;
  bladeColor: string;
  edgeColor: string;
  trailColor: string;
  damage: number;
  orbitSpeed: number; // radians per second
  throwSpeed: number; // units per second
  range: number;      // max throw travel distance
  speedMult: number;
  orbitRadius: number;
  rx: number;
  ry: number;
}

export const BLADE_CATALOG: BladeSpec[] = [
  {
    id: 'steel',
    name: 'Çelik Hançer',
    price: 0,
    bladeColor: '#e2e8f0',
    edgeColor: '#38bdf8',
    trailColor: 'rgba(56, 189, 248, 0.45)',
    damage: 38,
    orbitSpeed: 3.4,
    throwSpeed: 680,
    range: 290,
    speedMult: 1.0,
    orbitRadius: 48,
    rx: 48,
    ry: 48,
  },
  {
    id: 'crimson',
    name: 'Kızıl Hilal',
    price: 100,
    bladeColor: '#fca5a5',
    edgeColor: '#ef4444',
    trailColor: 'rgba(239, 68, 68, 0.48)',
    damage: 48,
    orbitSpeed: 3.4,
    throwSpeed: 680,
    range: 310,
    speedMult: 0.96,
    orbitRadius: 48,
    rx: 48,
    ry: 48,
  },
  {
    id: 'emerald',
    name: 'Zümrüt Orak',
    price: 180,
    bladeColor: '#86efac',
    edgeColor: '#22c55e',
    trailColor: 'rgba(34, 197, 94, 0.48)',
    damage: 44,
    orbitSpeed: 3.4,
    throwSpeed: 680,
    range: 355,
    speedMult: 1.12,
    orbitRadius: 48,
    rx: 48,
    ry: 48,
  },
  {
    id: 'lightning',
    name: 'Yıldırım Kılıcı',
    price: 260,
    bladeColor: '#fef08a',
    edgeColor: '#eab308',
    trailColor: 'rgba(250, 204, 21, 0.55)',
    damage: 58,
    orbitSpeed: 3.4,
    throwSpeed: 680,
    range: 340,
    speedMult: 1.24,
    orbitRadius: 48,
    rx: 48,
    ry: 48,
  },
];

export function getBladeSpec(id: string): BladeSpec {
  return BLADE_CATALOG.find((b) => b.id === id) || BLADE_CATALOG[0];
}
