import 'package:flutter/material.dart';

class JoinPlanPage extends StatefulWidget {
  const JoinPlanPage({super.key});

  @override
  State<JoinPlanPage> createState() => _JoinPlanPageState();
}

class _JoinPlanPageState extends State<JoinPlanPage> {
  final joinCodeController = TextEditingController();

  @override
  void dispose() {
    joinCodeController.dispose();
    super.dispose();
  }

  // Moved the button logic here to keep the UI code clean
  void _handleJoinPlan() {
    if (joinCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a plan code or link first!"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    
    // TODO: Add your actual Join logic here later
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Joining Plan... 🌹"),
        backgroundColor: Colors.green,
      ),
    );
    
    // Optional: Navigator.pop(context); // Use this if you want the page to close after joining
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0), // Consistent Mobile Margin 24
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBackButton(context),
              const SizedBox(height: 24),
              _buildHeader(),
              const SizedBox(height: 32),
              _buildInputField(),
              const SizedBox(height: 32),
              _buildJoinButton(),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI Helper Methods ---

  Widget _buildBackButton(BuildContext context) {
    return TextButton.icon(
      onPressed: () => Navigator.pop(context),
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
        foregroundColor: const Color(0xFFFFB84D), 
      ),
      icon: const Icon(Icons.arrow_back_ios, size: 16),
      label: const Text("Back"),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Join Plan',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4),
        Text(
          "Enter the plan code or link to join.",
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildInputField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Plan Code / Link",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: joinCodeController,
          decoration: InputDecoration(
            hintText: 'Enter code or link',
            filled: true,
            fillColor: const Color(0xFFF5F5F5), // Slightly softer grey
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJoinButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _handleJoinPlan,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFB84D),
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Join Plan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}