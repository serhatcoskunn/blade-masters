import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MatchResultsOverlay extends StatelessWidget {
  final int rank;
  final int kills;
  final int goldEarned;
  final VoidCallback onPlayAgain;
  final VoidCallback onLobby;

  const MatchResultsOverlay({
    super.key,
    required this.rank,
    required this.kills,
    required this.goldEarned,
    required this.onPlayAgain,
    required this.onLobby,
  });

  @override
  Widget build(BuildContext context) {
    final isWinner = rank == 1;

    return Container(
      color: const Color(0xD20F172A),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black, width: 4),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isWinner ? '👑 ARENA ŞAMPİYONU!' : 'MAÇ BİTTİ',
              textAlign: TextAlign.center,
              style: GoogleFonts.lilitaOne(
                fontSize: 26,
                color: isWinner ? const Color(0xFFFACC15) : Colors.white,
                shadows: _brawlShadows(),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black, width: 3),
              ),
              child: Column(
                children: [
                  _buildStatRow('Sıralama', '#$rank', isWinner ? const Color(0xFFFACC15) : Colors.white),
                  const Divider(color: Colors.black, thickness: 2, height: 16),
                  _buildStatRow('Toplam Skor', '$kills', const Color(0xFFFB7185)),
                  const Divider(color: Colors.black, thickness: 2, height: 16),
                  _buildStatRow('Kazanılan Altın', '+$goldEarned ALTIN', const Color(0xFF4ADE80)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onLobby,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(0, 4)),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'LOBİYE DÖN',
                        style: GoogleFonts.lilitaOne(
                          color: Colors.white,
                          fontSize: 14,
                          shadows: _brawlShadows(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: onPlayAgain,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4ADE80), Color(0xFF16A34A)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(0, 4)),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'TEKRAR OYNA',
                        style: GoogleFonts.lilitaOne(
                          color: Colors.white,
                          fontSize: 14,
                          shadows: _brawlShadows(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.nunito(
            color: const Color(0xFF94A3B8),
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.lilitaOne(
            color: valueColor,
            fontSize: 16,
            shadows: _brawlShadows(),
          ),
        ),
      ],
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
