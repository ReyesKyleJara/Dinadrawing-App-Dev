import 'package:dinadrawing/screens/plans/plan_dashboard/plan_dashboard.dart';
import 'package:flutter/material.dart';
import '../../services/plan_service.dart';

class JoinPlanPage extends StatefulWidget {
  const JoinPlanPage({super.key});

  @override
  State<JoinPlanPage> createState() => _JoinPlanPageState();
}

class _JoinPlanPageState extends State<JoinPlanPage> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitJoin() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an invite code.")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await PlanService.joinPlan(inviteCode: code);

      if (!mounted) return;

      if (result.containsKey('plan') ||
          result['message'] == 'Joined plan successfully') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Successfully joined the plan!")),
        );

        // KUKUNIN NATIN YUNG ID NG PLAN NA KAPAPASOK MO LANG
        final int newPlanId = result['plan']['id'];

        // IDEDERETSO KA NA SA PLAN DASHBOARD
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PlanDashboardScreen(planId: newPlanId),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to join plan.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Connection error: $e")));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: colors.onSurface, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Join Plan',
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Have an invite code?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the 6-character code given by the plan admin to join their plan.',
              style: TextStyle(
                fontSize: 14,
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              cursorColor: const Color(0xFFF2B73F),
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 18,
                letterSpacing: 2.0,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. A1B2C3',
                hintStyle: TextStyle(
                  color: colors.onSurfaceVariant,
                  letterSpacing: 0,
                ),
                filled: true,
                fillColor: colors.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFF2B73F),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitJoin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF2B73F),
                  disabledBackgroundColor: colors.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Join Now',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
