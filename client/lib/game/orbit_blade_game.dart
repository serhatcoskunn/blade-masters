import 'dart:math' as math;
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/blade_catalog.dart';
import '../models/game_models.dart';
import '../models/map_config.dart';
import '../network/network_service.dart';
import '../services/storage_service.dart';

const Color kOutlineColor = Color(0xFF0F172A);

class OrbitBladeGame extends FlameGame with KeyboardEvents {
  final NetworkService network;

  OrbitBladeGame({required this.network});

  // Active Map
  MapConfigData currentMap = kMapConfigs[0];

  // Local Player Properties
  String mySessionId = 'local_player';
  PlayerStateModel? localPlayer;
  BladeSpec activeSpec = kBladeCatalog[0];

  // Entities
  final Map<String, PlayerStateModel> players = {};
  final List<PowerUpStateModel> powerUps = [];
  final List<ParticleEffect> particles = [];
  final List<FloatingCombatText> floatingTexts = [];

  // Smooth Camera Coordinates
  double cameraX = kWorldWidth / 2;
  double cameraY = kWorldHeight / 2;

  // Visual Effects & Timers
  double globalTime = 0.0;
  double screenShakeTimer = 0.0;
  double screenShakeMag = 0.0;
  double hitStopTimer = 0.0;

  // Real-time HUD State Notifiers
  final ValueNotifier<double> hpNotifier = ValueNotifier(1.0);
  final ValueNotifier<int> goldNotifier = ValueNotifier(0);
  final ValueNotifier<int> killsNotifier = ValueNotifier(0);
  final ValueNotifier<String> buffsNotifier = ValueNotifier('');
  final ValueNotifier<int> matchTimeNotifier = ValueNotifier(0);
  final ValueNotifier<bool> bladeInOrbitNotifier = ValueNotifier(true);
  final ValueNotifier<List<LeaderboardEntry>> leaderboardNotifier = ValueNotifier([]);

  // Input State (Keyboard + Virtual Joystick)
  double joystickDx = 0.0;
  double joystickDy = 0.0;
  final Set<LogicalKeyboardKey> _pressedKeys = {};
  final math.Random _random = math.Random();

  @override
  Color backgroundColor() => const Color(0xFFE5C687); // Warm Desert Floor

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    goldNotifier.value = StorageService.getGold();
    final equippedId = StorageService.getEquippedBlade();
    activeSpec = getBladeSpecById(equippedId);

    final mapId = StorageService.getSelectedMap();
    currentMap = getMapConfigById(mapId);

