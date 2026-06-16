import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../auth/login.dart';

const Color _brandYellow = Color(0xFFE8B653);
const Color _brandYellowDark = Color(0xFFC98C22);

enum _UsernameAvailabilityState {
  unchanged,
  empty,
  invalid,
  checking,
  available,
  taken,
  error,
}

String _extractResultMessage(
  Map<String, dynamic> result, {
  required String fallback,
}) {
  final message = result['message']?.toString().trim();

  if (message != null && message.isNotEmpty) {
    return message;
  }

  final errors = result['errors'];

  if (errors is Map) {
    for (final value in errors.values) {
      if (value is List && value.isNotEmpty) {
        return value.first.toString();
      }

      if (value != null) {
        return value.toString();
      }
    }
  }

  return fallback;
}

bool _parseBool(dynamic value, {bool fallback = false}) {
  if (value == null) {
    return fallback;
  }

  if (value is bool) {
    return value;
  }

  if (value is int) {
    return value == 1;
  }

  final text = value.toString().trim().toLowerCase();

  return text == 'true' || text == '1';
}

String _normalizeUsername(String value) {
  return value.trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase();
}

String _formatUsername(dynamic value) {
  final username = value?.toString().trim() ?? '';

  if (username.isEmpty) {
    return '@user';
  }

  return username.startsWith('@') ? username : '@$username';
}

String? _validateUsername(String username) {
  if (username.isEmpty) {
    return 'Please enter a username.';
  }

  if (username.length < 3 || username.length > 20) {
    return 'Username must contain 3 to 20 characters.';
  }

  if (!RegExp(r'^[A-Za-z0-9._]+$').hasMatch(username)) {
    return 'Use letters, numbers, periods, and underscores only.';
  }

  return null;
}

// ─────────────────────────────────────────────
// SETTINGS HOME
// ─────────────────────────────────────────────

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() {
    return _SettingsPageState();
  }
}

class _SettingsPageState extends State<SettingsPage> {
  Uint8List? _avatarBytes;
  String? _profilePhotoUrl;

  String _profileName = 'User';
  String _profileUsername = '@user';

  bool _isLoadingProfile = true;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();

