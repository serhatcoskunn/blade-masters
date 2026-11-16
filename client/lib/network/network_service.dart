import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/blade_catalog.dart';
import '../models/game_models.dart';
import '../models/map_config.dart';

typedef OnStateSyncCallback = void Function(List<PlayerStateModel> players, List<PowerUpStateModel> powerUps, int matchTime);
typedef OnHitCallback = void Function(double x, double y, double damage, String targetId, String attackerId, String colorHex);
typedef OnKillCallback = void Function(String killerId, String victimId, String killerName, String victimName, int gold);
typedef OnPowerUpCallback = void Function(String playerId, PowerType type, double x, double y);

class NetworkService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _isConnected = false;
  bool _isOfflinePractice = false;
  String _mySessionId = 'local_player';

  // Callbacks
  OnStateSyncCallback? onStateSync;
  OnHitCallback? onHit;
  OnKillCallback? onKill;
  OnPowerUpCallback? onPowerUp;
  VoidCallback? onConnected;
  VoidCallback? onDisconnected;

  // Local Offline Simulation Timer & State (Practice Mode)
  Timer? _offlineSimTimer;
  final List<PlayerStateModel> _simPlayers = [];
  final List<PowerUpStateModel> _simPowerUps = [];
  MapConfigData _activeMap = kMapConfigs[0];
  double _simMatchTimeElapsed = 0.0;
  int _simMatchTime = 0;
  final math.Random _random = math.Random();

  bool get isConnected => _isConnected;
  bool get isOfflinePractice => _isOfflinePractice;
  String get mySessionId => _mySessionId;

  Future<bool> connect({
    required String serverUrl,
    required String playerName,
    required String bladeId,
    required String mapId,
    int botCount = 3,
  }) async {
    disconnect();
    _activeMap = getMapConfigById(mapId);

    // Normalize URL
    String wsUrl = serverUrl.trim();
    if (wsUrl.isEmpty) {
      if (kIsWeb && Uri.base.host.isNotEmpty && Uri.base.host != 'localhost') {
        final scheme = Uri.base.scheme == 'https' ? 'wss' : 'ws';
        final port = Uri.base.hasPort && Uri.base.port != 80 && Uri.base.port != 443 ? ':${Uri.base.port}' : '';
        wsUrl = '$scheme://${Uri.base.host}$port';
      } else {
        wsUrl = 'ws://localhost:2567';
      }
    }
    if (wsUrl.startsWith('https://')) {
      wsUrl = wsUrl.replaceFirst('https://', 'wss://');
    } else if (wsUrl.startsWith('http://')) {
      wsUrl = wsUrl.replaceFirst('http://', 'ws://');
    } else if (!wsUrl.startsWith('ws://') && !wsUrl.startsWith('wss://')) {
      wsUrl = 'ws://$wsUrl';
    }

    final completer = Completer<bool>();

    try {
      final uri = Uri.parse('$wsUrl/arena');
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;

      _sub = channel.stream.listen(
        (dynamic message) {
          if (!_isConnected) {
            _isConnected = true;
            _isOfflinePractice = false;
            onConnected?.call();
            if (!completer.isCompleted) completer.complete(true);

            // Send handshake join with chosen bot count
            send('join', {
              'name': playerName,
              'bladeId': bladeId,
              'mapId': mapId,
              'botCount': botCount,
            });
          }
          _handleServerMessage(message);
        },
        onError: (err) {
          debugPrint('[NetworkService] WebSocket error: $err');
          _fallbackToOfflineSimulation(playerName, bladeId, mapId, botCount);
          if (!completer.isCompleted) completer.complete(true);
        },
        onDone: () {
          debugPrint('[NetworkService] WebSocket disconnected');
          _isConnected = false;
          onDisconnected?.call();
        },
      );

      Timer(const Duration(milliseconds: 1500), () {
        if (!completer.isCompleted) {
          debugPrint('[NetworkService] Server not reached within 1.5s, starting practice arena');
          _fallbackToOfflineSimulation(playerName, bladeId, mapId, botCount);
          completer.complete(true);
        }
      });
    } catch (e) {
      debugPrint('[NetworkService] Connect exception: $e');
      _fallbackToOfflineSimulation(playerName, bladeId, mapId, botCount);
      completer.complete(true);
    }

    return completer.future;
  }

  void _handleServerMessage(dynamic rawMessage) {
    try {
      final decoded = jsonDecode(rawMessage.toString());
      if (decoded is! Map<String, dynamic>) return;

      final type = decoded['type']?.toString();
      final data = decoded['data'];

      if (type == 'init' && data is Map<String, dynamic>) {
        _mySessionId = data['sessionId']?.toString() ?? _mySessionId;
      } else if (type == 'sync' && data is Map<String, dynamic>) {
        final playersList = <PlayerStateModel>[];
        if (data['players'] is List) {
          for (final pJson in data['players']) {
            if (pJson is Map<String, dynamic>) {
              playersList.add(PlayerStateModel.fromJson(pJson));
            }
          }
        }

        final powerUpsList = <PowerUpStateModel>[];
        if (data['powerUps'] is List) {
          for (final powJson in data['powerUps']) {
            if (powJson is Map<String, dynamic>) {
              powerUpsList.add(PowerUpStateModel.fromJson(powJson));
            }
          }
        }

        final matchTime = (data['matchTime'] as num?)?.toInt() ?? 0;
        onStateSync?.call(playersList, powerUpsList, matchTime);
      } else if (type == 'hit' && data is Map<String, dynamic>) {
        onHit?.call(
          (data['x'] as num?)?.toDouble() ?? 0.0,
          (data['y'] as num?)?.toDouble() ?? 0.0,
          (data['damage'] as num?)?.toDouble() ?? 0.0,
          data['targetId']?.toString() ?? '',
          data['attackerId']?.toString() ?? '',
          data['color']?.toString() ?? '#ffffff',
        );
      } else if (type == 'kill' && data is Map<String, dynamic>) {
        onKill?.call(
          data['killerId']?.toString() ?? '',
          data['victimId']?.toString() ?? '',
          data['killerName']?.toString() ?? '',
          data['victimName']?.toString() ?? '',
          (data['goldAwarded'] as num?)?.toInt() ?? 35,
        );
      } else if (type == 'powerup' && data is Map<String, dynamic>) {
        PowerType pType = PowerType.damage;
        final tStr = data['type']?.toString().toUpperCase() ?? 'DAMAGE';
        if (tStr == 'HEAL') pType = PowerType.heal;
        if (tStr == 'SHIELD') pType = PowerType.shield;

        onPowerUp?.call(
          data['playerId']?.toString() ?? '',
          pType,
          (data['x'] as num?)?.toDouble() ?? 0.0,
          (data['y'] as num?)?.toDouble() ?? 0.0,
        );
      }
    } catch (e) {
      debugPrint('[NetworkService] Parsing error: $e');
    }
  }

  void sendMove(double dx, double dy) {
    if (_isConnected && _channel != null && !_isOfflinePractice) {
      send('move', {'dx': dx, 'dy': dy});
    } else if (_isOfflinePractice) {
      _offlineInputDx = dx;
      _offlineInputDy = dy;
    }
  }

  void sendThrow() {
    if (_isConnected && _channel != null && !_isOfflinePractice) {
      send('throw', {});
    } else if (_isOfflinePractice) {
      _offlineThrowLocalPlayer();
    }
  }

  void send(String type, Map<String, dynamic> data) {
    if (_channel != null && _isConnected) {
      try {
        _channel!.sink.add(jsonEncode({'type': type, 'data': data}));
      } catch (e) {
        debugPrint('[NetworkService] Send error: $e');
      }
    }
  }

  void disconnect() {
    _offlineSimTimer?.cancel();
    _offlineSimTimer = null;
    _sub?.cancel();
    _sub = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _isConnected = false;
    _isOfflinePractice = false;
  }

  // --- LOCAL OFFLINE SIMULATION: EXACT REPLICA OF PROTOTYPE LOGIC ---
  double _offlineInputDx = 0.0;
  double _offlineInputDy = 0.0;

  void _fallbackToOfflineSimulation(String playerName, String bladeId, String mapId, [int botCount = 3]) {
    disconnect();
    _isOfflinePractice = true;
    _isConnected = true;
    _mySessionId = 'local_player';
    _activeMap = getMapConfigById(mapId);
    _simMatchTimeElapsed = 0.0;
    _simMatchTime = 0;
    _simPlayers.clear();
    _simPowerUps.clear();

    // Reset bush rustles
    for (final b in _activeMap.bushes) {
      b.rustle = 0.0;
    }

    // 1. Spawn Local Player at WORLD_W / 2, WORLD_H - 180 (exact prototype spawn)
    final me = PlayerStateModel(
      id: _mySessionId,
      name: playerName.isEmpty ? 'SEN' : playerName,
      x: kWorldWidth / 2,
      y: kWorldHeight - 180,
      facing: -math.pi / 2,
      radius: 25,
      hp: 130,
      maxHp: 130,
      speed: 245,
      kills: 0,
      isBot: false,
      bladeId: bladeId,
      bladeState: BladeCombatState.orbit,
      bladeAngle: 0,
      bladeSpin: 0,
      bladeX: kWorldWidth / 2 + 48,
      bladeY: kWorldHeight - 180,
      frozenAngle: 0,
      orbitRadius: 48,
    );
    _simPlayers.add(me);

    // 2. Spawn Bots based on user selection (0 to 10 bots)
    final botBlades = ['steel', 'crimson', 'emerald', 'shadow', 'cyber', 'void', 'phoenix', 'inferno'];
    final botNames = [
      'Gölge Bıçak',
      'Fırtına TR',
      'Ejderha X',
      'Titan Pro',
      'Viper TR',
      'Ateş Kuşu',
      'Kaya Canavarı',
      'Siber Ninja',
      'Kurt Reis',
      'Şimşek 99',
    ];

    final effectiveBotCount = botCount.clamp(0, 10);
    for (int i = 0; i < effectiveBotCount; i++) {
      final sp = findSafeSpawn(me.x, me.y, _random);
      final bKey = botBlades[i % botBlades.length];
      final bAngle = _random.nextDouble() * math.pi * 2;
      final bot = PlayerStateModel(
        id: 'bot_$i',
        name: botNames[i % botNames.length],
        x: sp.dx,
        y: sp.dy,
        facing: 0,
        radius: 25,
        hp: 105,
        maxHp: 105,
        speed: 185,
        kills: 0,
        isBot: true,
        bladeId: bKey,
        bladeState: BladeCombatState.orbit,
        bladeAngle: bAngle,
        bladeSpin: bAngle,
        bladeX: sp.dx + math.cos(bAngle) * 48,
        bladeY: sp.dy + math.sin(bAngle) * 48,
        frozenAngle: 0,
        orbitRadius: 48,
        aiThinkTimer: 0.4 + _random.nextDouble() * 0.6,
      );
      _simPlayers.add(bot);
    }

    // 3. Initial 3 Central Power-Ups (matching prototype)
    _simPowerUps.addAll([
      PowerUpStateModel(
        id: 'pow_1',
        x: kWorldWidth / 2,
        y: kWorldHeight / 2,
        type: PowerType.damage,
        label: '2X GÜÇ',
        color: const Color(0xFFF97316),
      ),
      PowerUpStateModel(
        id: 'pow_2',
        x: kWorldWidth / 2 - 190,
        y: kWorldHeight / 2,
        type: PowerType.heal,
        label: '+45 CAN',
        color: const Color(0xFF22C55E),
      ),
      PowerUpStateModel(
        id: 'pow_3',
        x: kWorldWidth / 2 + 190,
        y: kWorldHeight / 2,
        type: PowerType.shield,
        label: 'KALKAN',
        color: const Color(0xFF38BDF8),
      ),
    ]);

    onConnected?.call();

    // 60Hz Local Simulation Loop for ultra-smooth responsiveness
    _offlineSimTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _tickOfflineSim(0.016);
    });
  }

  void _offlineThrowLocalPlayer() {
    final me = _simPlayers.firstWhere((p) => p.id == _mySessionId, orElse: () => _simPlayers[0]);
    _throwBlade(me);
  }

  void _throwBlade(PlayerStateModel ent) {
    if (ent.bladeState != BladeCombatState.orbit) return;
    ent.bladeState = BladeCombatState.out;
    ent.frozenAngle = ent.bladeAngle;
    ent.bladeDirX = math.cos(ent.frozenAngle);
    ent.bladeDirY = math.sin(ent.frozenAngle);
    ent.bladeX = ent.x + ent.bladeDirX * ent.orbitRadius;
    ent.bladeY = ent.y + ent.bladeDirY * ent.orbitRadius;
    ent.bladeDist = ent.orbitRadius;
    ent.bladeSpin = ent.frozenAngle;
    ent.bladeTrail.clear();
    ent.hitTargets.clear();
  }

  void _tickOfflineSim(double dt) {
    _simMatchTimeElapsed += dt;
    _simMatchTime = _simMatchTimeElapsed.floor();

    // Decay bush rustles
    for (final b in _activeMap.bushes) {
      if (b.rustle > 0) b.rustle = math.max(0.0, b.rustle - dt * 2.5);
    }

    final me = _simPlayers.firstWhere((p) => p.id == _mySessionId, orElse: () => _simPlayers[0]);

    // 1. Local Player Movement & Physics
    _updateEntityPhysics(me, _offlineInputDx, _offlineInputDy, dt);

    // 2. Bots Simulation (Exact Enemy Logic from prototype)
    for (final bot in _simPlayers) {
      if (!bot.isBot) continue;

      _updateBotAI(bot, me, dt);
      _updateEntityPhysics(bot, bot.aiMoveX, bot.aiMoveY, dt);
    }

    // 3. Power-Ups Update & Collection
    _updatePowerUps(dt);

    onStateSync?.call(_simPlayers, _simPowerUps, _simMatchTime);
  }

  // Exact Enemy AI logic from prototype
  void _updateBotAI(PlayerStateModel bot, PlayerStateModel player, double dt) {
    bot.aiThinkTimer -= dt;
    final canSeePlayer = !player.inBush || hypot(player.x - bot.x, player.y - bot.y) < 110;
    final targetX = canSeePlayer ? player.x : kWorldWidth / 2;
    final targetY = canSeePlayer ? player.y : kWorldHeight / 2;

    if (bot.aiThinkTimer <= 0) {
      bot.aiThinkTimer = 0.35 + _random.nextDouble() * 0.45;
      final dx = targetX - bot.x;
      final dy = targetY - bot.y;
      final dist = hypot(dx, dy);
      final effectiveDist = dist > 0.001 ? dist : 1.0;
      final strafe = (_random.nextDouble() - 0.5) * 1.3;
      final baseAngle = math.atan2(dy, dx);

      if (effectiveDist > 230) {
        bot.aiMoveX = math.cos(baseAngle + strafe * 0.4);
        bot.aiMoveY = math.sin(baseAngle + strafe * 0.4);
      } else if (effectiveDist < 145) {
        bot.aiMoveX = -math.cos(baseAngle) + math.cos(baseAngle + math.pi / 2) * strafe;
        bot.aiMoveY = -math.sin(baseAngle) + math.sin(baseAngle + math.pi / 2) * strafe;
      } else {
        bot.aiMoveX = math.cos(baseAngle + math.pi / 2) * (strafe >= 0 ? 1 : -1);
        bot.aiMoveY = math.sin(baseAngle + math.pi / 2) * (strafe >= 0 ? 1 : -1);
      }
    }

    // Bots fire strictly when their orbiting blade aligns with target!
    if (bot.bladeState == BladeCombatState.orbit && canSeePlayer) {
      final dx = player.x - bot.x;
      final dy = player.y - bot.y;
      final dist = hypot(dx, dy);
      if (dist < 310) {
        final desiredAngle = math.atan2(dy, dx);
        final diff = math.atan2(math.sin(bot.bladeAngle - desiredAngle), math.cos(bot.bladeAngle - desiredAngle));
        if (diff.abs() < 0.18) {
          _throwBlade(bot);
        }
      }
    }
  }

  void _updateEntityPhysics(PlayerStateModel ent, double mx, double my, double dt) {
    if (ent.flashTimer > 0) ent.flashTimer = math.max(0, ent.flashTimer - dt);
    if (ent.powerTimer > 0) ent.powerTimer = math.max(0, ent.powerTimer - dt);

    final len = hypot(mx, my);
    if (len > 0.01) {
      final norm = len > 1.0 ? 1.0 / len : 1.0;
      ent.vx = mx * norm * ent.speed;
      ent.vy = my * norm * ent.speed;
      ent.facing = math.atan2(ent.vy, ent.vx);
    } else {
      ent.vx = 0;
      ent.vy = 0;
    }

    final moved = resolveWallCollision(ent.x + ent.vx * dt, ent.y + ent.vy * dt, ent.radius, _activeMap);
    ent.x = moved.x;
    ent.y = moved.y;

    // Bush stealth & rustle
    bool insideBush = false;
    for (final b in _activeMap.bushes) {
      final d = hypot(ent.x - b.x, ent.y - b.y);
      if (d < b.r * 0.85) {
        insideBush = true;
        if (len > 0.1) {
          b.rustle = math.min(1.0, b.rustle + dt * 5.0);
        }
      }
    }
    ent.inBush = insideBush;
    ent.isHidden = insideBush && ent.bladeState == BladeCombatState.orbit;

    // Blade physics & boomerang
    _updateSimBlade(ent, dt);
  }

  void _updateSimBlade(PlayerStateModel ent, double dt) {
    final spec = getBladeSpecById(ent.bladeId);

    if (ent.bladeState == BladeCombatState.orbit) {
      ent.bladeAngle = (ent.bladeAngle + spec.orbitSpeed * dt) % (math.pi * 2);
      ent.bladeX = ent.x + math.cos(ent.bladeAngle) * ent.orbitRadius;
      ent.bladeY = ent.y + math.sin(ent.bladeAngle) * ent.orbitRadius;
      ent.bladeSpin = ent.bladeAngle;
    } else {
      final speed = (ent.isBot ? 560.0 : spec.throwSpeed) * spec.speedMult;
      ent.bladeSpin += 18.0 * dt;

      if (ent.bladeState == BladeCombatState.out) {
        final step = speed * dt;
        ent.bladeX += ent.bladeDirX * step;
        ent.bladeY += ent.bladeDirY * step;
        ent.bladeDist += step;

        if (pointHitsWall(ent.bladeX, ent.bladeY, 12, _activeMap) || ent.bladeDist >= spec.range) {
          ent.bladeState = BladeCombatState.returning;
          onHit?.call(ent.bladeX, ent.bladeY, 0, 'wall', ent.id, '#ffffff');
        }
      } else if (ent.bladeState == BladeCombatState.returning) {
        final slotX = ent.x + math.cos(ent.frozenAngle) * ent.orbitRadius;
        final slotY = ent.y + math.sin(ent.frozenAngle) * ent.orbitRadius;
        final dx = slotX - ent.bladeX;
        final dy = slotY - ent.bladeY;
        final dist = hypot(dx, dy);
        final returnStep = speed * 1.18 * dt;

        if (dist <= returnStep + 10) {
          ent.bladeState = BladeCombatState.orbit;
          ent.bladeAngle = ent.frozenAngle;
          ent.bladeX = slotX;
          ent.bladeY = slotY;
          ent.bladeTrail.clear();
        } else {
          ent.bladeX += (dx / dist) * returnStep;
          ent.bladeY += (dy / dist) * returnStep;
        }
      }

      // Blade trail
      ent.bladeTrail.add(BladeTrailPoint(x: ent.bladeX, y: ent.bladeY, life: 0.16, maxLife: 0.16));
      ent.bladeTrail.removeWhere((t) {
        t.life -= dt;
        return t.life <= 0;
      });

      // Target combat hit checks
      final targets = ent.isBot
          ? _simPlayers.where((p) => p.id != ent.id).toList()
          : _simPlayers.where((p) => p.isBot).toList();

      for (final target in targets) {
        if (target.hp <= 0 || ent.hitTargets.contains(target.id)) continue;
        final hitDist = hypot(ent.bladeX - target.x, ent.bladeY - target.y);
        if (hitDist <= target.radius + 18) {
          ent.hitTargets.add(target.id);

          if (target.shieldHits > 0) {
            target.shieldHits -= 1;
            target.flashTimer = 0.16;
            onHit?.call(target.x, target.y, 0, target.id, ent.id, '#38bdf8');
          } else {
            final mult = ent.powerTimer > 0 ? 1.65 : 1.0;
            final dmg = (spec.damage * mult).roundToDouble();
            target.hp = math.max(0, target.hp - dmg);
            target.flashTimer = 0.16;

            final hexColor = '#${spec.bladeColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
            onHit?.call(target.x, target.y, dmg, target.id, ent.id, hexColor);

            if (target.hp <= 0) {
              if (ent.id == _mySessionId) {
                ent.kills += 1;
                onKill?.call(ent.id, target.id, ent.name, target.name, 35);
              }
              if (!target.isBot) {
                // Player respawn
                final sp = findSafeSpawn(kWorldWidth / 2, kWorldHeight / 2, _random);
                target.x = sp.dx;
                target.y = sp.dy;
                target.hp = target.maxHp;
                target.bladeState = BladeCombatState.orbit;
                target.shieldHits = 1;
                onKill?.call(ent.id, target.id, ent.name, target.name, 0);
              } else {
                // Bot respawn
                final me = _simPlayers.firstWhere((p) => p.id == _mySessionId, orElse: () => _simPlayers[0]);
                final sp = findSafeSpawn(me.x, me.y, _random);
                target.x = sp.dx;
                target.y = sp.dy;
                target.hp = target.maxHp;
                target.bladeState = BladeCombatState.orbit;
              }
            }
          }
        }
      }
    }
  }

  void _updatePowerUps(double dt) {
    for (final p in _simPowerUps) {
      if (!p.active) {
        p.respawn -= dt;
        if (p.respawn <= 0) {
          p.active = true;
        }
        continue;
      }

      for (final ent in _simPlayers) {
        if (hypot(ent.x - p.x, ent.y - p.y) <= ent.radius + 20) {
          p.active = false;
          p.respawn = 9.0;

          if (p.type == PowerType.damage) {
            ent.powerTimer = 7.0;
          } else if (p.type == PowerType.heal) {
            ent.hp = math.min(ent.maxHp, ent.hp + 45);
          } else if (p.type == PowerType.shield) {
            ent.shieldHits = 1;
          }
          onPowerUp?.call(ent.id, p.type, p.x, p.y);
          break;
        }
      }
    }
  }
}