    // Register Network Callbacks
    network.onStateSync = _handleStateSync;
    network.onHit = _handleHit;
    network.onKill = _handleKill;
    network.onPowerUp = _handlePowerUp;
  }

  void updateActiveSpec(BladeSpec spec) {
    activeSpec = spec;
  }

  void switchMap(String mapId) {
    currentMap = getMapConfigById(mapId);
  }

  void setJoystickInput(double dx, double dy) {
    joystickDx = dx;
    joystickDy = dy;
  }

  void triggerThrow() {
    if (localPlayer != null && localPlayer!.bladeState == BladeCombatState.orbit) {
      network.sendThrow();
      bladeInOrbitNotifier.value = false;
    }
  }

  void triggerShake(double mag, double duration) {
    screenShakeMag = math.max(screenShakeMag, mag);
    screenShakeTimer = math.max(screenShakeTimer, duration);
  }

  void _spawnBurst(double x, double y, Color color, int count) {
    for (int i = 0; i < count; i++) {
      final a = (math.pi * 2 * i) / count + _random.nextDouble() * 0.5;
      final spd = 90.0 + _random.nextDouble() * 170.0;
      particles.add(ParticleEffect(
        x: x,
        y: y,
        vx: math.cos(a) * spd,
        vy: math.sin(a) * spd,
        life: 0.28 + _random.nextDouble() * 0.16,
        maxLife: 0.44,
        size: 5.0 + _random.nextDouble() * 5.0,
        color: color,
        star: i % 2 == 0,
      ));
    }
  }

  // Keyboard Event Listener
  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _pressedKeys.clear();
    _pressedKeys.addAll(keysPressed);

    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
      triggerThrow();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _handleStateSync(List<PlayerStateModel> serverPlayers, List<PowerUpStateModel> serverPowerUps, int matchTime) {
    matchTimeNotifier.value = matchTime;
    mySessionId = network.mySessionId;

    final receivedIds = <String>{};

    for (final sp in serverPlayers) {
      receivedIds.add(sp.id);
      if (players.containsKey(sp.id)) {
        final existing = players[sp.id]!;
        existing.name = sp.name;
        existing.hp = sp.hp;
        existing.maxHp = sp.maxHp;
        existing.kills = sp.kills;
        existing.facing = sp.facing;
        existing.bladeId = sp.bladeId;
        existing.bladeState = sp.bladeState;
        existing.bladeAngle = sp.bladeAngle;
        existing.bladeSpin = sp.bladeSpin;
        existing.bladeX = sp.bladeX;
        existing.bladeY = sp.bladeY;
        existing.frozenAngle = sp.frozenAngle;
        existing.powerTimer = sp.powerTimer;
        existing.shieldHits = sp.shieldHits;
        existing.shieldTimer = sp.shieldTimer;
        existing.isHidden = sp.isHidden;
        existing.inBush = sp.inBush;

        // Smooth Interpolation Target
        existing.targetX = sp.x;
        existing.targetY = sp.y;
      } else {
        players[sp.id] = sp;
      }
    }

    players.removeWhere((id, _) => !receivedIds.contains(id));

    // Power-ups sync
    powerUps.clear();
    powerUps.addAll(serverPowerUps);

    // Update Local Player Reference
    if (players.containsKey(mySessionId)) {
      localPlayer = players[mySessionId];
      hpNotifier.value = (localPlayer!.hp / localPlayer!.maxHp).clamp(0.0, 1.0);
      killsNotifier.value = localPlayer!.kills;
      bladeInOrbitNotifier.value = localPlayer!.bladeState == BladeCombatState.orbit;

      final buffs = <String>[];
      if (localPlayer!.powerTimer > 0) buffs.add('2X GÜÇ ${localPlayer!.powerTimer.toStringAsFixed(1)}s');
      if (localPlayer!.shieldHits > 0) buffs.add('KALKAN');
      buffsNotifier.value = buffs.join(' • ');
    }

    // Update Live Leaderboard
    final board = players.values.map((p) => LeaderboardEntry(
      name: p.id == mySessionId ? 'SEN' : p.name,
      kills: p.kills,
      isMe: p.id == mySessionId,
    )).toList()
      ..sort((a, b) => b.kills.compareTo(a.kills));

    leaderboardNotifier.value = board.take(4).toList();
  }

  void _handleHit(double x, double y, double damage, String targetId, String attackerId, String colorHex) {
    Color col;
    try {
      col = Color(int.parse(colorHex.replaceAll('#', '0xFF')));
    } catch (_) {
      col = const Color(0xFFFACC15);
    }

    if (damage == 0 && targetId == 'wall') {
      _spawnBurst(x, y, const Color(0xFFCBD5E1), 6);
    } else if (damage == 0) {
      // Shield block
      _spawnBurst(x, y, const Color(0xFF38BDF8), 10);
      floatingTexts.add(FloatingCombatText(x: x, y: y - 28, text: 'BLOK!', color: const Color(0xFF38BDF8)));
      if (attackerId == mySessionId || targetId == mySessionId) {
        hitStopTimer = 0.035;
        triggerShake(5, 0.12);
      }
    } else {
      // Successful Damage Hit
      _spawnBurst(x, y, col, 12);
      floatingTexts.add(FloatingCombatText(x: x, y: y - 30, text: '-${damage.toInt()}', color: const Color(0xFFEF4444)));
      if (attackerId == mySessionId || targetId == mySessionId) {
        hitStopTimer = 0.045;
        triggerShake(8, 0.18);
      }
    }

    if (players.containsKey(targetId)) {
      players[targetId]!.flashTimer = 0.16;
    }
  }

  void _handleKill(String killerId, String victimId, String killerName, String victimName, int goldAwarded) {
    if (killerId == mySessionId && goldAwarded > 0) {
      StorageService.addGold(goldAwarded);
      goldNotifier.value = StorageService.getGold();
      floatingTexts.add(FloatingCombatText(
        x: localPlayer?.x ?? kWorldWidth / 2,
        y: (localPlayer?.y ?? kWorldHeight / 2) - 42,
        text: '+$goldAwarded ALTIN',
        color: const Color(0xFFFACC15),
      ));
    }

    if (victimId == mySessionId) {
      floatingTexts.add(FloatingCombatText(
        x: localPlayer?.x ?? kWorldWidth / 2,
        y: (localPlayer?.y ?? kWorldHeight / 2) - 40,
        text: 'YENİDEN DOĞUŞ',
        color: const Color(0xFFF8FAFC),
      ));
    }
  }

  void _handlePowerUp(String playerId, PowerType type, double x, double y) {
    _spawnBurst(x, y, type == PowerType.damage ? const Color(0xFFF97316) : (type == PowerType.heal ? const Color(0xFF22C55E) : const Color(0xFF38BDF8)), 12);

    String txt = '2X GÜÇ!';
    Color col = const Color(0xFFFB923C);
    if (type == PowerType.heal) {
      txt = '+45 CAN';
      col = const Color(0xFF4ADE80);
    } else if (type == PowerType.shield) {
      txt = 'KALKAN';
      col = const Color(0xFF38BDF8);
    }

    floatingTexts.add(FloatingCombatText(x: x, y: y - 34, text: txt, color: col));
  }

  @override
  void update(double dt) {
    super.update(dt);
    globalTime += dt;

    if (screenShakeTimer > 0) {
      screenShakeTimer = math.max(0.0, screenShakeTimer - dt);
    }
    if (hitStopTimer > 0) {
      hitStopTimer = math.max(0.0, hitStopTimer - dt);
      return;
    }

    // 1. Process Movement Inputs (Joystick + Keyboard WASD)
    double mx = joystickDx;
    double my = joystickDy;

    if (_pressedKeys.contains(LogicalKeyboardKey.keyW) || _pressedKeys.contains(LogicalKeyboardKey.arrowUp)) my -= 1.0;
    if (_pressedKeys.contains(LogicalKeyboardKey.keyS) || _pressedKeys.contains(LogicalKeyboardKey.arrowDown)) my += 1.0;
    if (_pressedKeys.contains(LogicalKeyboardKey.keyA) || _pressedKeys.contains(LogicalKeyboardKey.arrowLeft)) mx -= 1.0;
    if (_pressedKeys.contains(LogicalKeyboardKey.keyD) || _pressedKeys.contains(LogicalKeyboardKey.arrowRight)) mx += 1.0;

    final mag = hypot(mx, my);
    if (mag > 0.05) {
      if (mag > 1.0) {
        mx /= mag;
        my /= mag;
      }
      if (localPlayer != null) {
        localPlayer!.facing = math.atan2(my, mx);
      }
    }

    // Send input to server / offline simulator
    network.sendMove(mx, my);

    // 2. Client-side entity interpolation
    for (final p in players.values) {
      if (p.flashTimer > 0) p.flashTimer = math.max(0, p.flashTimer - dt);

      // Smooth interpolation for remote entities
      p.renderX += (p.targetX - p.renderX) * math.min(1.0, 18.0 * dt);
      p.renderY += (p.targetY - p.renderY) * math.min(1.0, 18.0 * dt);
      p.x = p.renderX;
      p.y = p.renderY;
    }

    // 3. Update Visual FX
    particles.removeWhere((p) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt;
      return p.life <= 0;
    });

    floatingTexts.removeWhere((f) {
      f.y -= 34.0 * dt;
      f.life -= dt;
      return f.life <= 0;
    });

    for (final pow in powerUps) {
      pow.pulse += dt * 4.5;
    }

    // Smooth Camera Follow
    if (localPlayer != null) {
      cameraX += (localPlayer!.x - cameraX) * math.min(1.0, dt * 8.0);
      cameraY += (localPlayer!.y - cameraY) * math.min(1.0, dt * 8.0);
    }
  }

  // =========================================================================
  // 1:1 BRAWL CEL-SHADED 2.5D RENDERING PIPELINE (MATCHING PROTOTYPE EXACTLY)
  // =========================================================================
  @override
  void render(Canvas canvas) {
    super.render(canvas);

    canvas.save();

    final halfW = size.x / 2;
    final halfH = size.y / 2;

    // Screen Shake Offset
    double sx = 0.0;
    double sy = 0.0;
    if (screenShakeTimer > 0) {
      sx = (_random.nextDouble() - 0.5) * 2.0 * screenShakeMag;
      sy = (_random.nextDouble() - 0.5) * 2.0 * screenShakeMag;
    }

    // Camera Clamping within World Bounds
    final camX = math.max(halfW, math.min(kWorldWidth - halfW, cameraX));
    final camY = math.max(halfH, math.min(kWorldHeight - halfH, cameraY));

    canvas.translate(halfW - camX + sx, halfH - camY + sy);

    // 1. Warm Sunlit Desert / Temple Stone Tiles
    _renderArenaFloorAndGrid(canvas);

    // 2. Central Power-Up Pads
    _renderCentralPowerUps(canvas);

    // 3. Aim Guide & Frozen Return Slot Marker
    _renderAimAndSlotMarkers(canvas);

    // 4. Depth-Sorted 2.5D Extruded Walls, Brawlers & Puffy Bushes
    _renderDepthSortedScene(canvas);

    // 5. Perimeter 2.5D Border Wall
    _renderPerimeterBorder(canvas);

    // 6. Glowing Boomerang Blades & Slash Trails
    _renderBlades(canvas);

    // 7. Cartoon Particles & Floating Combat Texts
    _renderParticles(canvas);
    _renderFloatingTexts(canvas);

    canvas.restore();
  }

  // 1. Warm Checkered Floor with Temple Ring (Exact Prototype)
  void _renderArenaFloorAndGrid(Canvas canvas) {
    final basePaint = Paint()..color = const Color(0xFFE5C687);
    final altPaint = Paint()..color = const Color(0xFFDBB671);
    final groutPaint = Paint()
      ..color = const Color(0x3892682E)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const tile = kTileSize;
    final cols = (kWorldWidth / tile).ceil();
    final rows = (kWorldHeight / tile).ceil();

    // Base background
    canvas.drawRect(const Rect.fromLTWH(0, 0, kWorldWidth, kWorldHeight), basePaint);

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final tx = c * tile;
        final ty = r * tile;
        if (((r + c) & 1) == 1) {
          canvas.drawRect(Rect.fromLTWH(tx, ty, tile, tile), altPaint);
        }
        canvas.drawRect(Rect.fromLTWH(tx + 0.75, ty + 0.75, tile - 1.5, tile - 1.5), groutPaint);
      }
    }

    // Center Decorative Temple Ring
    final centerAltarFill = Paint()
      ..color = const Color(0x8CD9B36C)
      ..style = PaintingStyle.fill;
    final centerAltarStroke = Paint()
      ..color = const Color(0x5992682E)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(const Offset(kWorldWidth / 2, kWorldHeight / 2), 118.0, centerAltarFill);
    canvas.drawCircle(const Offset(kWorldWidth / 2, kWorldHeight / 2), 118.0, centerAltarStroke);
  }

  // 2. Central Power-Up Pads (Pedestal shadow, gem body with black outline, shine & tag)
  void _renderCentralPowerUps(Canvas canvas) {
    for (final p in powerUps) {
      if (!p.active) continue;
      final bob = math.sin(globalTime * 4.5 + p.x) * 4.0;

      // Pedestal Ring Shadow
      final shadowPaint = Paint()..color = const Color(0x330F172A);
      canvas.drawOval(Rect.fromCenter(center: Offset(p.x, p.y + 10), width: 44, height: 28), shadowPaint);

      // Gem Body with Black Outline
      final gemPaint = Paint()..color = p.color;
      final strokePaint = Paint()
        ..color = kOutlineColor
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(Offset(p.x, p.y + bob), 17.0, gemPaint);
      canvas.drawCircle(Offset(p.x, p.y + bob), 17.0, strokePaint);

      // Inner Shine
      final shinePaint = Paint()..color = const Color(0x8CFFFFFF);
      canvas.drawCircle(Offset(p.x - 5, p.y + bob - 5), 5.0, shinePaint);

      // Label Tag
      _drawOutlinedText(canvas, p.label, Offset(p.x, p.y + bob - 24), Colors.white, fontSize: 11);
    }
  }

  // 3. Aim Guide & Frozen Return Slot Marker
  void _renderAimAndSlotMarkers(Canvas canvas) {
    if (localPlayer == null) return;
    final p = localPlayer!;
    final spec = activeSpec;

    final inOrbit = p.bladeState == BladeCombatState.orbit;
    final slotAngle = inOrbit ? p.bladeAngle : p.frozenAngle;
    final slotX = p.x + math.cos(slotAngle) * p.orbitRadius;
    final slotY = p.y + math.sin(slotAngle) * p.orbitRadius;

    // Golden Dotted Aim Trajectory Line
    final aimPaint = Paint()
      ..color = inOrbit ? const Color(0xB8FACC15) : const Color(0x47FACC15)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final endX = p.x + math.cos(slotAngle) * spec.range;
    final endY = p.y + math.sin(slotAngle) * spec.range;
    _drawDashedLine(canvas, Offset(slotX, slotY), Offset(endX, endY), aimPaint, 7.0, 7.0);

    // Pulsing Frozen Slot Marker
    if (!inOrbit) {
      final pulse = 1.0 + math.sin(globalTime * 14.0) * 0.16;
      final fillPaint = Paint()
        ..color = const Color(0x59FACC15)
        ..style = PaintingStyle.fill;
      final strokePaint = Paint()
        ..color = const Color(0xFFFACC15)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(Offset(slotX, slotY), 13.0 * pulse, fillPaint);
      canvas.drawCircle(Offset(slotX, slotY), 13.0 * pulse, strokePaint);
    }
  }

  // 4. Depth-Sorted 2.5D Scene (Walls, Bushes, Brawlers)
  void _renderDepthSortedScene(Canvas canvas) {
    final renderables = <_RenderItem>[];

    // Walls
    for (final w in currentMap.walls) {
      renderables.add(_RenderItem(sortY: w.y + w.h, wall: w));
    }

    // Bushes
    for (final b in currentMap.bushes) {
      renderables.add(_RenderItem(sortY: b.y + b.r * 0.35, bush: b));
    }

    // Brawlers (Player & Bots)
    for (final p in players.values) {
      renderables.add(_RenderItem(sortY: p.y, brawler: p));
    }

    renderables.sort((a, b) => a.sortY.compareTo(b.sortY));

    for (final item in renderables) {
      if (item.wall != null) {
        _renderExtrudedWall(canvas, item.wall!);
      } else if (item.bush != null) {
        _renderPuffyBush(canvas, item.bush!);
      } else if (item.brawler != null) {
        _renderStylizedBrawler(canvas, item.brawler!);
      }
    }
  }

  // 2.5D Extruded Wall Drawing (Bevel, Sandstone top, highlight & black outline)
  void _renderExtrudedWall(Canvas canvas, RectBox w) {
    const bevelH = 22.0;
    const rad = 12.0;
    final topH = math.max(16.0, w.h - bevelH);

    // Ground Drop Shadow
    final shadowPaint = Paint()..color = const Color(0x3D0F172A);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w.x + 5, w.y + 8, w.w, w.h + 4), const Radius.circular(rad)), shadowPaint);

    // Front 3D Bevel Face (Slate)
    final frontPaint = Paint()..color = const Color(0xFF475569);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w.x, w.y, w.w, w.h), const Radius.circular(rad)), frontPaint);

    // Top Face (Sandstone / Slate)
    final topFacePaint = Paint()..color = const Color(0xFF94A3B8);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w.x, w.y, w.w, topH), const Radius.circular(rad)), topFacePaint);

    // Top Specular Highlight Strip
    final highlightPaint = Paint()..color = const Color(0xFFCBD5E1);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w.x + 5, w.y + 4, w.w - 10, math.max(8.0, topH - 10)), const Radius.circular(8)), highlightPaint);

    // Thick 3.5px Cel-Shaded Outline
    final contourPaint = Paint()
      ..color = kOutlineColor
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w.x, w.y, w.w, w.h), const Radius.circular(rad)), contourPaint);

    // Inner Bevel Seam Line
    final seamPaint = Paint()
      ..color = kOutlineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w.x + 3, w.y + topH), Offset(w.x + w.w - 3, w.y + topH), seamPaint);
  }

  // Perimeter 2.5D Slate Border Wall
  void _renderPerimeterBorder(Canvas canvas) {
    const t = kBoundaryPad;
    final borderPaint = Paint()..color = const Color(0xFF64748B);

    canvas.drawRect(const Rect.fromLTWH(0, 0, kWorldWidth, t), borderPaint);
    canvas.drawRect(const Rect.fromLTWH(0, kWorldHeight - t, kWorldWidth, t), borderPaint);
    canvas.drawRect(const Rect.fromLTWH(0, 0, t, kWorldHeight), borderPaint);
    canvas.drawRect(const Rect.fromLTWH(kWorldWidth - t, 0, t, kWorldHeight), borderPaint);

    // Top Bevel Strip
    final topBevelPaint = Paint()..color = const Color(0xFF94A3B8);
    canvas.drawRect(const Rect.fromLTWH(0, 0, kWorldWidth, t - 14), topBevelPaint);

    // Outer Thick Black Outline
    final contourPaint = Paint()
      ..color = kOutlineColor
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;
    canvas.drawRect(const Rect.fromLTWH(t, t, kWorldWidth - t * 2, kWorldHeight - t * 2), contourPaint);
  }

  // Puffy Cartoon Bushes (4-pass rendering with sway)
  void _renderPuffyBush(Canvas canvas, BushData b) {
    final sway = math.sin(globalTime * 14.0) * b.rustle * 4.0;
    final isPlayerInside = localPlayer != null && hypot(localPlayer!.x - b.x, localPlayer!.y - b.y) < b.r * 0.9;

    canvas.save();
    canvas.translate(b.x + sway, b.y);

    if (isPlayerInside) {
      canvas.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: 0.56));
    }

    // Ground Shadow
    final shadowPaint = Paint()..color = const Color(0x380F172A);
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 10), width: b.r * 1.9, height: b.r * 1.64), shadowPaint);

    // 1. Outer Black Silhouette Pass
    final outlinePaint = Paint()..color = kOutlineColor;
    for (final p in b.puffs) {
      canvas.drawCircle(Offset(p.dx, p.dy), p.r + 3.5, outlinePaint);
    }

    // 2. Base Dark Emerald Leaf Fill
    final darkEmeraldPaint = Paint()..color = const Color(0xFF15803D);
    for (final p in b.puffs) {
      canvas.drawCircle(Offset(p.dx, p.dy + 2), p.r, darkEmeraldPaint);
    }

    // 3. Mid Vibrant Green Leaf Fill
    final midGreenPaint = Paint()..color = const Color(0xFF22C55E);
    for (final p in b.puffs) {
      canvas.drawCircle(Offset(p.dx, p.dy - 2), p.r * 0.92, midGreenPaint);
    }

    // 4. Top Lime Highlight Puffs
    final limeHighlightPaint = Paint()..color = const Color(0xFF4ADE80);
    for (final p in b.puffs) {
      canvas.drawCircle(Offset(p.dx - p.r * 0.16, p.dy - p.r * 0.22), p.r * 0.52, limeHighlightPaint);
    }

    if (isPlayerInside) {
      canvas.restore();
    }
    canvas.restore();
  }

  // Stylized Brawl Stars Unit (Oval shadow, chunky shoulders, helmet, visor, HP bar)
  void _renderStylizedBrawler(Canvas canvas, PlayerStateModel ent) {
    // Hide bots inside bushes from player view unless close
    if (ent.id != mySessionId && ent.inBush && localPlayer != null) {
      if (hypot(ent.x - localPlayer!.x, ent.y - localPlayer!.y) > 115) {
        return;
      }
    }

    canvas.save();
    canvas.translate(ent.x, ent.y);

    if (ent.inBush) {
      canvas.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: 0.65));
    }

    // Ground Oval Drop Shadow
    final shadowPaint = Paint()..color = const Color(0x4D0F172A);
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 16), width: 48, height: 30), shadowPaint);

    // Active Power Aura
    if (ent.powerTimer > 0) {
      final auraPaint = Paint()
        ..color = const Color(0xFFFB923C)
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset.zero, 33.0 + math.sin(globalTime * 10.0) * 2.0, auraPaint);
    }

    // Active Shield Ring
    if (ent.shieldHits > 0) {
      final shieldFill = Paint()
        ..color = const Color(0x2E38BDF8)
        ..style = PaintingStyle.fill;
      final shieldStroke = Paint()
        ..color = const Color(0xFF38BDF8)
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset.zero, 35.0, shieldFill);
      canvas.drawCircle(Offset.zero, 35.0, shieldStroke);
    }

    final isMe = ent.id == mySessionId;
    final isFlashing = ent.flashTimer > 0;
    final mainColor = isFlashing ? Colors.white : (isMe ? const Color(0xFF0EA5E9) : const Color(0xFFF97316));
    final darkTrim = isFlashing ? const Color(0xFFE2E8F0) : (isMe ? const Color(0xFF0369A1) : const Color(0xFFC2410C));
    final crestCol = isMe ? const Color(0xFF38BDF8) : const Color(0xFFFACC15);

    // Rotate body towards facing direction
    canvas.save();
    canvas.rotate(ent.facing);

    final trimPaint = Paint()..color = darkTrim;
    final strokePaint = Paint()
      ..color = kOutlineColor
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    // Chunky Left & Right Shoulder Pads
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-10, -27, 20, 12), const Radius.circular(6)), trimPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-10, -27, 20, 12), const Radius.circular(6)), strokePaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-10, 15, 20, 12), const Radius.circular(6)), trimPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-10, 15, 20, 12), const Radius.circular(6)), strokePaint);

    // Main Torso / Helmet Circle
    final bodyPaint = Paint()..color = mainColor;
    canvas.drawCircle(Offset.zero, 21.0, bodyPaint);
    canvas.drawCircle(Offset.zero, 21.0, strokePaint);

    // Helmet Crest / Visor
    final crestPaint = Paint()..color = crestCol;
    final crestStroke = Paint()
      ..color = kOutlineColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -11, 18, 22), const Radius.circular(7)), crestPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -11, 18, 22), const Radius.circular(7)), crestStroke);

    // Glossy Specular Highlight on Helmet
    canvas.save();
    canvas.translate(-5, -6);
    canvas.rotate(-0.4);
    final shinePaint = Paint()..color = const Color(0x73FFFFFF);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 12, height: 8), shinePaint);
    canvas.restore();

    canvas.restore();

    // Brawl-Style HP Bar above head
    _drawBrawlHpBar(canvas, ent, isMe);

    if (ent.inBush) {
      canvas.restore();
    }
    canvas.restore();
  }

  // Rounded Brawl HP Bar (54 x 10 with backing, fill, top highlight & number)
  void _drawBrawlHpBar(Canvas canvas, PlayerStateModel ent, bool isMe) {
    const bw = 54.0;
    const bh = 10.0;
    const bx = -bw / 2;
    const by = -42.0;
    final ratio = (ent.hp / ent.maxHp).clamp(0.0, 1.0);

    // Dark Backing
    final bgPaint = Paint()..color = kOutlineColor;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(bx - 2, by - 2, bw + 4, bh + 4), const Radius.circular(6)), bgPaint);

    // Fill Bar
    final fillPaint = Paint()..color = isMe ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    if (ratio > 0) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, math.max(6.0, bw * ratio), bh), const Radius.circular(4)), fillPaint);
    }

    // Top Specular Highlight on Bar
    final hlPaint = Paint()..color = const Color(0x59FFFFFF);
    canvas.drawRect(Rect.fromLTWH(bx + 2, by + 1, math.max(0.0, bw * ratio - 4), 3), hlPaint);

    // HP Number Readout
    _drawOutlinedText(canvas, '${ent.hp.toInt()}', const Offset(0, by - 4), Colors.white, fontSize: 11);
  }

  // 6. Glowing Boomerang Blades & Slash Trails
  void _renderBlades(Canvas canvas) {
    for (final ent in players.values) {
      // Hide blade if bot is in bush and in orbit
      if (ent.id != mySessionId && ent.inBush && ent.bladeState == BladeCombatState.orbit && localPlayer != null) {
        if (hypot(ent.x - localPlayer!.x, ent.y - localPlayer!.y) > 115) {
          continue;
        }
      }

      final spec = getBladeSpecById(ent.bladeId);

      // Slash Ribbon Trail
      if (ent.bladeTrail.length > 1) {
        for (int i = 1; i < ent.bladeTrail.length; i++) {
          final p0 = ent.bladeTrail[i - 1];
          final p1 = ent.bladeTrail[i];
          final alpha = (p1.life / 0.16).clamp(0.0, 1.0);
          final trailPaint = Paint()
            ..color = spec.trailColor.withValues(alpha: alpha * 0.8)
            ..strokeWidth = 18.0 * alpha
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke;
          canvas.drawLine(Offset(p0.x, p0.y), Offset(p1.x, p1.y), trailPaint);
        }
      }

      // Stylized Cartoon Boomerang Blade Shape
      canvas.save();
      canvas.translate(ent.bladeX, ent.bladeY);
      canvas.rotate(ent.bladeSpin);

      // Outer Edge Glow & Contour
      final edgePaint = Paint()..color = spec.edgeColor;
      final strokePaint = Paint()
        ..color = kOutlineColor
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke;

      final edgePath = Path()
        ..moveTo(22, 0)
        ..quadraticBezierTo(4, -14, -16, -9)
        ..lineTo(-10, 0)
        ..lineTo(-16, 9)
        ..quadraticBezierTo(4, 14, 22, 0)
        ..close();

      canvas.drawPath(edgePath, edgePaint);
      canvas.drawPath(edgePath, strokePaint);

      // Inner Metallic Core
      final corePaint = Paint()..color = spec.bladeColor;
      final corePath = Path()
        ..moveTo(16, 0)
        ..quadraticBezierTo(3, -8, -11, -5)
        ..lineTo(-7, 0)
        ..lineTo(-11, 5)
        ..quadraticBezierTo(3, 8, 16, 0)
        ..close();

      canvas.drawPath(corePath, corePaint);

      // Hilt Rivet
      final rivetPaint = Paint()..color = const Color(0xFFFACC15);
      final rivetStroke = Paint()
        ..color = kOutlineColor
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(const Offset(-8, 0), 4.0, rivetPaint);
      canvas.drawCircle(const Offset(-8, 0), 4.0, rivetStroke);

      canvas.restore();
    }
  }

  // 7. Cartoon Star/Spark Particles & Floating Combat Numbers
  void _renderParticles(Canvas canvas) {
    for (final p in particles) {
      final alpha = (p.life / p.maxLife).clamp(0.0, 1.0);
      final fillPaint = Paint()..color = p.color.withValues(alpha: alpha);
      final strokePaint = Paint()
        ..color = kOutlineColor.withValues(alpha: alpha)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(Offset(p.x, p.y), p.size * alpha, fillPaint);
      canvas.drawCircle(Offset(p.x, p.y), p.size * alpha, strokePaint);
    }
  }

  void _renderFloatingTexts(Canvas canvas) {
    for (final ft in floatingTexts) {
      final alpha = (ft.life / ft.maxLife).clamp(0.0, 1.0);
      _drawOutlinedText(canvas, ft.text, Offset(ft.x, ft.y), ft.color.withValues(alpha: alpha), fontSize: 14);
    }
  }

  // Helper: Draw Outlined Text with Lilita One / Google Sans font
  void _drawOutlinedText(Canvas canvas, String text, Offset center, Color fill, {double fontSize = 14}) {
    // 1. Black Outline Pass
    final textPainterOutline = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.lilitaOne(
          fontSize: fontSize,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5
            ..color = kOutlineColor,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    textPainterOutline.paint(canvas, Offset(center.dx - textPainterOutline.width / 2, center.dy - textPainterOutline.height / 2));

    // 2. White / Color Fill Pass
    final textPainterFill = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.lilitaOne(
          fontSize: fontSize,
          color: fill,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    textPainterFill.paint(canvas, Offset(center.dx - textPainterFill.width / 2, center.dy - textPainterFill.height / 2));
  }

  // Helper: Draw Dashed Line
  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint, double dashWidth, double dashSpace) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance <= 0) return;

    final unitX = dx / distance;
    final unitY = dy / distance;

    double currentDist = 0.0;
    while (currentDist < distance) {
      final start = Offset(p1.dx + unitX * currentDist, p1.dy + unitY * currentDist);
      currentDist += dashWidth;
      if (currentDist > distance) currentDist = distance;
      final end = Offset(p1.dx + unitX * currentDist, p1.dy + unitY * currentDist);
      canvas.drawLine(start, end, paint);
      currentDist += dashSpace;
    }
  }
}

// 2.5D Depth Sorting Item
class _RenderItem {
  final double sortY;
  final RectBox? wall;
  final BushData? bush;
  final PlayerStateModel? brawler;

  const _RenderItem({
    required this.sortY,
    this.wall,
    this.bush,
    this.brawler,
  });
}
