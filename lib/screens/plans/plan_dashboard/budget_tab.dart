import 'package:flutter/material.dart';
import 'setup_budget_screen.dart';

class BudgetTab extends StatefulWidget {
  const BudgetTab({super.key});

  @override
  State<BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends State<BudgetTab> {
  // Ito yung "memory" ng app. Naka-false siya sa umpisa.
  bool isBudgetSet = false; 

  @override
  Widget build(BuildContext context) {
    // KUNG HINDI PA NASE-SET ANG BUDGET: Ipakita ang button
    if (!isBudgetSet) {
      return Center(
        child: ElevatedButton(
          onPressed: () async {
            // Hihintayin ng app na matapos ang SetupBudgetScreen
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SetupBudgetScreen()),
            );

            // Kung "true" ang ibinalik (meaning pinindot ang Confirm & Save), 
            // babaguhin natin ang state para lumabas na yung Overview!
            if (result == true) {
              setState(() {
                isBudgetSet = true;
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFB84D),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            '+ Set the Budget',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      );
    }

    // KUNG NASE-SET NA ANG BUDGET: Ipakita itong Overview Layout (scaled-down version)
    return ListView(
      padding: const EdgeInsets.all(24.0), 
      children: [
        _buildSectionTitle("Budget Overview"),
        _buildOverviewCard(),
        const SizedBox(height: 24), 

        _buildSectionTitle("Expenses Items"),
        _buildExpensesCard(),
        const SizedBox(height: 24), 

        _buildSectionTitle("Member Contributions"),
        _buildMemberCard(
          name: "Venice",
          amountDue: "₱113,074.00",
          status: "Paid",
          avatarIcon: Icons.face_3, 
        ),
        _buildMemberCard(
          name: "Kenjie",
          amountDue: "₱113,074.00",
          status: "Unpaid",
          avatarIcon: Icons.face, 
        ),
        _buildMemberCard(
          name: "Jara",
          amountDue: "₱113,074.00",
          status: "Unpaid",
          avatarIcon: Icons.face_2, 
        ),
        const SizedBox(height: 16), 
      ],
    );
  }

  // --- UI Helper Methods (Smaller Sizes) ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12), 
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14, 
          fontWeight: FontWeight.w800,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildOverviewCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14), 
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildOverviewRow("Estimated Budget", "₱33,222.00"),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
          _buildOverviewRow("Money Collected", "₱113,074.00"),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
          _buildOverviewRow("Not Collected", "₱79,852.00"),
        ],
      ),
    );
  }

  Widget _buildOverviewRow(String label, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), 
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87)), 
          Text(amount, style: const TextStyle(fontSize: 13, color: Colors.black87)), 
        ],
      ),
    );
  }

  Widget _buildExpensesCard() {
    return Container(
      padding: const EdgeInsets.all(14), 
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14), 
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: Text("Decor", style: TextStyle(fontSize: 13))), 
              const Text("₱33,222.00", style: TextStyle(fontSize: 13)), 
              const SizedBox(width: 10),
              _buildPill("Pending", Colors.grey.shade200, Colors.black54),
            ],
          ),
          const SizedBox(height: 12), 
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total Budget", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)), 
              Text("₱33,222.00", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)), 
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard({required String name, required String amountDue, required String status, required IconData avatarIcon}) {
    bool isPaid = status == "Paid";
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10), 
      padding: const EdgeInsets.all(12), 
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14), 
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18, 
            backgroundColor: Colors.grey.shade200,
            child: Icon(avatarIcon, color: Colors.black54, size: 20), 
          ),
          const SizedBox(width: 12), 
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), 
                const SizedBox(height: 2),
                Text("Amount Due: $amountDue", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)), 
              ],
            ),
          ),
          _buildPill(
            status, 
            isPaid ? const Color(0xFF447D46) : const Color(0xFFB03A2E), 
            Colors.white
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), 
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16), 
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor, 
          fontSize: 11, 
          fontWeight: FontWeight.bold
        ),
      ),
    );
  }
}