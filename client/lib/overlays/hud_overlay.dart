import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/orbit_blade_game.dart';
import '../models/game_models.dart';

class HudOverlay extends StatelessWidget {
  final OrbitBladeGame game;
  final VoidCallback onOpenMapModal;
  final VoidCallback onOpenShopModal;
  final VoidCallback onToggleTuning;
  final VoidCallback onLeaveMatch;

  const HudOverlay({
    super.key,
    required this.game,
    required this.onOpenMapModal,
    required this.onOpenShopModal,
    required this.onToggleTuning,
    required this.onLeaveMatch,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left Side: Player Status Box & Arena Leaderboard Box
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Player Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xE00F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: Offset(0, 5)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Stats Row
                    Row(
                      children: [
                        Text(
                          'SEN',
                          style: GoogleFonts.lilitaOne(
                            fontSize: 17,
                            color: const Color(0xFF38BDF8),
                            shadows: _brawlShadows(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ValueListenableBuilder<int>(
                          valueListenable: game.goldNotifier,
                          builder: (context, gold, _) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFACC15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.black, width: 2.5),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black, offset: Offset(0, 2)),
                                ],
                              ),
                              child: Text(
                                '$gold ALTIN',
                                style: GoogleFonts.nunito(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 6),
                        ValueListenableBuilder<int>(
                          valueListenable: game.killsNotifier,
                          builder: (context, kills, _) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFB7185),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.black, width: 2.5),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black, offset: Offset(0, 2)),
                                ],
                              ),
                              child: Text(
                                '$kills SKOR',
                                style: GoogleFonts.nunito(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  shadows: const [
                                    Shadow(offset: Offset(0, 1.5), color: Colors.black),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    // HP Bar Outer
                    Container(
                      width: 195,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: Colors.black, width: 2.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: ValueListenableBuilder<double>(
                          valueListenable: game.hpNotifier,
                          builder: (context, ratio, _) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: ratio.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Color(0xFF4ADE80), Color(0xFF16A34A)],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Buffs Row
                    ValueListenableBuilder<String>(
                      valueListenable: game.buffsNotifier,
                      builder: (context, buffs, _) {
                        if (buffs.isEmpty) return const SizedBox.shrink();
                        final buffItems = buffs.split(' • ');
                        return Row(
                          children: buffItems.map((b) {
                            final isDmg = b.contains('HASAR');
                            return Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDmg ? const Color(0xFFEF4444) : const Color(0xFF06B6D4),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.black, width: 2),
                              ),
                              child: Text(
                                b,
                                style: GoogleFonts.nunito(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                  shadows: const [
                                    Shadow(offset: Offset(0, 1), color: Colors.black),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Arena Leaderboard Box
              Container(
                constraints: const BoxConstraints(minWidth: 170),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xE00F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: Offset(0, 5)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ARENA SIRALAMASI',
                      style: GoogleFonts.lilitaOne(
                        fontSize: 13,
                        color: const Color(0xFFFACC15),
                        shadows: _brawlShadows(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ValueListenableBuilder<List<LeaderboardEntry>>(
                      valueListenable: game.leaderboardNotifier,
                      builder: (context, entries, _) {
                        return Column(
                          children: entries.asMap().entries.map((entry) {
                            final i = entry.key;
                            final e = entry.value;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 1.5),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '#${i + 1} ${e.name}',
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: e.isMe ? const Color(0xFF38BDF8) : Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${e.kills}',
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: e.isMe ? const Color(0xFF38BDF8) : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Right Side: Brawl Buttons
          Row(
            children: [
              _buildBrawlButton('AYARLAR', onToggleTuning, BrawlBtnColor.purple),
              const SizedBox(width: 8),
              _buildBrawlButton(
                'HARİTA: ${game.currentMap.name.split(' ')[0].toUpperCase()}',
                onOpenMapModal,
                BrawlBtnColor.green,
              ),
              const SizedBox(width: 8),
              _buildBrawlButton('BIÇAK MARKETİ', onOpenShopModal, BrawlBtnColor.yellow),
              const SizedBox(width: 8),
              _buildBrawlButton('AYRIL', onLeaveMatch, BrawlBtnColor.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBrawlButton(String text, VoidCallback onTap, BrawlBtnColor btnColor) {
    Gradient gradient;
    if (btnColor == BrawlBtnColor.yellow) {
      gradient = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFDE047), Color(0xFFF59E0B)],
      );
    } else if (btnColor == BrawlBtnColor.purple) {
      gradient = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFC084FC), Color(0xFF9333EA)],
      );
    } else if (btnColor == BrawlBtnColor.green) {
      gradient = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF4ADE80), Color(0xFF16A34A)],
      );
    } else {
      gradient = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFB7185), Color(0xFFE11D48)],
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.black, width: 3),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(0, 4)),
          ],
        ),
        child: Text(
          text,
          style: GoogleFonts.lilitaOne(
            color: Colors.white,
            fontSize: 14,
            shadows: _brawlShadows(),
          ),
        ),
      ),
    );
  }

  static const List<Shadow> _kBrawlShadows = [
    Shadow(offset: Offset(0, 2), color: Colors.black),
    Shadow(offset: Offset(-1.5, -1.5), color: Colors.black),
    Shadow(offset: Offset(1.5, -1.5), color: Colors.black),
    Shadow(offset: Offset(-1.5, 1.5), color: Colors.black),
    Shadow(offset: Offset(1.5, 1.5), color: Colors.black),
  ];

  List<Shadow> _brawlShadows() => _kBrawlShadows;
}

enum BrawlBtnColor { yellow, purple, green, red }
