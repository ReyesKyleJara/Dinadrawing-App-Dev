import 'package:flutter/material.dart';

class SetupBudgetScreen extends StatefulWidget {
  const SetupBudgetScreen({super.key});

  @override
  State<SetupBudgetScreen> createState() => _SetupBudgetScreenState();
}

class ExpenseItem {
  TextEditingController nameCtrl = TextEditingController();
  TextEditingController costCtrl = TextEditingController();
}

class MemberItem {
  String name;
  double amount;
  MemberItem({required this.name, required this.amount});
}

class _SetupBudgetScreenState extends State<SetupBudgetScreen> {
  int _currentStep = 1;
  
  // Data for Step 1
  List<ExpenseItem> expenses = [ExpenseItem()];
  
  // Data for Step 2
  bool _splitEqually = true;
  List<MemberItem> members = [
    MemberItem(name: "Member 1", amount: 0),
    MemberItem(name: "Member 2", amount: 0),
    MemberItem(name: "Member 3", amount: 0),
  ];

  double get totalEstimatedBudget {
    double total = 0;
    for (var exp in expenses) {
      total += double.tryParse(exp.costCtrl.text) ?? 0;
    }
    return total;
  }

  void _updateEqualSplit() {
    if (members.isNotEmpty) {
      double splitAmount = totalEstimatedBudget / members.length;
      for (var member in members) {
        member.amount = splitAmount;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: _buildCurrentStepContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TOP NAVIGATION BAR ---
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 16, right: 16),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () {
              if (_currentStep > 1) {
                setState(() => _currentStep--);
              } else {
                Navigator.pop(context);
              }
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
            icon: const Icon(Icons.arrow_back_ios, size: 14, color: Color(0xFFFFB84D)),
            label: const Text("Back", style: TextStyle(color: Color(0xFFFFB84D), fontSize: 14)),
          ),
        ],
      ),
    );
  }

  // --- STEP SWITCHER ---
  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildStep1AddExpenses();
      case 2:
        _updateEqualSplit(); // Auto-calculate before showing Step 2
        return _buildStep2SetDivision();
      case 3:
        return _buildStep3ConfirmPlan();
      default:
        return const SizedBox();
    }
  }

  // ==========================================
  // STEP 1: ADD EXPENSES
  // ==========================================
  Widget _buildStep1AddExpenses() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Step 1 of 3", style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        const Text("Add Expenses", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text("List down your expected expenses below.", style: TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 24),

        // Table Header
        Row(
          children: [
            const Expanded(flex: 2, child: Text("Expense", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey, fontSize: 12))),
            Expanded(flex: 1, child: Text("Estimated Cost (₱)", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey, fontSize: 12))),
            const SizedBox(width: 32), // Space for delete icon
          ],
        ),
        const Divider(height: 24),

        // Expense List
        ...List.generate(expenses.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: expenses[index].nameCtrl,
                    decoration: const InputDecoration(
                      hintText: "e.g. Food",
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: expenses[index].costCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    onChanged: (val) => setState(() {}), // Update total
                    decoration: const InputDecoration(
                      hintText: "0.00",
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () {
                    setState(() {
                      expenses.removeAt(index);
                      if (expenses.isEmpty) expenses.add(ExpenseItem());
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 12, color: Colors.grey),
                  ),
                )
              ],
            ),
          );
        }),

        const Divider(),
        
        // Add New Expense Button
        Center(
          child: TextButton.icon(
            onPressed: () => setState(() => expenses.add(ExpenseItem())),
            icon: const Icon(Icons.add, color: Color(0xFFFFB84D), size: 16),
            label: const Text("Add New Expense", style: TextStyle(color: Color(0xFFFFB84D))),
          ),
        ),

        const SizedBox(height: 32),

        // Total
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Total Estimated:", style: TextStyle(fontWeight: FontWeight.w600)),
            Text("₱${totalEstimatedBudget.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),

        const SizedBox(height: 32),

        // Next Button
        _buildBottomButton("Next", () {
          setState(() => _currentStep = 2);
        }),
      ],
    );
  }

  // ==========================================
  // STEP 2: SET DIVISION
  // ==========================================
  Widget _buildStep2SetDivision() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Step 2 of 3", style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        const Text("Set Division", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text("Let's divide ₱${totalEstimatedBudget.toStringAsFixed(2)} among your members.", style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 24),

        SegmentedButton<bool>(
          segments: const [
            ButtonSegment<bool>(
              value: true,
              label: Text("Split Equally", style: TextStyle(fontSize: 14)),
            ),
            ButtonSegment<bool>(
              value: false,
              label: Text("Custom Allocation", style: TextStyle(fontSize: 14)),
            ),
          ],
          selected: <bool>{_splitEqually},
          showSelectedIcon: false,
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.black;
              }
              return Colors.grey[700]!;
            }),
            backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
              if (states.contains(WidgetState.selected)) {
                return const Color(0xFFFFE1B0);
              }
              return Colors.white;
            }),
            side: const WidgetStatePropertyAll(
              BorderSide(color: Color(0xFFFFB84D)),
            ),
          ),
          onSelectionChanged: (selection) {
            final splitEqually = selection.first;
            setState(() {
              _splitEqually = splitEqually;
              if (_splitEqually) {
                _updateEqualSplit();
              }
            });
          },
        ),
        
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text("Member", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey, fontSize: 12)),
            Text("Amount (₱)", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey, fontSize: 12)),
          ],
        ),
        const Divider(height: 24),

        // Members List
        ...List.generate(members.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                const Icon(Icons.person_outline, color: Colors.grey, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(members[index].name, style: const TextStyle(fontSize: 14))),
                Text(
                  members[index].amount.toStringAsFixed(2), 
                  style: TextStyle(fontSize: 14, color: _splitEqually ? Colors.grey[700] : Colors.black)
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 12, color: Colors.grey),
                )
              ],
            ),
          );
        }),

        const Divider(),

        // Add Member
        Center(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFFFB84D).withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton.icon(
              onPressed: () {}, // Add member logic here
              icon: const Icon(Icons.add, color: Color(0xFFFFB84D), size: 16),
              label: const Text("Add New Member", style: TextStyle(color: Color(0xFFFFB84D))),
            ),
          ),
        ),

        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Total", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("₱${totalEstimatedBudget.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        
        const SizedBox(height: 32),

        // Navigation Buttons
        Row(
          children: [
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep = 1),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: Colors.grey),
                ),
                child: const Text("Back", style: TextStyle(color: Colors.black)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _buildBottomButton("Next", () {
                setState(() => _currentStep = 3);
              }),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // STEP 3: CONFIRM PLAN
  // ==========================================
  Widget _buildStep3ConfirmPlan() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Step 3 of 3", style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        const Text("Confirm Plan", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text("Here's a summary before saving your budget plan.", style: TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 32),

        // Summary Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F9F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Total Budget:", style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 4),
              Text("₱${totalEstimatedBudget.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Text("Division: ${_splitEqually ? 'Split equally' : 'Custom allocation'}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text("Members: ${members.length}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total", style: TextStyle(color: Colors.grey)),
                  Text("₱${totalEstimatedBudget.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),

        // Navigation Buttons
        Row(
          children: [
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep = 2),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: Colors.grey),
                ),
                child: const Text("Back", style: TextStyle(color: Colors.black)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _buildBottomButton("Confirm & Save", () {
                // 1. Ipakita muna ang SnackBar habang buhay pa ang screen!
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Budget plan saved successfully!"),
                    backgroundColor: Color(0xFF447D46),
                    behavior: SnackBarBehavior.floating,
                    margin: EdgeInsets.only(bottom: 80, left: 24, right: 24),
                  )
                );
                
                // 2. Saka tayo mag-pop at magpasa ng "true" pabalik sa tab
                Navigator.pop(context, true);
              }),
            ),
          ],
        ),
      ],
    );
  }

  // --- REUSABLE YELLOW BUTTON ---
  Widget _buildBottomButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFB84D),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }
}