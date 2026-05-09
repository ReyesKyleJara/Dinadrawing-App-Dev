import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'plan_dashboard/plan_dashboard.dart';

class CreatePlanPage extends StatefulWidget {
  const CreatePlanPage({super.key});

  @override
  State<CreatePlanPage> createState() => _CreatePlanPageState();
}

class _CreatePlanPageState extends State<CreatePlanPage> {
  final planNameController = TextEditingController();
  final descriptionController = TextEditingController();
  final locationController = TextEditingController();

  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  GoogleMapController? mapController;

  @override
  void dispose() {
    planNameController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    mapController?.dispose();
    super.dispose();
  }

  // --- Logic Methods ---

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFFB84D),
              onPrimary: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFFFFB84D)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => selectedTime = picked);
  }

  void _handleSavePlan() {
    if (planNameController.text.trim().isEmpty) {
      _showSnackBar("Please enter a plan name", Colors.redAccent);
      return;
    } 
    if (selectedDate == null || selectedTime == null) {
      _showSnackBar("Please select both date and time", Colors.orangeAccent);
      return;
    }

    String formattedDate = DateFormat('MMMM yyyy').format(selectedDate!);
    
    String locationText = locationController.text.isNotEmpty 
        ? locationController.text 
        : "Location TBD";
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PlanDashboardScreen(
          planName: planNameController.text.trim(),
          planDate: formattedDate,
          planLocation: locationText,
        ),
      ),
    );
    
    _showSnackBar("Plan created successfully!", Colors.green);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  // --- Main Build Method ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBackButton(context),
              const SizedBox(height: 24),
              _buildHeader(),
              const SizedBox(height: 24),

              _buildFieldLabel("Plan Name (required)"),
              _buildTextField("Enter a plan name", planNameController),
              const SizedBox(height: 24),

              _buildDateTimeFields(context),
              const SizedBox(height: 24),

              _buildFieldLabel("Location"),
              _buildTextField("Search for a location", locationController, icon: Icons.search),
              const SizedBox(height: 12),
              
              _buildMapPlaceholder(),
              const SizedBox(height: 32),
              
              _buildSaveButton(),
              const SizedBox(height: 40),
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
          "Create Plan", 
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4),
        Text(
          "Fill in the details to start planning", 
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildDateTimeFields(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFieldLabel("Date"),
              _buildPickerBox(
                selectedDate == null ? "Select Date" : DateFormat('MMM dd, yyyy').format(selectedDate!),
                Icons.calendar_today,
                () => _selectDate(context),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFieldLabel("Time"),
              _buildPickerBox(
                selectedTime == null ? "Select Time" : selectedTime!.format(context),
                Icons.access_time,
                () => _selectTime(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMapPlaceholder() {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFF9F9F9),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GoogleMap(
          onMapCreated: (controller) {
            setState(() {
              mapController = controller;
            });
          },
          initialCameraPosition: const CameraPosition(
            target: LatLng(14.5995, 120.9842),
            zoom: 15,
          ),
          onCameraMove: (CameraPosition position) {
            if (mounted) {
              locationController.text = '${position.target.latitude.toStringAsFixed(4)}, ${position.target.longitude.toStringAsFixed(4)}';
            }
          },
          onCameraIdle: () {},
          zoomControlsEnabled: true,
          myLocationButtonEnabled: false,
          myLocationEnabled: false,
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _handleSavePlan,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFB84D),
        minimumSize: const Size(double.infinity, 55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: const Text(
        'Save & Continue', 
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller, {IconData? icon}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, color: Colors.grey, size: 20) : null,
        filled: true,
        fillColor: const Color(0xFFF9F9F9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildPickerBox(String text, IconData icon, VoidCallback onTap) {
    bool isSelected = !text.contains("Select");
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9F9), 
          borderRadius: BorderRadius.circular(12)
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? const Color(0xFFFFB84D) : Colors.grey),
            const SizedBox(width: 10),
            Text(text, style: TextStyle(color: isSelected ? Colors.black : Colors.grey, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}