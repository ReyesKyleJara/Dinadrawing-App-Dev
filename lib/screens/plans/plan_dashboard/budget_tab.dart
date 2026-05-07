import 'package:flutter/material.dart';

class BudgetTab extends StatelessWidget {
  const BudgetTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Set your budget for this plan!", 
        style: TextStyle(color: Colors.grey, fontSize: 16),
      ),
    );
  }
}