import 'dart:math' as math;
import 'package:flutter/material.dart';

double hypot(double a, double b) => math.sqrt(a * a + b * b);

const double kWorldWidth = 1360.0;
const double kWorldHeight = 1040.0;
const double kTileSize = 68.0;
const double kBoundaryPad = 42.0;

class RectBox {
  final double x;
  final double y;
  final double w;
  final double h;

  const RectBox({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  Rect toRect() => Rect.fromLTWH(x, y, w, h);
}

class BushPuff {
  final double dx;
  final double dy;
  final double r;
  final int shade;

  const BushPuff({
    required this.dx,
    required this.dy,
    required this.r,
    required this.shade,
  });
}

class BushData {
  final double x;
  final double y;
  final double r;
  final List<BushPuff> puffs;
  double rustle;

  BushData({
    required this.x,
    required this.y,
    required this.r,
    required this.puffs,
    this.rustle = 0.0,
  });

  factory BushData.create(double x, double y, double r) {
    final puffs = <BushPuff>[
      BushPuff(dx: 0, dy: 0, r: r * 0.62, shade: 0),
    ];
    const count = 7;
    for (int i = 0; i < count; i++) {
      final a = (i / count) * math.pi * 2 + 0.3;
      final dist = r * 0.46;
      puffs.add(BushPuff(
        dx: math.cos(a) * dist,
        dy: math.sin(a) * dist,
        r: r * (0.42 + (i % 2) * 0.08),
        shade: i % 3,
      ));
    }
    return BushData(x: x, y: y, r: r, puffs: puffs);
  }
}

class MapConfigData {
  final String id;
  final String name;
  final String desc;
  final double width;
  final double height;
  final List<RectBox> walls;
  final List<BushData> bushes;

  const MapConfigData({
    required this.id,
    required this.name,
    required this.desc,
    this.width = kWorldWidth,
    this.height = kWorldHeight,
    required this.walls,
    required this.bushes,
  });

  double get size => math.max(width, height);
}

final List<MapConfigData> kMapConfigs = [
  MapConfigData(
    id: 'temple',
    name: 'Tapınak Arenası',
    desc: 'Sütun siperlikleri, gizlilik çalıları ve 2.5D taş bloklar.',
    walls: const [
      RectBox(x: 260, y: 220, w: 136, h: 68),
      RectBox(x: 964, y: 220, w: 136, h: 68),
      RectBox(x: 260, y: 752, w: 136, h: 68),
      RectBox(x: 964, y: 752, w: 136, h: 68),
      RectBox(x: 476, y: 452, w: 68, h: 136),
      RectBox(x: 816, y: 452, w: 68, h: 136),
    ],
    bushes: [
      BushData.create(680, 230, 62),
      BushData.create(680, 810, 62),
      BushData.create(240, 520, 66),
      BushData.create(1120, 520, 66),
      BushData.create(540, 340, 44),
      BushData.create(820, 700, 44),
    ],
  ),
  MapConfigData(
    id: 'maze',
    name: 'Taş Labirent',
    desc: 'Bıçakları sektiren koridorlar ve dar pusu noktaları.',
    walls: const [
      RectBox(x: 300, y: 200, w: 68, h: 240),
      RectBox(x: 300, y: 600, w: 68, h: 240),
      RectBox(x: 992, y: 200, w: 68, h: 240),
      RectBox(x: 992, y: 600, w: 68, h: 240),
      RectBox(x: 520, y: 260, w: 320, h: 68),
      RectBox(x: 520, y: 712, w: 320, h: 68),
    ],
    bushes: [
      BushData.create(440, 520, 58),
      BushData.create(920, 520, 58),
      BushData.create(680, 150, 52),
      BushData.create(680, 890, 52),
    ],
  ),
  MapConfigData(
    id: 'forest',
    name: 'Zümrüt Orman',
    desc: 'Yoğun yapraklı çalılar ve açık alan çatışmaları.',
    walls: const [
      RectBox(x: 420, y: 320, w: 96, h: 96),
      RectBox(x: 844, y: 320, w: 96, h: 96),
      RectBox(x: 420, y: 624, w: 96, h: 96),
      RectBox(x: 844, y: 624, w: 96, h: 96),
    ],
    bushes: [
      BushData.create(680, 340, 74),
      BushData.create(680, 700, 74),
      BushData.create(300, 520, 78),
      BushData.create(1060, 520, 78),
      BushData.create(520, 520, 54),
      BushData.create(840, 520, 54),
    ],
  ),
];

MapConfigData getMapConfigById(String id) {
  return kMapConfigs.firstWhere(
    (m) => m.id == id,
    orElse: () => kMapConfigs[0],
  );
}

class WallCollisionResult {
  final double x;
  final double y;
  final bool hitWall;

  const WallCollisionResult({
    required this.x,
    required this.y,
    required this.hitWall,
  });
}

// Circle-vs-AABB Wall & Boundary Collision Resolution (exact replica of prototype)
WallCollisionResult resolveWallCollision(double cx, double cy, double r, MapConfigData map) {
  double x = cx;
  double y = cy;
  bool hitWall = false;

  const pad = kBoundaryPad;
  if (x - r < pad) { x = pad + r; hitWall = true; }
  if (x + r > kWorldWidth - pad) { x = kWorldWidth - pad - r; hitWall = true; }
  if (y - r < pad) { y = pad + r; hitWall = true; }
  if (y + r > kWorldHeight - pad) { y = kWorldHeight - pad - r; hitWall = true; }

  for (final w in map.walls) {
    final closestX = x.clamp(w.x, w.x + w.w);
    final closestY = y.clamp(w.y, w.y + w.h);
    final dx = x - closestX;
    final dy = y - closestY;
    final distSq = dx * dx + dy * dy;
    if (distSq < r * r) {
      hitWall = true;
      final dist = math.sqrt(distSq);
      final overlap = r - (dist == 0 ? 0.001 : dist);
      final nx = dist > 0 ? dx / dist : 1.0;
      final ny = dist > 0 ? dy / dist : 0.0;
      x += nx * overlap;
      y += ny * overlap;
    }
  }
  return WallCollisionResult(x: x, y: y, hitWall: hitWall);
}

void resolveCircleWallCollisions(
  Offset pos,
  double radius,
  MapConfigData map,
  void Function(double nx, double ny) callback,
) {
  final res = resolveWallCollision(pos.dx, pos.dy, radius, map);
  callback(res.x, res.y);
}

// Flying Blade Wall Collision Detection (exact replica of prototype)
bool pointHitsWall(double px, double py, double r, MapConfigData map) {
  const pad = kBoundaryPad;
  if (px - r < pad || px + r > kWorldWidth - pad || py - r < pad || py + r > kWorldHeight - pad) {
    return true;
  }
  for (final w in map.walls) {
    final closestX = px.clamp(w.x, w.x + w.w);
    final closestY = py.clamp(w.y, w.y + w.h);
    final dx = px - closestX;
    final dy = py - closestY;
    if (dx * dx + dy * dy < r * r) return true;
  }
  return false;
}

bool checkBladeWallHit(double bx, double by, MapConfigData map, [double bladeRadius = 12.0]) =>
    pointHitsWall(bx, by, bladeRadius, map);

bool doesBladeHitWall(double bx, double by, MapConfigData map, [double bladeRadius = 12.0]) =>
    pointHitsWall(bx, by, bladeRadius, map);

// Bush Stealth Sensor (exact replica of prototype)
bool checkInsideBush(double x, double y, MapConfigData map) {
  for (final b in map.bushes) {
    if (hypot(x - b.x, y - b.y) < b.r * 0.85) {
      return true;
    }
  }
  return false;
}

Offset findSafeSpawn(double avoidX, double avoidY, [math.Random? random]) {
  const spots = [
    Offset(180, 180),
    Offset(kWorldWidth - 180, 180),
    Offset(kWorldWidth / 2, 160),
    Offset(180, kWorldHeight - 180),
    Offset(kWorldWidth - 180, kWorldHeight - 180),
  ];
  Offset best = spots[0];
  double bestDist = -1;
  for (final s in spots) {
    final d = hypot(s.dx - avoidX, s.dy - avoidY);
    if (d > bestDist) {
      bestDist = d;
      best = s;
    }
  }
  final rnd = random ?? math.Random();
  return Offset(
    best.dx + (rnd.nextDouble() - 0.5) * 40,
    best.dy + (rnd.nextDouble() - 0.5) * 40,
  );
}
