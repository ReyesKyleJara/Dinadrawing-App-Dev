import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../services/auth_service.dart';
import '../../../services/plan_service.dart';
import '../../../theme/plan_theme_palette.dart';

class PlanSettingsPage extends StatefulWidget {
  const PlanSettingsPage({super.key, required this.planId});

  final int planId;

  @override
  State<PlanSettingsPage> createState() {
    return _PlanSettingsPageState();
  }
}

class _PlanSettingsPageState extends State<PlanSettingsPage> {
  static const Color _brandYellow = Color(0xFFF2B73F);
  static const Color _brandYellowDark = Color(0xFFD89B22);

  final TextEditingController _planNameController = TextEditingController();
  final TextEditingController _planDescriptionController =
      TextEditingController();
  final TextEditingController _planDateController = TextEditingController();
  final TextEditingController _planLocationController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  final List<_PlanStatus> _statusOptions = const <_PlanStatus>[
    _PlanStatus(label: 'Plan Ongoing', color: Color(0xFFEAB308)),
    _PlanStatus(label: 'Plan Postponed', color: Color(0xFF3B82F6)),
    _PlanStatus(label: 'Plan Canceled', color: Color(0xFFEF4444)),
    _PlanStatus(label: 'Planned', color: Color(0xFF22C55E)),
    _PlanStatus(label: 'Completed', color: Color(0xFF16A34A)),
  ];

  final List<Color> _bannerPresetColors = const <Color>[
    Color(0xFFFF8243),
    Color(0xFFFFC0CB),
    Color(0xFFFCE883),
    Color(0xFF069494),
    Color(0xFFFF4F79),
    Color(0xFF00C2A8),
    Color(0xFFFFD166),
    Color(0xFF2F80ED),
    Color(0xFFF7F7FF),
  ];

  String _selectedStatus = 'Plan Ongoing';
  Color _bannerColor = const Color(0xFF2F80ED);
  String _themeColorHex = PlanThemePalette.defaultHex;

  String? _bannerImageUrl;
  File? _pendingBannerImage;
  bool _removeBannerImage = false;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isLeaving = false;
  bool _didSave = false;

  int? _currentUserId;
  int? _adminId;
  List<Map<String, dynamic>> _members = <Map<String, dynamic>>[];

  String _initialName = '';
  String _initialDescription = '';
  String _initialDate = '';
  String _initialLocation = '';
  String _initialStatus = 'Plan Ongoing';
  String _initialBannerColor = '#2F80ED';
  String _initialThemeColor = PlanThemePalette.defaultHex;
  String? _initialBannerImageUrl;

  bool get _isAdmin {
    return _currentUserId != null && _adminId == _currentUserId;
  }

  bool get _hasChanges {
    if (_isLoading) {
      return false;
    }

    return _planNameController.text.trim() != _initialName ||
        _planDescriptionController.text.trim() != _initialDescription ||
        _planDateController.text.trim() != _initialDate ||
        _planLocationController.text.trim() != _initialLocation ||
        _selectedStatus != _initialStatus ||
        PlanThemePalette.toHex(_bannerColor) != _initialBannerColor ||
        _themeColorHex != _initialThemeColor ||
        _pendingBannerImage != null ||
        _removeBannerImage ||
        _bannerImageUrl != _initialBannerImageUrl;
  }

  List<Map<String, dynamic>> get _transferableMembers {
    return _members.where((member) {
      final memberId = _parseInt(member['id']);
      final pivot = _asMap(member['pivot']);
      final role = pivot?['role']?.toString().toLowerCase();

      return memberId != null && memberId != _currentUserId && role != 'admin';
    }).toList();
  }

