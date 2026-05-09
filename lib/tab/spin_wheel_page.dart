import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:confetti/confetti.dart';

class SpinWheelPage extends StatefulWidget {
  const SpinWheelPage({super.key});

  @override
  State<SpinWheelPage> createState() => _SpinWheelPageState();
}

class WheelOption {
  final String name;
  final IconData icon;

  WheelOption({required this.name, required this.icon});
}

const List<Color> wheelColors = [
  Color(0xFF0080FF),
  Color(0xFFD500F9),
  Color(0xFFFF1493),
  Color(0xFFFF4500),
  Color(0xFFFFA500),
  Color(0xFFFFEA00),
  Color(0xFF00D084),
  Color(0xFF00B8E6),
];

class _SpinWheelPageState extends State<SpinWheelPage>
    with TickerProviderStateMixin {
  late AnimationController _wheelController;
  late Animation<double> _turnsAnimation;
  late ConfettiController _confettiController;

  late List<WheelOption> options;
  String? selectedOption;
  Color selectedColor = wheelColors[0];
  bool isSpinning = false;

  @override
  void initState() {
    super.initState();

    _wheelController = AnimationController(
      duration: const Duration(milliseconds: 5200),
      vsync: this,
    );

    _turnsAnimation = const AlwaysStoppedAnimation(0);

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );

    options = [
      WheelOption(name: 'Jollibee', icon: Icons.fastfood),
      WheelOption(name: 'McDonalds', icon: Icons.restaurant),
      WheelOption(name: 'Mang Inasal', icon: Icons.local_dining),
      WheelOption(name: 'S & R', icon: Icons.shopping_bag),
      WheelOption(name: 'Chowking', icon: Icons.rice_bowl),
      WheelOption(name: 'KFC', icon: Icons.local_fire_department),
      WheelOption(name: 'Pizza Hut', icon: Icons.local_pizza),
      WheelOption(name: 'Starbucks', icon: Icons.coffee),
    ];
  }

  @override
  void dispose() {
    _wheelController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Path _drawFirework(Size size) {
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final int points = 6;
    for (int i = 0; i < points * 2; i++) {
      final double angle = (math.pi / points) * i;
      final double radius = i.isEven ? size.width / 2 : size.width / 4;
      final Offset point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  void _spinWheel() {
    if (isSpinning) return;

    setState(() {
      isSpinning = true;
    });

    final random = math.Random();
    final targetDegrees = random.nextDouble() * 360;
    final targetTurns = 5 + targetDegrees / 360;

    final selectedIndex =
        ((360 - targetDegrees) / (360 / options.length)).floor() %
            options.length;

    _turnsAnimation = Tween<double>(
      begin: 0,
      end: targetTurns,
    ).animate(
      CurvedAnimation(
        parent: _wheelController,
        curve: Curves.decelerate,
      ),
    );

    _wheelController.forward(from: 0).then((_) {
      setState(() {
        selectedOption = options[selectedIndex].name;
        selectedColor = wheelColors[selectedIndex % wheelColors.length];
        isSpinning = false;
      });

      _confettiController.play();
      _showResultDialog(selectedOption!);
    });
  }

  void _showResultDialog(String result) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                Align(
                alignment: Alignment.topRight,
                child: InkWell(
                  borderRadius: BorderRadius.circular(50),
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 24),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Result',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: selectedColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    result,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Remove the option from the wheel and close dialog
                        setState(() {
                          final removeIndex = options.indexWhere((o) => o.name == result);
                          if (removeIndex != -1) {
                            options.removeAt(removeIndex);
                          }
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Remove',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F8FB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Spin the Wheel',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Let the wheel decide your next food trip.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 360,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    child: ConfettiWidget(
                      confettiController: _confettiController,
                      blastDirectionality: BlastDirectionality.explosive,
                      emissionFrequency: 0.05,
                      numberOfParticles: 15,
                      minBlastForce: 6,
                      maxBlastForce: 16,
                      particleDrag: 0.04,
                      gravity: 0.25,
                      shouldLoop: false,
                      colors: wheelColors,
                      createParticlePath: _drawFirework,
                      child: const SizedBox(width: 100, height: 100),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: ConfettiWidget(
                      confettiController: _confettiController,
                      blastDirectionality: BlastDirectionality.explosive,
                      emissionFrequency: 0.05,
                      numberOfParticles: 15,
                      minBlastForce: 6,
                      maxBlastForce: 16,
                      particleDrag: 0.04,
                      gravity: 0.25,
                      shouldLoop: false,
                      colors: wheelColors,
                      createParticlePath: _drawFirework,
                      child: const SizedBox(width: 100, height: 100),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: ConfettiWidget(
                      confettiController: _confettiController,
                      blastDirectionality: BlastDirectionality.explosive,
                      emissionFrequency: 0.05,
                      numberOfParticles: 15,
                      minBlastForce: 6,
                      maxBlastForce: 16,
                      particleDrag: 0.04,
                      gravity: 0.25,
                      shouldLoop: false,
                      colors: wheelColors,
                      createParticlePath: _drawFirework,
                      child: const SizedBox(width: 100, height: 100),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: ConfettiWidget(
                      confettiController: _confettiController,
                      blastDirectionality: BlastDirectionality.explosive,
                      emissionFrequency: 0.05,
                      numberOfParticles: 15,
                      minBlastForce: 6,
                      maxBlastForce: 16,
                      particleDrag: 0.04,
                      gravity: 0.25,
                      shouldLoop: false,
                      colors: wheelColors,
                      createParticlePath: _drawFirework,
                      child: const SizedBox(width: 100, height: 100),
                    ),
                  ),
                  Positioned(
                    top: 18,
                    child: GestureDetector(
                      onTap: isSpinning ? null : _spinWheel,
                      child: SizedBox(
                        width: 320,
                        height: 340,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            RotationTransition(
                              turns: _turnsAnimation,
                              child: CustomPaint(
                                painter: WheelPainter(options: options),
                                size: const Size(280, 280),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              child: CustomPaint(
                                painter: PointerPainter(),
                                size: const Size(46, 38),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSpinning ? null : _spinWheel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5B335),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isSpinning ? 'Spinning...' : 'Spin Now',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Options',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),

                  ...List.generate(options.length, (index) {
                    final option = options[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F8FB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200, width: 1),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18, color: Color(0xFFF5B335)),
                            onPressed: () => _editOption(index),
                            constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
                            padding: EdgeInsets.zero,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                            onPressed: () => _deleteOption(index),
                            constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          label: 'Add',
                          icon: Icons.add,
                          onTap: _addImage,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildActionButton(
                          label: 'Shuffle',
                          icon: Icons.shuffle,
                          onTap: _shuffleOptions,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildActionButton(
                          label: 'Sort',
                          icon: Icons.sort,
                          onTap: _sortOptions,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFF5B335),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.black),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addImage() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Add Option'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'Enter option name',
                  filled: true,
                  fillColor: const Color(0xFFF8F8FB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();

                if (name.isNotEmpty) {
                  setState(() {
                    options.add(
                      WheelOption(
                        name: name,
                        icon: Icons.local_dining,
                      ),
                    );
                  });

                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA41E8E),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _shuffleOptions() {
    setState(() {
      options.shuffle();
    });
  }

  void _sortOptions() {
    setState(() {
      options.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    });
  }

  void _editOption(int index) {
    final nameController = TextEditingController(text: options[index].name);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Edit Option'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'Enter option name',
                  filled: true,
                  fillColor: const Color(0xFFF8F8FB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();

                if (name.isNotEmpty) {
                  setState(() {
                    options[index] = WheelOption(
                      name: name,
                      icon: options[index].icon,
                    );
                  });

                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA41E8E),
                foregroundColor: Colors.white,
              ),
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _deleteOption(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Delete Option?'),
        content: Text(
          'Are you sure you want to delete "${options[index].name}"?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                options.removeAt(index);
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class WheelPainter extends CustomPainter {
  final List<WheelOption> options;

  WheelPainter({required this.options});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final colors = [
      const Color(0xFF0080FF), // Bright Blue
      const Color(0xFFD500F9), // Magenta
      const Color(0xFFFF1493), // Hot Pink
      const Color(0xFFFF4500), // Red-Orange
      const Color(0xFFFFA500), // Orange
      const Color(0xFFFFEA00), // Bright Yellow
      const Color(0xFF00D084), // Bright Green
      const Color(0xFF00B8E6), // Cyan
    ];

    canvas.drawCircle(
      center.translate(0, 8),
      radius - 8,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    canvas.drawCircle(
      center,
      radius - 2,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12,
    );

    for (int i = 0; i < options.length; i++) {
      final startAngle = (i / options.length) * 2 * math.pi - math.pi / 2;
      final sweepAngle = (1 / options.length) * 2 * math.pi;

      final segmentPaint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 8),
        startAngle,
        sweepAngle,
        true,
        segmentPaint,
      );

      final dividerPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawLine(
        center,
        Offset(
          center.dx + (radius - 10) * math.cos(startAngle),
          center.dy + (radius - 10) * math.sin(startAngle),
        ),
        dividerPaint,
      );

      final iconAngle = startAngle + sweepAngle / 2;

      final textRadius = radius * 0.72;
      final textX = center.dx + textRadius * math.cos(iconAngle);
      final textY = center.dy + textRadius * math.sin(iconAngle);

      final textPainter = TextPainter(
        text: TextSpan(
          text: options[i].name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );

      textPainter.layout(maxWidth: 80);

      canvas.save();
      canvas.translate(textX, textY);
      canvas.rotate(iconAngle + math.pi / 2);
      textPainter.paint(
        canvas,
        Offset(
          -textPainter.width / 2,
          -textPainter.height / 2,
        ),
      );
      canvas.restore();
    }

    canvas.drawCircle(
      center,
      radius * 0.19,
      Paint()..color = Colors.white,
    );

    canvas.drawCircle(
      center,
      radius * 0.19,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(WheelPainter oldDelegate) {
    return oldDelegate.options != options;
  }
}

class PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final arrowPaint = Paint()
      ..color = const Color(0xFFFFC107)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(4, 6)
      ..quadraticBezierTo(size.width / 2, 0, size.width - 4, 6)
      ..close();

    canvas.drawPath(path.shift(const Offset(0, 3)), shadowPaint);
    canvas.drawPath(path, arrowPaint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(PointerPainter oldDelegate) => false;
}