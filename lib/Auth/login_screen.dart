import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main-navigation.dart';
import '../providers/auth_provider.dart';
import 'sign_up_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool stayLoggedIn = false;
  bool isLoading = false;
  bool obscurePassword = true;

  Future<void> _login() async {
    if (phoneController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập đầy đủ số điện thoại và mật khẩu'),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final errorMsg = await authProvider.login(
      phoneController.text,
      passwordController.text,
      stayLoggedIn,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      isLoading = false;
    });

    if (errorMsg == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AppMainScreen()),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMsg), duration: const Duration(seconds: 4)),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature đang được phát triển')));
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFFB5B6C4),
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: Colors.white,
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF6A6A7E), size: 24),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE8E8EF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF6B5BFF)),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE8E8EF)),
      ),
    );
  }

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _MoxLogo(),
                    const SizedBox(height: 26),
                    const Text(
                      'Chào mừng trở lại',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF191929),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Đăng nhập để kết nối và\ntrò chuyện cùng bạn bè',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.55,
                        color: Color(0xFF8D8DA3),
                      ),
                    ),
                    const SizedBox(height: 42),
                    const Text(
                      'Email hoặc số điện thoại',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF232336),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.text,
                      decoration: _inputDecoration(
                        hintText: 'Nhập email hoặc số điện thoại',
                        prefixIcon: Icons.person_outline_rounded,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Mật khẩu',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF232336),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: _inputDecoration(
                        hintText: 'Nhập mật khẩu',
                        prefixIcon: Icons.lock_outline_rounded,
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: const Color(0xFF6A6A7E),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Transform.translate(
                          offset: const Offset(-10, 0),
                          child: Checkbox(
                            value: stayLoggedIn,
                            side: const BorderSide(color: Color(0xFFD6D7E2)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            activeColor: const Color(0xFF4A6CFF),
                            onChanged: (value) {
                              setState(() {
                                stayLoggedIn = value ?? false;
                              });
                            },
                          ),
                        ),
                        const Text(
                          'Ghi nhớ tôi',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF5B5B72),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => _showComingSoon('Quên mật khẩu'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF6170FF),
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Quên mật khẩu?',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [Color(0xFF3D6BFF), Color(0xFF7D37F5)],
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x2B643FF4),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 19),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Stack(
                                alignment: Alignment.center,
                                children: [
                                  Text(
                                    'Đăng nhập',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 34),
                    const Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Color(0xFFE4E5EE),
                            thickness: 1.2,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 18),
                          child: Text(
                            'hoặc',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF7F8094),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Color(0xFFE4E5EE),
                            thickness: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _SocialButton(
                      icon: const _GoogleMark(),
                      label: 'Tiếp tục với Google',
                      onTap: () => _showComingSoon('Đăng nhập với Google'),
                    ),
                    const SizedBox(height: 16),
                    _SocialButton(
                      icon: const Icon(
                        Icons.apple,
                        size: 28,
                        color: Color(0xFF141414),
                      ),
                      label: 'Tiếp tục với Apple',
                      onTap: () => _showComingSoon('Đăng nhập với Apple'),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Chưa có tài khoản? ',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF7F8094),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignUpScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Đăng ký',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6170FF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MoxLogo extends StatelessWidget {
  const _MoxLogo();

  @override
  Widget build(BuildContext context) {
    const gradient = LinearGradient(
      colors: [Color(0xFF4A72FF), Color(0xFF7A32F4)],
    );

    return Center(
      child: SizedBox(
        width: 190,
        height: 82,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: gradient.createShader,
              child: const Text(
                'Mox',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -2.5,
                  height: 1,
                ),
              ),
            ),
            Positioned(
              top: -2,
              right: 14,
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: gradient,
                ),
                child: const Center(
                  child: Text(
                    '•••',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFE8E8EF)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
        child: Row(
          children: [
            SizedBox(width: 32, child: Center(child: icon)),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2A2A3F),
                ),
              ),
            ),
            const SizedBox(width: 50),
          ],
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: Color(0xFF4285F4),
      ),
    );
  }
}
