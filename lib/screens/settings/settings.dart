import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../auth/login.dart';

/// Local ProfileService moved here so Settings owns the model used by avatar widgets.
class ProfileService {
  ProfileService._private();

  static final ProfileService instance = ProfileService._private();

  final ValueNotifier<Uint8List?> avatarBytes = ValueNotifier<Uint8List?>(null);
  final ValueNotifier<IconData?> avatarIcon = ValueNotifier<IconData?>(null);
  final ValueNotifier<String> name = ValueNotifier<String>('DiNaDrawing');
  final ValueNotifier<String> username = ValueNotifier<String>('@dinadrawing');

  void updateProfile({Uint8List? bytes, IconData? icon, String? newName, String? newUsername}) {
    if (bytes != null) avatarBytes.value = bytes;
    if (icon != null) avatarIcon.value = icon;
    if (newName != null) name.value = newName;
    if (newUsername != null) username.value = newUsername;
  }

  void resetProfile() {
    avatarBytes.value = null;
    avatarIcon.value = null;
    name.value = 'DiNaDrawing';
    username.value = '@dinadrawing';
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Uint8List? _avatarBytes;
  IconData? _selectedIcon;
  String _profileName = 'DiNaDrawing';
  String _profileUsername = '@dinadrawing';
  final List<IconData> _iconOptions = [
    Icons.face,
    Icons.face_2,
    Icons.face_3,
    Icons.face_4,
    Icons.face_5,
    Icons.face_6,
  ];

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final svc = ProfileService.instance;
    _avatarBytes = svc.avatarBytes.value;
    _selectedIcon = svc.avatarIcon.value;
    _profileName = svc.name.value;
    _profileUsername = svc.username.value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Settings',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black),
              ),
              const SizedBox(height: 30),
              
