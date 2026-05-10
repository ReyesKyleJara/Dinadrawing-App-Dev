import 'package:flutter/material.dart';

class CreatePoll extends StatefulWidget {
  const CreatePoll({super.key});

  @override
  State<CreatePoll> createState() => _CreatePollScreenState();
}

class _CreatePollScreenState extends State<CreatePoll> {
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  bool _allowMultiple = false;
  bool _anonymous = true;
  bool _allowMembersAdd = false;
  String _endsOn = "1 Week"; // Default dropdown value

  void _submitPoll() {
    if (_questionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a question.")));
      return;
    }
    
    // Return the poll data back to the feed
    Navigator.pop(context, {
      'type': 'poll',
      'question': _questionController.text,
      'options': _optionControllers.map((c) => c.text).where((t) => t.isNotEmpty).toList(),
      'endsOn': _endsOn,
      'anonymous': _anonymous,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 100,
        leading: TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, size: 14, color: Color(0xFFF5B335)),
          label: const Text('Back', style: TextStyle(color: Color(0xFFF5B335), fontSize: 14)),
          style: TextButton.styleFrom(padding: const EdgeInsets.only(left: 24)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Create Poll", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text("Start a poll and collect member feedback", style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 24),

            _buildTextField(_questionController, "Poll Question"),
            const SizedBox(height: 16),
            
            ...List.generate(_optionControllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildTextField(_optionControllers[index], "Poll Option ${index + 1}"),
              );
            }),

            TextButton.icon(
              onPressed: () {
                setState(() => _optionControllers.add(TextEditingController()));
              },
              icon: const Icon(Icons.add, size: 16, color: Color(0xFFF5B335)),
              label: const Text("Add more option", style: TextStyle(color: Color(0xFFF5B335), fontSize: 13)),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
            ),

            const SizedBox(height: 24),
            const Text("Poll Settings", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            _buildSwitchRow("Allow multiple votes", _allowMultiple, (v) => setState(() => _allowMultiple = v)),
            _buildSwitchRow("Anonymous voting", _anonymous, (v) => setState(() => _anonymous = v)),
            _buildSwitchRow("Allow members to add options", _allowMembersAdd, (v) => setState(() => _allowMembersAdd = v)),

            const SizedBox(height: 24),
            const Text("Ends on", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _endsOn,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFF5B335)),
                  items: ["1 Day", "3 Days", "1 Week", "2 Weeks"].map((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(fontSize: 14)));
                  }).toList(),
                  onChanged: (val) => setState(() => _endsOn = val!),
                ),
              ),
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitPoll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5B335),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Create Poll", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }

  Widget _buildSwitchRow(String label, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFFF5B335),
          ),
        ],
      ),
    );
  }
}