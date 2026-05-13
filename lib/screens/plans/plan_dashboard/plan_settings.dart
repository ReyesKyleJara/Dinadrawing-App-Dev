import 'package:flutter/material.dart';

class PlanSettingsPage extends StatefulWidget {
  const PlanSettingsPage({super.key});

  @override
  State<PlanSettingsPage> createState() => _PlanSettingsPageState();
}

class _PlanSettingsPageState extends State<PlanSettingsPage> {
  // --- Controllers ---
  final TextEditingController _planNameController = TextEditingController(text: 'Siquijor 2026');
  final TextEditingController _planDescriptionController = TextEditingController();
  final TextEditingController _planDateController = TextEditingController(text: '01/2026');
  final TextEditingController _planLocationController = TextEditingController(text: 'Siquijor, Philippines');

  String _selectedStatus = 'Plan Ongoing';

  final List<_PlanStatus> _statusOptions = const [
    _PlanStatus(label: 'Plan Ongoing', color: Color(0xFFEAB308)), // Yellow
    _PlanStatus(label: 'Plan Postponed', color: Color(0xFF3B82F6)), // Blue
    _PlanStatus(label: 'Plan Canceled', color: Color(0xFFEF4444)), // Red
    _PlanStatus(label: 'Planned', color: Color(0xFF22C55E)), // Light Green
    _PlanStatus(label: 'Completed', color: Color(0xFF16A34A)), // Dark Green
  ];

  // --- Banner State Variables ---
  Color? _bannerColor;
  LinearGradient? _bannerGradient = const LinearGradient(
    colors: [Color(0xFF6B8DE3), Color(0xFF1E3A8A)], // Default blue gradient from your image
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  String? _bannerImagePath;

  // --- Standard Banner Options ---
  final List<Color> _solidColors = const [
    Color(0xFFF2B73F), Color(0xFF3B82F6), Color(0xFF10B981), 
    Color(0xFFEF4444), Color(0xFF8B5CF6), Color(0xFF1F2937),
  ];

  final List<LinearGradient> _gradients = const [
    LinearGradient(colors: [Color(0xFF6B8DE3), Color(0xFF1E3A8A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFFCD34D)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF10B981), Color(0xFF6EE7B7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFF9A8D4)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFC4B5FD)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  ];

  // --- Show Banner Picker Bottom Sheet ---
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
                child: Text("Change Banner", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 24),

              // Solid Colors
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text("Solid Colors", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
              ),
              const SizedBox(height: 12),
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
                          _bannerGradient = null;
                          _bannerImagePath = null;
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
              const SizedBox(height: 24),

              // Gradients
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text("Gradients", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: _gradients.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _bannerGradient = _gradients[index];
                          _bannerColor = null;
                          _bannerImagePath = null;
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 50,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(gradient: _gradients[index], shape: BoxShape.circle),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),

              // Upload Custom Image
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Image upload coming soon!")),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                      ),
                      const SizedBox(width: 16),
                      const Text("Upload Custom Image", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA), // Off-white background
      body: SafeArea(
        child: SingleChildScrollView(
          // STRICT 24px HORIZONTAL MARGIN
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- BACK BUTTON ---
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

              // --- TITLE ---
              const Text(
                'Settings',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 24),

              // --- SECTION 1: PLAN DETAILS ---
              const Text('Plan Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 16),

              // DYNAMIC PLAN HEADER (Banner)
              _buildFieldLabel('Plan Header'),
              const SizedBox(height: 8),
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: _bannerColor,
                  gradient: _bannerColor == null && _bannerImagePath == null ? _bannerGradient : null,
                  image: _bannerImagePath != null 
                      ? DecorationImage(image: AssetImage(_bannerImagePath!), fit: BoxFit.cover) 
                      : null,
                ),
                alignment: Alignment.bottomRight,
                padding: const EdgeInsets.all(12),
                child: GestureDetector(
                  onTap: _showBannerPicker, // Opens the bottom sheet!
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3), // Dark translucent background for visibility
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, color: Colors.white, size: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Plan Name
              _buildFieldLabel('Plan Name'),
              const SizedBox(height: 8),
              _buildTextField(controller: _planNameController, hint: 'Plan Name'),
              const SizedBox(height: 16),

              // Plan Description
              _buildFieldLabel('Plan Description'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _planDescriptionController,
                hint: 'Type Plan Description...',
                maxLines: 4,
              ),
              const SizedBox(height: 16),

              // Plan Date & Time
              _buildFieldLabel('Plan Date & Time'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _planDateController,
                hint: 'MM/YYYY',
                suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18, color: Colors.black54),
              ),
              const SizedBox(height: 16),

              // Plan Location
              _buildFieldLabel('Plan Location'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _planLocationController,
                hint: 'Location',
                suffixIcon: const Icon(Icons.edit_outlined, size: 18, color: Colors.black54),
              ),
              const SizedBox(height: 24),

              // --- SECTION 2: PLAN STATUS ---
              const Text('Plan Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 16),
              
              _buildFieldLabel('Current Status'),
              const SizedBox(height: 8),
              
              // Dropdown
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
                    icon: const Padding(
                      padding: EdgeInsets.only(right: 12.0),
                      child: Icon(Icons.arrow_drop_down, color: Colors.black),
                    ),
                    items: _statusOptions.map((status) {
                      return DropdownMenuItem<String>(
                        value: status.label,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(color: status.color, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 12),
                              Text(status.label, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedStatus = value);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // --- SAVE CHANGES BUTTON ---
              Center(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF2B73F), // Yellow color
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Save Changes', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 32),

              // --- DANGER ZONE (Leave / Delete) ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9F9), // Very subtle background box like in the image
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Once you leave or delete this plan,\nyou will lose access to its details.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE5E7EB), // Light gray
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Leave Plan', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD9534F), // Red
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Delete Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI Helpers ---

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    Widget? suffixIcon,
  }) {
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFF2B73F), width: 1.5),
        ),
      ),
    );
  }
}

class _PlanStatus {
  final String label;
  final Color color;
  const _PlanStatus({required this.label, required this.color});
}