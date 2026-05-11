import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DecimalAmountTextInputFormatter extends TextInputFormatter {
  const DecimalAmountTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final rawText = newValue.text;
    if (rawText.isEmpty) {
      return newValue.copyWith(
        text: '',
        selection: const TextSelection.collapsed(offset: 0),
      );
    }

    final cleaned = rawText.replaceAll(RegExp(r'[^0-9.]'), '');
    final dotIndex = cleaned.indexOf('.');

    // Detect if the user just inserted a dot at the caret position.
    int insertedIndex = newValue.selection.baseOffset - 1;
    String insertedChar = '';
    if (insertedIndex >= 0 && insertedIndex < newValue.text.length) {
      insertedChar = newValue.text[insertedIndex];
    }

    if (insertedChar == '.') {
      // User explicitly typed '.', switch to decimal-entry mode preserving whole number part.
      final whole = cleaned.split('.').first.replaceAll('.', '');
      final formatted = '${whole.isEmpty ? '0' : whole}.';
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
        composing: TextRange.empty,
      );
    }

    if (dotIndex == -1) {
      final wholeNumber = cleaned.replaceAll('.', '');
      final formatted = '$wholeNumber.00';
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: wholeNumber.length),
        composing: TextRange.empty,
      );
    }

    final wholeNumber = cleaned.substring(0, dotIndex).replaceAll('.', '');
    String decimalPart = cleaned.substring(dotIndex + 1).replaceAll('.', '');

    // Allow user to type up to 2 decimal digits while editing; do not pad with zero here.
    if (decimalPart.length > 2) {
      decimalPart = decimalPart.substring(0, 2);
    }

    // If user only typed a dot (e.g. '79.'), preserve the dot so they can type decimals.
    if (decimalPart.isEmpty) {
      final formatted = '${wholeNumber.isEmpty ? '0' : wholeNumber}.';
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
        composing: TextRange.empty,
      );
    }

    final formatted = '${wholeNumber.isEmpty ? '0' : wholeNumber}.$decimalPart';
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
      composing: TextRange.empty,
    );
  }
}

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
          onAction: () async {
            final result = await showModalBottomSheet<Map<String, dynamic>>(
              context: context,
              isScrollControlled: true,
              builder: (_) => BudgetEditorBottomSheet(
                initialExpenses: expenses,
                initialMembers: members,
                initialMode: EditorMode.expenses,
              ),
            );

            if (result != null) {
              setState(() {
                isBudgetSet = true;
                _hydrateFromSetupResult(result);
              });
            }
          },
        ),
        _buildExpensesCard(),
        const SizedBox(height: 24), 

        _buildSectionTitle(
          "Member Contributions",
          actionText: isEditingMembers ? "Done" : "Edit",
          onAction: () async {
            final result = await showModalBottomSheet<Map<String, dynamic>>(
              context: context,
              isScrollControlled: true,
              builder: (_) => BudgetEditorBottomSheet(
                initialExpenses: expenses,
                initialMembers: members,
                initialMode: EditorMode.members,
              ),
            );

            if (result != null) {
              setState(() {
                isBudgetSet = true;
                _hydrateFromSetupResult(result);
              });
            }
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
    final controller = TextEditingController(text: value.toStringAsFixed(2));
    final focusNode = FocusNode();
    
    focusNode.addListener(() {
      if (!focusNode.hasFocus && controller.text.isNotEmpty && !controller.text.endsWith('.')) {
        final val = double.tryParse(controller.text) ?? 0;
        controller.text = val.toStringAsFixed(2);
        onChanged(val);
      }
    });

    return SizedBox(
      width: 110,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: textAlign,
        inputFormatters: const [DecimalAmountTextInputFormatter()],
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

class SetupBudgetScreen extends StatefulWidget {
  const SetupBudgetScreen({super.key});

  @override
  State<SetupBudgetScreen> createState() => _SetupBudgetScreenState();
}

class ExpenseItem {
  TextEditingController nameCtrl = TextEditingController();
  TextEditingController costCtrl = TextEditingController();

  void dispose() {
    nameCtrl.dispose();
    costCtrl.dispose();
  }
}

class MemberItem {
  String name;
  double amount;
  late TextEditingController amountCtrl;

  MemberItem({required this.name, required this.amount});

  MemberItem.withAmountController({required this.name, required this.amount})
      : amountCtrl = TextEditingController(text: amount.toStringAsFixed(2));

  void dispose() {
    amountCtrl.dispose();
  }
}

class _SetupBudgetScreenState extends State<SetupBudgetScreen> {
  int _currentStep = 1;

  List<ExpenseItem> expenses = [ExpenseItem()];

  bool _splitEqually = true;
  List<MemberItem> members = [
    MemberItem.withAmountController(name: "Member 1", amount: 0),
    MemberItem.withAmountController(name: "Member 2", amount: 0),
    MemberItem.withAmountController(name: "Member 3", amount: 0),
  ];

  double get totalEstimatedBudget {
    double total = 0;
    for (var exp in expenses) {
      total += _parseAmountText(exp.costCtrl.text);
    }
    return total;
  }

  String _displayAmount(double amount) {
    return amount.toStringAsFixed(2);
  }

  double _parseAmountText(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^0-9.]'), '');
    final parts = cleaned.split('.');
    if (parts.length > 2) {
      return double.tryParse('${parts[0]}.${parts[1]}') ?? 0;
    }
    return cleaned.isEmpty ? 0 : (double.tryParse(cleaned) ?? 0);
  }

  void _updateEqualSplit() {
    if (members.isNotEmpty) {
      double splitAmount = totalEstimatedBudget / members.length;
      for (var member in members) {
        member.amount = splitAmount;
        member.amountCtrl.text = splitAmount.toStringAsFixed(2);
      }
    }
  }

  @override
  void dispose() {
    for (final expense in expenses) {
      expense.dispose();
    }
    for (final member in members) {
      member.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _buildResultPayload() {
    final resultExpenses = expenses
        .map((expense) => {
              'name': expense.nameCtrl.text.trim().isEmpty ? 'Expense' : expense.nameCtrl.text.trim(),
              'amount': double.tryParse(expense.costCtrl.text) ?? 0,
            })
        .toList();

    final resultMembers = members
        .map((member) => {
              'name': member.name,
              'amount': member.amount,
              'isPaid': false,
            })
        .toList();

    return {
      'isBudgetSet': true,
      'expenses': resultExpenses,
      'members': resultMembers,
    };
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

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildStep1AddExpenses();
      case 2:
        if (_splitEqually) {
          _updateEqualSplit();
        }
        return _buildStep2SetDivision();
      case 3:
        return _buildStep3ConfirmPlan();
      default:
        return const SizedBox();
    }
  }

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
        Row(
          children: [
            const Expanded(flex: 2, child: Text("Expense", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey, fontSize: 12))),
            Expanded(flex: 1, child: Text("Estimated Cost (₱)", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey, fontSize: 12))),
            const SizedBox(width: 32),
          ],
        ),
        const Divider(height: 24),
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
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.right,
                    onChanged: (_) => setState(() {}),
                    onEditingComplete: () {
                      final text = expenses[index].costCtrl.text;
                      if (text.isNotEmpty && !text.endsWith('.')) {
                        final val = double.tryParse(text) ?? 0;
                        expenses[index].costCtrl.text = val.toStringAsFixed(2);
                      }
                      setState(() {});
                    },
                    inputFormatters: const [DecimalAmountTextInputFormatter()],
                    decoration: const InputDecoration(
                      hintText: "00.00",
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
        Center(
          child: TextButton.icon(
            onPressed: () => setState(() => expenses.add(ExpenseItem())),
            icon: const Icon(Icons.add, color: Color(0xFFFFB84D), size: 16),
            label: const Text("Add New Expense", style: TextStyle(color: Color(0xFFFFB84D))),
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Total Estimated:", style: TextStyle(fontWeight: FontWeight.w600)),
            Text("₱${totalEstimatedBudget.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 32),
        _buildBottomButton("Next", () {
          setState(() => _currentStep = 2);
        }),
      ],
    );
  }

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
        ...List.generate(members.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                const Icon(Icons.person_outline, color: Colors.grey, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(members[index].name, style: const TextStyle(fontSize: 14))),
                _splitEqually
                    ? Text(
                        _displayAmount(members[index].amount),
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      )
                    : SizedBox(
                        width: 110,
                        child: TextField(
                          controller: members[index].amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.right,
                          onChanged: (val) {
                            setState(() {
                              members[index].amount = _parseAmountText(val);
                            });
                          },
                          onEditingComplete: () {
                            final text = members[index].amountCtrl.text;
                            if (text.isNotEmpty && !text.endsWith('.')) {
                              final val = double.tryParse(text) ?? 0;
                              members[index].amountCtrl.text = val.toStringAsFixed(2);
                              members[index].amount = val;
                            }
                            setState(() {});
                          },
                          inputFormatters: const [DecimalAmountTextInputFormatter()],
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(fontSize: 14, color: Colors.black),
                        ),
                      ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () {
                    setState(() {
                      members.removeAt(index);
                      if (members.isEmpty) {
                        members.add(MemberItem.withAmountController(name: 'Member 1', amount: 0));
                      }
                      if (_splitEqually) {
                        _updateEqualSplit();
                      }
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
        Center(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFFFB84D).withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  members.add(MemberItem.withAmountController(name: "Member ${members.length + 1}", amount: 0));
                  if (_splitEqually) {
                    _updateEqualSplit();
                  }
                });
              },
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
        Row(
          children: [
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () => setState(() => _currentStep = 1),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Colors.grey),
                  ),
                  child: const Text("Back", style: TextStyle(color: Colors.black)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: _buildBottomButton("Next", () {
                setState(() => _currentStep = 3);
              }),
            ),
          ],
        ),
      ],
    );
  }

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
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () => setState(() => _currentStep = 2),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Colors.grey),
                  ),
                  child: const Text("Back", style: TextStyle(color: Colors.black)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildBottomButton("Confirm & Save", () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Budget plan saved successfully!"),
                    backgroundColor: Color(0xFF447D46),
                  ),
                );
                Navigator.pop(context, _buildResultPayload());
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomButton(String text, VoidCallback onPressed) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFB84D),
          elevation: 0,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }
}

