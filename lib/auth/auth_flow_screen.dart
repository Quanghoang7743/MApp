import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'widgets/auth_logo.dart';
import 'widgets/auth_panel.dart';
import 'widgets/auth_primary_button.dart';
import 'widgets/auth_prompt_link.dart';
import 'widgets/auth_text_field.dart';
import 'widgets/gender_control.dart';

enum AuthMode { login, signup }

class AuthFlowScreen extends StatefulWidget {
  const AuthFlowScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  State<AuthFlowScreen> createState() => _AuthFlowScreenState();
}

class _AuthFlowScreenState extends State<AuthFlowScreen> {
  AuthMode _mode = AuthMode.login;
  GenderOption _gender = GenderOption.male;
  DateTime? _birthDate;

  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    HapticFeedback.selectionClick();
    setState(() {
      _mode = _mode == AuthMode.signup ? AuthMode.login : AuthMode.signup;
    });
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20),
      firstDate: DateTime(1940),
      lastDate: now,
    );

    if (picked != null) {
      HapticFeedback.selectionClick();
      setState(() => _birthDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF101217), const Color(0xFF181B22)]
                : [const Color(0xFFF4F6FA), const Color(0xFFE9EDF3)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: InkWell(
                    onTap: widget.onToggleTheme,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF232733).withValues(alpha: 0.8)
                            : Colors.white.withValues(alpha: 0.84),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Icon(
                        widget.isDarkMode
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        size: 16,
                        color: isDark
                            ? const Color(0xFFF0F2F5)
                            : const Color(0xFF3E4758),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          // gradient: LinearGradient(
                          //   begin: Alignment.topCenter,
                          //   end: Alignment.bottomCenter,
                          //   colors: isDark
                          //       ? [
                          //           const Color(0xFF14171D),
                          //           const Color(0xFF1A1E26),
                          //         ]
                          //       : [
                          //           const Color(0xFFFCFDFF),
                          //           const Color(0xFFF3F6FB),
                          //         ],
                          // ),
                          // // borderRadius: BorderRadius.circular(32),
                          // boxShadow: [
                          //   BoxShadow(
                          //     color: Colors.black.withValues(
                          //       alpha: isDark ? 0.28 : 0.08,
                          //     ),
                          //     blurRadius: 36,
                          //     spreadRadius: -16,
                          //     offset: const Offset(0, 20),
                          //   ),
                          // ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                          child: Column(
                            children: [
                              const AuthLogo(),
                              const SizedBox(height: 18),
                              
                              Text(
                                _mode == AuthMode.login
                                    ? 'Chào mừng trở lại'
                                    : 'Tạo tài khoản',
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 6),
                              // Text(
                              //   _mode == AuthMode.login
                              //       ? 'Log in to continue your premium experience'
                              //       : 'Join with a calm and elegant identity',
                              //   textAlign: TextAlign.center,
                              //   style: theme.textTheme.bodyMedium,
                              // ),
                              Expanded(
                                child: AuthPanel(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 260),
                                    switchInCurve: Curves.easeOutCubic,
                                    switchOutCurve: Curves.easeInCubic,
                                    transitionBuilder: (child, animation) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(0.06, 0),
                                            end: Offset.zero,
                                          ).animate(animation),
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: _mode == AuthMode.login
                                        ? _LoginForm(
                                            key: const ValueKey('login-form'),
                                            phoneController: _phoneController,
                                            passwordController:
                                                _passwordController,
                                            onSwitch: _toggleMode,
                                          )
                                        : _SignUpForm(
                                            key: const ValueKey('signup-form'),
                                            usernameController:
                                                _usernameController,
                                            phoneController: _phoneController,
                                            birthDate: _birthDate,
                                            gender: _gender,
                                            onGenderChanged: (value) {
                                              if (value == null) {
                                                return;
                                              }
                                              HapticFeedback.selectionClick();
                                              setState(() => _gender = value);
                                            },
                                            onPickBirthDate: _pickBirthDate,
                                            onSwitch: _toggleMode,
                                          ),
                                  ),
                                ),
                              ),
                              
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



class _SignUpForm extends StatelessWidget {
  const _SignUpForm({
    super.key,
    required this.usernameController,
    required this.phoneController,
    required this.birthDate,
    required this.gender,
    required this.onGenderChanged,
    required this.onPickBirthDate,
    required this.onSwitch,
  });

  final TextEditingController usernameController;
  final TextEditingController phoneController;
  final DateTime? birthDate;
  final GenderOption gender;
  final ValueChanged<GenderOption?> onGenderChanged;
  final VoidCallback onPickBirthDate;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthTextField(
            label: 'Username',
            hintText: 'Enter your username',
            controller: usernameController,
          ),
          const SizedBox(height: 14),
          AuthTextField(
            label: 'Phone Number',
            hintText: '+84 901 234 567',
            keyboardType: TextInputType.phone,
            controller: phoneController,
          ),
          const SizedBox(height: 14),
          GenderControl(value: gender, onChanged: onGenderChanged),
          const SizedBox(height: 14),
          AuthTextField(
            label: 'Birth Date',
            hintText: 'Select your date of birth',
            readOnly: true,
            onTap: onPickBirthDate,
            valueText: birthDate == null
                ? ''
                : '${birthDate!.day.toString().padLeft(2, '0')}/'
                      '${birthDate!.month.toString().padLeft(2, '0')}/'
                      '${birthDate!.year}',
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(text: 'Create Account', onPressed: () {}),
          const SizedBox(height: 6),
          AuthPromptLink(
            prefix: 'Already have an account?',
            action: 'Log in',
            onTap: onSwitch,
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    super.key,
    required this.phoneController,
    required this.passwordController,
    required this.onSwitch,
  });

  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthTextField(
            label: 'Số điện thoại',
            hintText: '+84',
            keyboardType: TextInputType.phone,
            controller: phoneController,
          ),
          const SizedBox(height: 14),
          AuthTextField(
            label: 'Mật khẩu',
            hintText: 'Nhập mật khẩu',
            obscureText: true,
            controller: passwordController,
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(text: 'Login', onPressed: () {}),
          const SizedBox(height: 6),
          AuthPromptLink(
            prefix: 'Bạn chưa có tài khoản',
            action: 'Đăng ký',
            onTap: onSwitch,
          ),
        ],
      ),
    );
  }
}
