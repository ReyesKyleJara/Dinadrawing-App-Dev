import 'package:flutter/material.dart';
import 'setup_budget.dart';

class BudgetExpense {
  String name;
  double amount;

  BudgetExpense({required this.name, required this.amount});
}

class BudgetMember {
  String name;
  double amountDue;
  bool isPaid;
  IconData avatarIcon;

  BudgetMember({
    required this.name,
    required this.amountDue,
    required this.isPaid,
    required this.avatarIcon,
  });
}

class BudgetTab extends StatefulWidget {
  const BudgetTab({super.key});

  @override
  State<BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends State<BudgetTab> {
  // Ito yung "memory" ng app. Naka-false siya sa umpisa.
  bool isBudgetSet = false;
  bool isEditingBudget = false;
  bool isEditingMembers = false;

  List<BudgetExpense> expenses = [
    BudgetExpense(name: 'Decor', amount: 33222),
  ];

  List<BudgetMember> members = [
    BudgetMember(name: 'Venice', amountDue: 113074, isPaid: true, avatarIcon: Icons.face_3),
    BudgetMember(name: 'Kenjie', amountDue: 113074, isPaid: false, avatarIcon: Icons.face),
    BudgetMember(name: 'Jara', amountDue: 113074, isPaid: false, avatarIcon: Icons.face_2),
  ];

  double get totalEstimatedBudget {
    return expenses.fold<double>(0, (sum, expense) => sum + expense.amount);
  }

  double get moneyCollected {
    return members.fold<double>(0, (sum, member) => sum + (member.isPaid ? member.amountDue : 0));
  }

  double get notCollected {
    final totalDue = members.fold<double>(0, (sum, member) => sum + member.amountDue);
    return totalDue - moneyCollected;
  }

  String formatPeso(double amount) {
    return '₱${amount.toStringAsFixed(2)}';
  }

  Widget _buildPaidStatusToggle(BudgetMember member) {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment<bool>(value: true, label: Text('Paid')),
        ButtonSegment<bool>(value: false, label: Text('Unpaid')),
      ],
      selected: <bool>{member.isPaid},
      showSelectedIcon: false,
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFFFFE1B0);
          }
          return Colors.white;
        }),
        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.black;
          }
          return Colors.grey.shade700;
        }),
        side: WidgetStatePropertyAll(BorderSide(color: Colors.grey.shade300)),
      ),
      onSelectionChanged: (selection) {
        setState(() {
          member.isPaid = selection.first;
        });
      },
    );
  }

  void _hydrateFromSetupResult(Map<String, dynamic> result) {
    final rawExpenses = result['expenses'];
    final rawMembers = result['members'];

    if (rawExpenses is List && rawExpenses.isNotEmpty) {
      expenses = rawExpenses
          .whereType<Map>()
          .map((item) => BudgetExpense(
                name: (item['name']?.toString().trim().isNotEmpty ?? false)
                    ? item['name'].toString().trim()
                    : 'Expense',
                amount: (item['amount'] as num?)?.toDouble() ?? 0,
              ))
          .toList();
    }

    if (rawMembers is List && rawMembers.isNotEmpty) {
      final fallbackIcons = [Icons.face_3, Icons.face, Icons.face_2, Icons.person];
      members = rawMembers.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        if (item is! Map) {
          return BudgetMember(
            name: 'Member ${index + 1}',
            amountDue: 0,
            isPaid: false,
            avatarIcon: fallbackIcons[index % fallbackIcons.length],
          );
        }

        return BudgetMember(
          name: (item['name']?.toString().trim().isNotEmpty ?? false)
              ? item['name'].toString().trim()
              : 'Member ${index + 1}',
          amountDue: (item['amount'] as num?)?.toDouble() ?? 0,
          isPaid: (item['isPaid'] as bool?) ?? false,
          avatarIcon: fallbackIcons[index % fallbackIcons.length],
        );
      }).toList();
    }
  }

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

            // Kung may valid result, i-update natin ang local state
            // para lumabas na yung editable overview.
            if (result == true || (result is Map && result['isBudgetSet'] == true)) {
              setState(() {
                isBudgetSet = true;
                if (result is Map<String, dynamic>) {
                  _hydrateFromSetupResult(result);
                }
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

        _buildSectionTitle(
          "Expenses Items",
          actionText: isEditingBudget ? "Done" : "Edit",
          onAction: () {
            setState(() => isEditingBudget = !isEditingBudget);
          },
        ),
        _buildExpensesCard(),
        const SizedBox(height: 24), 

        _buildSectionTitle(
          "Member Contributions",
          actionText: isEditingMembers ? "Done" : "Edit",
          onAction: () {
            setState(() => isEditingMembers = !isEditingMembers);
          },
        ),
        ...List.generate(members.length, (index) {
          return _buildMemberCard(index: index);
        }),
        if (isEditingMembers)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  members.add(BudgetMember(
                    name: 'New Member',
                    amountDue: 0,
                    isPaid: false,
                    avatarIcon: Icons.person,
                  ));
                });
              },
              icon: const Icon(Icons.add, color: Color(0xFFFFB84D), size: 16),
              label: const Text(
                'Add Member',
                style: TextStyle(color: Color(0xFFFFB84D), fontWeight: FontWeight.w600),
              ),
            ),
          ),
        const SizedBox(height: 16), 
      ],
    );
  }

  // --- UI Helper Methods (Smaller Sizes) ---

  Widget _buildSectionTitle(String title, {String? actionText, VoidCallback? onAction}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12), 
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          if (actionText != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(40, 24),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionText,
                style: const TextStyle(
                  color: Color(0xFFFFB84D),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditableAmountField({
    required double value,
    required ValueChanged<double> onChanged,
    TextAlign textAlign = TextAlign.right,
  }) {
    return SizedBox(
      width: 110,
      child: TextFormField(
        initialValue: value.toStringAsFixed(2),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: textAlign,
        onChanged: (val) => onChanged(double.tryParse(val) ?? 0),
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
        ),
        style: const TextStyle(fontSize: 13, color: Colors.black87),
      ),
    );
  }

  Widget _buildEditableNameField({
    required String value,
    required ValueChanged<String> onChanged,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return TextFormField(
      initialValue: value,
      onChanged: onChanged,
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
      ),
      style: TextStyle(fontSize: 13, color: Colors.black87, fontWeight: fontWeight),
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
          _buildOverviewRow("Estimated Budget", formatPeso(totalEstimatedBudget)),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
          _buildOverviewRow("Money Collected", formatPeso(moneyCollected)),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
          _buildOverviewRow("Not Collected", formatPeso(notCollected)),
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
          ...List.generate(expenses.length, (index) {
            final expense = expenses[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: isEditingBudget
                        ? _buildEditableNameField(
                            value: expense.name,
                            onChanged: (value) => expense.name = value,
                          )
                        : Text(
                            expense.name,
                            style: const TextStyle(fontSize: 13),
                          ),
                  ),
                  isEditingBudget
                      ? _buildEditableAmountField(
                          value: expense.amount,
                          onChanged: (value) {
                            setState(() {
                              expense.amount = value;
                            });
                          },
                        )
                      : Text(formatPeso(expense.amount), style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 10),
                  if (isEditingBudget)
                    InkWell(
                      onTap: () {
                        setState(() {
                          expenses.removeAt(index);
                          if (expenses.isEmpty) {
                            expenses.add(BudgetExpense(name: 'Expense', amount: 0));
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 12, color: Colors.grey),
                      ),
                    )
                  else
                    _buildPill("Pending", Colors.grey.shade200, Colors.black54),
                ],
              ),
            );
          }),
          const SizedBox(height: 6),
          if (isEditingBudget)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    expenses.add(BudgetExpense(name: 'New Expense', amount: 0));
                  });
                },
                icon: const Icon(Icons.add, color: Color(0xFFFFB84D), size: 16),
                label: const Text(
                  'Add Expense',
                  style: TextStyle(color: Color(0xFFFFB84D), fontWeight: FontWeight.w600),
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total Budget", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)), 
              Text(formatPeso(totalEstimatedBudget), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)), 
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard({required int index}) {
    final member = members[index];
    
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
            child: Icon(member.avatarIcon, color: Colors.black54, size: 20), 
          ),
          const SizedBox(width: 12), 
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                isEditingMembers
                    ? _buildEditableNameField(
                        value: member.name,
                        onChanged: (value) => member.name = value,
                        fontWeight: FontWeight.bold,
                      )
                    : Text(member.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), 
                const SizedBox(height: 2),
                isEditingMembers
                    ? Row(
                        children: [
                          Text("Amount Due: ", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          _buildEditableAmountField(
                            value: member.amountDue,
                            onChanged: (value) {
                              setState(() {
                                member.amountDue = value;
                              });
                            },
                            textAlign: TextAlign.left,
                          ),
                        ],
                      )
                    : Text("Amount Due: ${formatPeso(member.amountDue)}", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)), 
              ],
            ),
          ),
          if (isEditingMembers)
            _buildPaidStatusToggle(member)
          else
            _buildPill(
              member.isPaid ? "Paid" : "Unpaid",
              member.isPaid ? const Color(0xFF447D46) : const Color(0xFFB03A2E),
              Colors.white,
            ),
          if (isEditingMembers)
            IconButton(
              onPressed: () {
                setState(() {
                  members.removeAt(index);
                  if (members.isEmpty) {
                    members.add(BudgetMember(
                      name: 'Member 1',
                      amountDue: 0,
                      isPaid: false,
                      avatarIcon: Icons.person,
                    ));
                  }
                });
              },
              icon: const Icon(Icons.close, size: 16, color: Colors.grey),
              splashRadius: 18,
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