              // Profile Header
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
                          decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                          child: const Icon(Icons.edit, color: Colors.white, size: 14),
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
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _profileUsername,
                      style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500), 
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Account Settings
              const Text("Account Settings", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 12)), 
              const SizedBox(height: 8),
              _buildSettingsTile(
                icon: Icons.person_outline, 
                title: "Profile", 
                onTap: () => _showProfileBottomSheet(context)
              ),
              _buildSettingsTile(
                icon: Icons.lock_outline, 
                title: "Security", 
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SecuritySubPage()))
              ),

              const SizedBox(height: 24),

              // App Settings
              const Text("App Settings", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 8),
              _buildSettingsTile(
                icon: Icons.notifications_none, 
                title: "Notifications",
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsSubPage()))
              ),
              _buildSettingsTile(
                icon: Icons.lightbulb_outline, 
                title: "Appearance", 
                trailing: const Text("Light", style: TextStyle(color: Colors.grey, fontSize: 13))
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

  // --- UI Helpers ---

  Widget _buildSettingsTile({required IconData icon, required String title, Widget? trailing, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.black, size: 20), 
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), 
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
    );
  }

  Widget _buildLogOutButton() {
    return SizedBox(
      width: double.infinity,
      height: 48, 
      child: OutlinedButton(
        onPressed: () {
          // --- LOGOUT CONFIRMATION DIALOG ---
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text(
                  "Log Out", 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                ),
                content: const Text(
                  "Are you sure you want to log out?",
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
                actions: [
                  // CANCEL BUTTON
                  TextButton(
                    onPressed: () => Navigator.pop(context), 
                    child: const Text(
                      "Cancel", 
                      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)
                    ),
                  ),
                  // CONFIRM LOGOUT BUTTON
                  ElevatedButton(
                    onPressed: () {
                      // Tuluyan nang maglo-log out kapag pinindot ito
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      "Log Out", 
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                    ),
                  ),
                ],
              );
            },
          );
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFF0F0F0), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text(
          "Log Out", 
          style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.bold)
        ), 
      ),
    );
  }

  // --- Panel 2: Profile Bottom Sheet ---
  Future<void> _showProfileBottomSheet(BuildContext context) async {
    Uint8List? draftAvatarBytes = _avatarBytes;
    IconData? draftSelectedIcon = _selectedIcon;
    final TextEditingController draftNameController = TextEditingController(text: _profileName);
    final TextEditingController draftUsernameController = TextEditingController(text: _profileUsername.replaceAll('@', '').trim());

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setBottomSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
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
                              decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                              child: const Icon(Icons.edit, color: Colors.white, size: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildInputLabel("Name"),
              _buildValidatedTextField(
                draftNameController,
                "Enter your name",
                onChanged: (_) => setBottomSheetState(() {}),
              ),
              _buildInputLabel("Username"),
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
                  onPressed: () {
                    final trimmedName = draftNameController.text.trim();
                    final rawUsername = draftUsernameController.text.trim();
                    final usernameCore = rawUsername.replaceAll('@', '').trim();

                    if (trimmedName.isEmpty || usernameCore.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Please fill in all fields", style: TextStyle(fontSize: 13)),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    } else {
                      setState(() {
                        _avatarBytes = draftAvatarBytes;
                        _selectedIcon = draftSelectedIcon;
                        _profileName = trimmedName;
                        _profileUsername = '@$usernameCore';
                      });
                      ProfileService.instance.updateProfile(
                        bytes: _avatarBytes,
                        icon: _selectedIcon,
                        newName: _profileName,
                        newUsername: _profileUsername,
                      );
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8B653), // Matched yellow
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    "Save Profile",
                    style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold),
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
      return CircleAvatar(radius: radius, backgroundColor: const Color(0xFFE0E0E0), backgroundImage: MemoryImage(activeAvatarBytes));
    }

    if (activeSelectedIcon != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFE0E0E0),
        child: Icon(activeSelectedIcon, size: radius * 0.8, color: Colors.black87),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE0E0E0),
      child: const Icon(Icons.person, size: 40, color: Colors.grey),
    );
  }

  void _showAvatarOptions(
    BuildContext context, {
    required Uint8List? currentAvatarBytes,
    required IconData? currentSelectedIcon,
    required void Function(Uint8List? avatarBytes, IconData? selectedIcon) onChanged,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
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
                  ProfileService.instance.updateProfile(bytes: pickedBytes);
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
                  ProfileService.instance.updateProfile(bytes: pickedBytes);
                }
              },
            ),
            _buildAvatarOptionTile(ctx, Icons.insert_emoticon, 'Choose Icon', () async {
              final IconData? selected = await _showIconPicker(context);
              if (selected != null) {
                onChanged(null, selected);
                setState(() {
                  _avatarBytes = null;
                  _selectedIcon = selected;
                });
                ProfileService.instance.updateProfile(icon: selected);
              }
            }),
            if (currentAvatarBytes != null || currentSelectedIcon != null)
              _buildAvatarOptionTile(ctx, Icons.refresh, 'Reset to Default', () {
                onChanged(null, null);
                setState(() {
                  _avatarBytes = null;
                  _selectedIcon = null;
                });
                ProfileService.instance.resetProfile();
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarOptionTile(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, size: 20, color: Colors.black87),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  // --- PINASIMPLENG IMAGE PICKER PARA SA WEB/PHONE ---
  Future<Uint8List?> _pickImageBytes() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
      if (file != null) return await file.readAsBytes();
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- PINASIMPLENG CAMERA PICKER PARA SA WEB/PHONE ---
  Future<Uint8List?> _takePhotoBytes() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.camera, maxWidth: 1200, imageQuality: 85);
      if (file != null) {
        return await file.readAsBytes();
      }
      return null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera error: $e', style: const TextStyle(fontSize: 13)),
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose an icon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 1, crossAxisSpacing: 12, mainAxisSpacing: 12),
              itemCount: _iconOptions.length,
              itemBuilder: (context, index) {
                final icon = _iconOptions[index];
                return GestureDetector(
                  onTap: () => Navigator.pop(ctx, icon),
                  child: CircleAvatar(
                    backgroundColor: const Color(0xFFF5F5F5),
                    child: Icon(icon, size: 24, color: Colors.black87),
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
      style: const TextStyle(fontSize: 14), 
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13), 
        filled: true,
        fillColor: const Color(0xFFF9F9F9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        prefixText: '@',
        prefixStyle: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF9F9F9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}


// --- Panel 3: Security Page ---
class SecuritySubPage extends StatefulWidget {
  const SecuritySubPage({super.key});

  @override
  State<SecuritySubPage> createState() => _SecuritySubPageState();
}

class _SecuritySubPageState extends State<SecuritySubPage> {
  final TextEditingController currentPasswordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  bool _confirmPasswordValidationRequested = false;
  bool _currentPasswordVisible = false;
  bool _newPasswordVisible = false;
  bool _confirmPasswordVisible = false;
  String? _currentPasswordError;

  bool get _hasLength => newPasswordController.text.length >= 8 && newPasswordController.text.length <= 20;
  bool get _hasLetterAndNumber => RegExp(r'(?=.*[A-Za-z])(?=.*\d)').hasMatch(newPasswordController.text);
  bool get _hasSpecial => RegExp(r'[^A-Za-z0-9]').hasMatch(newPasswordController.text);
  bool get _passwordsMatch => newPasswordController.text.isNotEmpty &&
      newPasswordController.text == confirmPasswordController.text;
  bool get _allPasswordCriteriaValid => _hasLength && _hasLetterAndNumber && _hasSpecial;

  @override
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _changePassword() {
    setState(() {
      _confirmPasswordValidationRequested = true;
      _currentPasswordError = null;
    });

    final currentPassword = currentPasswordController.text.trim();

    if (currentPassword.isEmpty) {
      setState(() => _currentPasswordError = "Please enter your current password");
      return;
    }

    if (!_allPasswordCriteriaValid || !_passwordsMatch) return;

    if (currentPassword != "correctpassword") {
      setState(() => _currentPasswordError = "Current password is incorrect");
      return;
    }

    Navigator.pop(context);
    _showSnackBar("Password changed successfully! 🌹", Colors.green);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: const TextStyle(fontSize: 13)), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context, "Security"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Manage your account's safety and access.", style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 32),
            const Text("Change Password", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            
            _buildInputLabel("Current Password"),
            _buildProfileTextField(
              currentPasswordController,
              "••••••••",
              isPassword: true,
              obscureText: !_currentPasswordVisible,
              onChanged: (_) {
                if (_currentPasswordError != null) setState(() => _currentPasswordError = null);
              },
              onToggle: () => setState(() => _currentPasswordVisible = !_currentPasswordVisible),
            ),
            if (_currentPasswordError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_currentPasswordError!, style: const TextStyle(color: Colors.red, fontSize: 11)),
              ),
              
            _buildInputLabel("New Password"),
            _buildProfileTextField(
              newPasswordController,
              "Enter new password",
              isPassword: true,
              obscureText: !_newPasswordVisible,
              onChanged: (_) => setState(() {}),
              onToggle: () => setState(() => _newPasswordVisible = !_newPasswordVisible),
            ),
            
            const SizedBox(height: 12),
            const Text("Password must have atleast:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            const SizedBox(height: 8),
            _buildPasswordCriteria(),
            
            const SizedBox(height: 16),
            _buildInputLabel("Confirm New Password"),
            _buildProfileTextField(
              confirmPasswordController,
              "Confirm new password",
              isPassword: true,
              obscureText: !_confirmPasswordVisible,
              onChanged: (_) => setState(() {}),
              onToggle: () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible),
            ),
            const SizedBox(height: 6),
            if (_confirmPasswordValidationRequested && !_passwordsMatch)
              _buildPasswordMatchValidationRow(false),
              
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
        _buildValidationRow("1 special character (Example: # ? ! \$ & @)", _hasSpecial),
      ],
    );
  }

  Widget _buildValidationRow(String label, bool valid) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(valid ? Icons.check_circle : Icons.close, size: 14, color: valid ? Colors.green : Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(color: valid ? Colors.green : Colors.grey, fontSize: 11))),
        ],
      ),
    );
  }

  Widget _buildPasswordMatchValidationRow(bool match) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, size: 14, color: Colors.red), 
        const SizedBox(width: 8),
        const Expanded(child: Text("Password does not match", style: TextStyle(color: Colors.red, fontSize: 11))),
      ],
    );
  }
}

