import 'dart:math' as math;
import 'dart:ui' as ui;
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

/// Maximum number of particles allowed at once to prevent GC pressure.
const int kMaxParticles = 120;

/// Maximum number of floating combat texts at once.
const int kMaxFloatingTexts = 24;

/// Maximum blade trail points per player.
const int kMaxBladeTrailPoints = 12;

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

  // --- Cached TextPainter LRU pool (LinkedHashMap insertion order = O(1) LRU) ---
  final Map<String, TextPainter> _textCache = {};
  static const int _maxTextCacheSize = 96;
  final Map<int, TextStyle> _outlineStyleCache = {};
  final Map<int, TextStyle> _fillStyleCache = {};

  // --- Cached static floor + perimeter picture (regenerated only on map change) ---
  ui.Picture? _floorPicture;
  String? _floorMapId;

  // --- Cached precomputed wall RRects per map ---
  final List<_WallRRects> _wallRRectCache = [];
  String? _wallCacheMapId;

  // --- Reusable depth sort list ---
  final List<_RenderItem> _renderablePool = [];

  // --- Input throttling for network ---
  double _lastSentMx = 0.0;
  double _lastSentMy = 0.0;

  // --- Reusable Paint objects (zero per-frame Paint allocation) ---
  static final Paint _powerShadowPaint = Paint()..color = const Color(0x330F172A);
  static final Paint _powerGemPaint = Paint();
  static final Paint _powerStrokePaint = Paint()
    ..color = kOutlineColor
    ..strokeWidth = 3.5
    ..style = PaintingStyle.stroke;
  static final Paint _powerShinePaint = Paint()..color = const Color(0x8CFFFFFF);

  static final Paint _aimPaint = Paint()
    ..strokeWidth = 3.0
    ..style = PaintingStyle.stroke;
  static final Paint _slotFillPaint = Paint()
    ..color = const Color(0x59FACC15)
    ..style = PaintingStyle.fill;
  static final Paint _slotStrokePaint = Paint()
    ..color = const Color(0xFFFACC15)
    ..strokeWidth = 2.5
    ..style = PaintingStyle.stroke;

  static final Paint _wallShadowPaint = Paint()..color = const Color(0x3D0F172A);
  static final Paint _wallFrontPaint = Paint()..color = const Color(0xFF475569);
  static final Paint _wallTopFacePaint = Paint()..color = const Color(0xFF94A3B8);
  static final Paint _wallHighlightPaint = Paint()..color = const Color(0xFFCBD5E1);
  static final Paint _wallContourPaint = Paint()
    ..color = kOutlineColor
    ..strokeWidth = 3.5
    ..style = PaintingStyle.stroke;
  static final Paint _wallSeamPaint = Paint()
    ..color = kOutlineColor
    ..strokeWidth = 2.5
    ..style = PaintingStyle.stroke;

  static final Paint _bushShadowPaint = Paint()..color = const Color(0x380F172A);
  static final Paint _bushOutlinePaint = Paint()..color = kOutlineColor;
  static final Paint _bushDarkEmeraldPaint = Paint()..color = const Color(0xFF15803D);
  static final Paint _bushMidGreenPaint = Paint()..color = const Color(0xFF22C55E);
  static final Paint _bushLimeHighlightPaint = Paint()..color = const Color(0xFF4ADE80);
  static final Paint _bushAlphaLayerPaint = Paint()..color = const Color(0x8FFFFFFF);

  static final Paint _brawlerAlphaLayerPaint = Paint()..color = const Color(0xA6FFFFFF);
  static final Paint _brawlerShadowPaint = Paint()..color = const Color(0x4D0F172A);
  static final Paint _brawlerAuraPaint = Paint()
    ..color = const Color(0xFFFB923C)
    ..strokeWidth = 3.0
    ..style = PaintingStyle.stroke;
  static final Paint _brawlerShieldFillPaint = Paint()
    ..color = const Color(0x2E38BDF8)
    ..style = PaintingStyle.fill;
  static final Paint _brawlerShieldStrokePaint = Paint()
    ..color = const Color(0xFF38BDF8)
    ..strokeWidth = 3.0
    ..style = PaintingStyle.stroke;
  static final Paint _brawlerTrimPaint = Paint();
  static final Paint _brawlerBodyPaint = Paint();
  static final Paint _brawlerCrestPaint = Paint();
  static final Paint _brawlerStrokePaint = Paint()
    ..color = kOutlineColor
    ..strokeWidth = 3.5
    ..style = PaintingStyle.stroke;
  static final Paint _brawlerCrestStrokePaint = Paint()
    ..color = kOutlineColor
    ..strokeWidth = 3.0
    ..style = PaintingStyle.stroke;
  static final Paint _brawlerShinePaint = Paint()..color = const Color(0x73FFFFFF);

  static final Paint _hpBgPaint = Paint()..color = kOutlineColor;
  static final Paint _hpFillPaint = Paint();
  static final Paint _hpHlPaint = Paint()..color = const Color(0x59FFFFFF);

  static final Paint _bladeTrailPaint = Paint()
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  static final Paint _bladeEdgePaint = Paint();
  static final Paint _bladeCorePaint = Paint();
  static final Paint _bladeStrokePaint = Paint()
    ..color = kOutlineColor
    ..strokeWidth = 3.5
    ..style = PaintingStyle.stroke;
  static final Paint _bladeRivetPaint = Paint()..color = const Color(0xFFFACC15);
  static final Paint _bladeRivetStrokePaint = Paint()
    ..color = kOutlineColor
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;

  static final Paint _particleFillPaint = Paint();
  static final Paint _particleStrokePaint = Paint()
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;

  // --- Static pre-built boomerang blade Paths ---
  static final Path _bladeEdgePath = Path()
    ..moveTo(22, 0)
    ..quadraticBezierTo(4, -14, -16, -9)
    ..lineTo(-10, 0)
    ..lineTo(-16, 9)
    ..quadraticBezierTo(4, 14, 22, 0)
    ..close();

  static final Path _bladeCorePath = Path()
    ..moveTo(16, 0)
    ..quadraticBezierTo(3, -8, -11, -5)
    ..lineTo(-7, 0)
    ..lineTo(-11, 5)
    ..quadraticBezierTo(3, 8, 16, 0)
    ..close();

  // --- Reusable static RRects for brawler geometry ---
  static final RRect _shoulderLeftRRect = RRect.fromRectAndRadius(const Rect.fromLTWH(-10, -27, 20, 12), const Radius.circular(6));
  static final RRect _shoulderRightRRect = RRect.fromRectAndRadius(const Rect.fromLTWH(-10, 15, 20, 12), const Radius.circular(6));
  static final RRect _visorRRect = RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -11, 18, 22), const Radius.circular(7));
  static final RRect _hpBgRRect = RRect.fromRectAndRadius(const Rect.fromLTWH(-29, -44, 58, 14), const Radius.circular(6));

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
    // Invalidate cached floor & wall geometry when map changes
    _floorPicture?.dispose();
    _floorPicture = null;
    _floorMapId = null;
    _wallCacheMapId = null;
  }

  @override
  void onRemove() {
    _floorPicture?.dispose();
    _floorPicture = null;
    for (final tp in _textCache.values) {
      tp.dispose();
    }
    _textCache.clear();
    _outlineStyleCache.clear();
    _fillStyleCache.clear();
    super.onRemove();
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
    // Cap total particles to prevent GC pressure
    final spawnCount = math.min(count, kMaxParticles - particles.length);
    if (spawnCount <= 0) return;

    for (int i = 0; i < spawnCount; i++) {
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

    // Update Live Leaderboard (avoid allocating if unchanged)
    _updateLeaderboard();
  }

  /// Separated leaderboard update to avoid per-sync allocation when nothing changed.
  void _updateLeaderboard() {
    final board = players.values.map((p) => LeaderboardEntry(
      name: p.id == mySessionId ? 'SEN' : p.name,
      kills: p.kills,
      isMe: p.id == mySessionId,
    )).toList()
      ..sort((a, b) => b.kills.compareTo(a.kills));

    final top = board.length > 4 ? board.sublist(0, 4) : board;

    // Only update notifier if data actually changed
    final current = leaderboardNotifier.value;
    bool changed = current.length != top.length;
    if (!changed) {
      for (int i = 0; i < top.length; i++) {
        if (current[i].name != top[i].name || current[i].kills != top[i].kills) {
          changed = true;
          break;
        }
      }
    }
    if (changed) {
      leaderboardNotifier.value = top;
    }
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
      _addFloatingText(x, y - 28, 'BLOK!', const Color(0xFF38BDF8));
      if (attackerId == mySessionId || targetId == mySessionId) {
        hitStopTimer = 0.035;
        triggerShake(5, 0.12);
      }
    } else {
      // Successful Damage Hit
      _spawnBurst(x, y, col, 12);
      _addFloatingText(x, y - 30, '-${damage.toInt()}', const Color(0xFFEF4444));
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
      _addFloatingText(
        localPlayer?.x ?? kWorldWidth / 2,
        (localPlayer?.y ?? kWorldHeight / 2) - 42,
        '+$goldAwarded ALTIN',
        const Color(0xFFFACC15),
      );
    }

    if (victimId == mySessionId) {
      _addFloatingText(
        localPlayer?.x ?? kWorldWidth / 2,
        (localPlayer?.y ?? kWorldHeight / 2) - 40,
        'YENİDEN DOĞUŞ',
        const Color(0xFFF8FAFC),
      );
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

    _addFloatingText(x, y - 34, txt, col);
  }

  /// Add a floating text with cap enforcement.
  void _addFloatingText(double x, double y, String text, Color color) {
    if (floatingTexts.length >= kMaxFloatingTexts) {
      floatingTexts.removeAt(0); // Remove oldest
    }
    floatingTexts.add(FloatingCombatText(x: x, y: y, text: text, color: color));
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

    // Send input to server / offline simulator only when changed (saves 80-99% WS traffic)
    if ((mx - _lastSentMx).abs() > 0.01 ||
        (my - _lastSentMy).abs() > 0.01 ||
        (mx == 0.0 && my == 0.0 && (_lastSentMx != 0.0 || _lastSentMy != 0.0))) {
      _lastSentMx = mx;
      _lastSentMy = my;
      network.sendMove(mx, my);
    }

    // 2. Client-side entity interpolation
    final interp = math.min(1.0, 18.0 * dt);
    for (final p in players.values) {
      if (p.flashTimer > 0) p.flashTimer = math.max(0, p.flashTimer - dt);

      // Smooth interpolation for remote entities
      p.renderX += (p.targetX - p.renderX) * interp;
      p.renderY += (p.targetY - p.renderY) * interp;
      p.x = p.renderX;
      p.y = p.renderY;
    }

    // 3. Update Visual FX (O(1) swap-remove, zero closure allocation)
    for (int i = particles.length - 1; i >= 0; i--) {
      final p = particles[i];
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt;
      if (p.life <= 0) {
        particles[i] = particles.last;
        particles.removeLast();
      }
    }

    for (int i = floatingTexts.length - 1; i >= 0; i--) {
      final f = floatingTexts[i];
      f.y -= 34.0 * dt;
      f.life -= dt;
      if (f.life <= 0) {
        floatingTexts[i] = floatingTexts.last;
        floatingTexts.removeLast();
      }
    }

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
  // 1:1 BRAWL CEL-SHADED 2.5D RENDERING PIPELINE
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

    // Visible viewport bounds with margin for culling off-screen entities
    const cullMargin = 140.0;
    final visLeft = camX - halfW - cullMargin;
    final visRight = camX + halfW + cullMargin;
    final visTop = camY - halfH - cullMargin;
    final visBottom = camY + halfH + cullMargin;

    // 1. Warm Sunlit Desert / Temple Stone Tiles & Perimeter Border (cached as Picture)
    _renderArenaFloorCached(canvas);

    // 2. Central Power-Up Pads
    _renderCentralPowerUps(canvas, visLeft, visTop, visRight, visBottom);

    // 3. Aim Guide & Frozen Return Slot Marker
    _renderAimAndSlotMarkers(canvas);

    // 4. Depth-Sorted 2.5D Extruded Walls, Brawlers & Puffy Bushes
    _renderDepthSortedScene(canvas, visLeft, visTop, visRight, visBottom);

    // 5. Glowing Boomerang Blades & Slash Trails
    _renderBlades(canvas, visLeft, visTop, visRight, visBottom);

    // 6. Cartoon Particles & Floating Combat Texts
    _renderParticles(canvas, visLeft, visTop, visRight, visBottom);
    _renderFloatingTexts(canvas, visLeft, visTop, visRight, visBottom);

    canvas.restore();
  }

  // 1. Floor + Perimeter Border rendering with Picture caching (static content, drawn once)
  void _renderArenaFloorCached(Canvas canvas) {
    if (_floorPicture == null || _floorMapId != currentMap.id) {
      _floorPicture?.dispose();
      _floorPicture = _buildFloorPicture();
      _floorMapId = currentMap.id;
    }
    canvas.drawPicture(_floorPicture!);
  }

  ui.Picture _buildFloorPicture() {
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    _renderArenaFloorAndGrid(c);
    _renderPerimeterBorder(c);
    return recorder.endRecording();
  }

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
  void _renderCentralPowerUps(Canvas canvas, double visLeft, double visTop, double visRight, double visBottom) {
    for (final p in powerUps) {
      if (!p.active) continue;
      if (p.x < visLeft || p.x > visRight || p.y < visTop || p.y > visBottom) continue;

      final bob = math.sin(globalTime * 4.5 + p.x) * 4.0;

      // Pedestal Ring Shadow
      canvas.drawOval(Rect.fromCenter(center: Offset(p.x, p.y + 10), width: 44, height: 28), _powerShadowPaint);

      // Gem Body with Black Outline
      _powerGemPaint.color = p.color;
      final gemCenter = Offset(p.x, p.y + bob);
      canvas.drawCircle(gemCenter, 17.0, _powerGemPaint);
      canvas.drawCircle(gemCenter, 17.0, _powerStrokePaint);

      // Inner Shine
      canvas.drawCircle(Offset(p.x - 5, p.y + bob - 5), 5.0, _powerShinePaint);

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
    final cosA = math.cos(slotAngle);
    final sinA = math.sin(slotAngle);
    final slotX = p.x + cosA * p.orbitRadius;
    final slotY = p.y + sinA * p.orbitRadius;

    // Golden Dotted Aim Trajectory Line
    _aimPaint.color = inOrbit ? const Color(0xB8FACC15) : const Color(0x47FACC15);

    final endX = p.x + cosA * spec.range;
    final endY = p.y + sinA * spec.range;
    _drawDashedLine(canvas, Offset(slotX, slotY), Offset(endX, endY), _aimPaint, 7.0, 7.0);

    // Pulsing Frozen Slot Marker
    if (!inOrbit) {
      final pulse = 1.0 + math.sin(globalTime * 14.0) * 0.16;
      final slotCenter = Offset(slotX, slotY);
      canvas.drawCircle(slotCenter, 13.0 * pulse, _slotFillPaint);
      canvas.drawCircle(slotCenter, 13.0 * pulse, _slotStrokePaint);
    }
  }

  void _ensureWallRRectCache() {
    if (_wallCacheMapId == currentMap.id && _wallRRectCache.isNotEmpty) return;
    _wallRRectCache.clear();
    const bevelH = 22.0;
    const rad = Radius.circular(12.0);
    const hlRad = Radius.circular(8.0);
    for (final w in currentMap.walls) {
      final topH = math.max(16.0, w.h - bevelH);
      _wallRRectCache.add(_WallRRects(
        wall: w,
        shadow: RRect.fromRectAndRadius(Rect.fromLTWH(w.x + 5, w.y + 8, w.w, w.h + 4), rad),
        body: RRect.fromRectAndRadius(Rect.fromLTWH(w.x, w.y, w.w, w.h), rad),
        topFace: RRect.fromRectAndRadius(Rect.fromLTWH(w.x, w.y, w.w, topH), rad),
        highlight: RRect.fromRectAndRadius(Rect.fromLTWH(w.x + 5, w.y + 4, w.w - 10, math.max(8.0, topH - 10)), hlRad),
        seamStart: Offset(w.x + 3, w.y + topH),
        seamEnd: Offset(w.x + w.w - 3, w.y + topH),
      ));
    }
    _wallCacheMapId = currentMap.id;
  }

  // 4. Depth-Sorted 2.5D Scene (Walls, Bushes, Brawlers) with Viewport Culling
  void _renderDepthSortedScene(Canvas canvas, double visLeft, double visTop, double visRight, double visBottom) {
    _ensureWallRRectCache();
    _renderablePool.clear();

    // Walls (culled against viewport)
    for (final wc in _wallRRectCache) {
      final w = wc.wall;
      if (w.x + w.w < visLeft || w.x > visRight || w.y + w.h < visTop || w.y > visBottom) continue;
      _renderablePool.add(_RenderItem(sortY: w.y + w.h, wallCache: wc));
    }

    // Bushes (culled against viewport)
    for (final b in currentMap.bushes) {
      if (b.x + b.r < visLeft || b.x - b.r > visRight || b.y + b.r < visTop || b.y - b.r > visBottom) continue;
      _renderablePool.add(_RenderItem(sortY: b.y + b.r * 0.35, bush: b));
    }

    // Brawlers (Player & Bots, culled against viewport)
    for (final p in players.values) {
      if (p.x < visLeft || p.x > visRight || p.y < visTop || p.y > visBottom) continue;
      _renderablePool.add(_RenderItem(sortY: p.y, brawler: p));
    }

    _renderablePool.sort((a, b) => a.sortY.compareTo(b.sortY));

    for (final item in _renderablePool) {
      if (item.wallCache != null) {
        _renderExtrudedWall(canvas, item.wallCache!);
      } else if (item.bush != null) {
        _renderPuffyBush(canvas, item.bush!);
      } else if (item.brawler != null) {
        _renderStylizedBrawler(canvas, item.brawler!);
      }
    }
  }

  // 2.5D Extruded Wall Drawing (zero allocations per frame)
  void _renderExtrudedWall(Canvas canvas, _WallRRects wc) {
    canvas.drawRRect(wc.shadow, _wallShadowPaint);
    canvas.drawRRect(wc.body, _wallFrontPaint);
    canvas.drawRRect(wc.topFace, _wallTopFacePaint);
    canvas.drawRRect(wc.highlight, _wallHighlightPaint);
    canvas.drawRRect(wc.body, _wallContourPaint);
    canvas.drawLine(wc.seamStart, wc.seamEnd, _wallSeamPaint);
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

  // Puffy Cartoon Bushes (4-pass rendering with sway & tight saveLayer bounds)
  void _renderPuffyBush(Canvas canvas, BushData b) {
    final sway = b.rustle > 0.001 ? math.sin(globalTime * 14.0) * b.rustle * 4.0 : 0.0;
    bool isPlayerInside = false;
    if (localPlayer != null) {
      final dx = localPlayer!.x - b.x;
      final dy = localPlayer!.y - b.y;
      final thresh = b.r * 0.9;
      isPlayerInside = (dx * dx + dy * dy) < (thresh * thresh);
    }

    canvas.save();
    canvas.translate(b.x + sway, b.y);

    if (isPlayerInside) {
      final r = b.r + 20.0;
      canvas.saveLayer(Rect.fromLTRB(-r, -r, r, r), _bushAlphaLayerPaint);
    }

    // Ground Shadow
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 10), width: b.r * 1.9, height: b.r * 1.64), _bushShadowPaint);

    // 1. Outer Black Silhouette Pass
    for (final p in b.puffs) {
      canvas.drawCircle(Offset(p.dx, p.dy), p.r + 3.5, _bushOutlinePaint);
    }

    // 2. Base Dark Emerald Leaf Fill
    for (final p in b.puffs) {
      canvas.drawCircle(Offset(p.dx, p.dy + 2), p.r, _bushDarkEmeraldPaint);
    }

    // 3. Mid Vibrant Green Leaf Fill
    for (final p in b.puffs) {
      canvas.drawCircle(Offset(p.dx, p.dy - 2), p.r * 0.92, _bushMidGreenPaint);
    }

    // 4. Top Lime Highlight Puffs
    for (final p in b.puffs) {
      canvas.drawCircle(Offset(p.dx - p.r * 0.16, p.dy - p.r * 0.22), p.r * 0.52, _bushLimeHighlightPaint);
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
      final dx = ent.x - localPlayer!.x;
      final dy = ent.y - localPlayer!.y;
      if (dx * dx + dy * dy > 115.0 * 115.0) {
        return;
      }
    }

    canvas.save();
    canvas.translate(ent.x, ent.y);

    if (ent.inBush) {
      canvas.saveLayer(const Rect.fromLTWH(-46, -64, 92, 102), _brawlerAlphaLayerPaint);
    }

    // Ground Oval Drop Shadow
    canvas.drawOval(const Rect.fromLTWH(-24, 1, 48, 30), _brawlerShadowPaint);

    // Active Power Aura
    if (ent.powerTimer > 0) {
      canvas.drawCircle(Offset.zero, 33.0 + math.sin(globalTime * 10.0) * 2.0, _brawlerAuraPaint);
    }

    // Active Shield Ring
    if (ent.shieldHits > 0) {
      canvas.drawCircle(Offset.zero, 35.0, _brawlerShieldFillPaint);
      canvas.drawCircle(Offset.zero, 35.0, _brawlerShieldStrokePaint);
    }

    final isMe = ent.id == mySessionId;
    final isFlashing = ent.flashTimer > 0;
    final mainColor = isFlashing ? Colors.white : (isMe ? const Color(0xFF0EA5E9) : const Color(0xFFF97316));
    final darkTrim = isFlashing ? const Color(0xFFE2E8F0) : (isMe ? const Color(0xFF0369A1) : const Color(0xFFC2410C));
    final crestCol = isMe ? const Color(0xFF38BDF8) : const Color(0xFFFACC15);

    // Rotate body towards facing direction
    canvas.save();
    canvas.rotate(ent.facing);

    _brawlerTrimPaint.color = darkTrim;
    _brawlerBodyPaint.color = mainColor;
    _brawlerCrestPaint.color = crestCol;

    // Chunky Left & Right Shoulder Pads
    canvas.drawRRect(_shoulderLeftRRect, _brawlerTrimPaint);
    canvas.drawRRect(_shoulderLeftRRect, _brawlerStrokePaint);
    canvas.drawRRect(_shoulderRightRRect, _brawlerTrimPaint);
    canvas.drawRRect(_shoulderRightRRect, _brawlerStrokePaint);

    // Main Torso / Helmet Circle
    canvas.drawCircle(Offset.zero, 21.0, _brawlerBodyPaint);
    canvas.drawCircle(Offset.zero, 21.0, _brawlerStrokePaint);

    // Helmet Crest / Visor
    canvas.drawRRect(_visorRRect, _brawlerCrestPaint);
    canvas.drawRRect(_visorRRect, _brawlerCrestStrokePaint);

    // Glossy Specular Highlight on Helmet
    canvas.save();
    canvas.translate(-5, -6);
    canvas.rotate(-0.4);
    canvas.drawOval(const Rect.fromLTWH(-6, -4, 12, 8), _brawlerShinePaint);
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
    canvas.drawRRect(_hpBgRRect, _hpBgPaint);

    // Fill Bar
    _hpFillPaint.color = isMe ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    if (ratio > 0) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, math.max(6.0, bw * ratio), bh), const Radius.circular(4)), _hpFillPaint);
    }

    // Top Specular Highlight on Bar
    canvas.drawRect(Rect.fromLTWH(bx + 2, by + 1, math.max(0.0, bw * ratio - 4), 3), _hpHlPaint);

    // HP Number Readout
    _drawOutlinedText(canvas, '${ent.hp.toInt()}', const Offset(0, by - 4), Colors.white, fontSize: 11);
  }

  // 5. Glowing Boomerang Blades & Slash Trails
  void _renderBlades(Canvas canvas, double visLeft, double visTop, double visRight, double visBottom) {
    for (final ent in players.values) {
      // Hide blade if bot is in bush and in orbit
      if (ent.id != mySessionId && ent.inBush && ent.bladeState == BladeCombatState.orbit && localPlayer != null) {
        final dx = ent.x - localPlayer!.x;
        final dy = ent.y - localPlayer!.y;
        if (dx * dx + dy * dy > 115.0 * 115.0) {
          continue;
        }
      }

      final bladeVisible = ent.bladeX >= visLeft && ent.bladeX <= visRight && ent.bladeY >= visTop && ent.bladeY <= visBottom;
      if (!bladeVisible && ent.bladeTrail.isEmpty) continue;

      final spec = getBladeSpecById(ent.bladeId);

      // Slash Ribbon Trail
      if (ent.bladeTrail.length > 1) {
        for (int i = 1; i < ent.bladeTrail.length; i++) {
          final p0 = ent.bladeTrail[i - 1];
          final p1 = ent.bladeTrail[i];
          final alpha = (p1.life / 0.16).clamp(0.0, 1.0);
          _bladeTrailPaint.color = spec.trailColor.withValues(alpha: alpha * 0.8);
          _bladeTrailPaint.strokeWidth = 18.0 * alpha;
          canvas.drawLine(Offset(p0.x, p0.y), Offset(p1.x, p1.y), _bladeTrailPaint);
        }
      }

      if (!bladeVisible) continue;

      // Stylized Cartoon Boomerang Blade Shape (using pre-built static Paths)
      canvas.save();
      canvas.translate(ent.bladeX, ent.bladeY);
      canvas.rotate(ent.bladeSpin);

      _bladeEdgePaint.color = spec.edgeColor;
      _bladeCorePaint.color = spec.bladeColor;

      canvas.drawPath(_bladeEdgePath, _bladeEdgePaint);
      canvas.drawPath(_bladeEdgePath, _bladeStrokePaint);
      canvas.drawPath(_bladeCorePath, _bladeCorePaint);

      // Hilt Rivet
      canvas.drawCircle(const Offset(-8, 0), 4.0, _bladeRivetPaint);
      canvas.drawCircle(const Offset(-8, 0), 4.0, _bladeRivetStrokePaint);

      canvas.restore();
    }
  }

  // 6. Cartoon Star/Spark Particles & Floating Combat Numbers
  void _renderParticles(Canvas canvas, double visLeft, double visTop, double visRight, double visBottom) {
    for (final p in particles) {
      if (p.x < visLeft || p.x > visRight || p.y < visTop || p.y > visBottom) continue;
      final alpha = (p.life / p.maxLife).clamp(0.0, 1.0);
      _particleFillPaint.color = p.color.withValues(alpha: alpha);
      _particleStrokePaint.color = kOutlineColor.withValues(alpha: alpha);

      final center = Offset(p.x, p.y);
      final r = p.size * alpha;
      canvas.drawCircle(center, r, _particleFillPaint);
      canvas.drawCircle(center, r, _particleStrokePaint);
    }
  }

  void _renderFloatingTexts(Canvas canvas, double visLeft, double visTop, double visRight, double visBottom) {
    for (final ft in floatingTexts) {
      if (ft.x < visLeft || ft.x > visRight || ft.y < visTop || ft.y > visBottom) continue;
      final alpha = (ft.life / ft.maxLife).clamp(0.0, 1.0);
      // Quantize alpha to 10 discrete steps so TextPainter cache hits >90% of frames
      final quantizedAlpha = (alpha * 10).round() / 10.0;
      if (quantizedAlpha <= 0.0) continue;
      _drawOutlinedText(canvas, ft.text, Offset(ft.x, ft.y), ft.color.withValues(alpha: quantizedAlpha), fontSize: 14);
    }
  }

  // Helper: Draw Outlined Text with O(1) LinkedHashMap LRU TextPainter cache
  void _drawOutlinedText(Canvas canvas, String text, Offset center, Color fill, {double fontSize = 14}) {
    final sizeInt = fontSize.toInt();
    final outlineKey = 'o|$text|$sizeInt';
    final outlinePainter = _getCachedOutlinePainter(outlineKey, text, fontSize, sizeInt);
    final ox = center.dx - outlinePainter.width / 2;
    final oy = center.dy - outlinePainter.height / 2;
    outlinePainter.paint(canvas, Offset(ox, oy));

    final fillKey = 'f|$text|$sizeInt|${fill.toARGB32()}';
    final fillPainter = _getCachedFillPainter(fillKey, text, fontSize, sizeInt, fill);
    fillPainter.paint(canvas, Offset(center.dx - fillPainter.width / 2, center.dy - fillPainter.height / 2));
  }

  TextPainter _getCachedOutlinePainter(String key, String text, double fontSize, int sizeInt) {
    final cached = _textCache.remove(key);
    if (cached != null) {
      _textCache[key] = cached; // Move to MRU end in O(1)
      return cached;
    }

    _evictTextCacheIfNeeded();

    final style = _outlineStyleCache.putIfAbsent(
      sizeInt,
      () => GoogleFonts.lilitaOne(
        fontSize: fontSize,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..color = kOutlineColor,
      ),
    );

    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    _textCache[key] = tp;
    return tp;
  }

  TextPainter _getCachedFillPainter(String key, String text, double fontSize, int sizeInt, Color fill) {
    final cached = _textCache.remove(key);
    if (cached != null) {
      _textCache[key] = cached; // Move to MRU end in O(1)
      return cached;
    }

    _evictTextCacheIfNeeded();

    final baseStyle = _fillStyleCache.putIfAbsent(
      sizeInt,
      () => GoogleFonts.lilitaOne(fontSize: fontSize),
    );

    final tp = TextPainter(
      text: TextSpan(text: text, style: baseStyle.copyWith(color: fill)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    _textCache[key] = tp;
    return tp;
  }

  void _evictTextCacheIfNeeded() {
    while (_textCache.length >= _maxTextCacheSize) {
      final oldestKey = _textCache.keys.first;
      final removed = _textCache.remove(oldestKey);
      removed?.dispose();
    }
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

// Precomputed RRects for a static wall
class _WallRRects {
  final RectBox wall;
  final RRect shadow;
  final RRect body;
  final RRect topFace;
  final RRect highlight;
  final Offset seamStart;
  final Offset seamEnd;

  const _WallRRects({
    required this.wall,
    required this.shadow,
    required this.body,
    required this.topFace,
    required this.highlight,
    required this.seamStart,
    required this.seamEnd,
  });
}

// 2.5D Depth Sorting Item
class _RenderItem {
  final double sortY;
  final _WallRRects? wallCache;
  final BushData? bush;
  final PlayerStateModel? brawler;

  const _RenderItem({
    required this.sortY,
    this.wallCache,
    this.bush,
    this.brawler,
  });
}
