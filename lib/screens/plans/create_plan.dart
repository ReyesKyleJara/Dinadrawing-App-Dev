import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
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
  Set<Marker> mapMarkers = {};
  LatLng? selectedLocation;
  String? selectedLocationLabel;
  _SelectionSource selectionSource = _SelectionSource.none;
  bool isMapExpanded = false;
  bool isSearchingLocations = false;
  List<_LocationResult> locationSuggestions = [];
  Timer? _locationSearchDebounce;
  StateSetter? _expandedMapSetState;

  @override
  void dispose() {
    _locationSearchDebounce?.cancel();
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
        const yellow = Color(0xFFFFB84D);
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: yellow,
              secondary: yellow,
              onPrimary: Colors.black,
            ),
            timePickerTheme: TimePickerThemeData(
              dayPeriodColor: yellow,
              dayPeriodTextColor: Colors.black,
              dialHandColor: yellow,
              dialBackgroundColor: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => selectedTime = picked);
  }

  Future<void> _searchLocation(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      _showSnackBar("Please enter a place to search", Colors.orangeAccent);
      return;
    }

    try {
      final locationResult = await _searchLocationWithFallback(trimmedQuery);
      if (locationResult == null) {
        _showSnackBar("No places found", Colors.orangeAccent);
        return;
      }

      await _updateSelectedLocation(
        locationResult.location,
        label: locationResult.label,
        source: _SelectionSource.search,
      );
    } catch (_) {
      _showSnackBar("Could not find that place", Colors.redAccent);
    }
  }

  void _onLocationQueryChanged(String query) {
    _locationSearchDebounce?.cancel();

    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 2) {
      setState(() {
        locationSuggestions = [];
        isSearchingLocations = false;
      });
      return;
    }

    _locationSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      _loadLocationSuggestions(trimmedQuery);
    });
  }

  Future<void> _loadLocationSuggestions(String query) async {
    if (!mounted) return;

    setState(() => isSearchingLocations = true);

    try {
      final suggestions = await _fetchLocationSuggestions(query);
      if (!mounted) return;

      setState(() {
        locationSuggestions = suggestions;
        isSearchingLocations = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        locationSuggestions = [];
        isSearchingLocations = false;
      });
    }
  }

  Future<List<_LocationResult>> _fetchLocationSuggestions(String query) async {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=${Uri.encodeQueryComponent(query)}&format=jsonv2&limit=5',
    );

    final response = await http.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'dinadrawing-app/1.0',
      },
    );

    if (response.statusCode != 200) {
      return [];
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      return [];
    }

    return decoded.map<_LocationResult>((item) {
      final locationData = item as Map<String, dynamic>;
      final latitude = double.tryParse(locationData['lat']?.toString() ?? '');
      final longitude = double.tryParse(locationData['lon']?.toString() ?? '');
      final displayName = locationData['display_name']?.toString() ?? query;

      if (latitude == null || longitude == null) {
        return _LocationResult(
          location: const LatLng(14.5995, 120.9842),
          label: displayName,
        );
      }

      return _LocationResult(
        location: LatLng(latitude, longitude),
        label: displayName,
      );
    }).where((result) => result.location.latitude != 14.5995 || result.location.longitude != 120.9842 || result.label.isNotEmpty).toList();
  }

  Future<_LocationResult?> _searchLocationWithFallback(String query) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeQueryComponent(query)}&format=jsonv2&limit=1',
      );

      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'dinadrawing-app/1.0',
        },
      );

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) {
        return null;
      }

      final first = decoded.first as Map<String, dynamic>;
      final latitude = double.tryParse(first['lat']?.toString() ?? '');
      final longitude = double.tryParse(first['lon']?.toString() ?? '');
      final displayName = first['display_name']?.toString();

      if (latitude == null || longitude == null) {
        return null;
      }

      return _LocationResult(
        location: LatLng(latitude, longitude),
        label: displayName ?? query,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String> _reverseGeocodeLabel(LatLng location) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${location.latitude}&lon=${location.longitude}&format=jsonv2',
      );

      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'dinadrawing-app/1.0',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final displayName = decoded['display_name']?.toString();
          if (displayName != null && displayName.isNotEmpty) {
            return displayName;
          }
        }
      }

      return '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}';
    } catch (_) {
      return '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}';
    }
  }

  Future<void> _updateSelectedLocation(
    LatLng location, {
    String? label,
    required _SelectionSource source,
  }) async {
    final readableLabel = label ?? await _reverseGeocodeLabel(location);

    if (!mounted) return;

    setState(() {
      selectedLocation = location;
      selectedLocationLabel = readableLabel;
      selectionSource = source;
      mapMarkers = {
        Marker(
          markerId: const MarkerId('selected-location'),
          position: location,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            source == _SelectionSource.search
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(title: readableLabel),
        ),
      };
      locationController.text = readableLabel;
    });

    _expandedMapSetState?.call(() {});

    await mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: location, zoom: 16),
      ),
    );
  }

  Future<void> _handleMapTap(LatLng tappedLocation) async {
    await _updateSelectedLocation(tappedLocation, source: _SelectionSource.tap);
  }

  Future<void> _selectSuggestion(_LocationResult suggestion) async {
    locationController.text = suggestion.label;
    setState(() {
      locationSuggestions = [];
    });
    await _updateSelectedLocation(
      suggestion.location,
      label: suggestion.label,
      source: _SelectionSource.search,
    );
  }

  Future<void> _showExpandedMap() async {
    setState(() => isMapExpanded = true);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, dialogSetState) {
            _expandedMapSetState = dialogSetState;

            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: SizedBox(
                height: MediaQuery.of(dialogContext).size.height * 0.75,
                width: double.infinity,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Pick a location',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              _expandedMapSetState = null;
                              Navigator.pop(dialogContext);
                            },
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: _buildGoogleMap(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (mounted) {
      setState(() => isMapExpanded = false);
      _expandedMapSetState = null;
    }
  }

  void _handleSavePlan() {
    if (planNameController.text.trim().isEmpty) {
      _showSnackBar("Please enter a plan name", Colors.redAccent);
      return;
    } 
    // Date and time are optional now. Only plan name is required.
    String formattedDate;
    if (selectedDate != null) {
      formattedDate = DateFormat('MMMM yyyy').format(selectedDate!);
    } else {
      formattedDate = "Date TBD";
    }
    
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
              _buildTextField(
                "Search for a location",
                locationController,
                icon: Icons.search,
                onSubmitted: _searchLocation,
                onChanged: _onLocationQueryChanged,
              ),
              if (isSearchingLocations) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(minHeight: 2),
              ],
              if (locationSuggestions.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildSuggestionList(),
              ],
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
              _buildFieldLabel("Date (optional)"),
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
              _buildFieldLabel("Time (optional)"),
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
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFF9F9F9),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _buildGoogleMap(),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.push_pin,
                      size: 16,
                      color: selectionSource == _SelectionSource.none
                          ? Colors.grey
                          : const Color(0xFF4CAF50),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      selectedLocationLabel == null ? 'Tap map to pin' : 'Pin selected',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: FloatingActionButton.small(
              heroTag: 'expand-map',
              backgroundColor: Colors.white,
              onPressed: _showExpandedMap,
              child: const Icon(Icons.open_in_full, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleMap() {
    final fallbackTarget = selectedLocation ?? const LatLng(14.5995, 120.9842);

    return GoogleMap(
      onMapCreated: (controller) {
        mapController = controller;
        if (selectedLocation != null) {
          controller.moveCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: selectedLocation!, zoom: 16),
            ),
          );
        }
      },
      initialCameraPosition: CameraPosition(
        target: fallbackTarget,
        zoom: selectedLocation == null ? 15 : 16,
      ),
      markers: mapMarkers,
      onTap: _handleMapTap,
      zoomControlsEnabled: true,
      compassEnabled: true,
      myLocationButtonEnabled: false,
      myLocationEnabled: false,
      mapToolbarEnabled: false,
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

  Widget _buildTextField(
    String hint,
    TextEditingController controller, {
    IconData? icon,
    ValueChanged<String>? onSubmitted,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
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

  Widget _buildSuggestionList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: locationSuggestions.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final suggestion = locationSuggestions[index];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.place_outlined, color: Color(0xFFFFB84D)),
            title: Text(
              suggestion.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _selectSuggestion(suggestion),
          );
        },
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

enum _SelectionSource { none, tap, search }

class _LocationResult {
  final LatLng location;
  final String label;

  const _LocationResult({required this.location, required this.label});
}