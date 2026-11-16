import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game/orbit_blade_game.dart';
import 'network/network_service.dart';
import 'overlays/hud_overlay.dart';
import 'overlays/main_lobby_overlay.dart';
import 'overlays/map_modal_overlay.dart';
import 'overlays/match_results_overlay.dart';
import 'overlays/shop_modal_overlay.dart';
import 'overlays/throw_button.dart';
import 'overlays/tuning_drawer_overlay.dart';
import 'overlays/virtual_joystick.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force Landscape Orientation for optimal arena gameplay across mobile devices
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Hide system status & navigation bars for immersive fullscreen gameplay
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Initialize Persistent Local Storage
  await StorageService.init();

  runApp(const OrbitBladeApp());
}

class OrbitBladeApp extends StatelessWidget {
  const OrbitBladeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OrbitBlade.io',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF090D16),
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final NetworkService _network = NetworkService();
  OrbitBladeGame? _game;

  bool _inLobby = true;
  bool _showMapModal = false;
  bool _showShopModal = false;
  bool _showTuningDrawer = false;
  bool _showResults = false;

  int _finalRank = 1;
  int _finalKills = 0;
  int _finalGold = 0;

  @override
  void initState() {
    super.initState();
    _game = OrbitBladeGame(network: _network);
  }

  @override
  void dispose() {
    _network.disconnect();
    super.dispose();
  }

  void _startGame() async {
    final nick = StorageService.getNickname();
    final bladeId = StorageService.getEquippedBlade();
    final mapId = StorageService.getSelectedMap();
    final srvUrl = StorageService.getServerUrl();
    final botCount = StorageService.getBotCount();

    // Create Game instance
    final game = OrbitBladeGame(network: _network);
    _game = game;

    // Connect to Server (or start local practice arena)
    await _network.connect(
      serverUrl: srvUrl,
      playerName: nick,
      bladeId: bladeId,
      mapId: mapId,
      botCount: botCount,
    );

    setState(() {
      _inLobby = false;
      _showResults = false;
    });
  }

  void _returnToLobby() {
    _network.disconnect();
    setState(() {
      _inLobby = true;
      _showResults = false;
      _showMapModal = false;
      _showShopModal = false;
      _showTuningDrawer = false;
    });
  }

  void _finishMatch() {
    if (!mounted || _showResults || _game == null) return;
    final kills = _game!.killsNotifier.value;
    final rank = _game!.leaderboardNotifier.value.indexWhere((e) => e.isMe) + 1;
    setState(() {
      _showResults = true;
      _finalRank = rank > 0 ? rank : 1;
      _finalKills = kills;
      _finalGold = kills * 50;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_inLobby) {
      return Scaffold(
        body: Stack(
          children: [
            MainLobbyOverlay(
              onPlay: _startGame,
              onOpenMapModal: () => setState(() => _showMapModal = true),
              onOpenShopModal: () => setState(() => _showShopModal = true),
            ),
            if (_showMapModal && _game != null)
              MapModalOverlay(
                game: _game!,
                onClose: () => setState(() => _showMapModal = false),
              ),
            if (_showShopModal && _game != null)
              ShopModalOverlay(
                game: _game!,
                onClose: () => setState(() => _showShopModal = false),
              ),
          ],
        ),
      );
    }

    if (_game == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8))),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. Flame Game Engine Canvas
          GameWidget(game: _game!),

          // 2. In-Game HUD
          HudOverlay(
            game: _game!,
            onOpenMapModal: () => setState(() => _showMapModal = true),
            onOpenShopModal: () => setState(() => _showShopModal = true),
            onToggleTuning: () => setState(() => _showTuningDrawer = !_showTuningDrawer),
            onLeaveMatch: _finishMatch,
          ),

          // 3. Multi-Touch Floating Virtual Joystick (Left)
          VirtualJoystickOverlay(game: _game!),

          // 4. Large Action Throw Button (Right)
          ThrowButtonOverlay(game: _game!),

          // 5. Live Mechanics Tuning Drawer
          if (_showTuningDrawer)
            TuningDrawerOverlay(
              game: _game!,
              onClose: () => setState(() => _showTuningDrawer = false),
            ),

          // 6. Map Selection Modal
          if (_showMapModal)
            MapModalOverlay(
              game: _game!,
              onClose: () => setState(() => _showMapModal = false),
            ),

          // 7. Blade Shop & Armory Modal
          if (_showShopModal)
            ShopModalOverlay(
              game: _game!,
              onClose: () => setState(() => _showShopModal = false),
            ),

          // 8. Match Results Overlay
          if (_showResults)
            MatchResultsOverlay(
              rank: _finalRank,
              kills: _finalKills,
              goldEarned: _finalGold,
              onPlayAgain: _startGame,
              onLobby: _returnToLobby,
            ),
        ],
      ),
    );
  }
}