  @override
  void initState() {
    super.initState();

    for (final controller in <TextEditingController>[
      _planNameController,
      _planDescriptionController,
      _planDateController,
      _planLocationController,
    ]) {
      controller.addListener(_refreshSaveState);
    }

    _loadPlanDetails();
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _planNameController,
      _planDescriptionController,
      _planDateController,
      _planLocationController,
    ]) {
      controller.removeListener(_refreshSaveState);
      controller.dispose();
    }

    super.dispose();
  }

  void _refreshSaveState() {
    if (mounted) {
      setState(() {});
    }
  }

  int? _parseInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString());
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  String _memberDisplayName(Map<String, dynamic> member) {
    final name = member['name']?.toString().trim();
    final username = member['username']?.toString().trim();
    final email = member['email']?.toString().trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    if (username != null && username.isNotEmpty) {
      return username.startsWith('@') ? username : '@$username';
    }

    if (email != null && email.isNotEmpty) {
      return email;
    }

    return 'Member';
  }

  String _memberSubtitle(Map<String, dynamic> member) {
    final email = member['email']?.toString().trim();
    final username = member['username']?.toString().trim();

    if (email != null && email.isNotEmpty) {
      return email;
    }

    if (username != null && username.isNotEmpty) {
      return username.startsWith('@') ? username : '@$username';
    }

    return 'Plan member';
  }

  Future<void> _loadPlanDetails() async {
    try {
      final user = await AuthService.getCurrentUser();
      final result = await PlanService.getPlanById(widget.planId);

      if (!mounted) {
        return;
      }

      final plan = _asMap(result['plan']);

      if (plan == null) {
        setState(() {
          _isLoading = false;
        });

        _showMessage(
          result['message']?.toString() ?? 'Plan not found.',
          isError: true,
        );
        return;
      }

      final userMap = _asMap(user);
      final currentUser = _asMap(userMap?['user']) ?? userMap;
      final admin = _asMap(plan['admin']);
      final rawMembers = plan['members'];

      _currentUserId = _parseInt(currentUser?['id']);
      _adminId = _parseInt(plan['admin_id'] ?? admin?['id']);

      _members = rawMembers is List
          ? rawMembers
                .whereType<Map>()
                .map((member) => Map<String, dynamic>.from(member))
                .toList()
          : <Map<String, dynamic>>[];

      _planNameController.text = plan['title']?.toString() ?? '';
      _planDescriptionController.text = plan['description']?.toString() ?? '';
      _planDateController.text = plan['plan_date']?.toString() ?? '';
      _planLocationController.text = plan['location']?.toString() ?? '';
      _selectedStatus = plan['status']?.toString() ?? 'Plan Ongoing';
      _bannerColor = PlanThemePalette.parseHex(
        plan['banner_color']?.toString(),
        fallback: const Color(0xFF2F80ED),
      );
      _themeColorHex =
          plan['theme_color']?.toString().toUpperCase() ??
          PlanThemePalette.defaultHex;
      _bannerImageUrl = plan['banner_image_url']?.toString();

      _captureInitialValues();

      setState(() {
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('PLAN SETTINGS LOAD ERROR: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      _showMessage('Unable to load plan settings.', isError: true);
    }
  }

  void _captureInitialValues() {
    _initialName = _planNameController.text.trim();
    _initialDescription = _planDescriptionController.text.trim();
    _initialDate = _planDateController.text.trim();
    _initialLocation = _planLocationController.text.trim();
    _initialStatus = _selectedStatus;
    _initialBannerColor = PlanThemePalette.toHex(_bannerColor);
    _initialThemeColor = _themeColorHex;
    _initialBannerImageUrl = _bannerImageUrl;
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    final colors = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colors.error : null,
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (!_isAdmin) {
      _showMessage(
        'Only the plan admin can edit plan settings.',
        isError: true,
      );
      return;
    }

    if (!_hasChanges || _isSaving) {
      return;
    }

    if (_planNameController.text.trim().isEmpty) {
      _showMessage('Plan Name is required.', isError: true);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final detailResult = await PlanService.updatePlan(
        planId: widget.planId,
        title: _planNameController.text.trim(),
        description: _planDescriptionController.text.trim(),
        planDate: _planDateController.text.trim(),
        location: _planLocationController.text.trim(),
        status: _selectedStatus,
      );

      if (detailResult['success'] != true) {
        throw Exception(
          detailResult['message']?.toString() ?? 'Unable to save plan details.',
        );
      }

      final appearanceResult = await PlanService.updatePlanAppearance(
        planId: widget.planId,
        bannerColor: PlanThemePalette.toHex(_bannerColor),
        themeColor: _themeColorHex,
        bannerImageFile: _pendingBannerImage,
        removeBannerImage: _removeBannerImage,
      );

      if (appearanceResult['success'] != true) {
        throw Exception(
          appearanceResult['message']?.toString() ??
              'Unable to save plan appearance.',
        );
      }

      final updatedPlan = _asMap(appearanceResult['plan']);

      if (updatedPlan != null) {
        _bannerImageUrl = updatedPlan['banner_image_url']?.toString();
        _themeColorHex =
            updatedPlan['theme_color']?.toString().toUpperCase() ??
            _themeColorHex;
      } else if (_removeBannerImage) {
        _bannerImageUrl = null;
      }

      _pendingBannerImage = null;
      _removeBannerImage = false;
      _didSave = true;
      _captureInitialValues();

      if (!mounted) {
        return;
      }

      setState(() {});
      _showMessage('Changes saved.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error.toString().replaceFirst('Exception: ', '');
      _showMessage(message, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _pickBannerImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );

    if (picked == null || !mounted) {
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      maxWidth: 1600,
      maxHeight: 900,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Plan Banner',
          toolbarColor: isDark ? const Color(0xFF171717) : Colors.white,
          toolbarWidgetColor: isDark ? Colors.white : Colors.black,
          backgroundColor: isDark ? const Color(0xFF101010) : Colors.white,
          activeControlsWidgetColor: _brandYellow,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Crop Plan Banner',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          doneButtonTitle: 'Use Banner',
          cancelButtonTitle: 'Cancel',
        ),
      ],
    );

    if (cropped == null || !mounted) {
      return;
    }

    setState(() {
      _pendingBannerImage = File(cropped.path);
      _removeBannerImage = false;
    });
  }

  Future<void> _showCustomBannerColor() async {
    Color temporaryColor = _bannerColor;

    final selected = await showDialog<Color>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colors = theme.colorScheme;

        return AlertDialog(
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Custom Banner Color',
            style: theme.textTheme.titleLarge?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: temporaryColor,
              onColorChanged: (color) {
                temporaryColor = color;
              },
              enableAlpha: false,
              displayThumbColor: true,
              pickerAreaHeightPercent: 0.78,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, temporaryColor);
              },
              style: FilledButton.styleFrom(
                backgroundColor: _brandYellow,
                foregroundColor: Colors.black,
              ),
              child: const Text(
                'Use Color',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _bannerColor = selected;
    });
  }

  Future<void> _showBannerEditor() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final theme = Theme.of(sheetContext);
            final colors = theme.colorScheme;

            void refreshBoth(VoidCallback callback) {
              setState(callback);
              setSheetState(() {});
            }

            return Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.outlineVariant,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Plan Banner',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    Text(
                      'Choose a preset, use a custom color, or upload a cropped image.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildBannerPreview(height: 150),
                    const SizedBox(height: 22),
                    Text(
                      'PRESET COLORS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _bannerPresetColors.map((color) {
                        final selected =
                            PlanThemePalette.toHex(color) ==
                            PlanThemePalette.toHex(_bannerColor);

                        return InkWell(
                          onTap: () {
                            refreshBoth(() {
                              _bannerColor = color;
                            });
                          },
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? colors.onSurface
                                    : colors.outlineVariant,
                                width: selected ? 3 : 1,
                              ),
                            ),
                            child: selected
                                ? Icon(
                                    Icons.check_rounded,
                                    color: PlanThemePalette.contrastColor(
                                      color,
                                    ),
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await _showCustomBannerColor();

                        if (sheetContext.mounted) {
                          setSheetState(() {});
                        }
                      },
                      icon: const Icon(Icons.palette_outlined),
                      label: const Text('Custom Color'),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'BANNER IMAGE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () async {
                              await _pickBannerImage();

                              if (sheetContext.mounted) {
                                setSheetState(() {});
                              }
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: _brandYellow,
                              foregroundColor: Colors.black,
                              minimumSize: const Size.fromHeight(48),
                            ),
                            icon: const Icon(Icons.image_outlined),
                            label: Text(
                              _pendingBannerImage != null ||
                                      (_bannerImageUrl?.isNotEmpty ?? false)
                                  ? 'Change / Re-crop'
                                  : 'Upload Image',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        if (_pendingBannerImage != null ||
                            (_bannerImageUrl?.isNotEmpty ?? false)) ...<Widget>[
                          const SizedBox(width: 10),
                          IconButton.outlined(
                            tooltip: 'Remove banner image',
                            onPressed: () {
                              refreshBoth(() {
                                _pendingBannerImage = null;
                                _bannerImageUrl = null;
                                _removeBannerImage = true;
                              });
                            },
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: colors.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showThemeEditor() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final theme = Theme.of(sheetContext);
            final colors = theme.colorScheme;
            final palette = PlanThemePalette.fromHex(
              _themeColorHex,
              brightness: theme.brightness,
            );

            return Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.outlineVariant,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Plan Theme',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'This changes poll and responsibility accents. Status and error colors stay consistent.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: PlanThemePalette.presetHexColors.map((hex) {
                        final color = PlanThemePalette.parseHex(hex);
                        final selected = hex == _themeColorHex;

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _themeColorHex = hex;
                            });
                            setSheetState(() {});
                          },
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? colors.onSurface
                                    : colors.outlineVariant,
                                width: selected ? 3 : 1,
                              ),
                            ),
                            child: selected
                                ? Icon(
                                    Icons.check_rounded,
                                    color: PlanThemePalette.contrastColor(
                                      color,
                                    ),
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'PREVIEW',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: palette.softest,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: palette.border),
                      ),
                      child: Column(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: palette.primary),
                            ),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: palette.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.check_rounded,
                                    size: 15,
                                    color: palette.onPrimary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Sunday',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colors.onSurface,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  '62%',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: palette.dark,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  'Documentation',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colors.onSurface,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.soft,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Assigned',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: palette.dark,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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
  }

  Future<void> _pickPlanDate() async {
    final initialDate =
        DateTime.tryParse(_planDateController.text.trim()) ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 10),
    );

    if (picked == null) {
      return;
    }

    _planDateController.text =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasChanges) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colors = theme.colorScheme;

        return AlertDialog(
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Discard changes?',
            style: theme.textTheme.titleLarge?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'You have unsaved changes in this plan.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Keep Editing'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              child: const Text('Discard'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> _handleBack() async {
    if (_isSaving) {
      return;
    }

    final canLeave = await _confirmDiscard();

    if (!canLeave || !mounted) {
      return;
    }

    Navigator.pop(context, _didSave ? true : null);
  }

  Future<void> _deletePlan() async {
    if (!_isAdmin || _isDeleting) {
      return;
    }

    final confirmed = await _showActionConfirmation(
      title: 'Delete Plan?',
      message:
          'This moves the plan to Deleted Plans. You can restore it later.',
      confirmText: 'Delete',
      destructive: true,
    );

    if (!confirmed) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    final result = await PlanService.deletePlan(widget.planId);

    if (!mounted) {
      return;
    }

    setState(() {
      _isDeleting = false;
    });

    if (result['success'] != true) {
      _showMessage(
        result['message']?.toString() ?? 'Unable to delete plan.',
        isError: true,
      );
      return;
    }

    Navigator.pop(context, 'deleted');
  }

  Future<void> _leavePlan() async {
    if (_isAdmin || _isLeaving) {
      return;
    }

    final confirmed = await _showActionConfirmation(
      title: 'Leave Plan?',
      message: 'You will lose access to this plan and its shared details.',
      confirmText: 'Leave',
      destructive: true,
    );

    if (!confirmed) {
      return;
    }

    setState(() {
      _isLeaving = true;
    });

    final result = await PlanService.leavePlan(widget.planId);

    if (!mounted) {
      return;
    }

    setState(() {
      _isLeaving = false;
    });

    if (result['success'] != true) {
      _showMessage(
        result['message']?.toString() ?? 'Unable to leave plan.',
        isError: true,
      );
      return;
    }

    Navigator.pop(context, 'left');
  }

  Future<void> _transferAdminAndLeave() async {
    if (!_isAdmin || _isLeaving) {
      return;
    }

    final candidates = _transferableMembers;

    if (candidates.isEmpty) {
      _showMessage(
        'Add another member before transferring admin access.',
        isError: true,
      );
      return;
    }

    final selectedId = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colors = theme.colorScheme;

        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Choose New Admin',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  itemBuilder: (context, index) {
                    final member = candidates[index];
                    final memberId = _parseInt(member['id']);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _brandYellow.withValues(alpha: 0.18),
                        child: const Icon(
                          Icons.person_rounded,
                          color: _brandYellowDark,
                        ),
                      ),
                      title: Text(
                        _memberDisplayName(member),
                        style: TextStyle(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        _memberSubtitle(member),
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      onTap: memberId == null
                          ? null
                          : () {
                              Navigator.pop(sheetContext, memberId);
                            },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selectedId == null || !mounted) {
      return;
    }

    final selectedMember = candidates.firstWhere(
      (member) => _parseInt(member['id']) == selectedId,
    );

    final confirmed = await _showActionConfirmation(
      title: 'Transfer Admin & Leave?',
      message:
          '${_memberDisplayName(selectedMember)} will become the new admin, and you will leave this plan.',
      confirmText: 'Transfer & Leave',
      destructive: true,
    );

    if (!confirmed) {
      return;
    }

    setState(() {
      _isLeaving = true;
    });

    final result = await PlanService.leavePlan(
      widget.planId,
      newAdminId: selectedId,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isLeaving = false;
    });

    if (result['success'] != true) {
      _showMessage(
        result['message']?.toString() ?? 'Unable to transfer admin access.',
        isError: true,
      );
      return;
    }

    Navigator.pop(context, 'left');
  }

  Future<bool> _showActionConfirmation({
    required String title,
    required String message,
    required String confirmText,
    required bool destructive,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colors = theme.colorScheme;

        return AlertDialog(
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: destructive ? colors.error : _brandYellow,
                foregroundColor: destructive ? colors.onError : Colors.black,
              ),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(color: _brandYellow),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        if (_isSaving) {
          return false;
        }

        final canLeave = await _confirmDiscard();

        if (canLeave && mounted) {
          Navigator.pop(context, _didSave ? true : null);
        }

        return false;
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              _buildStickyHeader(),
              Divider(height: 1, color: colors.outlineVariant),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Settings',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: colors.onSurface,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 26),
                      _buildSectionTitle('Plan Details'),
                      const SizedBox(height: 16),
                      _buildFieldLabel('Plan Name'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _planNameController,
                        hint: 'Plan name',
                        enabled: _isAdmin,
                      ),
                      const SizedBox(height: 18),
                      _buildFieldLabel('Plan Description'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _planDescriptionController,
                        hint: 'Type plan description...',
                        maxLines: 4,
                        enabled: _isAdmin,
                      ),
                      const SizedBox(height: 18),
                      _buildFieldLabel('Plan Date'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _planDateController,
                        hint: 'YYYY-MM-DD',
                        readOnly: true,
                        enabled: _isAdmin,
                        onTap: _isAdmin ? _pickPlanDate : null,
                        suffixIcon: Icon(
                          Icons.calendar_today_outlined,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _buildFieldLabel('Plan Location'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _planLocationController,
                        hint: 'Location',
                        enabled: _isAdmin,
                        suffixIcon: Icon(
                          Icons.edit_location_alt_outlined,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 26),
                      _buildSectionTitle('Plan Appearance'),
                      const SizedBox(height: 14),
                      _buildAppearanceCard(
                        icon: Icons.panorama_outlined,
                        title: 'Plan Banner',
                        subtitle:
                            'Preset color, custom color, or cropped image',
                        trailing: SizedBox(
                          width: 52,
                          height: 36,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: _buildBannerPreview(height: 36),
                          ),
                        ),
                        onTap: _isAdmin ? _showBannerEditor : null,
                      ),
                      const SizedBox(height: 12),
                      _buildAppearanceCard(
                        icon: Icons.palette_outlined,
                        title: 'Plan Theme',
                        subtitle: 'Poll and responsibility colors',
                        trailing: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: PlanThemePalette.parseHex(_themeColorHex),
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.outlineVariant),
                          ),
                        ),
                        onTap: _isAdmin ? _showThemeEditor : null,
                      ),
                      const SizedBox(height: 26),
                      _buildSectionTitle('Plan Status'),
                      const SizedBox(height: 14),
                      _buildStatusDropdown(),
                      const SizedBox(height: 28),
                      _buildPlanAccessSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStickyHeader() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 10, 8),
      child: Row(
        children: <Widget>[
          TextButton.icon(
            onPressed: _isSaving ? null : _handleBack,
            icon: const Icon(Icons.arrow_back_rounded, color: _brandYellow),
            label: Text(
              'Back',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: _isAdmin && _hasChanges && !_isSaving
                ? _saveChanges
                : null,
            style: TextButton.styleFrom(
              foregroundColor: _brandYellowDark,
              disabledForegroundColor: colors.onSurfaceVariant.withValues(
                alpha: 0.45,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: _brandYellowDark,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerPreview({required double height}) {
    final imageFile = _pendingBannerImage;
    final imageUrl = _bannerImageUrl;

    Widget background;

    if (imageFile != null) {
      background = Image.file(
        imageFile,
        fit: BoxFit.cover,
        width: double.infinity,
        height: height,
      );
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      background = Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: height,
        errorBuilder: (_, _, _) {
          return ColoredBox(color: _bannerColor);
        },
      );
    } else {
      background = ColoredBox(color: _bannerColor);
    }

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          background,
          if (imageFile != null || (imageUrl?.isNotEmpty ?? false))
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.30),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppearanceCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _brandYellow.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: _brandYellowDark),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
              if (onTap != null) ...<Widget>[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedStatus,
          isExpanded: true,
          dropdownColor: colors.surface,
          icon: Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: colors.onSurfaceVariant,
            ),
          ),
          items: _statusOptions.map((status) {
            return DropdownMenuItem<String>(
              value: status.label,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: status.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Text(
                      status.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          onChanged: !_isAdmin
              ? null
              : (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _selectedStatus = value;
                  });
                },
        ),
      ),
    );
  }

  Widget _buildPlanAccessSection() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _isAdmin ? 'Admin Controls' : 'Plan Access',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isAdmin
                ? 'Transfer admin access before leaving, or move this plan to Deleted Plans.'
                : 'You can leave this plan at any time.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          if (_isAdmin) ...<Widget>[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLeaving ? null : _transferAdminAndLeave,
                icon: _isLeaving
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.swap_horiz_rounded),
                label: const Text('Transfer Admin & Leave'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isDeleting ? null : _deletePlan,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                ),
                icon: _isDeleting
                    ? SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onError,
                        ),
                      )
                    : const Icon(Icons.delete_outline_rounded),
                label: const Text('Move to Deleted Plans'),
              ),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLeaving ? null : _leavePlan,
                icon: _isLeaving
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout_rounded),
                label: const Text('Leave Plan'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Text(
      text,
      style: theme.textTheme.titleLarge?.copyWith(
        color: colors.onSurface,
        fontSize: 19,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Text(
      text,
      style: theme.textTheme.labelLarge?.copyWith(
        color: colors.onSurface,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    bool enabled = true,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return TextField(
      controller: controller,
      enabled: enabled,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: maxLines,
      style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant.withValues(alpha: 0.70),
        ),
        filled: true,
        fillColor: colors.surface,
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _brandYellow, width: 1.5),
        ),
      ),
    );
  }
}

class _PlanStatus {
  const _PlanStatus({required this.label, required this.color});

  final String label;
  final Color color;
}