    _loadProfile();
  }

  String? _readPhotoUrl(Map<String, dynamic> user) {
    final possibleValues = [
      user['profile_photo_url'],
      user['photo_url'],
      user['avatar_url'],
    ];

    for (final value in possibleValues) {
      final url = value?.toString().trim();

      if (url != null && url.isNotEmpty) {
        return url;
      }
    }

    return null;
  }

  Future<void> _loadProfile() async {
    if (mounted) {
      setState(() {
        _isLoadingProfile = true;
      });
    }

    try {
      final settingsResult = await AuthService.getUserSettings();

      Map<String, dynamic>? user;

      final settingsUser = settingsResult['user'];

      if (settingsUser is Map) {
        user = Map<String, dynamic>.from(settingsUser);
      }

      user ??= await AuthService.getCurrentUser();

      if (!mounted) {
        return;
      }

      if (user == null) {
        setState(() {
          _isLoadingProfile = false;
        });

        return;
      }

      final name = user['name']?.toString().trim() ?? '';

      final username = _formatUsername(user['username']);

      final photoUrl = _readPhotoUrl(user);

      setState(() {
        _profileName = name.isEmpty ? 'User' : name;
        _profileUsername = username;
        _profilePhotoUrl = photoUrl;

        _avatarBytes = null;
        _isLoadingProfile = false;
      });

      ProfileService.instance.updateProfile(
        newName: _profileName,
        newUsername: _profileUsername,
        photoUrl: photoUrl,
        clearAvatar: photoUrl == null,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _confirmLogout() async {
    final colorScheme = Theme.of(context).colorScheme;

    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.logout_rounded,
              color: colorScheme.onErrorContainer,
              size: 24,
            ),
          ),
          title: const Text(
            'Log out?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          content: Text(
            'You will need to sign in again to access your plans.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Stay Logged In'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !mounted) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await AuthService.logout();

      ProfileService.instance.resetProfile();

      if (!mounted) {
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Logout failed: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  Color _usernameMessageColor(_UsernameAvailabilityState state) {
    switch (state) {
      case _UsernameAvailabilityState.available:
        return Colors.green.shade700;

      case _UsernameAvailabilityState.invalid:
      case _UsernameAvailabilityState.taken:
      case _UsernameAvailabilityState.error:
        return Colors.redAccent;

      case _UsernameAvailabilityState.checking:
      case _UsernameAvailabilityState.unchanged:
      case _UsernameAvailabilityState.empty:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  IconData? _usernameMessageIcon(_UsernameAvailabilityState state) {
    switch (state) {
      case _UsernameAvailabilityState.available:
        return Icons.check_circle_rounded;

      case _UsernameAvailabilityState.invalid:
      case _UsernameAvailabilityState.taken:
      case _UsernameAvailabilityState.error:
        return Icons.error_rounded;

      case _UsernameAvailabilityState.checking:
      case _UsernameAvailabilityState.unchanged:
      case _UsernameAvailabilityState.empty:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: _brandYellow,
          onRefresh: _loadProfile,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            children: [
              Text(
                'Settings',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage your account and app preferences.',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              _buildProfileCard(),
              const SizedBox(height: 28),
              _SectionLabel(
                label: 'ACCOUNT',
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 10),
              _SettingsSectionCard(
                children: [
                  _SettingsMenuTile(
                    icon: Icons.person_outline_rounded,
                    iconBackground: colorScheme.primaryContainer,
                    iconColor: colorScheme.onPrimaryContainer,
                    title: 'Profile',
                    subtitle: 'Update your name, username, and photo.',
                    onTap: _isLoadingProfile ? null : _showProfileBottomSheet,
                  ),
                  const _SettingsDivider(),
                  _SettingsMenuTile(
                    icon: Icons.lock_outline_rounded,
                    iconBackground: const Color(0xFFE9E5FF),
                    iconColor: const Color(0xFF6654B5),
                    title: 'Security',
                    subtitle: 'Manage your password and account access.',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) {
                            return const SecuritySubPage();
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 26),
              _SectionLabel(
                label: 'PREFERENCES',
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 10),
              _SettingsSectionCard(
                children: [
                  _SettingsMenuTile(
                    icon: Icons.notifications_none_rounded,
                    iconBackground: const Color(0xFFE1F3FF),
                    iconColor: const Color(0xFF357A9F),
                    title: 'Notifications',
                    subtitle: 'Choose which updates you want to receive.',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) {
                            return const NotificationsSubPage();
                          },
                        ),
                      );
                    },
                  ),
                  const _SettingsDivider(),
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, child) {
                      return _SettingsMenuTile(
                        icon: Icons.palette_outlined,
                        iconBackground: const Color(0xFFFFE9DC),
                        iconColor: const Color(0xFFB86538),
                        title: 'Appearance',
                        subtitle: 'Customize how Dinadrawing looks.',
                        trailingText: themeProvider.currentLabel,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) {
                                return const AppearanceSubPage();
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _buildLogoutButton(),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: _isLoadingProfile ? null : _showProfileBottomSheet,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildAvatarWidget(radius: 34),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _brandYellow,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.surface,
                          width: 2.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 12,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _isLoadingProfile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LoadingBar(
                            width: 130,
                            color: colorScheme.surfaceContainerHighest,
                          ),
                          const SizedBox(height: 8),
                          _LoadingBar(
                            width: 90,
                            height: 10,
                            color: colorScheme.surfaceContainerHighest,
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _profileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _profileUsername,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Edit Profile',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _isLoggingOut ? null : _confirmLogout,
        icon: _isLoggingOut
            ? const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.redAccent,
                ),
              )
            : const Icon(Icons.logout_rounded, size: 19),
        label: Text(_isLoggingOut ? 'Logging out...' : 'Log Out'),
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.error,
          side: BorderSide(color: colorScheme.error.withValues(alpha: 0.25)),
          backgroundColor: colorScheme.errorContainer.withValues(alpha: 0.18),
        ),
      ),
    );
  }

  Future<void> _showProfileBottomSheet() async {
    Uint8List? draftAvatarBytes = _avatarBytes;
    String? draftPhotoUrl = _profilePhotoUrl;

    String draftPhotoFilename = 'profile_photo.jpg';

    bool removePhoto = false;
    bool isSaving = false;

    String? saveError;

    Timer? usernameDebounce;

    final originalName = _profileName.trim();

    final originalUsername = _normalizeUsername(_profileUsername);

    final nameController = TextEditingController(text: originalName);

    final usernameController = TextEditingController(text: originalUsername);

    var usernameState = _UsernameAvailabilityState.unchanged;

    String? usernameMessage;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final theme = Theme.of(sheetContext);
            final colorScheme = theme.colorScheme;

            final normalizedUsername = _normalizeUsername(
              usernameController.text,
            );

            final name = nameController.text.trim();

            final nameIsValid = name.length >= 2;

            final localUsernameError = _validateUsername(normalizedUsername);

            final usernameIsReady =
                normalizedUsername == originalUsername ||
                usernameState == _UsernameAvailabilityState.available;

            final photoChanged = draftAvatarBytes != null || removePhoto;

            final profileChanged =
                name != originalName ||
                normalizedUsername != originalUsername ||
                photoChanged;

            final canSave =
                !isSaving &&
                profileChanged &&
                nameIsValid &&
                localUsernameError == null &&
                usernameIsReady;

            Future<void> chooseAvatar() async {
              await _showAvatarOptions(
                context: sheetContext,
                hasAvatar: draftAvatarBytes != null || draftPhotoUrl != null,
                onPhotoSelected: (bytes, filename) {
                  if (!sheetContext.mounted) {
                    return;
                  }

                  setSheetState(() {
                    draftAvatarBytes = bytes;
                    draftPhotoUrl = null;
                    draftPhotoFilename = filename;

                    removePhoto = false;
                    saveError = null;
                  });
                },
                onPhotoRemoved: () {
                  if (!sheetContext.mounted) {
                    return;
                  }

                  setSheetState(() {
                    draftAvatarBytes = null;
                    draftPhotoUrl = null;

                    removePhoto = true;
                    saveError = null;
                  });
                },
              );
            }

            void handleUsernameChanged(String value) {
              usernameDebounce?.cancel();

              final username = _normalizeUsername(value);

              setSheetState(() {
                saveError = null;
              });

              if (username.isEmpty) {
                setSheetState(() {
                  usernameState = _UsernameAvailabilityState.empty;

                  usernameMessage = 'Please enter a username.';
                });

                return;
              }

              if (username == originalUsername) {
                setSheetState(() {
                  usernameState = _UsernameAvailabilityState.unchanged;

                  usernameMessage = null;
                });

                return;
              }

              final validationError = _validateUsername(username);

              if (validationError != null) {
                setSheetState(() {
                  usernameState = _UsernameAvailabilityState.invalid;

                  usernameMessage = validationError;
                });

                return;
              }

              setSheetState(() {
                usernameState = _UsernameAvailabilityState.checking;

                usernameMessage = 'Checking availability...';
              });

              usernameDebounce = Timer(
                const Duration(milliseconds: 500),
                () async {
                  final result = await AuthService.checkUsername(
                    username: username,
                  );

                  if (!sheetContext.mounted) {
                    return;
                  }

                  final latestUsername = _normalizeUsername(
                    usernameController.text,
                  );

                  if (latestUsername != username) {
                    return;
                  }

                  final isAvailable =
                      result['success'] == true && result['available'] == true;

                  setSheetState(() {
                    if (isAvailable) {
                      usernameState = _UsernameAvailabilityState.available;

                      usernameMessage = 'Username is available.';
                    } else if (result['success'] == true) {
                      usernameState = _UsernameAvailabilityState.taken;

                      usernameMessage =
                          result['message']?.toString() ??
                          'Username already exists. Try another.';
                    } else {
                      usernameState = _UsernameAvailabilityState.error;

                      usernameMessage =
                          result['message']?.toString() ??
                          'Unable to check username availability.';
                    }
                  });
                },
              );
            }

            Future<void> saveProfile() async {
              final name = nameController.text.trim();

              final username = _normalizeUsername(usernameController.text);

              final usernameError = _validateUsername(username);

              if (name.length < 2 || usernameError != null) {
                setSheetState(() {
                  saveError = name.length < 2
                      ? 'Please enter a valid name.'
                      : usernameError;
                });

                return;
              }

              if (username != originalUsername &&
                  usernameState != _UsernameAvailabilityState.available) {
                return;
              }

              setSheetState(() {
                isSaving = true;
                saveError = null;
              });

              final result = await AuthService.updateProfile(
                name: name,
                username: username,
                photoBytes: draftAvatarBytes,
                photoFilename: draftPhotoFilename,
                removePhoto: removePhoto,
              );

              if (!mounted || !sheetContext.mounted) {
                return;
              }

              if (result['success'] != true) {
                final message = _extractResultMessage(
                  result,
                  fallback: 'Unable to update profile.',
                );

                setSheetState(() {
                  isSaving = false;
                  saveError = message;

                  if (message.toLowerCase().contains('username')) {
                    usernameState = _UsernameAvailabilityState.taken;

                    usernameMessage = message;
                  }
                });

                return;
              }

              final rawUser = result['user'];

              final user = rawUser is Map
                  ? Map<String, dynamic>.from(rawUser)
                  : <String, dynamic>{};

              final savedName = user['name']?.toString().trim() ?? name;

              final savedUsername = _formatUsername(
                user['username'] ?? username,
              );

              final savedPhotoUrl = _readPhotoUrl(user);

              setState(() {
                _profileName = savedName;
                _profileUsername = savedUsername;

                if (removePhoto) {
    _profilePhotoUrl = null;
    _avatarBytes = null;
  } else if (draftAvatarBytes != null) {
    _avatarBytes = draftAvatarBytes;
    _profilePhotoUrl = savedPhotoUrl;
  } else {
    _avatarBytes = null;
    _profilePhotoUrl = savedPhotoUrl;
  }
              });

              ProfileService.instance.updateProfile(
  bytes: _avatarBytes,
  photoUrl: _profilePhotoUrl,
  newName: _profileName,
  newUsername: _profileUsername,
  clearAvatar: removePhoto,
);
              Navigator.pop(sheetContext);
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.92,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 16, 14, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Edit Profile',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Changes are saved only after you confirm.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: isSaving
                              ? null
                              : () {
                                  Navigator.pop(sheetContext);
                                },
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: colorScheme.outlineVariant),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        22,
                        22,
                        22,
                        MediaQuery.of(sheetContext).viewInsets.bottom + 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    _buildAvatarWidget(
                                      radius: 43,
                                      avatarBytes: draftAvatarBytes,
                                      photoUrl: draftPhotoUrl,
                                      useSavedFallback: false,
                                    ),
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: Material(
                                        color: _brandYellow,
                                        shape: const CircleBorder(),
                                        child: InkWell(
                                          onTap: isSaving ? null : chooseAvatar,
                                          customBorder: const CircleBorder(),
                                          child: const SizedBox(
                                            width: 30,
                                            height: 30,
                                            child: Icon(
                                              Icons.camera_alt_rounded,
                                              color: Colors.black,
                                              size: 15,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: isSaving ? null : chooseAvatar,
                                  child: const Text('Change Photo'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _FieldLabel(
                            label: 'Name',
                            color: colorScheme.onSurface,
                          ),
                          const SizedBox(height: 7),
                          TextField(
                            controller: nameController,
                            enabled: !isSaving,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) {
                              setSheetState(() {
                                saveError = null;
                              });
                            },
                            decoration: const InputDecoration(
                              hintText: 'Enter your name',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _FieldLabel(
                            label: 'Username',
                            color: colorScheme.onSurface,
                          ),
                          const SizedBox(height: 7),
                          TextField(
                            controller: usernameController,
                            enabled: !isSaving,
                            textInputAction: TextInputAction.done,
                            autocorrect: false,
                            enableSuggestions: false,
                            onChanged: handleUsernameChanged,
                            decoration: const InputDecoration(
                              prefixText: '@',
                              hintText: 'Enter username',
                              prefixIcon: Icon(Icons.alternate_email_rounded),
                            ),
                          ),
                          if (usernameMessage != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (usernameState ==
                                    _UsernameAvailabilityState.checking)
                                  SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.8,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  )
                                else if (_usernameMessageIcon(usernameState) !=
                                    null)
                                  Icon(
                                    _usernameMessageIcon(usernameState),
                                    size: 16,
                                    color: _usernameMessageColor(usernameState),
                                  ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    usernameMessage!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 11,
                                      color: _usernameMessageColor(
                                        usernameState,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            'Your username is visible to other members and must be unique.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (saveError != null) ...[
                            const SizedBox(height: 18),
                            _InlineStatusCard(
                              icon: Icons.error_outline_rounded,
                              message: saveError!,
                              backgroundColor: colorScheme.errorContainer,
                              foregroundColor: colorScheme.onErrorContainer,
                            ),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: canSave ? saveProfile : null,
                              child: isSaving
                                  ? const SizedBox(
                                      width: 19,
                                      height: 19,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Text('Save Changes'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    usernameDebounce?.cancel();

    nameController.dispose();
    usernameController.dispose();
  }

  Widget _buildAvatarWidget({
    double radius = 40,
    Uint8List? avatarBytes,
    String? photoUrl,
    bool useSavedFallback = true,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    final bytes = useSavedFallback ? avatarBytes ?? _avatarBytes : avatarBytes;

    final url = useSavedFallback ? photoUrl ?? _profilePhotoUrl : photoUrl;

    if (bytes != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: colorScheme.surfaceContainerHighest,
        backgroundImage: MemoryImage(bytes),
      );
    }

    if (url != null && url.trim().isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: colorScheme.surfaceContainerHighest,
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, _) {},
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.person_rounded,
        size: radius * 0.95,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }

  Future<void> _showAvatarOptions({
    required BuildContext context,
    required bool hasAvatar,
    required void Function(Uint8List bytes, String filename) onPhotoSelected,
    required VoidCallback onPhotoRemoved,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (optionsContext) {
        final theme = Theme.of(optionsContext);
        final colorScheme = theme.colorScheme;

        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Profile Photo',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                _AvatarActionTile(
                  icon: Icons.camera_alt_outlined,
                  title: 'Take a Photo',
                  subtitle: 'Use your device camera.',
                  onTap: () async {
                    Navigator.pop(optionsContext);

                    final file = await _pickImage(ImageSource.camera);

                    if (file == null) {
                      return;
                    }

                    final bytes = await file.readAsBytes();

                    onPhotoSelected(bytes, file.name);
                  },
                ),
                const SizedBox(height: 8),
                _AvatarActionTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Choose from Gallery',
                  subtitle: 'Select an image from your device.',
                  onTap: () async {
                    Navigator.pop(optionsContext);

                    final file = await _pickImage(ImageSource.gallery);

                    if (file == null) {
                      return;
                    }

                    final bytes = await file.readAsBytes();

                    final croppedBytes = await _showCropDialog(bytes);

                    if (croppedBytes == null) {
                      return;
                    }

                    onPhotoSelected(croppedBytes, file.name);
                  },
                ),
                if (hasAvatar) ...[
                  const SizedBox(height: 8),
                  _AvatarActionTile(
                    icon: Icons.delete_outline_rounded,
                    title: 'Remove Photo',
                    subtitle: 'Return to the default profile icon.',
                    destructive: true,
                    onTap: () {
                      Navigator.pop(optionsContext);

                      onPhotoRemoved();
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<XFile?> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();

      return await picker.pickImage(
        source: source,
        maxWidth: 1200,
        imageQuality: 85,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to open the image picker: $error')),
        );
      }

      return null;
    }
  }

  Future<Uint8List?> _showCropDialog(Uint8List imageData) async {
    // Build a fixed, responsive dialog where the crop area is flexible
    final transformationController = TransformationController();
    final previewKey = GlobalKey();

    double currentScale = 1.0;

    return showDialog<Uint8List?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final media = MediaQuery.of(dialogContext);
        final maxHeight = media.size.height * 0.88;
        final dialogWidth = media.size.width < 720 ? media.size.width * 0.94 : 720.0;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          child: StatefulBuilder(builder: (context, setState) {
            return SizedBox(
              width: dialogWidth,
              height: maxHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(null),
                          child: const Text('Cancel'),
                        ),
                        Text(
                          'Crop Photo',
                          style: Theme.of(dialogContext).textTheme.titleMedium,
                        ),
                        TextButton(
                          onPressed: () async {
                            try {
                              final boundary = previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
                              if (boundary == null) {
                                Navigator.of(dialogContext).pop(null);
                                return;
                              }

                              final pixelRatio = media.devicePixelRatio;
                              final ui.Image img = await boundary.toImage(pixelRatio: pixelRatio);
                              final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
                              final bytes = byteData?.buffer.asUint8List();

                              Navigator.of(dialogContext).pop(bytes);
                            } catch (_) {
                              Navigator.of(dialogContext).pop(null);
                            }
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Crop area (expand to fill available space)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18.0),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: dialogWidth - 72,
                            maxHeight: maxHeight - 180,
                            minWidth: 200,
                            minHeight: 200,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              RepaintBoundary(
                                key: previewKey,
                                child: ClipRect(
                                  child: InteractiveViewer(
                                    transformationController: transformationController,
                                    clipBehavior: Clip.hardEdge,
                                    panEnabled: true,
                                    minScale: 1.0,
                                    maxScale: 4.0,
                                    child: SizedBox(
                                      width: double.infinity,
                                      height: double.infinity,
                                      child: FittedBox(
                                        fit: BoxFit.cover,
                                        child: SizedBox(
                                          width: 600,
                                          height: 600,
                                          child: Image.memory(imageData),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Crop border overlay (visual only)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _CircularCropOverlayPainter(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Zoom slider
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
                    child: Row(
                      children: [
                        const Icon(Icons.zoom_out, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Slider(
                            value: currentScale,
                            min: 1.0,
                            max: 4.0,
                            divisions: 30,
                            onChanged: (v) {
                              setState(() {
                                currentScale = v;
                                // apply scale while keeping translation simple
                                transformationController.value = Matrix4.identity()..scale(currentScale);
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.zoom_in, size: 20),
                      ],
                    ),
                  ),

                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(null),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 120,
                          child: ElevatedButton(
                            onPressed: () async {
                              try {
                                final boundary = previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
                                if (boundary == null) {
                                  Navigator.of(dialogContext).pop(null);
                                  return;
                                }

                                final pixelRatio = media.devicePixelRatio;
                                final ui.Image img = await boundary.toImage(pixelRatio: pixelRatio);
                                final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
                                final bytes = byteData?.buffer.asUint8List();

                                Navigator.of(dialogContext).pop(bytes);
                              } catch (_) {
                                Navigator.of(dialogContext).pop(null);
                              }
                            },
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  
  
  
  
}

class _CircularCropOverlayPainter extends CustomPainter {
  final Color overlayColor = Colors.black.withOpacity(0.45);

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Offset.zero & size;

    // Circle radius and center
    final radius = math.min(size.width, size.height) / 2 - 8;
    final center = Offset(size.width / 2, size.height / 2);
    // Draw dark overlay outside the circle by clearing the circle area
    canvas.saveLayer(fullRect, Paint());

    // draw full overlay
    canvas.drawRect(fullRect, Paint()..color = overlayColor);

    // clear the circular area to make it fully visible
    canvas.drawCircle(center, radius, Paint()..blendMode = BlendMode.clear);

    canvas.restore();

    // Draw white circle border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────
// SECURITY
// ─────────────────────────────────────────────

class SecuritySubPage extends StatefulWidget {
  const SecuritySubPage({super.key});

  @override
  State<SecuritySubPage> createState() {
    return _SecuritySubPageState();
  }
}

class _SecuritySubPageState extends State<SecuritySubPage> {
  final TextEditingController currentPasswordController =
      TextEditingController();

  final TextEditingController newPasswordController = TextEditingController();

  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool _currentPasswordVisible = false;
  bool _newPasswordVisible = false;
  bool _confirmPasswordVisible = false;

  bool _confirmPasswordValidationRequested = false;

  bool _isChangingPassword = false;

  String? _currentPasswordError;
  String? _formError;
  String? _successMessage;

  bool get _hasLength {
    final length = newPasswordController.text.length;

    return length >= 8 && length <= 20;
  }

  bool get _hasLetterAndNumber {
    return RegExp(
      r'(?=.*[A-Za-z])(?=.*\d)',
    ).hasMatch(newPasswordController.text);
  }

  bool get _hasSpecial {
    return RegExp(r'[^A-Za-z0-9]').hasMatch(newPasswordController.text);
  }

  bool get _passwordsMatch {
    return newPasswordController.text.isNotEmpty &&
        newPasswordController.text == confirmPasswordController.text;
  }

  bool get _allPasswordCriteriaValid {
    return _hasLength && _hasLetterAndNumber && _hasSpecial;
  }

  bool get _canSubmit {
    return !_isChangingPassword &&
        currentPasswordController.text.isNotEmpty &&
        _allPasswordCriteriaValid &&
        _passwordsMatch;
  }

  @override
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();

    super.dispose();
  }

  Future<void> _changePassword() async {
    setState(() {
      _confirmPasswordValidationRequested = true;

      _currentPasswordError = null;
      _formError = null;
      _successMessage = null;
    });

    final currentPassword = currentPasswordController.text;

    if (currentPassword.trim().isEmpty) {
      setState(() {
        _currentPasswordError = 'Please enter your current password.';
      });

      return;
    }

    if (!_allPasswordCriteriaValid || !_passwordsMatch) {
      return;
    }

    setState(() {
      _isChangingPassword = true;
    });

    final result = await AuthService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPasswordController.text,
      confirmPassword: confirmPasswordController.text,
    );

    if (!mounted) {
      return;
    }

    if (result['success'] != true) {
      final message = _extractResultMessage(
        result,
        fallback: 'Unable to change password.',
      );

      setState(() {
        _isChangingPassword = false;

        if (message.toLowerCase().contains('current password')) {
          _currentPasswordError = message;
        } else {
          _formError = message;
        }
      });

      return;
    }

    currentPasswordController.clear();
    newPasswordController.clear();
    confirmPasswordController.clear();

    setState(() {
      _confirmPasswordValidationRequested = false;

      _currentPasswordError = null;
      _formError = null;

      _successMessage = 'Your password was changed successfully.';

      _isChangingPassword = false;
    });
  }

  void _clearMessages() {
    _formError = null;
    _successMessage = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildPageAppBar(context, title: 'Security'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(
              'Change Password',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Enter your current password before creating a new one.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            _SettingsSectionCard(
              padding: const EdgeInsets.all(18),
              children: [
                _FieldLabel(
                  label: 'Current Password',
                  color: colorScheme.onSurface,
                ),
                const SizedBox(height: 7),
                _PasswordTextField(
                  controller: currentPasswordController,
                  hint: 'Enter current password',
                  visible: _currentPasswordVisible,
                  enabled: !_isChangingPassword,
                  onChanged: (_) {
                    setState(() {
                      _currentPasswordError = null;

                      _clearMessages();
                    });
                  },
                  onToggle: () {
                    setState(() {
                      _currentPasswordVisible = !_currentPasswordVisible;
                    });
                  },
                ),
                if (_currentPasswordError != null) ...[
                  const SizedBox(height: 7),
                  _FieldErrorText(message: _currentPasswordError!),
                ],
                const SizedBox(height: 18),
                _FieldLabel(
                  label: 'New Password',
                  color: colorScheme.onSurface,
                ),
                const SizedBox(height: 7),
                _PasswordTextField(
                  controller: newPasswordController,
                  hint: 'Enter new password',
                  visible: _newPasswordVisible,
                  enabled: !_isChangingPassword,
                  onChanged: (_) {
                    setState(() {
                      _confirmPasswordValidationRequested = false;

                      _clearMessages();
                    });
                  },
                  onToggle: () {
                    setState(() {
                      _newPasswordVisible = !_newPasswordVisible;
                    });
                  },
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your password must include:',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _PasswordRequirement(
                        label: '8–20 characters',
                        valid: _hasLength,
                      ),
                      const SizedBox(height: 7),
                      _PasswordRequirement(
                        label: 'At least 1 letter and 1 number',
                        valid: _hasLetterAndNumber,
                      ),
                      const SizedBox(height: 7),
                      _PasswordRequirement(
                        label: 'At least 1 special character (# ? ! \$ & @)',
                        valid: _hasSpecial,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _FieldLabel(
                  label: 'Confirm New Password',
                  color: colorScheme.onSurface,
                ),
                const SizedBox(height: 7),
                _PasswordTextField(
                  controller: confirmPasswordController,
                  hint: 'Re-enter new password',
                  visible: _confirmPasswordVisible,
                  enabled: !_isChangingPassword,
                  onChanged: (_) {
                    setState(() {
                      _confirmPasswordValidationRequested = false;

                      _clearMessages();
                    });
                  },
                  onToggle: () {
                    setState(() {
                      _confirmPasswordVisible = !_confirmPasswordVisible;
                    });
                  },
                ),
                if ((_confirmPasswordValidationRequested ||
                        confirmPasswordController.text.isNotEmpty) &&
                    !_passwordsMatch) ...[
                  const SizedBox(height: 7),
                  const _FieldErrorText(message: 'Passwords do not match.'),
                ],
                if (_formError != null) ...[
                  const SizedBox(height: 16),
                  _InlineStatusCard(
                    icon: Icons.error_outline_rounded,
                    message: _formError!,
                    backgroundColor: colorScheme.errorContainer,
                    foregroundColor: colorScheme.onErrorContainer,
                  ),
                ],
                if (_successMessage != null) ...[
                  const SizedBox(height: 16),
                  _InlineStatusCard(
                    icon: Icons.check_circle_outline_rounded,
                    message: _successMessage!,
                    backgroundColor: Colors.green.withValues(alpha: 0.12),
                    foregroundColor: Colors.green.shade700,
                  ),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _canSubmit ? _changePassword : null,
                    child: _isChangingPassword
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text('Change Password'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// NOTIFICATIONS
// ─────────────────────────────────────────────

class NotificationsSubPage extends StatefulWidget {
  const NotificationsSubPage({super.key});

  @override
  State<NotificationsSubPage> createState() {
    return _NotificationsSubPageState();
  }
}

class _NotificationsSubPageState extends State<NotificationsSubPage> {
  bool _isLoading = true;

  String? _savingKey;
  String? _pageError;

  bool _emailVerified = false;
  bool _emailReminders = false;
  bool _pushNotifications = true;
  bool _inAppAlerts = true;

  @override
  void initState() {
    super.initState();

    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _isLoading = true;
      _pageError = null;
    });

    final result = await AuthService.getUserSettings();

    if (!mounted) {
      return;
    }

    final rawUser = result['user'];

    if (result['success'] != true || rawUser is! Map) {
      setState(() {
        _isLoading = false;

        _pageError =
            result['message']?.toString() ??
            'Unable to load notification settings.';
      });

      return;
    }

    final user = Map<String, dynamic>.from(rawUser);

    setState(() {
      _emailVerified = _parseBool(user['email_verified']);

      _emailReminders = _emailVerified && _parseBool(user['email_reminders']);

      _pushNotifications = _parseBool(
        user['push_notifications'],
        fallback: true,
      );

      _inAppAlerts = _parseBool(user['in_app_alerts'], fallback: true);

      _isLoading = false;
    });
  }

  Future<void> _savePreferences({
    required String key,
    bool? emailReminders,
    bool? pushNotifications,
    bool? inAppAlerts,
  }) async {
    if (_savingKey != null) {
      return;
    }

    final previousEmail = _emailReminders;
    final previousPush = _pushNotifications;
    final previousInApp = _inAppAlerts;

    final nextEmail = emailReminders ?? _emailReminders;

    final nextPush = pushNotifications ?? _pushNotifications;

    final nextInApp = inAppAlerts ?? _inAppAlerts;

    setState(() {
      _savingKey = key;
      _pageError = null;

      _emailReminders = nextEmail;
      _pushNotifications = nextPush;
      _inAppAlerts = nextInApp;
    });

    final result = await AuthService.updateNotificationPreferences(
      emailReminders: nextEmail,
      pushNotifications: nextPush,
      inAppAlerts: nextInApp,
    );

    if (!mounted) {
      return;
    }

    if (result['success'] != true) {
      setState(() {
        _savingKey = null;

        _emailReminders = previousEmail;
        _pushNotifications = previousPush;
        _inAppAlerts = previousInApp;

        _pageError = _extractResultMessage(
          result,
          fallback: 'Unable to save notification settings.',
        );
      });

      return;
    }

    final rawNotifications = result['notifications'];

    final notifications = rawNotifications is Map
        ? Map<String, dynamic>.from(rawNotifications)
        : <String, dynamic>{};

    setState(() {
      _emailReminders = _parseBool(
        notifications['email_reminders'],
        fallback: nextEmail,
      );

      _pushNotifications = _parseBool(
        notifications['push_notifications'],
        fallback: nextPush,
      );

      _inAppAlerts = _parseBool(
        notifications['in_app_alerts'],
        fallback: nextInApp,
      );

      _savingKey = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildPageAppBar(context, title: 'Notifications'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: _brandYellow,
              onRefresh: _loadPreferences,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  if (_pageError != null) ...[
                    const SizedBox(height: 16),
                    _InlineStatusCard(
                      icon: Icons.error_outline_rounded,
                      message: _pageError!,
                      backgroundColor: colorScheme.errorContainer,
                      foregroundColor: colorScheme.onErrorContainer,
                    ),
                  ],
                  if (!_emailVerified) ...[
                    const SizedBox(height: 16),
                    _InlineStatusCard(
                      icon: Icons.mark_email_unread_outlined,
                      message: 'Verify your email to enable email reminders.',
                      backgroundColor: colorScheme.primaryContainer,
                      foregroundColor: colorScheme.onPrimaryContainer,
                    ),
                  ],
                  const SizedBox(height: 24),
                  _SectionLabel(
                    label: 'NOTIFICATION CHANNELS',
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 10),
                  _SettingsSectionCard(
                    children: [
                      _NotificationTile(
                        icon: Icons.email_outlined,
                        title: 'Email Reminders',
                        subtitle: _emailVerified
                            ? 'Receive important plan updates in your inbox.'
                            : 'Unavailable until your email is verified.',
                        value: _emailReminders,
                        enabled: _emailVerified && _savingKey == null,
                        isSaving: _savingKey == 'email',
                        onChanged: (value) {
                          _savePreferences(key: 'email', emailReminders: value);
                        },
                      ),
                      const _SettingsDivider(),
                      _NotificationTile(
                        icon: Icons.phone_android_rounded,
                        title: 'Push Notifications',
                        subtitle: 'Receive real-time alerts on this device.',
                        value: _pushNotifications,
                        enabled: _savingKey == null,
                        isSaving: _savingKey == 'push',
                        onChanged: (value) {
                          _savePreferences(
                            key: 'push',
                            pushNotifications: value,
                          );
                        },
                      ),
                      const _SettingsDivider(),
                      _NotificationTile(
                        icon: Icons.notifications_none_rounded,
                        title: 'In-App Alerts',
                        subtitle: 'See updates while using Dinadrawing.',
                        value: _inAppAlerts,
                        enabled: _savingKey == null,
                        isSaving: _savingKey == 'in_app',
                        onChanged: (value) {
                          _savePreferences(key: 'in_app', inAppAlerts: value);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Changes are saved automatically.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────
// APPEARANCE
// ─────────────────────────────────────────────

class AppearanceSubPage extends StatefulWidget {
  const AppearanceSubPage({super.key});

  @override
  State<AppearanceSubPage> createState() {
    return _AppearanceSubPageState();
  }
}

class _AppearanceSubPageState extends State<AppearanceSubPage> {
  ThemeMode? _updatingMode;

  Future<void> _selectTheme(ThemeMode mode) async {
    final provider = context.read<ThemeProvider>();

    if (provider.themeMode == mode) {
      return;
    }

    setState(() {
      _updatingMode = mode;
    });

    await provider.setThemeMode(mode);

    if (!mounted) {
      return;
    }

    setState(() {
      _updatingMode = null;
    });
  }

  String _systemDescription(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);

    return brightness == Brightness.dark
        ? 'Your device is currently using Dark Mode.'
        : 'Your device is currently using Light Mode.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildPageAppBar(context, title: 'Appearance'),
      body: Consumer<ThemeProvider>(
        builder: (context, provider, child) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    'Theme',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      provider.currentLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                'Changes apply instantly and remain on this device.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              _AppearanceOptionCard(
                mode: ThemeMode.system,
                selected: provider.themeMode == ThemeMode.system,
                loading: _updatingMode == ThemeMode.system,
                title: 'Use Device Setting',
                description: _systemDescription(context),
                icon: Icons.brightness_auto_rounded,
                onTap: () {
                  _selectTheme(ThemeMode.system);
                },
              ),
              const SizedBox(height: 14),
              _AppearanceOptionCard(
                mode: ThemeMode.light,
                selected: provider.themeMode == ThemeMode.light,
                loading: _updatingMode == ThemeMode.light,
                title: 'Light Mode',
                description: 'A bright and clean appearance for daytime use.',
                icon: Icons.light_mode_rounded,
                onTap: () {
                  _selectTheme(ThemeMode.light);
                },
              ),
              const SizedBox(height: 14),
              _AppearanceOptionCard(
                mode: ThemeMode.dark,
                selected: provider.themeMode == ThemeMode.dark,
                loading: _updatingMode == ThemeMode.dark,
                title: 'Dark Mode',
                description:
                    'A softer, darker appearance for low-light environments.',
                icon: Icons.dark_mode_rounded,
                onTap: () {
                  _selectTheme(ThemeMode.dark);
                },
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 19,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'Plan colors are customized separately inside each plan. Changing the app theme will not overwrite them.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SHARED UI
// ─────────────────────────────────────────────

PreferredSizeWidget _buildPageAppBar(
  BuildContext context, {
  required String title,
}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  return AppBar(
    backgroundColor: theme.scaffoldBackgroundColor,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    leadingWidth: 78,
    leading: TextButton(
      onPressed: () {
        Navigator.pop(context);
      },
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        padding: const EdgeInsets.only(left: 14),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_back_ios_new_rounded, size: 15),
          SizedBox(width: 5),
          Text(
            'Back',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
    title: Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
    ),
    centerTitle: true,
  );
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _SettingsSectionCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  const _SettingsSectionCard({
    required this.children,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsMenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;

  final String title;
  final String subtitle;

  final VoidCallback? onTap;
  final String? trailingText;

  const _SettingsMenuTile({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingText != null) ...[
                const SizedBox(width: 8),
                Text(
                  trailingText!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(width: 5),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 68),
      child: Divider(
        height: 1,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const _LoadingBar({
    required this.width,
    required this.color,
    this.height = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _FieldLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: color,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _FieldErrorText extends StatelessWidget {
  final String message;

  const _FieldErrorText({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 15,
          color: Colors.redAccent,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: Colors.redAccent,
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineStatusCard extends StatelessWidget {
  final IconData icon;
  final String message;

  final Color backgroundColor;
  final Color foregroundColor;

  const _InlineStatusCard({
    required this.icon,
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foregroundColor),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: foregroundColor,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  final VoidCallback onTap;
  final bool destructive;

  const _AvatarActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final foreground = destructive ? colorScheme.error : colorScheme.onSurface;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: foreground, size: 21),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: destructive
                            ? colorScheme.error.withValues(alpha: 0.78)
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  final bool visible;
  final bool enabled;

  final ValueChanged<String>? onChanged;
  final VoidCallback onToggle;

  const _PasswordTextField({
    required this.controller,
    required this.hint,
    required this.visible,
    required this.enabled,
    required this.onChanged,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: !visible,
      enabled: enabled,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: enabled ? onToggle : null,
          icon: Icon(
            visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 19,
          ),
        ),
      ),
    );
  }
}

class _PasswordRequirement extends StatelessWidget {
  final String label;
  final bool valid;

  const _PasswordRequirement({required this.label, required this.valid});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final color = valid ? Colors.green.shade700 : colorScheme.onSurfaceVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          valid ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 15,
          color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 11, color: color),
          ),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  final bool value;
  final bool enabled;
  final bool isSaving;

  final ValueChanged<bool> onChanged;

  const _NotificationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.isSaving,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color: enabled
                  ? colorScheme.onSurface
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: enabled
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isSaving)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch(value: value, onChanged: enabled ? onChanged : null),
        ],
      ),
    );
  }
}

class _AppearanceOptionCard extends StatelessWidget {
  final ThemeMode mode;

  final bool selected;
  final bool loading;

  final String title;
  final String description;

  final IconData icon;
  final VoidCallback onTap;

  const _AppearanceOptionCard({
    required this.mode,
    required this.selected,
    required this.loading,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected
            ? colorScheme.primaryContainer.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.34 : 0.56,
              )
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? _brandYellow : colorScheme.outlineVariant,
          width: selected ? 1.7 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _ThemePreview(mode: mode),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            icon,
                            size: 18,
                            color: selected
                                ? _brandYellowDark
                                : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (loading)
                  const SizedBox(
                    width: 21,
                    height: 21,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: selected ? _brandYellowDark : colorScheme.outline,
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemePreview extends StatelessWidget {
  final ThemeMode mode;

  const _ThemePreview({required this.mode});

  @override
  Widget build(BuildContext context) {
    const width = 58.0;
    const height = 76.0;

    if (mode == ThemeMode.system) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: const SizedBox(
          width: width,
          height: height,
          child: Row(
            children: [
              Expanded(child: _MiniThemeScreen(dark: false, roundedLeft: true)),
              Expanded(child: _MiniThemeScreen(dark: true, roundedRight: true)),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: _MiniThemeScreen(
        dark: mode == ThemeMode.dark,
        roundedLeft: true,
        roundedRight: true,
      ),
    );
  }
}

class _MiniThemeScreen extends StatelessWidget {
  final bool dark;
  final bool roundedLeft;
  final bool roundedRight;

  const _MiniThemeScreen({
    required this.dark,
    this.roundedLeft = false,
    this.roundedRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final background = dark ? const Color(0xFF171719) : const Color(0xFFF8F8FA);

    final card = dark ? const Color(0xFF29292D) : Colors.white;

    final line = dark ? const Color(0xFFB9B5AE) : const Color(0xFF5A5A60);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.horizontal(
          left: roundedLeft ? const Radius.circular(12) : Radius.zero,
          right: roundedRight ? const Radius.circular(12) : Radius.zero,
        ),
        border: Border.all(
          color: dark ? const Color(0xFF414147) : const Color(0xFFE1E0E5),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: _brandYellow,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: line.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 4,
                    decoration: BoxDecoration(
                      color: line.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    width: 24,
                    height: 3,
                    decoration: BoxDecoration(
                      color: line.withValues(alpha: 0.34),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _brandYellow,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
