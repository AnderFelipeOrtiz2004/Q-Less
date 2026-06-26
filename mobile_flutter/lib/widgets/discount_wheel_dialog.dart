import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/discount_wheel_service.dart';
import '../services/sound_service.dart';

class DiscountWheelDialog extends StatefulWidget {
  const DiscountWheelDialog({super.key});

  static Future<void> showIfAvailable(BuildContext context) async {
    final canSpin = await DiscountWheelService.canSpin();
    if (!canSpin || !context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DiscountWheelDialog(),
    );
  }

  @override
  State<DiscountWheelDialog> createState() => _DiscountWheelDialogState();
}

class _DiscountWheelDialogState extends State<DiscountWheelDialog>
    with SingleTickerProviderStateMixin {
  static const Color _brandGreen = Color(0xFF56C900);
  final List<int> _prizes = DiscountWheelService.prizes;
  late final AnimationController _controller;
  late Animation<double> _rotationAnimation;
  bool _spinning = false;
  bool _finished = false;
  int? _result;
  double _currentRotation = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 0).animate(_controller)
      ..addListener(() {
        if (mounted) {
          setState(() => _currentRotation = _rotationAnimation.value);
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _spinWheel() async {
    if (_spinning) return;
    final canSpin = await DiscountWheelService.canSpin();
    if (!canSpin) {
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }

    final prize = await DiscountWheelService.spin();
    if (prize < 0) {
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }

    final prizeIndex = _prizes.indexOf(prize);
    final targetIndex = prizeIndex >= 0 ? prizeIndex : 0;
    final segmentAngle = 2 * math.pi / _prizes.length;
    final extraTurns = 5 * 2 * math.pi;
    final endRotation = _currentRotation + extraTurns + (targetIndex * segmentAngle);

    setState(() {
      _spinning = true;
      _finished = false;
      _result = null;
    });

    _rotationAnimation = Tween<double>(
      begin: _currentRotation,
      end: endRotation,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.reset();
    await _controller.forward();

    try {
      await SoundService.playSuccess();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _spinning = false;
      _finished = true;
      _result = prize;
      _currentRotation = endRotation % (2 * math.pi);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ruleta de descuentos',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Gira la ruleta tras tu compra. Puedes volver a girar cada 10 minutos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              width: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: _currentRotation,
                    child: CustomPaint(
                      size: const Size(220, 220),
                      painter: _WheelPainter(prizes: _prizes),
                    ),
                  ),
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: _brandGreen, width: 3),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 8),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.local_offer, color: _brandGreen),
                  ),
                  const Positioned(
                    top: 0,
                    child: Icon(Icons.arrow_drop_down, size: 36, color: Colors.red),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_finished && _result != null)
              Text(
                _result! > 0
                    ? '¡Ganaste $_result% de descuento en tu próxima compra!'
                    : 'Sin premio esta vez. ¡Intenta en 10 minutos!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _result! > 0 ? _brandGreen : Colors.orange[800],
                ),
              ),
            const SizedBox(height: 16),
            if (!_finished)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _spinning ? null : _spinWheel,
                  style: FilledButton.styleFrom(backgroundColor: _brandGreen),
                  child: Text(_spinning ? 'Girando...' : 'Girar ruleta'),
                ),
              ),
            if (_finished)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.prizes});

  final List<int> prizes;
  static const _colors = [
    Color(0xFF56C900),
    Color(0xFF7AD948),
    Color(0xFF3FA300),
    Color(0xFF9BE66A),
    Color(0xFF48B000),
    Color(0xFF6FD13A),
    Color(0xFFBDBDBD),
    Color(0xFF2E8B00),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sweep = 2 * math.pi / prizes.length;

    for (var i = 0; i < prizes.length; i++) {
      final paint = Paint()..color = _colors[i % _colors.length];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * sweep,
        sweep,
        true,
        paint,
      );

      final labelAngle = i * sweep + sweep / 2;
      final label = prizes[i] > 0 ? '${prizes[i]}%' : '0%';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelOffset = Offset(
        center.dx + (radius * 0.62) * math.cos(labelAngle) - textPainter.width / 2,
        center.dy + (radius * 0.62) * math.sin(labelAngle) - textPainter.height / 2,
      );
      textPainter.paint(canvas, labelOffset);
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) => oldDelegate.prizes != prizes;
}