// --- Budget Editor Modal (Standalone, not linked to stepper) ---
class BudgetEditorDialog extends StatefulWidget {
  final List<BudgetExpense> initialExpenses;
  final List<BudgetMember> initialMembers;

  const BudgetEditorDialog({super.key, required this.initialExpenses, required this.initialMembers});

  @override
  State<BudgetEditorDialog> createState() => _BudgetEditorDialogState();
}

class _BudgetEditorDialogState extends State<BudgetEditorDialog> {
  late List<BudgetExpense> expenses;
  late List<BudgetMember> members;

  @override
  void initState() {
    super.initState();
    // Work on local copies
    expenses = widget.initialExpenses.map((e) => BudgetExpense(name: e.name, amount: e.amount)).toList();
    members = widget.initialMembers.map((m) => BudgetMember(name: m.name, amountDue: m.amountDue, isPaid: m.isPaid, avatarIcon: m.avatarIcon)).toList();
  }

  double get total => expenses.fold(0.0, (s, e) => s + e.amount);

  void _saveAndClose() {
    final resultExpenses = expenses.map((e) => {'name': e.name, 'amount': e.amount}).toList();
    final resultMembers = members.map((m) => {'name': m.name, 'amount': m.amountDue, 'isPaid': m.isPaid}).toList();
    Navigator.of(context).pop({'isBudgetSet': true, 'expenses': resultExpenses, 'members': resultMembers});
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: SizedBox(
        width: double.infinity,
        height: 520,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Edit Budget', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(tabs: [Tab(text: 'Expenses'), Tab(text: 'Members')]),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Expenses tab
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: expenses.length,
                                    itemBuilder: (_, i) {
                                      final e = expenses[i];
                                      final nameCtrl = TextEditingController(text: e.name);
                                      final costCtrl = TextEditingController(text: e.amount.toStringAsFixed(2));
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: TextField(controller: nameCtrl, onChanged: (v) => e.name = v, decoration: const InputDecoration(hintText: 'Expense', border: OutlineInputBorder(), isDense: true)),
                                            ),
                                            const SizedBox(width: 8),
                                            SizedBox(
                                              width: 110,
                                              child: TextField(
                                                controller: costCtrl,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                textAlign: TextAlign.right,
                                                inputFormatters: const [DecimalAmountTextInputFormatter()],
                                                onChanged: (v) => e.amount = double.tryParse(v) ?? e.amount,
                                                onEditingComplete: () {
                                                  final val = double.tryParse(costCtrl.text) ?? 0;
                                                  costCtrl.text = val.toStringAsFixed(2);
                                                  e.amount = val;
                                                  setState(() {});
                                                },
                                                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            InkWell(
                                              onTap: () { setState(() { expenses.removeAt(i); }); },
                                              child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle), child: const Icon(Icons.close, size: 14)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                TextButton.icon(onPressed: () { setState(() { expenses.add(BudgetExpense(name: 'New Expense', amount: 0)); }); }, icon: const Icon(Icons.add, color: Color(0xFFFFB84D)), label: const Text('Add Expense', style: TextStyle(color: Color(0xFFFFB84D)))),
                              ],
                            ),
                          ),
                          // Members tab
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: members.length,
                                    itemBuilder: (_, i) {
                                      final m = members[i];
                                      final nameCtrl = TextEditingController(text: m.name);
                                      final amtCtrl = TextEditingController(text: m.amountDue.toStringAsFixed(2));
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.person_outline, color: Colors.grey),
                                            const SizedBox(width: 8),
                                            Expanded(child: TextField(controller: nameCtrl, onChanged: (v) => m.name = v, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true))),
                                            const SizedBox(width: 8),
                                            SizedBox(
                                              width: 110,
                                              child: TextField(
                                                controller: amtCtrl,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                textAlign: TextAlign.right,
                                                inputFormatters: const [DecimalAmountTextInputFormatter()],
                                                onChanged: (v) => m.amountDue = double.tryParse(v) ?? m.amountDue,
                                                onEditingComplete: () {
                                                  final val = double.tryParse(amtCtrl.text) ?? 0;
                                                  amtCtrl.text = val.toStringAsFixed(2);
                                                  m.amountDue = val;
                                                  setState(() {});
                                                },
                                                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            InkWell(onTap: () { setState(() { members.removeAt(i); }); }, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle), child: const Icon(Icons.close, size: 14))),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                TextButton.icon(onPressed: () { setState(() { members.add(BudgetMember(name: 'New Member', amountDue: 0, isPaid: false, avatarIcon: Icons.person)); }); }, icon: const Icon(Icons.add, color: Color(0xFFFFB84D)), label: const Text('Add Member', style: TextStyle(color: Color(0xFFFFB84D)))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(onPressed: _saveAndClose, child: const Text('Save'))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Bottom sheet variant of the budget editor
enum EditorMode { both, expenses, members }

class BudgetEditorBottomSheet extends StatefulWidget {
  final List<BudgetExpense> initialExpenses;
  final List<BudgetMember> initialMembers;
  final EditorMode initialMode;

  const BudgetEditorBottomSheet({super.key, required this.initialExpenses, required this.initialMembers, this.initialMode = EditorMode.both});

  @override
  State<BudgetEditorBottomSheet> createState() => _BudgetEditorBottomSheetState();
}

class _BudgetEditorBottomSheetState extends State<BudgetEditorBottomSheet> {
  static const Color _accentYellow = Color(0xFFFFB84D);
  static const Color _textBlack = Color(0xFF222222);
  static const Color _lineGray = Color(0xFFD9D9D9);
  static const Color _bgSoft = Color(0xFFF8F8F8);

  late List<BudgetExpense> expenses;
  late List<BudgetMember> members;

  @override
  void initState() {
    super.initState();
    expenses = widget.initialExpenses.map((e) => BudgetExpense(name: e.name, amount: e.amount)).toList();
    members = widget.initialMembers.map((m) => BudgetMember(name: m.name, amountDue: m.amountDue, isPaid: m.isPaid, avatarIcon: m.avatarIcon)).toList();
  }

  double get total => expenses.fold(0.0, (s, e) => s + e.amount);

  void _saveAndClose() {
    final resultExpenses = expenses.map((e) => {'name': e.name, 'amount': e.amount}).toList();
    final resultMembers = members.map((m) => {'name': m.name, 'amount': m.amountDue, 'isPaid': m.isPaid}).toList();
    Navigator.of(context).pop({'isBudgetSet': true, 'expenses': resultExpenses, 'members': resultMembers});
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Choose layout based on requested mode
    Widget content;
    if (widget.initialMode == EditorMode.both) {
      content = DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(tabs: [Tab(text: 'Expenses'), Tab(text: 'Members')]),
            Expanded(
              child: TabBarView(
                children: [
                  _buildExpensesEditor(),
                  _buildMembersEditor(useAmount: true),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (widget.initialMode == EditorMode.expenses) {
      content = _buildExpensesEditor();
    } else {
      content = _buildMembersEditor(useAmount: false);
    }

    return SafeArea(
      child: Container(
        height: media.size.height * 0.75,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFCFCFCF), borderRadius: BorderRadius.circular(4)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Edit Budget', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textBlack)),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, color: _textBlack)),
                ],
              ),
            ),
            const Divider(height: 1, color: _lineGray),
            Expanded(child: content),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textBlack,
                        side: const BorderSide(color: _lineGray),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        minimumSize: const Size.fromHeight(42),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveAndClose,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentYellow,
                        foregroundColor: _textBlack,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        minimumSize: const Size.fromHeight(42),
                      ),
                      child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
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

  Widget _buildExpensesEditor() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: expenses.length,
              itemBuilder: (_, i) {
                final e = expenses[i];
                final nameCtrl = TextEditingController(text: e.name);
                final costCtrl = TextEditingController(text: e.amount.toStringAsFixed(2));
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nameCtrl,
                          onChanged: (v) => e.name = v,
                          decoration: InputDecoration(
                            hintText: 'Expense',
                            border: OutlineInputBorder(borderSide: const BorderSide(color: _lineGray), borderRadius: BorderRadius.circular(10)),
                            enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: _lineGray), borderRadius: BorderRadius.circular(10)),
                            focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _textBlack), borderRadius: BorderRadius.circular(10)),
                            fillColor: _bgSoft,
                            filled: true,
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 110,
                        child: TextField(
                          controller: costCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.right,
                          inputFormatters: const [DecimalAmountTextInputFormatter()],
                          onChanged: (v) => e.amount = double.tryParse(v) ?? e.amount,
                          onEditingComplete: () {
                            final val = double.tryParse(costCtrl.text) ?? 0;
                            costCtrl.text = val.toStringAsFixed(2);
                            e.amount = val;
                            setState(() {});
                          },
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderSide: const BorderSide(color: _lineGray), borderRadius: BorderRadius.circular(10)),
                            enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: _lineGray), borderRadius: BorderRadius.circular(10)),
                            focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _textBlack), borderRadius: BorderRadius.circular(10)),
                            fillColor: _bgSoft,
                            filled: true,
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(onTap: () { setState(() { expenses.removeAt(i); }); }, child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Color(0xFFF0F0F0), shape: BoxShape.circle), child: const Icon(Icons.close, size: 14, color: _textBlack))),
                    ],
                  ),
                );
              },
            ),
          ),
          TextButton.icon(onPressed: () { setState(() { expenses.add(BudgetExpense(name: 'New Expense', amount: 0)); }); }, icon: const Icon(Icons.add, color: _accentYellow), label: const Text('Add Expense', style: TextStyle(color: _accentYellow, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildMembersEditor({required bool useAmount}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: members.length,
              itemBuilder: (_, i) {
                final m = members[i];
                final nameCtrl = TextEditingController(text: m.name);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, color: Color(0xFF888888)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: nameCtrl,
                          onChanged: (v) => m.name = v,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderSide: const BorderSide(color: _lineGray), borderRadius: BorderRadius.circular(10)),
                            enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: _lineGray), borderRadius: BorderRadius.circular(10)),
                            focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _textBlack), borderRadius: BorderRadius.circular(10)),
                            fillColor: _bgSoft,
                            filled: true,
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (useAmount) ...[
                        SizedBox(
                          width: 110,
                          child: TextField(
                            controller: TextEditingController(text: m.amountDue.toStringAsFixed(2)),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.right,
                            inputFormatters: const [DecimalAmountTextInputFormatter()],
                            onChanged: (v) => m.amountDue = double.tryParse(v) ?? m.amountDue,
                            onEditingComplete: () {
                              setState(() {});
                            },
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderSide: const BorderSide(color: _lineGray), borderRadius: BorderRadius.circular(10)),
                              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: _lineGray), borderRadius: BorderRadius.circular(10)),
                              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _textBlack), borderRadius: BorderRadius.circular(10)),
                              fillColor: _bgSoft,
                              filled: true,
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // Paid / Unpaid toggle
                      ChoiceChip(
                        label: Text(m.isPaid ? 'Paid' : 'Unpaid', style: TextStyle(color: m.isPaid ? Colors.white : _textBlack, fontWeight: FontWeight.w600)),
                        selected: m.isPaid,
                        onSelected: (sel) { setState(() { m.isPaid = sel; }); },
                        selectedColor: _textBlack,
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: _lineGray),
                        showCheckmark: m.isPaid,
                        checkmarkColor: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      InkWell(onTap: () { setState(() { members.removeAt(i); }); }, child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Color(0xFFF0F0F0), shape: BoxShape.circle), child: const Icon(Icons.close, size: 14, color: _textBlack))),
                    ],
                  ),
                );
              },
            ),
          ),
          TextButton.icon(onPressed: () { setState(() { members.add(BudgetMember(name: 'New Member', amountDue: 0, isPaid: false, avatarIcon: Icons.person)); }); }, icon: const Icon(Icons.add, color: _accentYellow), label: const Text('Add Member', style: TextStyle(color: _accentYellow, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}