import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../../services/plan_service.dart';
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
  bool isSavingPlan = false;
  StateSetter? _expandedMapSetState;

  @override
  void dispose() {
    planNameController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    mapController?.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        final theme = Theme.of(context);
        final colors = theme.colorScheme;

        return Theme(
          data: theme.copyWith(
            colorScheme: colors.copyWith(
              primary: const Color(0xFFFFB84D),
              onPrimary: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        const yellow = Color(0xFFFFB84D);
        final theme = Theme.of(context);
        final colors = theme.colorScheme;

        return Theme(
          data: theme.copyWith(
            colorScheme: colors.copyWith(
              primary: yellow,
              secondary: yellow,
              onPrimary: Colors.black,
            ),
            timePickerTheme: theme.timePickerTheme.copyWith(
              dayPeriodColor: yellow,
              dayPeriodTextColor: Colors.black,
              dialHandColor: yellow,
              dialBackgroundColor: colors.surfaceContainerHighest,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => selectedTime = picked);
    }
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

  Future<void> _showExpandedMap() async {
    setState(() => isMapExpanded = true);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, dialogSetState) {
            _expandedMapSetState = dialogSetState;

            final theme = Theme.of(dialogContext);
            final colors = theme.colorScheme;

            return Dialog(
              backgroundColor: colors.surface,
              surfaceTintColor: colors.surface,
              insetPadding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: SizedBox(
                height: MediaQuery.of(dialogContext).size.height * 0.75,
                width: double.infinity,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Pick a location',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              _expandedMapSetState = null;
                              Navigator.pop(dialogContext);
                            },
                            color: colors.onSurface,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: colors.outlineVariant),
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

  Future<void> _handleSavePlan() async {
    if (planNameController.text.trim().isEmpty) {
      _showSnackBar("Please enter a plan name", Colors.redAccent);
      return;
    }

    setState(() {
      isSavingPlan = true;
    });

    try {
      final planDateForApi = selectedDate == null
          ? null
          : DateFormat('yyyy-MM-dd').format(selectedDate!);

      final planTimeForApi = selectedTime == null
          ? null
          : '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}';

      final result = await PlanService.createPlan(
        title: planNameController.text.trim(),
        description: descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
        planDate: planDateForApi,
        planTime: planTimeForApi,
        location: locationController.text.trim().isEmpty
            ? null
            : locationController.text.trim(),
        latitude: selectedLocation?.latitude,
        longitude: selectedLocation?.longitude,
        status: 'Plan Ongoing',
      );

      print('CREATE PLAN RESULT: $result');

      if (!mounted) return;

      if (result.containsKey('plan')) {
        final plan = result['plan'] as Map<String, dynamic>;

        _showSnackBar("Plan created successfully!", Colors.green);

        final createdPlanId = plan['id'];

        if (createdPlanId == null) {
          _showSnackBar(
            'Plan created, but unable to open dashboard. Missing plan ID.',
            Colors.redAccent,
          );
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PlanDashboardScreen(
              planId: createdPlanId is int
                  ? createdPlanId
                  : int.parse(createdPlanId.toString()),
            ),
          ),
        );
      } else {
        String errorMessage = result['message'] ?? 'Failed to create plan.';

        if (result['errors'] != null &&
            result['errors'] is Map<String, dynamic>) {
          final errors = result['errors'] as Map<String, dynamic>;

          if (errors.isNotEmpty) {
            final firstError = errors.values.first;

            if (firstError is List && firstError.isNotEmpty) {
              errorMessage = firstError.first.toString();
            }
          }
        }

        _showSnackBar(errorMessage, Colors.redAccent);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar("Connection error: $e", Colors.redAccent);
    } finally {
      if (mounted) {
        setState(() {
          isSavingPlan = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
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
              _buildFieldLabel("Description (optional)"),
              _buildTextField(
                "Enter a short description",
                descriptionController,
              ),
              const SizedBox(height: 24),
              _buildDateTimeFields(context),
              const SizedBox(height: 24),
              _buildFieldLabel("Location"),
              _buildTextField(
                "Search for a location",
                locationController,
                icon: Icons.search,
                onSubmitted: _searchLocation,
              ),
              const SizedBox(height: 6),
              Text(
                'Press Enter/Search to locate • Search data © OpenStreetMap contributors',
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
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

  Widget _buildBackButton(BuildContext context) {
    return TextButton.icon(
      onPressed: isSavingPlan ? null : () => Navigator.pop(context),
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
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Create Plan",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Fill in the details to start planning",
          style: TextStyle(color: colors.onSurfaceVariant),
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
                selectedDate == null
                    ? "Select Date"
                    : DateFormat('MMM dd, yyyy').format(selectedDate!),
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
                selectedTime == null
                    ? "Select Time"
                    : selectedTime!.format(context),
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
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colors.surfaceContainerHighest,
        border: Border.all(color: colors.outlineVariant),
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
                color: colors.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.outlineVariant),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.push_pin,
                      size: 16,
                      color: selectionSource == _SelectionSource.none
                          ? colors.onSurfaceVariant
                          : const Color(0xFF4CAF50),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      selectedLocationLabel == null
                          ? 'Tap map to pin'
                          : 'Pin selected',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
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
              backgroundColor: colors.surface,
              foregroundColor: colors.onSurface,
              onPressed: _showExpandedMap,
              child: const Icon(Icons.open_in_full),
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
    final colors = Theme.of(context).colorScheme;

    return ElevatedButton(
      onPressed: isSavingPlan ? null : _handleSavePlan,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFB84D),
        disabledBackgroundColor: colors.surfaceContainerHighest,
        minimumSize: const Size(double.infinity, 55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: isSavingPlan
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.black,
              ),
            )
          : const Text(
              'Save & Continue',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black,
              ),
            ),
    );
  }

  Widget _buildFieldLabel(String label) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: colors.onSurface,
        ),
      ),
    );
  }

  Widget _buildTextField(
    String hint,
    TextEditingController controller, {
    IconData? icon,
    ValueChanged<String>? onSubmitted,
    ValueChanged<String>? onChanged,
  }) {
    final colors = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      style: TextStyle(color: colors.onSurface),
      cursorColor: const Color(0xFFFFB84D),
      textInputAction: icon != null
          ? TextInputAction.search
          : TextInputAction.done,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: colors.onSurfaceVariant),
        prefixIcon: icon != null
            ? Icon(icon, color: colors.onSurfaceVariant, size: 20)
            : null,
        filled: true,
        fillColor: colors.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFB84D), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildPickerBox(String text, IconData icon, VoidCallback onTap) {
    final bool isSelected = !text.contains("Select");
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: isSavingPlan ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? const Color(0xFFFFB84D)
                  : colors.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected
                      ? colors.onSurface
                      : colors.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ),
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
