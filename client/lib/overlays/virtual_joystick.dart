import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game/orbit_blade_game.dart';

class VirtualJoystickOverlay extends StatefulWidget {
  final OrbitBladeGame game;

  const VirtualJoystickOverlay({super.key, required this.game});

  @override
  State<VirtualJoystickOverlay> createState() => _VirtualJoystickOverlayState();
}

class _VirtualJoystickOverlayState extends State<VirtualJoystickOverlay> {
  bool _active = false;
  Offset _basePos = const Offset(110, 110);
  Offset _knobPos = const Offset(110, 110);
  final double _radius = 55.0;

  @override
  Widget build(BuildContext context) {
    // Only capture touches on the left 48% of the screen so canvas clicks elsewhere don't block
    return Align(
      alignment: Alignment.bottomLeft,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.48,
        height: MediaQuery.of(context).size.height * 0.70,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (details) {
            setState(() {
              _active = true;
              _basePos = details.localPosition;
              _knobPos = details.localPosition;
            });
            widget.game.setJoystickInput(0, 0);
          },
          onPanUpdate: (details) {
            if (!_active) return;
            final offset = details.localPosition - _basePos;
            final dist = offset.distance;
            final clampedDist = math.min(dist, _radius);
            final angle = math.atan2(offset.dy, offset.dx);

            setState(() {
              _knobPos = _basePos + Offset(math.cos(angle) * clampedDist, math.sin(angle) * clampedDist);
            });

            if (dist > 6.0) {
              final norm = clampedDist / _radius;
              widget.game.setJoystickInput(math.cos(angle) * norm, math.sin(angle) * norm);
            } else {
              widget.game.setJoystickInput(0, 0);
            }
          },
          onPanEnd: (_) => _resetJoystick(),
          onPanCancel: () => _resetJoystick(),
          child: CustomPaint(
            painter: _JoystickPainter(
              active: _active,
              basePos: _active ? _basePos : Offset(90, MediaQuery.of(context).size.height * 0.70 - 90),
              knobPos: _active ? _knobPos : Offset(90, MediaQuery.of(context).size.height * 0.70 - 90),
              radius: _radius,
            ),
          ),
        ),
      ),
    );
  }

  void _resetJoystick() {
    setState(() {
      _active = false;
    });
    widget.game.setJoystickInput(0, 0);
  }
}

class _JoystickPainter extends CustomPainter {
  final bool active;
  final Offset basePos;
  final Offset knobPos;
  final double radius;

  _JoystickPainter({
    required this.active,
    required this.basePos,
    required this.knobPos,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Outer base circle (Brawl Stars Joystick base)
    final baseBgPaint = Paint()
      ..color = const Color(0x730F172A) // rgba(15, 23, 42, 0.45)
      ..style = PaintingStyle.fill;
    final baseBorderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.75)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(basePos, radius, baseBgPaint);
    canvas.drawCircle(basePos, radius, baseBorderPaint);

    // Inner knob (Brawl Stars cyan knob with black border)
    final knobPaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.fill;
    final knobBorder = Paint()
      ..color = Colors.black
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(knobPos, 23.0, knobPaint);
    canvas.drawCircle(knobPos, 23.0, knobBorder);
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) {
    return oldDelegate.active != active ||
        oldDelegate.basePos != basePos ||
        oldDelegate.knobPos != knobPos;
  }
}
