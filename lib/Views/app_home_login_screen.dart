import 'package:flutter/material.dart';
import '../Auth/login_screen.dart';
import '../Auth/sign_up_screen.dart';

class HomeLoginScreen extends StatefulWidget {
  const HomeLoginScreen({super.key});

  @override
  State<StatefulWidget> createState() => _HomeLoginScreen();
}

class _HomeLoginScreen extends State<HomeLoginScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 30),
                    const _MoxLogo(),
                    const SizedBox(height: 10),
                    const Text(
                      "Kết nối và trò chuyện với bạn bè",
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 70),
                    Column(
                      
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: DecoratedBox(
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
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginScreen(),
                                  ),
                                );
                              },
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
                              child: const Text(
                                "Đăng nhập",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Nút Đăng ký dạng TextButton để giảm sự chú ý
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignUpScreen(),
                              ),
                            );
                          },
                          child: RichText(
                            text: const TextSpan(
                              text: "Chưa có tài khoản? ",
                              style: TextStyle(color: Colors.grey),
                              children: [
                                TextSpan(
                                  text: "Đăng ký ngay",
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
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
              top: -5,
              right: 10,
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
