import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/orbit_blade_game.dart';
import '../models/blade_catalog.dart';
import '../services/storage_service.dart';

class ShopModalOverlay extends StatefulWidget {
  final OrbitBladeGame game;
  final VoidCallback onClose;

  const ShopModalOverlay({
    super.key,
    required this.game,
    required this.onClose,
  });

  @override
  State<ShopModalOverlay> createState() => _ShopModalOverlayState();
}

class _ShopModalOverlayState extends State<ShopModalOverlay> {
  late List<String> _ownedBlades;
  late String _equippedBladeId;
  late int _gold;

  @override
  void initState() {
    super.initState();
    _ownedBlades = StorageService.getOwnedBlades();
    _equippedBladeId = StorageService.getEquippedBlade();
    _gold = StorageService.getGold();
  }

  void _handleAction(BladeSpec blade) async {
    if (_ownedBlades.contains(blade.id)) {
      await StorageService.setEquippedBlade(blade.id);
      widget.game.updateActiveSpec(blade);
      setState(() {
        _equippedBladeId = blade.id;
      });
    } else {
      if (_gold >= blade.price) {
        final success = await StorageService.spendGold(blade.price);
        if (success) {
          await StorageService.addOwnedBlade(blade.id);
          await StorageService.setEquippedBlade(blade.id);
          widget.game.updateActiveSpec(blade);
          widget.game.goldNotifier.value = StorageService.getGold();

          setState(() {
            _gold = StorageService.getGold();
            _ownedBlades = StorageService.getOwnedBlades();
            _equippedBladeId = blade.id;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xD20F172A),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 480),
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
            // Modal Top
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'BIÇAK DÜKKANI',
                      style: GoogleFonts.lilitaOne(
                        fontSize: 22,
                        color: const Color(0xFFFACC15),
                        shadows: _brawlShadows(),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFACC15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black, width: 2.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Text(
                        '$_gold ALTIN',
                        style: GoogleFonts.nunito(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: widget.onClose,
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
            // Cards Grid
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.55,
                ),
                itemCount: kBladeCatalog.length,
                itemBuilder: (context, index) {
                  final blade = kBladeCatalog[index];
                  final isOwned = _ownedBlades.contains(blade.id);
                  final isEquipped = _equippedBladeId == blade.id;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isEquipped ? const Color(0xFF172554) : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isEquipped ? const Color(0xFFFACC15) : Colors.black,
                        width: 3,
                      ),
                      boxShadow: const [
                        BoxShadow(color: Colors.black, offset: Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              blade.name,
                              style: GoogleFonts.lilitaOne(
                                color: blade.bladeColor,
                                fontSize: 16,
                                shadows: _brawlShadows(),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Hasar: ${blade.damage.toInt()} • Menzil: ${blade.range.toInt()} • Dönüş: ${blade.orbitSpeed.toStringAsFixed(1)}',
                              style: GoogleFonts.nunito(
                                color: const Color(0xFFCBD5E1),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => _handleAction(blade),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            decoration: BoxDecoration(
                              gradient: isEquipped
                                  ? const LinearGradient(
                                      colors: [Color(0xFFFDE047), Color(0xFFF59E0B)],
                                    )
                                  : (isOwned
                                      ? const LinearGradient(
                                          colors: [Color(0xFF4ADE80), Color(0xFF16A34A)],
                                        )
                                      : const LinearGradient(
                                          colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                                        )),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(color: Colors.black, width: 2.5),
                              boxShadow: const [
                                BoxShadow(color: Colors.black, offset: Offset(0, 3)),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              isEquipped
                                  ? 'KUŞANILDI'
                                  : (isOwned ? 'KUŞAN' : '${blade.price} ALTIN AL'),
                              style: GoogleFonts.lilitaOne(
                                color: isEquipped ? Colors.black : Colors.white,
                                fontSize: 13,
                                shadows: isEquipped ? null : _brawlShadows(),
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

  static const List<Shadow> _kBrawlShadows = [
    Shadow(offset: Offset(0, 2), color: Colors.black),
    Shadow(offset: Offset(-1.5, -1.5), color: Colors.black),
    Shadow(offset: Offset(1.5, -1.5), color: Colors.black),
    Shadow(offset: Offset(-1.5, 1.5), color: Colors.black),
    Shadow(offset: Offset(1.5, 1.5), color: Colors.black),
  ];

  List<Shadow> _brawlShadows() => _kBrawlShadows;
}
