import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/orbit_blade_game.dart';

class ThrowButtonOverlay extends StatelessWidget {
  final OrbitBladeGame game;

  const ThrowButtonOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 28,
      bottom: 28,
      child: ValueListenableBuilder<bool>(
        valueListenable: game.bladeInOrbitNotifier,
        builder: (context, inOrbit, child) {
          return Opacity(
            opacity: inOrbit ? 1.0 : 0.65,
            child: GestureDetector(
              onTap: inOrbit ? () => game.triggerThrow() : null,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: inOrbit
                      ? const RadialGradient(
                          center: Alignment(-0.3, -0.4),
                          radius: 0.85,
                          colors: [
                            Color(0xFFFDE047),
                            Color(0xFFF97316),
                            Color(0xFFDC2626),
                          ],
                          stops: [0.0, 0.45, 1.0],
                        )
                      : const RadialGradient(
                          center: Alignment(-0.3, -0.4),
                          radius: 0.85,
                          colors: [
                            Color(0xFF94A3B8),
                            Color(0xFF64748B),
                            Color(0xFF334155),
                          ],
                          stops: [0.0, 0.45, 1.0],
                        ),
                  border: Border.all(color: Colors.black, width: 4),
                  boxShadow: [
                    const BoxShadow(color: Colors.black, offset: Offset(0, 6)),
                    if (inOrbit)
                      const BoxShadow(
                        color: Color(0x8CDC2626),
                        blurRadius: 25,
                        offset: Offset(0, 10),
                      ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  'FIRLAT',
                  style: GoogleFonts.lilitaOne(
                    color: Colors.white,
                    fontSize: 19,
                    letterSpacing: 0.6,
                    shadows: const [
                      Shadow(offset: Offset(0, 2), color: Colors.black),
                      Shadow(offset: Offset(-1.5, -1.5), color: Colors.black),
                      Shadow(offset: Offset(1.5, -1.5), color: Colors.black),
                      Shadow(offset: Offset(-1.5, 1.5), color: Colors.black),
                      Shadow(offset: Offset(1.5, 1.5), color: Colors.black),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
