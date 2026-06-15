import 'dart:async';

import 'package:flutter/material.dart';

import '../../navigation/main_wrapper.dart';
import '../../services/auth_service.dart';
import 'login.dart';

const Color _brandYellow = Color(0xFFE8B653);

enum _UsernameStatus { idle, checking, available, taken, invalid, error }

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() {
    return _SignUpScreenState();
  }
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _nameController = TextEditingController();

  final TextEditingController _usernameController = TextEditingController();

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  Timer? _usernameDebounce;

  bool _obscurePassword = true;
  bool _isLoading = false;

  String? _formMessage;
  bool _isInfoMessage = false;

  _UsernameStatus _usernameStatus = _UsernameStatus.idle;

  String? _usernameMessage;
  String? _lastCheckedUsername;

  String _normalizeUsername(String value) {
    return value.trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase();
  }

  String? _validateUsername(String username) {
    if (username.isEmpty) {
      return 'Enter a username.';
    }

    if (username.length < 3 || username.length > 20) {
      return 'Username must contain 3 to 20 characters.';
    }

    if (!RegExp(r'^[A-Za-z0-9._]+$').hasMatch(username)) {
      return 'Use letters, numbers, periods, and underscores only.';
    }

    return null;
  }

  bool _isValidEmail(String email) {
    final atIndex = email.indexOf('@');
    final lastDotIndex = email.lastIndexOf('.');

    return atIndex > 0 &&
        lastDotIndex > atIndex + 1 &&
        lastDotIndex < email.length - 1;
  }

  String _extractErrorMessage(Map<String, dynamic> result) {
    final message = result['message']?.toString().trim();

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

    if (message != null && message.isNotEmpty) {
      return message;
    }

    return 'Unable to create your account.';
  }

  void _clearFormMessage() {
    if (_formMessage == null) {
      return;
    }

    setState(() {
      _formMessage = null;
      _isInfoMessage = false;
    });
  }

  void _handleUsernameChanged(String value) {
    _usernameDebounce?.cancel();

    final username = _normalizeUsername(value);
    final validationError = _validateUsername(username);

    _clearFormMessage();

    if (username.isEmpty) {
      setState(() {
        _usernameStatus = _UsernameStatus.idle;
        _usernameMessage = null;
        _lastCheckedUsername = null;
      });

      return;
    }

    if (validationError != null) {
      setState(() {
        _usernameStatus = _UsernameStatus.invalid;
        _usernameMessage = validationError;
        _lastCheckedUsername = null;
      });

      return;
    }

    setState(() {
      _usernameStatus = _UsernameStatus.checking;
      _usernameMessage = 'Checking username availability...';
      _lastCheckedUsername = null;
    });

    _usernameDebounce = Timer(const Duration(milliseconds: 550), () {
      _checkUsernameAvailability(username);
    });
  }

  Future<bool> _checkUsernameAvailability(String username) async {
    final validationError = _validateUsername(username);

    if (validationError != null) {
      if (mounted) {
        setState(() {
          _usernameStatus = _UsernameStatus.invalid;
          _usernameMessage = validationError;
          _lastCheckedUsername = null;
        });
      }

      return false;
    }

    if (mounted) {
      setState(() {
        _usernameStatus = _UsernameStatus.checking;
        _usernameMessage = 'Checking username availability...';
      });
    }

    try {
      final result = await AuthService.checkUsername(username: username);

      if (!mounted) {
        return false;
      }

      final currentUsername = _normalizeUsername(_usernameController.text);

      if (currentUsername != username) {
        return false;
      }

      final available =
          result['success'] == true && result['available'] == true;

      setState(() {
        _lastCheckedUsername = username;

        if (available) {
          _usernameStatus = _UsernameStatus.available;
          _usernameMessage = 'Username is available.';
        } else if (result['success'] == true) {
          _usernameStatus = _UsernameStatus.taken;
          _usernameMessage =
              result['message']?.toString() ??
              'Username already exists. Try another.';
        } else {
          _usernameStatus = _UsernameStatus.error;
          _usernameMessage =
              result['message']?.toString() ?? 'Unable to check this username.';
        }
      });

      return available;
    } catch (_) {
      if (!mounted) {
        return false;
      }

      setState(() {
        _usernameStatus = _UsernameStatus.error;
        _usernameMessage = 'Unable to check username availability.';
        _lastCheckedUsername = null;
      });

      return false;
    }
  }

  Future<void> _submitSignUp() async {
    FocusScope.of(context).unfocus();
    _usernameDebounce?.cancel();

    final name = _nameController.text.trim();

    final username = _normalizeUsername(_usernameController.text);

    final email = _emailController.text.trim();

    final password = _passwordController.text;

    if (name.isEmpty || username.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() {
        _formMessage = 'Complete all required fields.';
        _isInfoMessage = false;
      });

      return;
    }

    if (name.length < 2) {
      setState(() {
        _formMessage = 'Enter a valid name.';
        _isInfoMessage = false;
      });

      return;
    }

    final usernameError = _validateUsername(username);

    if (usernameError != null) {
      setState(() {
        _usernameStatus = _UsernameStatus.invalid;
        _usernameMessage = usernameError;

        _formMessage = 'Check your username before continuing.';
        _isInfoMessage = false;
      });

      return;
    }

    if (!_isValidEmail(email)) {
      setState(() {
        _formMessage = 'Enter a valid email address.';
        _isInfoMessage = false;
      });

      return;
    }

    if (password.length < 8) {
      setState(() {
        _formMessage = 'Password must contain at least 8 characters.';
        _isInfoMessage = false;
      });

      return;
    }

    final usernameAlreadyVerified =
        _usernameStatus == _UsernameStatus.available &&
        _lastCheckedUsername == username;

    if (!usernameAlreadyVerified) {
      final usernameAvailable = await _checkUsernameAvailability(username);

      if (!usernameAvailable || !mounted) {
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _formMessage = null;
      _isInfoMessage = false;
    });

    try {
      final result = await AuthService.register(
        name: name,
        username: username,
        email: email,
        password: password,
      );

      if (!mounted) {
        return;
      }

      final success = result['success'] == true || result['token'] != null;

      if (success) {
        setState(() {
          _isLoading = false;
        });

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainWrapper()),
          (route) => false,
        );

        return;
      }

      final errorMessage = _extractErrorMessage(result);

      setState(() {
        _isLoading = false;
        _formMessage = errorMessage;
        _isInfoMessage = false;

        if (errorMessage.toLowerCase().contains('username')) {
          _usernameStatus = _UsernameStatus.taken;
          _usernameMessage = 'Username already exists. Try another.';
          _lastCheckedUsername = username;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _formMessage =
            'Unable to connect to the server. Check your connection and try again.';
        _isInfoMessage = false;
      });
    }
  }

  void _showGoogleComingSoon() {
    FocusScope.of(context).unfocus();

    setState(() {
      _formMessage = 'Google Sign-In is not available yet.';
      _isInfoMessage = true;
    });
  }

  Color _usernameMessageColor(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    switch (_usernameStatus) {
      case _UsernameStatus.available:
        return Colors.green.shade700;

      case _UsernameStatus.invalid:
      case _UsernameStatus.taken:
      case _UsernameStatus.error:
        return colors.error;

      case _UsernameStatus.checking:
      case _UsernameStatus.idle:
        return colors.onSurfaceVariant;
    }
  }

  IconData? get _usernameMessageIcon {
    switch (_usernameStatus) {
      case _UsernameStatus.available:
        return Icons.check_circle_rounded;

      case _UsernameStatus.invalid:
      case _UsernameStatus.taken:
      case _UsernameStatus.error:
        return Icons.error_rounded;

      case _UsernameStatus.checking:
      case _UsernameStatus.idle:
        return null;
    }
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();

    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: AutofillGroup(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Back',
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.maybePop(context);
                          },
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: colors.onSurface,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                _buildLogoHeader(),

                const SizedBox(height: 32),

                Text(
                  'Sign Up',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: colors.onSurface,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Create an account to start planning\nwith your barkada!',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),

                const SizedBox(height: 38),

                _buildLabeledField(
                  label: 'Name',
                  hint: 'Enter your name',
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  onChanged: (_) {
                    _clearFormMessage();
                  },
                ),

                const SizedBox(height: 20),

                _buildLabeledField(
                  label: 'Username',
                  hint: 'username_123',
                  controller: _usernameController,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newUsername],
                  autocorrect: false,
                  enableSuggestions: false,
                  prefixText: '@',
                  onChanged: _handleUsernameChanged,
                ),

                if (_usernameMessage != null) ...[
                  const SizedBox(height: 8),
                  _buildUsernameMessage(),
                ],

                const SizedBox(height: 20),

                _buildLabeledField(
                  label: 'Email',
                  hint: 'example@gmail.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: (_) {
                    _clearFormMessage();
                  },
                ),

                const SizedBox(height: 20),

                _buildLabeledField(
                  label: 'Password',
                  hint: 'Enter your password',
                  controller: _passwordController,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: (_) {
                    _clearFormMessage();
                  },
                  onSubmitted: (_) {
                    if (!_isLoading) {
                      _submitSignUp();
                    }
                  },
                ),

                const SizedBox(height: 8),

                Text(
                  'Must contain at least 8 characters.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                if (_formMessage != null) ...[
                  const SizedBox(height: 20),
                  _InlineSignUpMessage(
                    message: _formMessage!,
                    isInformation: _isInfoMessage,
                  ),
                ],

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitSignUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandYellow,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: colors.surfaceContainerHighest,
                      disabledForegroundColor: colors.onSurfaceVariant,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 21,
                            height: 21,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            'Sign Up',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 30),

                _buildDivider(),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _showGoogleComingSoon,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.onSurface,
                      backgroundColor: colors.surface,
                      side: BorderSide(
                        color: colors.outlineVariant,
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.g_mobiledata_rounded,
                          color: colors.onSurface,
                          size: 29,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Continue with Google',
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    GestureDetector(
                      onTap: _isLoading
                          ? null
                          : () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) {
                                    return const LoginScreen();
                                  },
                                ),
                              );
                            },
                      child: const Text(
                        'Log In',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _brandYellow,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUsernameMessage() {
    final theme = Theme.of(context);
    final color = _usernameMessageColor(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_usernameStatus == _UsernameStatus.checking)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 1.8, color: color),
          )
        else if (_usernameMessageIcon != null)
          Icon(_usernameMessageIcon, size: 16, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            _usernameMessage!,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: color,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoHeader() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'images/logo.png',
          height: 29,
          width: 29,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.calendar_today_rounded,
              size: 28,
              color: _brandYellow,
            );
          },
        ),
        const SizedBox(width: 9),
        Text(
          'DiNaDrawing',
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: colors.onSurface,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Expanded(child: Divider(color: colors.outlineVariant, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or continue with',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: colors.outlineVariant, thickness: 1)),
      ],
    );
  }

  Widget _buildLabeledField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool isPassword = false,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputAction? textInputAction,
    Iterable<String>? autofillHints,
    bool autocorrect = true,
    bool enableSuggestions = true,
    String? prefixText,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
          ),
        ),

        const SizedBox(height: 8),

        TextField(
          controller: controller,
          obscureText: isPassword ? _obscurePassword : false,
          enabled: !_isLoading,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          autocorrect: autocorrect,
          enableSuggestions: enableSuggestions,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            color: colors.onSurface,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefixText,
            filled: true,
            fillColor: colors.surface,
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.70),
              fontSize: 14,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
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
              borderSide: const BorderSide(color: _brandYellow, width: 1.5),
            ),
            suffixIcon: isPassword
                ? IconButton(
                    tooltip: _obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: colors.onSurfaceVariant,
                      size: 20,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

class _InlineSignUpMessage extends StatelessWidget {
  const _InlineSignUpMessage({
    required this.message,
    required this.isInformation,
  });

  final String message;
  final bool isInformation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final backgroundColor = isInformation
        ? colors.primaryContainer
        : colors.errorContainer;

    final foregroundColor = isInformation
        ? colors.onPrimaryContainer
        : colors.onErrorContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isInformation
                ? Icons.info_outline_rounded
                : Icons.error_outline_rounded,
            color: foregroundColor,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: foregroundColor,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
