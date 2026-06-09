import 'package:flutter/material.dart';
import '../../../services/plan_service.dart';

class PlanSettingsPage extends StatefulWidget {
  final int planId; // Tatanggapin na natin ang ID

  const PlanSettingsPage({super.key, required this.planId});

  @override
  State<PlanSettingsPage> createState() => _PlanSettingsPageState();
}

class _PlanSettingsPageState extends State<PlanSettingsPage> {
  // --- Controllers ---
  final TextEditingController _planNameController = TextEditingController();
  final TextEditingController _planDescriptionController = TextEditingController();
  final TextEditingController _planDateController = TextEditingController();
  final TextEditingController _planLocationController = TextEditingController();

  String _selectedStatus = 'Plan Ongoing';
  Color? _bannerColor;
  
  bool _isLoading = true;
  bool _isSaving = false;

  final List<_PlanStatus> _statusOptions = const [
    _PlanStatus(label: 'Plan Ongoing', color: Color(0xFFEAB308)),
    _PlanStatus(label: 'Plan Postponed', color: Color(0xFF3B82F6)),
    _PlanStatus(label: 'Plan Canceled', color: Color(0xFFEF4444)),
    _PlanStatus(label: 'Planned', color: Color(0xFF22C55E)),
    _PlanStatus(label: 'Completed', color: Color(0xFF16A34A)),
  ];

  // Eksaktong mga kulay galing sa Laravel backend mo
  final List<Color> _solidColors = const [
    Color(0xFFFF8243), Color(0xFFFFC0CB), Color(0xFFFCE883),
    Color(0xFF069494), Color(0xFFFF4F79), Color(0xFF00C2A8),
    Color(0xFFFFD166), Color(0xFF2F80ED), Color(0xFFF7F7FF),
  ];

  @override
  void initState() {
    super.initState();
    _loadPlanDetails();
  }

  // --- KUNIN ANG DATA SA DATABASE ---
  Future<void> _loadPlanDetails() async {
    try {
      final result = await PlanService.getPlanById(widget.planId);
      if (mounted && result['plan'] != null) {
        final plan = result['plan'];
        setState(() {
          _planNameController.text = plan['title'] ?? '';
          _planDescriptionController.text = plan['description'] ?? '';
          _planDateController.text = plan['plan_date'] ?? '';
          _planLocationController.text = plan['location'] ?? '';
          _selectedStatus = plan['status'] ?? 'Plan Ongoing';
          
          if (plan['banner_color'] != null) {
            String hex = plan['banner_color'].toString().replaceAll('#', '');
            if (hex.length == 6) hex = 'FF$hex';
            _bannerColor = Color(int.parse(hex, radix: 16));
          } else {
            _bannerColor = const Color(0xFF2F80ED);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading plan: $e');
      setState(() => _isLoading = false);
    }
  }

  bool _isDeleting = false;

  Future<void> _deletePlan() async {
    // 1. Ipakita muna ang confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Plan?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('This will move the plan to Deleted Plans. It will be permanently deleted after 30 days.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);

    try {
      final result = await PlanService.deletePlan(widget.planId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Plan deleted.')),
        );
        // 2. Pagkatapos ma-delete, isasara ang Settings AT Dashboard para bumalik sa My Plans list
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _saveChanges() async {
    if (_planNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan Name is required!')),
      );
      return;
    }

    setState(() => _isSaving = true);

    String hexColor = '#${_bannerColor!.value.toRadixString(16).substring(2).toUpperCase()}';

    try {
      final result = await PlanService.updatePlan(
        planId: widget.planId,
        title: _planNameController.text.trim(),
        description: _planDescriptionController.text.trim(),
        planDate: _planDateController.text.trim(),
        location: _planLocationController.text.trim(),
        status: _selectedStatus,
        bannerColor: hexColor,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Settings saved!')),
        );
        Navigator.pop(context, true); // I-pop at magpasa ng 'true' para mag-refresh ang Dashboard
      }
    } catch (e) {
      print('Error saving plan: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showBannerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text("Change Banner Color", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: _solidColors.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _bannerColor = _solidColors[index];
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 50,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(color: _solidColors[index], shape: BoxShape.circle),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _planNameController.dispose();
    _planDescriptionController.dispose();
    _planDateController.dispose();
    _planLocationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFAFAFA),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFF2B73F))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Row(
                  children: const [
                    Icon(Icons.arrow_back, color: Color(0xFFF2B73F), size: 20),
                    SizedBox(width: 8),
                    Text('Back', style: TextStyle(color: Colors.black87, fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Settings',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 24),

              const Text('Plan Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 16),

              _buildFieldLabel('Plan Header'),
              const SizedBox(height: 8),
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: _bannerColor,
                ),
                alignment: Alignment.bottomRight,
                padding: const EdgeInsets.all(12),
                child: GestureDetector(
                  onTap: _showBannerPicker,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, color: Colors.white, size: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _buildFieldLabel('Plan Name'),
              const SizedBox(height: 8),
              _buildTextField(controller: _planNameController, hint: 'Plan Name'),
              const SizedBox(height: 16),

              _buildFieldLabel('Plan Description'),
              const SizedBox(height: 8),
              _buildTextField(controller: _planDescriptionController, hint: 'Type Plan Description...', maxLines: 4),
              const SizedBox(height: 16),

              _buildFieldLabel('Plan Date & Time'),
              const SizedBox(height: 8),
              _buildTextField(controller: _planDateController, hint: 'YYYY-MM-DD', suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18, color: Colors.black54)),
              const SizedBox(height: 16),

              _buildFieldLabel('Plan Location'),
              const SizedBox(height: 8),
              _buildTextField(controller: _planLocationController, hint: 'Location', suffixIcon: const Icon(Icons.edit_outlined, size: 18, color: Colors.black54)),
              const SizedBox(height: 24),

              const Text('Plan Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 16),
              
              _buildFieldLabel('Current Status'),
              const SizedBox(height: 8),
              
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedStatus,
                    isExpanded: true,
                    icon: const Padding(padding: EdgeInsets.only(right: 12.0), child: Icon(Icons.arrow_drop_down, color: Colors.black)),
                    items: _statusOptions.map((status) {
                      return DropdownMenuItem<String>(
                        value: status.label,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Row(
                            children: [
                              Container(width: 10, height: 10, decoration: BoxDecoration(color: status.color, shape: BoxShape.circle)),
                              const SizedBox(width: 12),
                              Text(status.label, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _selectedStatus = value);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32),

              Center(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges, // TINATAWAG DITO YUNG SAVE FUNCTION
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF2B73F),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isSaving 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black))
                    : const Text('Save Changes', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) => Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black));

  Widget _buildTextField({required TextEditingController controller, required String hint, int maxLines = 1, Widget? suffixIcon}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, color: Colors.black54),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFF2B73F), width: 1.5)),
      ),
    );
  }
}

class _PlanStatus {
  final String label;
  final Color color;
  const _PlanStatus({required this.label, required this.color});
}