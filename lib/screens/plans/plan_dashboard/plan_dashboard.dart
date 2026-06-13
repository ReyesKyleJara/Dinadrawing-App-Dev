import 'package:flutter/material.dart';
import '../../myplans/plan_model.dart';
import '../../../services/plan_service.dart';
import 'budget_tab.dart';
import 'members_page.dart';
import 'plan_settings.dart';
import 'feed_tab.dart';

class PlanDashboardScreen extends StatefulWidget {
  final int planId;

  const PlanDashboardScreen({super.key, required this.planId});

  @override
  State<PlanDashboardScreen> createState() => _PlanDashboardScreenState();
}

class _PlanDashboardScreenState extends State<PlanDashboardScreen> {
  bool isFeedActive = true;

  Plan? selectedPlan;
  bool isLoadingPlan = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSelectedPlan();
  }

  Future<void> _loadSelectedPlan() async {
    try {
      final result = await PlanService.getPlanById(widget.planId);

      if (!mounted) return;

      final planData = result['plan'];

      if (planData == null) {
        setState(() {
          errorMessage = result['message']?.toString() ?? 'Plan not found.';
          isLoadingPlan = false;
        });
        return;
      }

      setState(() {
        selectedPlan = Plan.fromJson(planData as Map<String, dynamic>);
        isLoadingPlan = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Failed to load plan: $e';
        isLoadingPlan = false;
      });
    }
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlanSettingsPage(planId: widget.planId),
      ),
    );

    if (!mounted) return;

    if (result == 'deleted' || result == 'left') {
      Navigator.pop(context, true);
      return;
    }

    if (result == true) {
      setState(() {
        isLoadingPlan = true;
      });

      await _loadSelectedPlan();
    }
  }

  String _getPlanDateLocationText(Plan plan) {
    final hasDate = plan.date.trim().isNotEmpty;
    final hasLocation = plan.location.trim().isNotEmpty;

    if (hasDate && hasLocation) {
      return '${plan.date} • ${plan.location}';
    }

    if (hasDate) {
      return plan.date;
    }

    if (hasLocation) {
      return plan.location;
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingPlan) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFF2B73F)),
        ),
      );
    }

    if (errorMessage != null || selectedPlan == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFF4A78D6),
          foregroundColor: Colors.white,
          title: const Text('Plan Dashboard'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              errorMessage ?? 'Unable to load plan.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          _buildBannerHeader(context),
          _buildTabSwitcher(),
          Expanded(
            child: isFeedActive
                ? FeedTab(planId: widget.planId)
                : const BudgetTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerHeader(BuildContext context) {
    final plan = selectedPlan!;
    final bannerColor = Plan.parseColor(plan.bannerColor);
    final dateLocationText = _getPlanDateLocationText(plan);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 58, left: 24, right: 24, bottom: 28),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.person_add_alt_1,
                      color: Colors.black87,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              MembersPage(planId: widget.planId),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: Colors.black87,
                    ),
                    onPressed: _openSettings,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 30),
          Text(
            plan.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
              height: 1.08,
            ),
          ),
          if (dateLocationText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              dateLocationText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black.withValues(alpha: 0.68),
                height: 1.25,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        height: 45,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => isFeedActive = true),
                child: Container(
                  decoration: BoxDecoration(
                    color: isFeedActive
                        ? const Color(0xFFF2B73F)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "Feed",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isFeedActive ? Colors.black : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => isFeedActive = false),
                child: Container(
                  decoration: BoxDecoration(
                    color: !isFeedActive
                        ? const Color(0xFFF2B73F)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "Budget",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: !isFeedActive ? Colors.black : Colors.black87,
                    ),
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
