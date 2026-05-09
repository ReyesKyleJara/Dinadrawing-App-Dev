import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Avatar state: either bytes for an image, or an icon selected by user
  Uint8List? _avatarBytes;
  IconData? _selectedIcon;
  String _profileName = 'DiNaDrawing';
  String _profileUsername = '@dinadrawing';
  final List<IconData> _iconOptions = [
    Icons.person,
    Icons.pets,
    Icons.star,
    Icons.palette,
    Icons.brush,
    Icons.favorite,
    Icons.camera_alt,
    Icons.mood,
  ];

  @override
  void dispose() {
    super.dispose();
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
              const Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              
              // Profile Header (Clickable Avatar)
              Center(
                child: GestureDetector(
                  onTap: () => _showProfileBottomSheet(context),
                  child: Stack(
                    children: [
                      _buildAvatarWidget(radius: 50),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                          child: const Icon(Icons.edit, color: Colors.white, size: 16),
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
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _profileUsername,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Account Settings
              const Text("Account Settings", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
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

              const SizedBox(height: 30),

              // App Settings
              const Text("App Settings", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              _buildSettingsTile(
                icon: Icons.notifications_none, 
                title: "Notifications",
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsSubPage()))
              ),
              _buildSettingsTile(
                icon: Icons.lightbulb_outline, 
                title: "Appearance", 
                trailing: const Text("Light", style: TextStyle(color: Colors.grey))
              ),

              const SizedBox(height: 40),
              _buildLogOutButton(),
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
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
    );
  }

  Widget _buildLogOutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFF5F5F5)),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text("Log Out", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- Panel 2: Profile Bottom Sheet with Left-Alignment & Validation ---
  Future<void> _showProfileBottomSheet(BuildContext context) async {
    Uint8List? draftAvatarBytes = _avatarBytes;
    IconData? draftSelectedIcon = _selectedIcon;
    final TextEditingController draftNameController = TextEditingController(text: _profileName);
    final TextEditingController draftUsernameController = TextEditingController(text: _profileUsername);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setBottomSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
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
                              child: const Icon(Icons.edit, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              _buildInputLabel("Name"),
              _buildValidatedTextField(
                draftNameController,
                "Enter your name",
                onChanged: (_) => setBottomSheetState(() {}),
              ),
              _buildInputLabel("Username"),
              _buildValidatedTextField(
                draftUsernameController,
                "Enter username",
                onChanged: (_) => setBottomSheetState(() {}),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    final trimmedName = draftNameController.text.trim();
                    final trimmedUsername = draftUsernameController.text.trim();

                    if (trimmedName.isEmpty || trimmedUsername.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Please fill in all fields"),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    } else {
                      setState(() {
                        _avatarBytes = draftAvatarBytes;
                        _selectedIcon = draftSelectedIcon;
                        _profileName = trimmedName;
                        _profileUsername = trimmedUsername;
                      });
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB84D),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    "Save Profile",
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
        child: Icon(activeSelectedIcon, size: radius * 0.8, color: Colors.deepPurple),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE0E0E0),
      child: const Icon(Icons.person, size: 40, color: Colors.grey),
    );
  }

  // Show avatar options and update only draft state while bottom sheet is open
  void _showAvatarOptions(
    BuildContext context, {
    required Uint8List? currentAvatarBytes,
    required IconData? currentSelectedIcon,
    required void Function(Uint8List? avatarBytes, IconData? selectedIcon) onChanged,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Upload Image'),
              onTap: () async {
                Navigator.pop(ctx);
                final Uint8List? pickedBytes = await _pickImageBytes();
                if (pickedBytes != null) {
                  onChanged(pickedBytes, null);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_emoticon),
              title: const Text('Choose Icon'),
              onTap: () async {
                Navigator.pop(ctx);
                final IconData? selected = await _showIconPicker(context);
                if (selected != null) {
                  onChanged(null, selected);
                }
              },
            ),
            if (currentAvatarBytes != null || currentSelectedIcon != null)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Reset to Default'),
                onTap: () {
                  onChanged(null, null);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<Uint8List?> _pickImageBytes() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
      if (file != null) {
        return file.readAsBytes();
      }
      return null;
    } catch (e) {
      // ignore errors for now
      return null;
    }
  }

  Future<IconData?> _showIconPicker(BuildContext context) {
    return showModalBottomSheet<IconData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose an icon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 1, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemCount: _iconOptions.length,
              itemBuilder: (context, index) {
                final icon = _iconOptions[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx, icon);
                  },
                  child: Container(
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, size: 28, color: Colors.deepPurple),
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
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF9F9F9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
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
  bool get _allPasswordCriteriaValid =>
      _hasLength &&
      _hasLetterAndNumber &&
      _hasSpecial;

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
      setState(() {
        _currentPasswordError = "Please enter your current password";
      });
      return;
    }

    if (!_allPasswordCriteriaValid) {
      return;
    }

    if (!_passwordsMatch) {
      return;
    }

    if (currentPassword != "correctpassword") {
      setState(() {
        _currentPasswordError = "Current password is incorrect";
      });
      return;
    }

    Navigator.pop(context);
    _showSnackBar("Password changed successfully! 🌹", Colors.green);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
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
            const Text("Manage your account's safety and access.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            const Text("Change Password", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            _buildInputLabel("Current Password"),
            _buildProfileTextField(
              currentPasswordController,
              "••••••••",
              isPassword: true,
              obscureText: !_currentPasswordVisible,
              onChanged: (_) {
                if (_currentPasswordError != null) {
                  setState(() {
                    _currentPasswordError = null;
                  });
                }
              },
              onToggle: () => setState(() => _currentPasswordVisible = !_currentPasswordVisible),
            ),
            if (_currentPasswordError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _currentPasswordError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
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
            const Text(
              "Password must have atleast:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 10),
            _buildPasswordCriteria(),
            const SizedBox(height: 20),
            _buildInputLabel("Confirm New Password"),
            _buildProfileTextField(
              confirmPasswordController,
              "Confirm new password",
              isPassword: true,
              obscureText: !_confirmPasswordVisible,
              onChanged: (_) => setState(() {}),
              onToggle: () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible),
            ),
            const SizedBox(height: 8),
            if (_confirmPasswordValidationRequested && !_passwordsMatch)
              _buildPasswordMatchValidationRow(false),
            const SizedBox(height: 10),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            valid ? Icons.check_circle : Icons.close,
            size: 18,
            color: valid ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: valid ? Colors.green : Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordMatchValidationRow(bool match) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            'images/warning sign.png',
            width: 18,
            height: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Password does not match",
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
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
            const Text("Manage your alerts to stay focused and organized.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            _buildSwitchTile(
              "Email reminders",
              "Receive plan updates in your inbox.",
              emailReminders,
              (value) => setState(() => emailReminders = value),
            ),
            _buildSwitchTile(
              "Push notifications",
              "Get real-time alerts on your device.",
              pushNotifications,
              (value) => setState(() => pushNotifications = value),
            ),
            _buildSwitchTile(
              "In-app alerts",
              "See notifications while using the app.",
              inAppAlerts,
              (value) => setState(() => inAppAlerts = value),
            ),
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
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Switch(value: value, activeColor: const Color(0xFFFFB84D), onChanged: onChanged),
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
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios, size: 16, color: Color(0xFFFFB84D)),
      onPressed: () => Navigator.pop(context),
    ),
    title: Text(title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
    centerTitle: false,
  );
}

Widget _buildInputLabel(String label) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 16),
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
    decoration: InputDecoration(
      hintText: hint,
      suffixIcon: isPassword
          ? IconButton(
              onPressed: onToggle,
              icon: Icon(
                obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 20,
              ),
            )
          : null,
      filled: true,
      fillColor: const Color(0xFFF9F9F9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    ),
  );
}

Widget _buildActionButton(String text, VoidCallback onTap) {
  return SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFB84D),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
    ),
  );
}