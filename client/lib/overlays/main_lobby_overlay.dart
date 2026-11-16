import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/blade_catalog.dart';
import '../models/map_config.dart';
import '../services/storage_service.dart';

class MainLobbyOverlay extends StatefulWidget {
  final VoidCallback onPlay;
  final VoidCallback onOpenMapModal;
  final VoidCallback onOpenShopModal;

  const MainLobbyOverlay({
    super.key,
    required this.onPlay,
    required this.onOpenMapModal,
    required this.onOpenShopModal,
  });

  @override
  State<MainLobbyOverlay> createState() => _MainLobbyOverlayState();
}

class _MainLobbyOverlayState extends State<MainLobbyOverlay> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _serverController = TextEditingController();
  late int _gold;
  late int _botCount;

  @override
  void initState() {
    super.initState();
    final nick = StorageService.getNickname();
    _nameController.text = nick.isEmpty ? 'SEN' : nick;
    _serverController.text = StorageService.getServerUrl();
    _gold = StorageService.getGold();
    _botCount = StorageService.getBotCount();
  }

  void _updateBotCount(int count) {
    final clamped = count.clamp(0, 10);
    setState(() {
      _botCount = clamped;
    });
    StorageService.setBotCount(clamped);
  }

  void _handleStart() {
    final nick = _nameController.text.trim();
    if (nick.isNotEmpty) {
      StorageService.setNickname(nick);
    }
    final srv = _serverController.text.trim();
    if (srv.isNotEmpty) {
      StorageService.setServerUrl(srv);
    }
    widget.onPlay();
  }

  @override
  Widget build(BuildContext context) {
    final equippedId = StorageService.getEquippedBlade();
    final equippedBlade = getBladeSpecById(equippedId);
    final mapId = StorageService.getSelectedMap();
    final map = getMapConfigById(mapId);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.black, width: 4),
              boxShadow: const [
                BoxShadow(color: Colors.black, offset: Offset(0, 8)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title
                Column(
                  children: [
                    Text(
                      'ORBITBRAWL ARENA',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lilitaOne(
                        fontSize: 28,
                        color: const Color(0xFFFACC15),
                        shadows: _brawlShadows(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Brawl Stars Tarzı 2D Bıçak Arenası',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Gold Badge
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFACC15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black, width: 2.5),
                      boxShadow: const [
                        BoxShadow(color: Colors.black, offset: Offset(0, 3)),
                      ],
                    ),
                    child: Text(
                      '$_gold ALTIN',
                      style: GoogleFonts.nunito(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Nickname Field
                Text(
                  'OYUNCU ADI',
                  style: GoogleFonts.lilitaOne(
                    color: const Color(0xFF38BDF8),
                    fontSize: 13,
                    shadows: _brawlShadows(),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    hintText: 'Adınızı girin',
                    hintStyle: const TextStyle(color: Color(0xFF64748B)),
                    prefixIcon: const Icon(Icons.person, color: Color(0xFF38BDF8), size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.black, width: 3),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 3),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Map & Blade Selectors
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: widget.onOpenMapModal,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.black, width: 3),
                            boxShadow: const [
                              BoxShadow(color: Colors.black, offset: Offset(0, 3)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'HARİTA',
                                style: GoogleFonts.lilitaOne(
                                  fontSize: 11,
                                  color: const Color(0xFF4ADE80),
                                  shadows: _brawlShadows(),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                map.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: widget.onOpenShopModal,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.black, width: 3),
                            boxShadow: const [
                              BoxShadow(color: Colors.black, offset: Offset(0, 3)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BIÇAK',
                                style: GoogleFonts.lilitaOne(
                                  fontSize: 11,
                                  color: const Color(0xFFFACC15),
                                  shadows: _brawlShadows(),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                equippedBlade.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: equippedBlade.bladeColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Bot Count Selector (0 - 10 Bots)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.smart_toy_rounded, color: Color(0xFF38BDF8), size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'BOT SAYISI',
                                style: GoogleFonts.lilitaOne(
                                  fontSize: 12,
                                  color: const Color(0xFF38BDF8),
                                  shadows: _brawlShadows(),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _botCount == 0
                                ? 'BOTSUZ (0)'
                                : _botCount == 10
                                    ? '10 BOT (MAX KAOS)'
                                    : '$_botCount BOT',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: _botCount == 0
                                  ? const Color(0xFF94A3B8)
                                  : _botCount == 10
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFFFACC15),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Minus Button
                          GestureDetector(
                            onTap: _botCount > 0 ? () => _updateBotCount(_botCount - 1) : null,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: _botCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF475569),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.black, width: 2.5),
                                boxShadow: _botCount > 0
                                    ? const [BoxShadow(color: Colors.black, offset: Offset(0, 2))]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: const Icon(Icons.remove, color: Colors.white, size: 20),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Slider
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: const Color(0xFF38BDF8),
                                inactiveTrackColor: const Color(0xFF0F172A),
                                thumbColor: const Color(0xFFFACC15),
                                overlayColor: const Color(0x33FACC15),
                                trackHeight: 8,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                              ),
                              child: Slider(
                                value: _botCount.toDouble(),
                                min: 0,
                                max: 10,
                                divisions: 10,
                                onChanged: (val) => _updateBotCount(val.round()),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Plus Button
                          GestureDetector(
                            onTap: _botCount < 10 ? () => _updateBotCount(_botCount + 1) : null,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: _botCount < 10 ? const Color(0xFF22C55E) : const Color(0xFF475569),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.black, width: 2.5),
                                boxShadow: _botCount < 10
                                    ? const [BoxShadow(color: Colors.black, offset: Offset(0, 2))]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: const Icon(Icons.add, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // Giant Brawl Play Button
                GestureDetector(
                  onTap: _handleStart,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF4ADE80), Color(0xFF16A34A)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black, width: 4),
                      boxShadow: const [
                        BoxShadow(color: Colors.black, offset: Offset(0, 5)),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'SAVAŞA BAŞLA!',
                      style: GoogleFonts.lilitaOne(
                        fontSize: 20,
                        letterSpacing: 0.8,
                        color: Colors.white,
                        shadows: _brawlShadows(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Shadow> _brawlShadows() {
    return const [
      Shadow(offset: Offset(0, 2), color: Colors.black),
      Shadow(offset: Offset(-1.5, -1.5), color: Colors.black),
      Shadow(offset: Offset(1.5, -1.5), color: Colors.black),
      Shadow(offset: Offset(-1.5, 1.5), color: Colors.black),
      Shadow(offset: Offset(1.5, 1.5), color: Colors.black),
    ];
  }
}
