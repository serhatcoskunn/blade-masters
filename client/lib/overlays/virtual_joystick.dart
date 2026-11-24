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
  final _JoystickNotifier _joystick = _JoystickNotifier();
  final double _radius = 55.0;

  @override
  void dispose() {
    _joystick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final areaW = screenSize.width * 0.48;
    final areaH = screenSize.height * 0.70;
    _joystick.defaultPos = Offset(90, areaH - 90);

    // Only capture touches on the left 48% of the screen so canvas clicks elsewhere don't block
    return Align(
      alignment: Alignment.bottomLeft,
      child: SizedBox(
        width: areaW,
        height: areaH,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (details) {
            _joystick.start(details.localPosition);
            widget.game.setJoystickInput(0, 0);
          },
          onPanUpdate: (details) {
            if (!_joystick.active) return;
            final offset = details.localPosition - _joystick.basePos;
            final dist = offset.distance;
            final clampedDist = math.min(dist, _radius);
            final angle = math.atan2(offset.dy, offset.dx);

            _joystick.updateKnob(
              _joystick.basePos + Offset(math.cos(angle) * clampedDist, math.sin(angle) * clampedDist),
            );

            if (dist > 6.0) {
              final norm = clampedDist / _radius;
              widget.game.setJoystickInput(math.cos(angle) * norm, math.sin(angle) * norm);
            } else {
              widget.game.setJoystickInput(0, 0);
            }
          },
          onPanEnd: (_) => _resetJoystick(),
          onPanCancel: () => _resetJoystick(),
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _JoystickPainter(
                state: _joystick,
                radius: _radius,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _resetJoystick() {
    _joystick.reset();
    widget.game.setJoystickInput(0, 0);
  }
}

class _JoystickNotifier extends ChangeNotifier {
  bool active = false;
  Offset basePos = const Offset(110, 110);
  Offset knobPos = const Offset(110, 110);
  Offset defaultPos = const Offset(90, 200);

  void start(Offset pos) {
    active = true;
    basePos = pos;
    knobPos = pos;
    notifyListeners();
  }

  void updateKnob(Offset pos) {
    knobPos = pos;
    notifyListeners();
  }

  void reset() {
    if (!active) return;
    active = false;
    notifyListeners();
  }
}

class _JoystickPainter extends CustomPainter {
  final _JoystickNotifier state;
  final double radius;

  static final Paint _baseBgPaint = Paint()
    ..color = const Color(0x730F172A)
    ..style = PaintingStyle.fill;
  static final Paint _baseBorderPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.75)
    ..strokeWidth = 3.5
    ..style = PaintingStyle.stroke;
  static final Paint _knobPaint = Paint()
    ..color = const Color(0xFF38BDF8)
    ..style = PaintingStyle.fill;
  static final Paint _knobBorder = Paint()
    ..color = Colors.black
    ..strokeWidth = 3.5
    ..style = PaintingStyle.stroke;

  _JoystickPainter({
    required this.state,
    required this.radius,
  }) : super(repaint: state);

  @override
  void paint(Canvas canvas, Size size) {
    final base = state.active ? state.basePos : state.defaultPos;
    final knob = state.active ? state.knobPos : state.defaultPos;

    canvas.drawCircle(base, radius, _baseBgPaint);
    canvas.drawCircle(base, radius, _baseBorderPaint);

    canvas.drawCircle(knob, 23.0, _knobPaint);
    canvas.drawCircle(knob, 23.0, _knobBorder);
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) {
    return oldDelegate.radius != radius || oldDelegate.state != state;
  }
}
