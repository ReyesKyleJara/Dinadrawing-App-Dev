import 'package:flutter/material.dart';
import 'feed_tab.dart';
import 'budget_tab.dart';

class PlanDashboardScreen extends StatefulWidget {
  final String planName;
  final String planDate;
  final String planLocation;

  const PlanDashboardScreen({
    super.key,
    required this.planName,
    required this.planDate,
    required this.planLocation,
  });

  @override
  State<PlanDashboardScreen> createState() => _PlanDashboardScreenState();
}

class _PlanDashboardScreenState extends State<PlanDashboardScreen> {
  bool isFeedActive = true; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Light grey background
      body: Column(
        children: [
          _buildBlueHeader(context),
          
          // The Custom Toggle Tab (Feed / Budget)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => isFeedActive = true),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isFeedActive ? const Color(0xFFF2B73F) : Colors.transparent,
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
                          color: !isFeedActive ? const Color(0xFFF2B73F) : Colors.transparent,
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
          ),

          // Main Content Area seamlessly switching between files
          Expanded(
            child: isFeedActive ? const FeedTab() : const BudgetTab(),
          ),
        ],
      ),
    );
  }

  // --- UI Helper for the Header ---

  Widget _buildBlueHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF4A78D6), // The vibrant blue from your design
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
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
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context), // Goes back to previous screen
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
                    onPressed: () {}, // Invite users
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: Colors.white),
                    onPressed: () {}, // TODO: Navigate to Plan Settings later
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.planName,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            "${widget.planDate} • ${widget.planLocation}",
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}