// --- Panel 4: Notifications Page ---
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
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context, "Notifications"),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Manage your alerts to stay focused and organized.", style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 32),
            _buildSwitchTile("Email reminders", "Receive plan updates in your inbox.", emailReminders, (v) => setState(() => emailReminders = v)),
            _buildSwitchTile("Push notifications", "Get real-time alerts on your device.", pushNotifications, (v) => setState(() => pushNotifications = v)),
            _buildSwitchTile("In-app alerts", "See notifications while using the app.", inAppAlerts, (v) => setState(() => inAppAlerts = v)),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, String sub, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), 
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 11)), 
              ],
            ),
          ),
          Switch(value: value, activeColor: Colors.white, activeTrackColor: const Color(0xFFE8B653), onChanged: onChanged), 
        ],
      ),
    );
  }
}

// --- Shared Custom Components ---

PreferredSizeWidget _buildAppBar(BuildContext context, String title) {
  return AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    leadingWidth: 80,
    leading: TextButton.icon(
      onPressed: () => Navigator.pop(context),
      icon: const Icon(Icons.arrow_back_ios, size: 14, color: Colors.black87),
      label: const Text('Back', style: TextStyle(color: Colors.black87, fontSize: 13)),
      style: TextButton.styleFrom(padding: const EdgeInsets.only(left: 20)),
    ),
    title: Text(title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)), 
    centerTitle: true,
  );
}

Widget _buildInputLabel(String label) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 12),
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)), 
  );
}

Widget _buildProfileTextField(
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
    style: const TextStyle(fontSize: 14), 
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), 
      suffixIcon: isPassword
          ? IconButton(
              onPressed: onToggle,
              icon: Icon(
                obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18,
                color: Colors.grey,
              ),
            )
          : null,
      filled: true,
      fillColor: const Color(0xFFF9F9F9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE8B653), width: 1.5), 
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold)),
    ),
  );
}