import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../auth/login.dart';
import '../../providers/theme_provider.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_settings_service.dart';
import '../../services/profile_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Uint8List? _avatarBytes;
  IconData? _selectedIcon;
  String _profileName = 'User';
  String _profileUsername = '@user';
  String _themeLabel = 'Light';

  bool _isLoggingOut = false;

  final List<IconData> _iconOptions = [
    Icons.face,
    Icons.face_2,
    Icons.face_3,
    Icons.face_4,
    Icons.face_5,
    Icons.face_6,
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ProfileService.instance.loadForCurrentUser();
      if (!mounted) return;

      final svc = ProfileService.instance;
      setState(() {
        _avatarBytes = svc.avatarBytes.value;
        _selectedIcon = svc.avatarIcon.value;
        _profileName = svc.name.value;
        _profileUsername = svc.username.value;
      });

      await _loadCurrentTheme();
      await _loadProfileFromBackend();
    });
  }

  Future<void> _loadCurrentTheme() async {
    if (!mounted) return;

    final themeProvider = context.read<ThemeProvider>();
    setState(() {
      _themeLabel = themeProvider.labelFor(themeProvider.themeMode);
    });
  }

  Future<void> _loadProfileFromBackend() async {
    try {
      final firebaseResult = await FirebaseSettingsService.loadProfile();
      final profile = firebaseResult['profile'] as Map<String, dynamic>?;

      if (profile != null && profile.isNotEmpty) {
        final name = (profile['name'] ?? '').toString().trim();
        final username = (profile['username'] ?? '').toString().trim();

        if (!mounted) return;

        setState(() {
          _profileName = name.isNotEmpty ? name : _profileName;
          _profileUsername = username.isNotEmpty ? '@$username' : _profileUsername;
        });

        await ProfileService.instance.updateProfile(
          newName: _profileName,
          newUsername: _profileUsername,
        );
        return;
      }

      final backendUser = await AuthService.getCurrentUser();
      if (!mounted || backendUser == null) return;

      final name = (backendUser['name'] ?? '').toString().trim();
      final username = (backendUser['username'] ?? '').toString().trim();

      setState(() {
        _profileName = name.isNotEmpty ? name : _profileName;
        _profileUsername = username.isNotEmpty ? '@$username' : _profileUsername;
      });

      await ProfileService.instance.updateProfile(
        newName: _profileName,
        newUsername: _profileUsername,
      );
    } catch (_) {
      // Keep the current local profile if remote data is unavailable.
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Theme.of(dialogContext).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "Log Out",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Text(
            "Are you sure you want to log out?",
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                "Cancel",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "Log Out",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) return;

    try {
      if (!mounted) return;

      setState(() {
        _isLoggingOut = true;
      });

      await ProfileService.instance.clearInMemoryCache();
      await AuthService.logout();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Logout failed: $e',
            style: const TextStyle(fontSize: 13),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'Settings',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 30),

              Center(
                child: GestureDetector(
                  onTap: () => _showProfileBottomSheet(context),
                  child: Stack(
                    children: [
                      _buildAvatarWidget(radius: 45),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.edit,
                            color: Theme.of(context).colorScheme.surface,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Center(
                child: Column(
                  children: [
                    Text(
                      _profileName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _profileUsername,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              Text(
                "Account Settings",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),

              _buildSettingsTile(
                icon: Icons.person_outline,
                title: "Profile",
                onTap: () => _showProfileBottomSheet(context),
              ),
              _buildSettingsTile(
                icon: Icons.lock_outline,
                title: "Security",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SecuritySubPage(),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Text(
                "App Settings",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),

              _buildSettingsTile(
                icon: Icons.notifications_none,
                title: "Notifications",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsSubPage(),
                  ),
                ),
              ),
              _buildSettingsTile(
                icon: Icons.lightbulb_outline,
                title: "Appearance",
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ThemeSubPage(),
                    ),
                  );
                  await _loadCurrentTheme();
                },
                trailing: Text(
                  _themeLabel,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              _buildLogOutButton(),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurface,
        size: 20,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      trailing: trailing ??
          Icon(
            Icons.chevron_right,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 20,
          ),
    );
  }

  Widget _buildLogOutButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: _isLoggingOut ? null : _confirmLogout,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoggingOut
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.red,
                ),
              )
            : const Text(
                "Log Out",
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Future<void> _showProfileBottomSheet(BuildContext context) async {
    Uint8List? draftAvatarBytes = _avatarBytes;
    IconData? draftSelectedIcon = _selectedIcon;

    final TextEditingController draftNameController =
        TextEditingController(text: _profileName);

    final TextEditingController draftUsernameController =
        TextEditingController(
      text: _profileUsername.replaceAll('@', '').trim(),
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setBottomSheetState) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).dialogTheme.backgroundColor ?? Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _showAvatarOptions(
                            context,
                            currentAvatarBytes: draftAvatarBytes,
                            currentSelectedIcon: draftSelectedIcon,
                            onChanged: (newBytes, newIcon) {
                              setBottomSheetState(() {
                                draftAvatarBytes = newBytes;
                                draftSelectedIcon = newIcon;
                              });
                            },
                          ),
                          child: _buildAvatarWidget(
                            radius: 40,
                            avatarBytes: draftAvatarBytes,
                            selectedIcon: draftSelectedIcon,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _showAvatarOptions(
                              context,
                              currentAvatarBytes: draftAvatarBytes,
                              currentSelectedIcon: draftSelectedIcon,
                              onChanged: (newBytes, newIcon) {
                                setBottomSheetState(() {
                                  draftAvatarBytes = newBytes;
                                  draftSelectedIcon = newIcon;
                                });
                              },
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.onSurface,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.edit,
                                color: Theme.of(context).colorScheme.surface,
                                size: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              _buildInputLabel(context, "Name"),
              _buildValidatedTextField(
                draftNameController,
                "Enter your name",
                onChanged: (_) => setBottomSheetState(() {}),
              ),

              _buildInputLabel(context, "Username"),
              _buildUsernameField(
                draftUsernameController,
                "Enter username",
                onChanged: (_) => setBottomSheetState(() {}),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);
                    final trimmedName = draftNameController.text.trim();
                    final rawUsername = draftUsernameController.text.trim();
                    final usernameCore =
                        rawUsername.replaceAll('@', '').trim();

                    if (trimmedName.isEmpty || usernameCore.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Please fill in all fields",
                            style: TextStyle(fontSize: 13),
                          ),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    try {
                      var result = await AuthService.updateProfile(
                        name: trimmedName,
                        username: usernameCore,
                      );

                      if (!mounted) return;

                      if ((result['message'] ?? '').toString().toLowerCase().contains('success') == false &&
                          (result['message'] ?? '').toString().toLowerCase().contains('updated') == false) {
                        try {
                          result = await FirebaseSettingsService.updateProfile(
                            name: trimmedName,
                            photoUrl: null,
                          );
                        } catch (_) {
                          result = {'success': false, 'message': 'Unable to update profile.'};
                        }
                      } else {
                        result = {'success': true, 'message': result['message'] ?? 'Profile updated successfully.'};
                      }

                      if (result['success'] != true) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(result['message'].toString()),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }

                      setState(() {
                        _avatarBytes = draftAvatarBytes;
                        _selectedIcon = draftSelectedIcon;
                        _profileName = trimmedName;
                        _profileUsername = '@$usernameCore';
                      });

                      await ProfileService.instance.updateProfile(
                        bytes: _avatarBytes,
                        icon: _selectedIcon,
                        newName: _profileName,
                        newUsername: _profileUsername,
                      );

                      navigator.pop();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Profile updated successfully.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;

                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Profile update failed: $e'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8B653),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Save Profile",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );

    draftNameController.dispose();
    draftUsernameController.dispose();
  }

  Widget _buildAvatarWidget({
    double radius = 40,
    Uint8List? avatarBytes,
    IconData? selectedIcon,
  }) {
    final Uint8List? activeAvatarBytes = avatarBytes ?? _avatarBytes;
    final IconData? activeSelectedIcon = selectedIcon ?? _selectedIcon;

    if (activeAvatarBytes != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        backgroundImage: MemoryImage(activeAvatarBytes),
      );
    }

    if (activeSelectedIcon != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          activeSelectedIcon,
          size: radius * 0.8,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.person,
        size: 40,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  void _showAvatarOptions(
    BuildContext context, {
    required Uint8List? currentAvatarBytes,
    required IconData? currentSelectedIcon,
    required void Function(Uint8List? avatarBytes, IconData? selectedIcon)
        onChanged,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(ctx);

                final Uint8List? pickedBytes = await _takePhotoBytes();

                if (pickedBytes != null) {
                  onChanged(pickedBytes, null);

                  setState(() {
                    _avatarBytes = pickedBytes;
                    _selectedIcon = null;
                  });

                  await ProfileService.instance.uploadAndPersistAvatar(pickedBytes);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Upload Image'),
              onTap: () async {
                Navigator.pop(ctx);

                final Uint8List? pickedBytes = await _pickImageBytes();

                if (pickedBytes != null) {
                  onChanged(pickedBytes, null);

                  setState(() {
                    _avatarBytes = pickedBytes;
                    _selectedIcon = null;
                  });

                  await ProfileService.instance.uploadAndPersistAvatar(pickedBytes);
                }
              },
            ),
            _buildAvatarOptionTile(
              ctx,
              Icons.insert_emoticon,
              'Choose Icon',
              () async {
                final IconData? selected = await _showIconPicker(context);

                if (selected != null) {
                  onChanged(null, selected);

                  setState(() {
                    _avatarBytes = null;
                    _selectedIcon = selected;
                  });

                  await ProfileService.instance.updateProfile(icon: selected);
                }
              },
            ),
            if (currentAvatarBytes != null || currentSelectedIcon != null)
              _buildAvatarOptionTile(
                ctx,
                Icons.refresh,
                'Reset to Default',
                () {
                  onChanged(null, null);

                  setState(() {
                    _avatarBytes = null;
                    _selectedIcon = null;
                  });

                  ProfileService.instance.resetProfile();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarOptionTile(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(
        icon,
        size: 20,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Future<Uint8List?> _pickImageBytes() async {
    try {
      final ImagePicker picker = ImagePicker();

      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );

      if (file != null) return await file.readAsBytes();

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Uint8List?> _takePhotoBytes() async {
    try {
      final ImagePicker picker = ImagePicker();

      final XFile? file = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        imageQuality: 85,
      );

      if (file != null) {
        return await file.readAsBytes();
      }

      return null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Camera error: $e',
              style: const TextStyle(fontSize: 13),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      return null;
    }
  }

  Future<IconData?> _showIconPicker(BuildContext context) {
    return showModalBottomSheet<IconData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose an icon',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _iconOptions.length,
              itemBuilder: (context, index) {
                final icon = _iconOptions[index];

                return GestureDetector(
                  onTap: () => Navigator.pop(ctx, icon),
                  child: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Icon(
                      icon,
                      size: 24,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildValidatedTextField(
    TextEditingController controller,
    String hint, {
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(
        fontSize: 14,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildUsernameField(
    TextEditingController controller,
    String hint, {
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(
        fontSize: 14,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        prefixText: '@',
        prefixStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        hintText: hint,
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class ThemeSubPage extends StatefulWidget {
  const ThemeSubPage({super.key});

  @override
  State<ThemeSubPage> createState() => _ThemeSubPageState();
}

class _ThemeSubPageState extends State<ThemeSubPage> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final themeProvider = context.read<ThemeProvider>();
    if (!mounted) return;

    setState(() => _themeMode = themeProvider.themeMode);
  }

  Future<void> _setTheme(ThemeMode mode) async {
    final themeProvider = context.read<ThemeProvider>();
    await themeProvider.setTheme(mode);
    if (!mounted) return;

    setState(() => _themeMode = mode);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context, 'Appearance'),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose how the app looks while you use it.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            _buildThemeOption(
              'Light Mode',
              'Use the bright interface for daytime use.',
              ThemeMode.light,
            ),
            const SizedBox(height: 12),
            _buildThemeOption(
              'Dark Mode',
              'Use the darker interface for low-light use.',
              ThemeMode.dark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(String title, String subtitle, ThemeMode mode) {
    final selected = _themeMode == mode;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: selected
            ? colorScheme.primaryContainer.withValues(alpha: 0.35)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? const Color(0xFFE8B653) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: () => _setTheme(mode),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
          trailing: selected
              ? const Icon(Icons.check_circle, color: Color(0xFFE8B653), size: 18)
              : Icon(Icons.circle_outlined, color: colorScheme.outline, size: 18),
        ),
      ),
    );
  }
}

class SecuritySubPage extends StatefulWidget {
  const SecuritySubPage({super.key});

  @override
  State<SecuritySubPage> createState() => _SecuritySubPageState();
}

class _SecuritySubPageState extends State<SecuritySubPage> {
  final TextEditingController currentPasswordController =
      TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool _confirmPasswordValidationRequested = false;
  bool _showPasswordMismatchError = false;
  bool _currentPasswordVisible = false;
  bool _newPasswordVisible = false;
  bool _confirmPasswordVisible = false;
  String? _currentPasswordError;

  bool get _hasLength =>
      newPasswordController.text.length >= 8 &&
      newPasswordController.text.length <= 20;

  bool get _hasLetterAndNumber =>
      RegExp(r'(?=.*[A-Za-z])(?=.*\d)').hasMatch(newPasswordController.text);

  bool get _hasSpecial =>
      RegExp(r'[^A-Za-z0-9]').hasMatch(newPasswordController.text);

  bool get _passwordsMatch =>
      newPasswordController.text.isNotEmpty &&
      newPasswordController.text == confirmPasswordController.text;

  bool get _allPasswordCriteriaValid =>
      _hasLength && _hasLetterAndNumber && _hasSpecial;

  String get _passwordRequirementMessage {
    final parts = <String>[];
    if (!_hasLength) parts.add('8 characters (20 max)');
    if (!_hasLetterAndNumber) parts.add('1 letter and 1 number');
    if (!_hasSpecial) parts.add('1 special character');
    return parts.isEmpty
        ? 'Password requirements are met.'
        : 'Password must contain ${parts.join(', ')}.';
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
    });

    final currentPassword = currentPasswordController.text.trim();
    final newPassword = newPasswordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (currentPassword.isEmpty) {
      setState(() {
        _currentPasswordError = "Please enter your current password";
      });
      return;
    }

    if (!_allPasswordCriteriaValid || !_passwordsMatch) {
      setState(() {
        _showPasswordMismatchError = !_passwordsMatch;
      });
      _showSnackBar(
        _passwordRequirementMessage,
        Colors.orange,
      );
      return;
    }

    setState(() {
      _showPasswordMismatchError = false;
    });

    try {
      final result = await AuthService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );

      if (!mounted) return;

      final success = (result['message'] ?? '').toString().toLowerCase().contains('success') ||
          (result['message'] ?? '').toString().toLowerCase().contains('updated');

      if (success) {
        Navigator.pop(context);
        _showSnackBar(result['message'].toString(), Colors.green);
        return;
      }

      if (result['message'].toString().toLowerCase().contains('current password')) {
        setState(() {
          _currentPasswordError = result['message'].toString();
        });
      } else {
        _showSnackBar(result['message'].toString(), Colors.redAccent);
      }
    } catch (e) {
      if (!mounted) return;

      _showSnackBar('Password change failed: $e', Colors.redAccent);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 13),
        ),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context, "Security"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Manage your account's safety and access.",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "Change Password",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            _buildInputLabel(context, "Current Password"),
            _buildProfileTextField(
              context,
              currentPasswordController,
              "••••••••",
              isPassword: true,
              obscureText: !_currentPasswordVisible,
              onChanged: (_) {
                if (_currentPasswordError != null) {
                  setState(() => _currentPasswordError = null);
                }
              },
              onToggle: () {
                setState(() {
                  _currentPasswordVisible = !_currentPasswordVisible;
                });
              },
            ),
            if (_currentPasswordError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _currentPasswordError!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 11,
                  ),
                ),
              ),
            _buildInputLabel(context, "New Password"),
            _buildProfileTextField(
              context,
              newPasswordController,
              "Enter new password",
              isPassword: true,
              obscureText: !_newPasswordVisible,
              onChanged: (_) {
                setState(() {
                  _showPasswordMismatchError = false;
                  _confirmPasswordValidationRequested = false;
                });
              },
              onToggle: () {
                setState(() {
                  _newPasswordVisible = !_newPasswordVisible;
                });
              },
            ),
            const SizedBox(height: 12),
            const Text(
              "Password must have at least:",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            _buildPasswordCriteria(),
            const SizedBox(height: 16),
            _buildInputLabel(context, "Confirm New Password"),
            _buildProfileTextField(
              context,
              confirmPasswordController,
              "Confirm new password",
              isPassword: true,
              obscureText: !_confirmPasswordVisible,
              onChanged: (_) {
                setState(() {
                  _showPasswordMismatchError = false;
                  _confirmPasswordValidationRequested = false;
                });
              },
              onToggle: () {
                setState(() {
                  _confirmPasswordVisible = !_confirmPasswordVisible;
                });
              },
            ),
            const SizedBox(height: 6),
            if ((_confirmPasswordValidationRequested || _showPasswordMismatchError) && !_passwordsMatch)
              _buildPasswordMatchValidationRow(),
            const SizedBox(height: 32),
            _buildActionButton("Change Password", _changePassword),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordCriteria() {
    return Column(
      children: [
        _buildValidationRow("8 characters (20 max)", _hasLength),
        _buildValidationRow("1 letter and 1 number", _hasLetterAndNumber),
        _buildValidationRow(
          "1 special character (Example: # ? ! \$ & @)",
          _hasSpecial,
        ),
      ],
    );
  }

  Widget _buildValidationRow(String label, bool valid) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            valid ? Icons.check_circle : Icons.close,
            size: 14,
            color: valid ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: valid ? Colors.green : Colors.grey,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordMatchValidationRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.error_outline,
          size: 14,
          color: Colors.red,
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            !_allPasswordCriteriaValid
                ? _passwordRequirementMessage
                : 'Password does not match.',
            style: const TextStyle(
              color: Colors.red,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

class NotificationsSubPage extends StatefulWidget {
  const NotificationsSubPage({super.key});

  @override
  State<NotificationsSubPage> createState() => _NotificationsSubPageState();
}

class _NotificationsSubPageState extends State<NotificationsSubPage> {
  bool emailReminders = true;
  bool pushNotifications = true;
  bool inAppAlerts = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context, "Notifications"),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Manage your alerts to stay focused and organized.",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 32),
            _buildSwitchTile(
              "Email reminders",
              "Receive plan updates in your inbox.",
              emailReminders,
              (v) => setState(() => emailReminders = v),
            ),
            _buildSwitchTile(
              "Push notifications",
              "Get real-time alerts on your device.",
              pushNotifications,
              (v) => setState(() => pushNotifications = v),
            ),
            _buildSwitchTile(
              "In-app alerts",
              "See notifications while using the app.",
              inAppAlerts,
              (v) => setState(() => inAppAlerts = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String sub,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFFE8B653),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

PreferredSizeWidget _buildAppBar(BuildContext context, String title) {
  return AppBar(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    elevation: 0,
    leadingWidth: 80,
    leading: TextButton.icon(
      onPressed: () => Navigator.pop(context),
      icon: Icon(
        Icons.arrow_back_ios,
        size: 14,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      label: Text(
        'Back',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 13,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.only(left: 20),
      ),
    ),
    title: Text(
      title,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    ),
    centerTitle: true,
  );
}

Widget _buildInputLabel(BuildContext context, String label) {
  return Padding(
    padding: const EdgeInsets.only(
      bottom: 6,
      top: 12,
    ),
    child: Text(
      label,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 13,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    ),
  );
}

Widget _buildProfileTextField(
  BuildContext context,
  TextEditingController controller,
  String hint, {
  bool isPassword = false,
  bool obscureText = false,
  ValueChanged<String>? onChanged,
  VoidCallback? onToggle,
}) {
  return TextField(
    controller: controller,
    obscureText: isPassword ? obscureText : false,
    onChanged: onChanged,
    style: TextStyle(
      fontSize: 14,
      color: Theme.of(context).colorScheme.onSurface,
    ),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 13,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      suffixIcon: isPassword
          ? IconButton(
              onPressed: onToggle,
              icon: Icon(
                obscureText
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFE8B653),
          width: 1.5,
        ),
      ),
    ),
  );
}

Widget _buildActionButton(String text, VoidCallback onTap) {
  return SizedBox(
    width: double.infinity,
    height: 48,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFE8B653),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}