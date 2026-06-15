import 'package:flutter/material.dart';

import '../../navigation/main_wrapper.dart';
import '../../services/auth_service.dart';
import 'signup.dart';

const Color _brandYellow = Color(0xFFE8B653);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() {
    return _LoginScreenState();
  }
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _loginUser = TextEditingController();

  final TextEditingController _loginPass = TextEditingController();

  bool _obscureLogin = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  String? _formMessage;
  bool _isInfoMessage = false;

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

    return 'Unable to log in. Please check your credentials.';
  }

  void _clearMessage() {
    if (_formMessage == null) {
      return;
    }

    setState(() {
      _formMessage = null;
      _isInfoMessage = false;
    });
  }

  Future<void> _submitLogin() async {
    FocusScope.of(context).unfocus();

    final login = _loginUser.text.trim();
    final password = _loginPass.text;

    if (login.isEmpty && password.isEmpty) {
      setState(() {
        _formMessage = 'Enter your username or email and password.';
        _isInfoMessage = false;
      });

      return;
    }

    if (login.isEmpty) {
      setState(() {
        _formMessage = 'Enter your username or email.';
        _isInfoMessage = false;
      });

      return;
    }

    if (password.isEmpty) {
      setState(() {
        _formMessage = 'Enter your password.';
        _isInfoMessage = false;
      });

      return;
    }

    setState(() {
      _isLoading = true;
      _formMessage = null;
      _isInfoMessage = false;
    });

    try {
      final result = await AuthService.login(login: login, password: password);

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

      setState(() {
        _isLoading = false;
        _formMessage = _extractErrorMessage(result);
        _isInfoMessage = false;
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

  @override
  void dispose() {
    _loginUser.dispose();
    _loginPass.dispose();

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
                  'Log In',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: colors.onSurface,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Welcome back!\nLog in to continue planning.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),

                const SizedBox(height: 38),

                _buildLabeledField(
                  label: 'Username or Email',
                  hint: 'Enter your username or email',
                  controller: _loginUser,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email,
                  ],
                  onChanged: (_) {
                    _clearMessage();
                  },
                ),

                const SizedBox(height: 20),

                _buildLabeledField(
                  label: 'Password',
                  hint: 'Enter your password',
                  controller: _loginPass,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onChanged: (_) {
                    _clearMessage();
                  },
                  onSubmitted: (_) {
                    if (!_isLoading) {
                      _submitLogin();
                    }
                  },
                ),

                const SizedBox(height: 13),

                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _rememberMe,
                        activeColor: _brandYellow,
                        checkColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        side: BorderSide(color: colors.outline, width: 1.4),
                        onChanged: _isLoading
                            ? null
                            : (value) {
                                setState(() {
                                  _rememberMe = value ?? false;
                                });
                              },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Remember Me',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

                if (_formMessage != null) ...[
                  const SizedBox(height: 20),
                  _InlineFormMessage(
                    message: _formMessage!,
                    isInformation: _isInfoMessage,
                  ),
                ],

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitLogin,
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
                            'Log In',
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
                      'Don\'t have an account? ',
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
                                    return const SignUpScreen();
                                  },
                                ),
                              );
                            },
                      child: const Text(
                        'Sign Up',
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
    TextInputAction? textInputAction,
    Iterable<String>? autofillHints,
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
          obscureText: isPassword ? _obscureLogin : false,
          enabled: !_isLoading,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          autocorrect: !isPassword,
          enableSuggestions: !isPassword,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            color: colors.onSurface,
          ),
          decoration: InputDecoration(
            hintText: hint,
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
                    tooltip: _obscureLogin ? 'Show password' : 'Hide password',
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _obscureLogin = !_obscureLogin;
                            });
                          },
                    icon: Icon(
                      _obscureLogin
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

class _InlineFormMessage extends StatelessWidget {
  const _InlineFormMessage({
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
