import 'package:flutter/material.dart';

class BladeSpec {
  final String id;
  final String name;
  final int price;
  final Color bladeColor;
  final Color edgeColor;
  final Color trailColor;
  double damage;
  double orbitSpeed;
  double throwSpeed;
  double range;
  double speedMult;
  double orbitRadius;

  BladeSpec({
    required this.id,
    required this.name,
    required this.price,
    required this.bladeColor,
    required this.edgeColor,
    required this.trailColor,
    required this.damage,
    required this.orbitSpeed,
    required this.throwSpeed,
    required this.range,
    this.speedMult = 1.0,
    this.orbitRadius = 48.0,
  });

  // Backward compatibility getters
  Color get color => bladeColor;
  Color get glowColor => trailColor;
  double get rx => orbitRadius;
  double get ry => orbitRadius;
  set rx(double val) => orbitRadius = val;
  set ry(double val) => orbitRadius = val;

  BladeSpec copyWith({
    double? damage,
    double? orbitSpeed,
    double? throwSpeed,
    double? range,
    double? speedMult,
    double? orbitRadius,
    double? rx,
    double? ry,
  }) {
    return BladeSpec(
      id: id,
      name: name,
      price: price,
      bladeColor: bladeColor,
      edgeColor: edgeColor,
      trailColor: trailColor,
      damage: damage ?? this.damage,
      orbitSpeed: orbitSpeed ?? this.orbitSpeed,
      throwSpeed: throwSpeed ?? this.throwSpeed,
      range: range ?? this.range,
      speedMult: speedMult ?? this.speedMult,
      orbitRadius: orbitRadius ?? rx ?? this.orbitRadius,
    );
  }
}

final List<BladeSpec> kBladeCatalog = [
  BladeSpec(
    id: 'steel',
    name: 'Çelik Hançer',
    price: 0,
    damage: 38,
    range: 290,
    speedMult: 1.0,
    bladeColor: const Color(0xFFE2E8F0),
    edgeColor: const Color(0xFF38BDF8),
    trailColor: const Color(0x7338BDF8),
    orbitSpeed: 3.4,
    throwSpeed: 680,
    orbitRadius: 48,
  ),
  BladeSpec(
    id: 'crimson',
    name: 'Kızıl Hilal',
    price: 100,
    damage: 48,
    range: 310,
    speedMult: 0.96,
    bladeColor: const Color(0xFFFCA5A5),
    edgeColor: const Color(0xFFEF4444),
    trailColor: const Color(0x7AEF4444),
    orbitSpeed: 3.4,
    throwSpeed: 680,
    orbitRadius: 48,
  ),
  BladeSpec(
    id: 'emerald',
    name: 'Zümrüt Orak',
    price: 180,
    damage: 44,
    range: 355,
    speedMult: 1.12,
    bladeColor: const Color(0xFF86EFAC),
    edgeColor: const Color(0xFF22C55E),
    trailColor: const Color(0x7A22C55E),
    orbitSpeed: 3.4,
    throwSpeed: 680,
    orbitRadius: 48,
  ),
  BladeSpec(
    id: 'lightning',
    name: 'Yıldırım Kılıcı',
    price: 260,
    damage: 58,
    range: 340,
    speedMult: 1.24,
    bladeColor: const Color(0xFFFEF08A),
    edgeColor: const Color(0xFFEAB308),
    trailColor: const Color(0x8DFACC15),
    orbitSpeed: 3.4,
    throwSpeed: 680,
    orbitRadius: 48,
  ),
];

BladeSpec getBladeSpecById(String id) {
  return kBladeCatalog.firstWhere(
    (b) => b.id == id,
    orElse: () => kBladeCatalog[0],
  );
}
