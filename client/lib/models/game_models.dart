import 'package:flutter/material.dart';

enum BladeCombatState { orbit, out, returning }

enum PowerType { damage, heal, shield }

class BladeTrailPoint {
  final double x;
  final double y;
  double life;
  final double maxLife;

  BladeTrailPoint({
    required this.x,
    required this.y,
    this.life = 0.16,
    this.maxLife = 0.16,
  });
}

class PlayerStateModel {
  final String id;
  String name;
  double x;
  double y;
  double vx;
  double vy;
  double facing;
  double radius;
  double hp;
  double maxHp;
  double speed;
  int kills;
  bool isBot;
  String bladeId;
  BladeCombatState bladeState;
  double bladeAngle;
  double bladeSpin;
  double bladeX;
  double bladeY;
  double bladeDist;
  double bladeDirX;
  double bladeDirY;
  double frozenAngle;
  double orbitRadius;
  double powerTimer;
  int shieldHits;
  double shieldTimer;
  bool isHidden;
  bool inBush;
  double flashTimer;
  double aiThinkTimer;
  double aiMoveX;
  double aiMoveY;
  final Set<String> hitTargets;
  final List<BladeTrailPoint> bladeTrail;

  // Local visual interpolations
  double renderX;
  double renderY;
  double targetX;
  double targetY;

  PlayerStateModel({
    required this.id,
    required this.name,
    this.x = 0,
    this.y = 0,
    this.vx = 0,
    this.vy = 0,
    this.facing = 0,
    this.radius = 25,
    this.hp = 130,
    this.maxHp = 130,
    this.speed = 245,
    this.kills = 0,
    this.isBot = false,
    this.bladeId = 'steel',
    this.bladeState = BladeCombatState.orbit,
    this.bladeAngle = 0,
    this.bladeSpin = 0,
    this.bladeX = 0,
    this.bladeY = 0,
    this.bladeDist = 0,
    this.bladeDirX = 1,
    this.bladeDirY = 0,
    this.frozenAngle = 0,
    this.orbitRadius = 48,
    this.powerTimer = 0,
    this.shieldHits = 0,
    this.shieldTimer = 0,
    this.isHidden = false,
    this.inBush = false,
    this.flashTimer = 0,
    this.aiThinkTimer = 0.5,
    this.aiMoveX = 0,
    this.aiMoveY = 0,
    Set<String>? hitTargets,
    List<BladeTrailPoint>? bladeTrail,
    this.renderX = 0,
    this.renderY = 0,
    this.targetX = 0,
    this.targetY = 0,
  })  : hitTargets = hitTargets ?? <String>{},
        bladeTrail = bladeTrail ?? <BladeTrailPoint>[];

  // Backward compatibility getter & setter
  double get dmgTimer => powerTimer;
  set dmgTimer(double v) => powerTimer = v;

  factory PlayerStateModel.fromJson(Map<String, dynamic> json) {
    BladeCombatState bState = BladeCombatState.orbit;
    final bStr = json['bladeState']?.toString() ?? 'orbit';
    if (bStr == 'out') {
      bState = BladeCombatState.out;
    } else if (bStr == 'return' || bStr == 'returning') {
      bState = BladeCombatState.returning;
    }

    final px = (json['x'] as num?)?.toDouble() ?? 0.0;
    final py = (json['y'] as num?)?.toDouble() ?? 0.0;
    final isBot = json['isBot'] == true;

    return PlayerStateModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Player',
      x: px,
      y: py,
      facing: (json['facing'] as num?)?.toDouble() ?? 0.0,
      radius: (json['radius'] as num?)?.toDouble() ?? 25.0,
      hp: (json['hp'] as num?)?.toDouble() ?? (isBot ? 105.0 : 130.0),
      maxHp: (json['maxHp'] as num?)?.toDouble() ?? (isBot ? 105.0 : 130.0),
      speed: (json['speed'] as num?)?.toDouble() ?? (isBot ? 185.0 : 245.0),
      kills: (json['kills'] as num?)?.toInt() ?? 0,
      isBot: isBot,
      bladeId: json['bladeId']?.toString() ?? 'steel',
      bladeState: bState,
      bladeAngle: (json['bladeAngle'] as num?)?.toDouble() ?? 0.0,
      bladeSpin: (json['bladeSpin'] as num?)?.toDouble() ?? 0.0,
      bladeX: (json['bladeX'] as num?)?.toDouble() ?? 0.0,
      bladeY: (json['bladeY'] as num?)?.toDouble() ?? 0.0,
      frozenAngle: (json['frozenAngle'] as num?)?.toDouble() ?? 0.0,
      orbitRadius: (json['orbitRadius'] as num?)?.toDouble() ?? 48.0,
      powerTimer: (json['dmgTimer'] as num?)?.toDouble() ?? 0.0,
      shieldHits: (json['shieldHits'] as num?)?.toInt() ?? 0,
      shieldTimer: (json['shieldTimer'] as num?)?.toDouble() ?? 0.0,
      isHidden: json['isHidden'] == true,
      inBush: json['inBush'] == true,
      renderX: px,
      renderY: py,
      targetX: px,
      targetY: py,
    );
  }
}

class PowerUpStateModel {
  final String id;
  final double x;
  final double y;
  final PowerType type;
  final String label;
  final Color color;
  bool active;
  double respawn;
  double pulse;

  PowerUpStateModel({
    required this.id,
    required this.x,
    required this.y,
    required this.type,
    required this.label,
    required this.color,
    this.active = true,
    this.respawn = 0.0,
    this.pulse = 0.0,
  });

  factory PowerUpStateModel.fromJson(Map<String, dynamic> json) {
    PowerType pType = PowerType.damage;
    String lbl = '2X GÜÇ';
    Color col = const Color(0xFFF97316);

    final tStr = json['type']?.toString().toUpperCase() ?? 'DAMAGE';
    if (tStr == 'HEAL') {
      pType = PowerType.heal;
      lbl = '+45 CAN';
      col = const Color(0xFF22C55E);
    } else if (tStr == 'SHIELD') {
      pType = PowerType.shield;
      lbl = 'KALKAN';
      col = const Color(0xFF38BDF8);
    }

    return PowerUpStateModel(
      id: json['id']?.toString() ?? '',
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      type: pType,
      label: lbl,
      color: col,
    );
  }
}

class ParticleEffect {
  double x;
  double y;
  double vx;
  double vy;
  double life;
  final double maxLife;
  final double size;
  final Color color;
  final bool star;

  ParticleEffect({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.maxLife,
    this.size = 6.0,
    required this.color,
    this.star = false,
  });
}

class ShockwaveEffect {
  final double x;
  final double y;
  double radius;
  double alpha;
  final Color color;

  ShockwaveEffect({
    required this.x,
    required this.y,
    this.radius = 10,
    this.alpha = 1.0,
    required this.color,
  });
}

class FloatingCombatText {
  final double x;
  double y;
  final String text;
  final Color color;
  double life;
  final double maxLife;

  FloatingCombatText({
    required this.x,
    required this.y,
    required this.text,
    required this.color,
    this.life = 0.85,
    this.maxLife = 0.85,
  });
}

class LeaderboardEntry {
  final String name;
  final int kills;
  final bool isMe;

  LeaderboardEntry({
    required this.name,
    required this.kills,
    required this.isMe,
  });
}
