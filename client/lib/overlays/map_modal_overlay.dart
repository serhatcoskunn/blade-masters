import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/orbit_blade_game.dart';
import '../models/map_config.dart';
import '../services/storage_service.dart';

class MapModalOverlay extends StatelessWidget {
  final OrbitBladeGame game;
  final VoidCallback onClose;

  const MapModalOverlay({
    super.key,
    required this.game,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xD20F172A),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 460),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black, width: 4),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(0, 8)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ARENA HARİTASI SEÇ',
                  style: GoogleFonts.lilitaOne(
                    fontSize: 22,
                    color: const Color(0xFFFACC15),
                    shadows: _brawlShadows(),
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: Colors.black, width: 3),
                      boxShadow: const [
                        BoxShadow(color: Colors.black, offset: Offset(0, 4)),
                      ],
                    ),
                    child: Text(
                      'KAPAT',
                      style: GoogleFonts.lilitaOne(
                        color: Colors.white,
                        fontSize: 14,
                        shadows: _brawlShadows(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: kMapConfigs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final map = kMapConfigs[index];
                  final isSelected = game.currentMap.id == map.id;

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF172554) : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFFACC15) : Colors.black,
                        width: 3,
                      ),
                      boxShadow: const [
                        BoxShadow(color: Colors.black, offset: Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                map.name,
                                style: GoogleFonts.lilitaOne(
                                  fontSize: 18,
                                  color: const Color(0xFF4ADE80),
                                  shadows: _brawlShadows(),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                map.desc,
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  color: const Color(0xFFCBD5E1),
                                  fontWeight: FontWeight.w700,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        GestureDetector(
                          onTap: () {
                            StorageService.setSelectedMap(map.id);
                            game.switchMap(map.id);
                            onClose();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(
                                      colors: [Color(0xFF4ADE80), Color(0xFF16A34A)],
                                    )
                                  : const LinearGradient(
                                      colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                                    ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black, width: 2.5),
                              boxShadow: const [
                                BoxShadow(color: Colors.black, offset: Offset(0, 3)),
                              ],
                            ),
                            child: Text(
                              isSelected ? 'AKTİF HARİTA' : 'HARİTAYI SEÇ',
                              style: GoogleFonts.lilitaOne(
                                color: Colors.white,
                                fontSize: 13,
                                shadows: _brawlShadows(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
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
