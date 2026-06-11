import 'package:flutter/material.dart';
import 'spin_the_wheel.dart'; 
import 'blitz_poll_page.dart';


class QuickDecisionPage extends StatefulWidget {
  const QuickDecisionPage({super.key});

  @override
  State<QuickDecisionPage> createState() => _QuickDecisionPageState();
}

class _QuickDecisionPageState extends State<QuickDecisionPage> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Quick Decision',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                'Decide in seconds',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 24),
              // Spin the Wheel Option
              _buildOptionCard(
                title: 'Spin the Wheel',
                description: "Can't decide? Let the app\nrandomly pick for you.",
                icon: _buildWheelIcon(),
                onTap: () {
                  // Navigate to Spin the Wheel screen
                  _navigateToSpinWheel(context);
                },
              ),
              const SizedBox(height: 16),
              // Blitz Poll Option
              _buildOptionCard(
                title: 'Blitz Poll',
                description: 'Quick yes/No vote to get a fast\ndecision.',
                icon: _buildBlitzPollIcon(),
                onTap: () {
                  // Navigate to Blitz Poll screen
                  _navigateToBlitzPoll(context);
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String description,
    required Widget icon,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            SizedBox(
              width: 80,
              height: 80,
              child: icon,
            ),
            const SizedBox(width: 16),
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWheelIcon() {
    return CustomPaint(
      painter: WheelPainter(),
      size: const Size(64, 64),
    );
  }

  Widget _buildBlitzPollIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Yes Button
        Positioned(
          left: 0,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Center(
              child: Text(
                '✓',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        // No Button
        Positioned(
          right: 0,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFE53935),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Center(
              child: Text(
                '✕',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToSpinWheel(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SpinWheelPage()),
    );
  }

  void _navigateToBlitzPoll(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BlitzPollPage()),
    );
  }
}

class WheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Define colors for wheel segments
    final colors = [
      const Color(0xFF1976D2), // Blue
      const Color(0xFF0097A7), // Cyan
      const Color(0xFF00796B), // Teal
      const Color(0xFF7CB342), // Light Green
      const Color(0xFFFBC02D), // Yellow
      const Color(0xFFF57C00), // Orange
      const Color(0xFFD32F2F), // Red
      const Color(0xFF7B1FA2), // Purple
    ];

    // Draw wheel segments
    for (int i = 0; i < colors.length; i++) {
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.fill;

      final startAngle = (i / colors.length) * 2 * 3.14159;
      final sweepAngle = (1 / colors.length) * 2 * 3.14159;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
    }

    // Draw center circle
    canvas.drawCircle(
      center,
      radius * 0.25,
      Paint()..color = Colors.white,
    );

    // Draw center dot
    canvas.drawCircle(
      center,
      radius * 0.1,
      Paint()..color = Colors.grey[400]!,
    );
  }

  @override
  bool shouldRepaint(WheelPainter oldDelegate) => false;
}