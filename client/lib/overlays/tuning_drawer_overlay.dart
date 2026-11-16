import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/orbit_blade_game.dart';

class TuningDrawerOverlay extends StatefulWidget {
  final OrbitBladeGame game;
  final VoidCallback onClose;

  const TuningDrawerOverlay({
    super.key,
    required this.game,
    required this.onClose,
  });

  @override
  State<TuningDrawerOverlay> createState() => _TuningDrawerOverlayState();
}

class _TuningDrawerOverlayState extends State<TuningDrawerOverlay> {
  late double _orbitSpeed;
  late double _throwSpeed;
  late double _range;

  @override
  void initState() {
    super.initState();
    final spec = widget.game.activeSpec;
    _orbitSpeed = spec.orbitSpeed;
    _throwSpeed = spec.throwSpeed;
    _range = spec.range;
  }

  void _syncSpec() {
    final spec = widget.game.activeSpec;
    spec.orbitSpeed = _orbitSpeed;
    spec.throwSpeed = _throwSpeed;
    spec.range = _range;
    widget.game.updateActiveSpec(spec);

    // Sync with server if connected
    widget.game.network.send('tune', {
      'orbitSpeed': _orbitSpeed,
      'throwSpeed': _throwSpeed,
      'range': _range,
    });

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 68,
      right: 12,
      width: 255,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xE00F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black, width: 3),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(0, 5)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CANLI FİZİK AYARLARI',
                  style: GoogleFonts.lilitaOne(
                    color: const Color(0xFFFACC15),
                    fontSize: 14,
                    shadows: const [
                      Shadow(offset: Offset(0, 1.5), color: Colors.black),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildSliderItem(
              'Yörünge Dönüş Hızı',
              _orbitSpeed.toStringAsFixed(1),
              _orbitSpeed,
              1.8,
              5.5,
              (v) {
                _orbitSpeed = v;
                _syncSpec();
              },
            ),
            _buildSliderItem(
              'Bıçak Fırlatma Hızı',
              _throwSpeed.toInt().toString(),
              _throwSpeed,
              450,
              950,
              (v) {
                _throwSpeed = v;
                _syncSpec();
              },
            ),
            _buildSliderItem(
              'Fırlatma Menzili',
              _range.toInt().toString(),
              _range,
              200,
              500,
              (v) {
                _range = v;
                _syncSpec();
              },
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderItem(
    String label,
    String valueStr,
    double val,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    bool isLast = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.nunito(
                color: const Color(0xFF94A3B8),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.black, width: 1.5),
              ),
              child: Text(
                valueStr,
                style: GoogleFonts.lilitaOne(
                  color: const Color(0xFF38BDF8),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 5,
            activeTrackColor: const Color(0xFF38BDF8),
            inactiveTrackColor: const Color(0xFF334155),
            thumbColor: const Color(0xFFFACC15),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: SliderComponentShape.noOverlay,
          ),
          child: Slider(
            value: val.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        if (!isLast) const SizedBox(height: 6),
      ],
    );
  }
}
