import 'package:flutter/material.dart';

class CreateTask extends StatefulWidget {
  const CreateTask({super.key});

  @override
  State<CreateTask> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTask> {
  final TextEditingController _titleController = TextEditingController();
  final List<TextEditingController> _taskControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  bool _allowMembersAdd = false;
  bool _setDeadlines = true;

  void _submitTasks() {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a Task Title.")));
      return;
    }
    
    Navigator.pop(context, {
      'type': 'task',
      'title': _titleController.text,
      'tasks': _taskControllers.map((c) => c.text).where((t) => t.isNotEmpty).toList(),
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
            const Text("Assigned Tasks", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text("Add tasks and set deadlines for members.", style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 24),

            _buildTextField(_titleController, "Task Title"),
            const SizedBox(height: 16),
            
            ...List.generate(_taskControllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildTextField(_taskControllers[index], "List a task"),
              );
            }),

            TextButton.icon(
              onPressed: () {
                setState(() => _taskControllers.add(TextEditingController()));
              },
              icon: const Icon(Icons.add, size: 16, color: Color(0xFFF5B335)),
              label: const Text("Add more task", style: TextStyle(color: Color(0xFFF5B335), fontSize: 13)),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
            ),

            const SizedBox(height: 24),
            const Text("Assigned task settings", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            _buildSwitchRow("Allow members to add tasks", _allowMembersAdd, (v) => setState(() => _allowMembersAdd = v)),
            _buildSwitchRow("Set Deadlines", _setDeadlines, (v) => setState(() => _setDeadlines = v)),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitTasks,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5B335),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Create Task List", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
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
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFFF5B335),
          ),
        ],
      ),
    );
  }
}