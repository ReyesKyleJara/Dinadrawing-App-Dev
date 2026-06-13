import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
  bool isSearchingLocations = false;
  bool isSavingPlan = false;
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

  Future<void> _selectDate(BuildContext context) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: Color(0xFFFFB84D),
                    onPrimary: Colors.black,
                  )
                : const ColorScheme.light(
                    primary: Color(0xFFFFB84D),
                    onPrimary: Colors.black,
                  ),
            dialogTheme: DialogThemeData(
              backgroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final yellow = const Color(0xFFFFB84D);

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: Color(0xFFFFB84D),
                    secondary: Color(0xFFFFB84D),
                    onPrimary: Colors.black,
                  )
                : const ColorScheme.light(
                    primary: Color(0xFFFFB84D),
                    secondary: Color(0xFFFFB84D),
                    onPrimary: Colors.black,
                  ),
            timePickerTheme: TimePickerThemeData(
              dayPeriodColor: yellow,
              dayPeriodTextColor: theme.colorScheme.onSurface,
              dialHandColor: yellow,
              dialBackgroundColor: theme.colorScheme.surfaceContainerHighest,
              backgroundColor: theme.colorScheme.surface,
              hourMinuteTextColor: theme.colorScheme.onSurface,
              entryModeIconColor: yellow,
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

    return decoded
        .map<_LocationResult>((item) {
          final locationData = item as Map<String, dynamic>;
          final latitude =
              double.tryParse(locationData['lat']?.toString() ?? '');
          final longitude =
              double.tryParse(locationData['lon']?.toString() ?? '');
          final displayName =
              locationData['display_name']?.toString() ?? query;

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
        })
        .where(
          (result) =>
              result.location.latitude != 14.5995 ||
              result.location.longitude != 120.9842 ||
              result.label.isNotEmpty,
        )
        .toList();
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
    await _updateSelectedLocation(
      tappedLocation,
      source: _SelectionSource.tap,
    );
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
                          const Expanded(
                            child: Text(
                              'Pick a location',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
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
              _buildFieldLabel("Description"),
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

  Widget _buildBackButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextButton.icon(
      onPressed: isSavingPlan ? null : () => Navigator.pop(context),
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
        foregroundColor: colorScheme.primary,
      ),
      icon: const Icon(Icons.arrow_back_ios, size: 16),
      label: const Text("Back"),
    );
  }

  Widget _buildHeader() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create Plan',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Fill in the details to start planning',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outlineVariant),
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
                color: colorScheme.surface.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(20),
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
                          ? Colors.grey
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
                        color: colorScheme.onSurface,
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
              backgroundColor: colorScheme.surface,
              onPressed: _showExpandedMap,
              child: Icon(
                Icons.open_in_full,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleMap() {
    if (kIsWeb) {
      final colorScheme = Theme.of(context).colorScheme;

      return Container(
        color: colorScheme.surfaceContainerLow,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map, size: 48, color: colorScheme.onSurfaceVariant),
                const SizedBox(height: 12),
                Text(
                  'Map unavailable on Web.\nAdd the Google Maps JS API key to web/index.html or run on a device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
      onPressed: isSavingPlan ? null : _handleSavePlan,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFB84D),
        disabledBackgroundColor: Colors.grey.shade300,
        minimumSize: const Size(double.infinity, 55),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: colorScheme.onSurface,
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
    final colorScheme = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      style: TextStyle(color: colorScheme.onSurface),
      textInputAction:
          icon != null ? TextInputAction.search : TextInputAction.done,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        prefixIcon: icon != null
            ? Icon(
                icon,
                color: colorScheme.onSurfaceVariant,
                size: 20,
              )
            : null,
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildSuggestionList() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
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
            leading: const Icon(
              Icons.place_outlined,
              color: Color(0xFFFFB84D),
            ),
            title: Text(
              suggestion.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colorScheme.onSurface),
            ),
            onTap: () => _selectSuggestion(suggestion),
          );
        },
      ),
    );
  }

  Widget _buildPickerBox(String text, IconData icon, VoidCallback onTap) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isSelected = !text.contains('Select');

    return InkWell(
      onTap: isSavingPlan ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Text(
              text,
              style: TextStyle(
                color: isSelected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                fontSize: 14,
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

  const _LocationResult({
    required this.location,
    required this.label,
  });
}