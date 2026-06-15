import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../services/quick_decision_service.dart';

class SpinWheelPage extends StatefulWidget {
  const SpinWheelPage({super.key});

  @override
  State<SpinWheelPage> createState() => _SpinWheelPageState();
}

class WheelOption {
  final int? id;
  final String name;
  final IconData icon;
  final String? color;

  WheelOption({this.id, required this.name, required this.icon, this.color});
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
  int? selectedOptionIndex;
  Color selectedColor = wheelColors[0];
  bool isSpinning = false;
  bool isLoading = true;
  int? currentWheelId;

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

    options = [];
    _loadWheels();
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

  Future<void> _loadWheels() async {
    try {
      final wheels = await QuickDecisionService.getWheels();
      if (!mounted) return;
      if (wheels.isNotEmpty) {
        final wheel = wheels.first as Map<String, dynamic>;
        currentWheelId = wheel['id'] as int?;
        final loadedOptions = (wheel['options'] as List<dynamic>? ?? []).map((item) {
          final option = item as Map<String, dynamic>;
          return WheelOption(
            id: option['id'] as int?,
            name: option['option_name']?.toString() ?? '',
            icon: Icons.local_dining,
            color: option['color']?.toString(),
          );
        }).toList();
        setState(() {
          options = loadedOptions;
          isLoading = false;
        });
        return;
      }

      final created = await QuickDecisionService.createWheel('My Wheel', [
        {'option_name': 'Jollibee', 'color': '#0080FF'},
        {'option_name': 'McDonalds', 'color': '#D500F9'},
        {'option_name': 'Mang Inasal', 'color': '#FF1493'},
      ]);
      if (!mounted) return;
      final wheel = created['wheel'] as Map<String, dynamic>? ?? {};
      currentWheelId = wheel['id'] as int?;
      final loadedOptions = (wheel['options'] as List<dynamic>? ?? []).map((item) {
        final option = item as Map<String, dynamic>;
        return WheelOption(id: option['id'] as int?, name: option['option_name']?.toString() ?? '', icon: Icons.local_dining, color: option['color']?.toString());
      }).toList();
      setState(() {
        options = loadedOptions;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to load wheel: $e')));
      setState(() => isLoading = false);
    }
  }

  Future<void> _saveWheel() async {
    if (currentWheelId == null) {
      return;
    }

    try {
      final result = await QuickDecisionService.updateWheel(
        currentWheelId!,
        'My Wheel',
        options.map((option) => {
          'id': option.id,
          'option_name': option.name,
          'color': option.color ?? wheelColors[options.indexOf(option) % wheelColors.length].toARGB32().toRadixString(16),
        }).toList(),
      );
      if (result['success'] == true) {
        final updatedWheel = result['wheel'] as Map<String, dynamic>? ?? {};
        final loadedOptions = (updatedWheel['options'] as List<dynamic>? ?? []).map((item) {
          final option = item as Map<String, dynamic>;
          return WheelOption(id: option['id'] as int?, name: option['option_name']?.toString() ?? '', icon: Icons.local_dining, color: option['color']?.toString());
        }).toList();
        if (mounted) {
          setState(() => options = loadedOptions);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to save wheel: $e')));
      }
    }
  }

  Future<void> _spinWheel() async {
    if (isSpinning || currentWheelId == null || options.isEmpty) return;

    try {
      await QuickDecisionService.spinWheel(currentWheelId!);
      if (!mounted) return;

      _wheelController.stop();
      _wheelController.reset();

      final random = math.Random();
      final targetTurns = 5 + random.nextDouble() * 3;
      final spinAnimation = Tween<double>(begin: 0, end: targetTurns).animate(
        CurvedAnimation(parent: _wheelController, curve: Curves.easeOutCubic),
      );

      if (!mounted) return;
      setState(() {
        _turnsAnimation = spinAnimation;
        isSpinning = true;
      });

      await _wheelController.forward(from: 0);

      final finalWinnerIndex = _winnerIndexFromFinalRotation(targetTurns);
      final winner = options[finalWinnerIndex];

      if (!mounted) return;
      setState(() {
        selectedOption = winner.name;
        selectedOptionIndex = finalWinnerIndex;
        selectedColor = wheelColors[finalWinnerIndex % wheelColors.length];
        isSpinning = false;
      });

      _confettiController.play();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      await _showWinnerDialog(winner);
    } catch (e) {
      if (mounted) {
        setState(() => isSpinning = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to spin wheel: $e')));
      }
    }
  }

  int _winnerIndexFromFinalRotation(double totalTurns) {
    final segmentCount = options.length;
    final totalRadians = totalTurns * 2 * math.pi;
    final pointerAngle = _normalizeAngle(-math.pi / 2);

    for (int index = 0; index < segmentCount; index++) {
      final start = _normalizeAngle((-math.pi / 2 + (index / segmentCount) * 2 * math.pi) + totalRadians);
      final end = _normalizeAngle(start + (2 * math.pi / segmentCount));

      if (_angleInRange(pointerAngle, start, end)) {
        return index;
      }
    }

    return 0;
  }

  double _normalizeAngle(double angle) {
    final normalized = angle % (2 * math.pi);
    return normalized < 0 ? normalized + 2 * math.pi : normalized;
  }

  bool _angleInRange(double angle, double start, double end) {
    if (start < end) {
      return angle >= start && angle < end;
    }
    return angle >= start || angle < end;
  }

  Future<void> _removeWinnerOption(WheelOption winner) async {
    if (!mounted) return;

    try {
      if (winner.id != null) {
        final result = await QuickDecisionService.deleteWheelOption(winner.id!);
        if (!mounted) return;
        if (result['success'] == true) {
          await _loadWheels();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${winner.name} was removed and saved.')));
          return;
        }
      }

      if (!mounted) return;
      setState(() {
        options.removeWhere((option) => option.id == winner.id || option.name == winner.name);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${winner.name} was removed locally.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to remove winner: $e')));
      }
    }
  }


  Future<void> _showWinnerDialog(WheelOption winner) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Material(
              color: Colors.transparent,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.92, end: 1),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 380),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFEAEAEA)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, 18)),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.workspace_premium_outlined, color: Color(0xFFB7791F), size: 28),
                      ),
                      const SizedBox(height: 14),
                      const Text('Winner', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                      const SizedBox(height: 8),
                      Text(
                        winner.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await _removeWinnerOption(winner);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF111827),
                                side: const BorderSide(color: Color(0xFFE5E7EB)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Close'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await _removeWinnerOption(winner);
                                if (mounted && options.isNotEmpty) {
                                  await _spinWheel();
                                }
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFF5B335),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                              ),
                              child: const Text('Spin Again'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1F2937)),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFF8FAFC),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFFFE082), width: 1),
                        ),
                        child: const Text(
                          'Smart choice, made simple',
                          style: TextStyle(
                            color: Color(0xFFB7791F),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFEAEAEA)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 24,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Spin the Wheel',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF111827),
                            height: 1.1,
                          ) ?? const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Can\'t decide? Let the wheel choose for you.',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildWheelCard(),
                      const SizedBox(height: 18),
                      _buildWinnerCard(),
                      const SizedBox(height: 18),
                      _buildSpinButton(),
                      const SizedBox(height: 18),
                      _buildOptionsCard(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWheelCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFEAEAEA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Wheel',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Text(
                  options.isEmpty ? 'Ready' : '${options.length} choices',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563), fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: Center(
              child: SizedBox(
                height: 380,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: ConfettiWidget(
                        confettiController: _confettiController,
                        blastDirectionality: BlastDirectionality.explosive,
                        emissionFrequency: 0.04,
                        numberOfParticles: 16,
                        minBlastForce: 8,
                        maxBlastForce: 18,
                        particleDrag: 0.03,
                        gravity: 0.2,
                        shouldLoop: false,
                        colors: wheelColors,
                        createParticlePath: _drawFirework,
                        child: const SizedBox.expand(),
                      ),
                    ),
                    GestureDetector(
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
                                size: const Size(300, 300),
                              ),
                            ),
                            Positioned(top: 0, child: CustomPaint(painter: PointerPainter(), size: const Size(50, 42))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _buildWinnerCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEAEAEA)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 10)),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: selectedOption == null
            ? Container(
                key: const ValueKey('no-winner'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Text(
                  'No winner yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
                ),
              )
            : Container(
                key: ValueKey('winner-$selectedOption'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFFE082)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium_outlined, color: Color(0xFFB7791F)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Winner: $selectedOption',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSpinButton() {
    return SizedBox(
      width: double.infinity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: isSpinning
              ? [BoxShadow(color: const Color(0xFFF5B335).withValues(alpha: 0.30), blurRadius: 18, spreadRadius: 1)]
              : [const BoxShadow(color: Colors.transparent, blurRadius: 0)],
        ),
        child: FilledButton(
          onPressed: isSpinning || isLoading ? null : _spinWheel,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF5B335),
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 0,
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSpinning)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)),
                ),
              Text(isSpinning ? 'Spinning...' : 'Spin Now'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFEAEAEA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Options', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('${options.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4B5563))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Edit, remove, or reorder options in one place.', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          const SizedBox(height: 16),
          ...List.generate(options.length, (index) {
            final option = options[index];
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 8)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.fastfood_rounded, color: Color(0xFFB7791F), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      option.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _editOption(index),
                    icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFFF5B335)),
                    style: IconButton.styleFrom(backgroundColor: const Color(0xFFFFF8E1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () => _deleteOption(index),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                    style: IconButton.styleFrom(backgroundColor: const Color(0xFFFFF1F2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(width: 160, child: _buildActionButton(label: 'Add Option', icon: Icons.add_rounded, onTap: _addImage)),
              SizedBox(width: 160, child: _buildActionButton(label: 'Shuffle', icon: Icons.shuffle_rounded, onTap: _shuffleOptions)),
              SizedBox(width: 160, child: _buildActionButton(label: 'Sort', icon: Icons.sort_rounded, onTap: _sortOptions)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Ink(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFFF5B335),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFF5B335).withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 6)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: Colors.black),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black),
                  ),
                ],
              ),
            ),
          ),
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
                    options.add(WheelOption(name: name, icon: Icons.local_dining));
                  });
                  _saveWheel();
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

  Future<void> _shuffleOptions() async {
    if (currentWheelId == null) return;

    try {
      final result = await QuickDecisionService.shuffleWheel(currentWheelId!);
      if (!mounted) return;
      final updated = (result['options'] as List<dynamic>? ?? []).map((item) {
        final option = item as Map<String, dynamic>;
        return WheelOption(id: option['id'] as int?, name: option['option_name']?.toString() ?? '', icon: Icons.local_dining, color: option['color']?.toString());
      }).toList();
      setState(() => options = updated);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Options shuffled successfully')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to shuffle options: $e')));
      }
    }
  }

  Future<void> _sortOptions() async {
    if (currentWheelId == null) return;

    try {
      final result = await QuickDecisionService.sortWheel(currentWheelId!);
      if (!mounted) return;
      final updated = (result['options'] as List<dynamic>? ?? []).map((item) {
        final option = item as Map<String, dynamic>;
        return WheelOption(id: option['id'] as int?, name: option['option_name']?.toString() ?? '', icon: Icons.local_dining, color: option['color']?.toString());
      }).toList();
      setState(() => options = updated);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Options sorted successfully')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to sort options: $e')));
      }
    }
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
                    options[index] = WheelOption(id: options[index].id, name: name, icon: options[index].icon, color: options[index].color);
                  });
                  _saveWheel();
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF2B73F),
                foregroundColor: Colors.black,
              ),
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _deleteOption(int index) {
    final option = options[index];

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
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              navigator.pop();
              try {
                if (option.id != null) {
                  final result = await QuickDecisionService.deleteWheelOption(option.id!);
                  if (!mounted) return;
                  if (result['success'] == true) {
                    await _loadWheels();
                    if (!mounted) return;
                    messenger.showSnackBar(const SnackBar(content: Text('Option deleted successfully')));
                    return;
                  }
                }
                if (!mounted) return;
                setState(() => options.removeAt(index));
                messenger.showSnackBar(const SnackBar(content: Text('Option deleted locally')));
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(SnackBar(content: Text('Unable to delete option: $e')));
                }
              }
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