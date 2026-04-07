import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Text(
                      'Cài đặt',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              // Menu Section 1
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: SvgPicture.asset(
                            'assets/icons/add-user.svg',
                            width: 20,
                            height: 20,
                          ),
                          label: const Text('Account'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.black87,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 15,
                            ),
                            minimumSize: const Size(double.infinity, 0),
                            alignment: Alignment.centerLeft,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: SvgPicture.asset(
                            'assets/icons/add-user.svg',
                            width: 20,
                            height: 20,
                          ),
                          label: const Text('Notification'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.black87,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 15,
                            ),
                            minimumSize: const Size(double.infinity, 0),
                            alignment: Alignment.centerLeft,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: SvgPicture.asset(
                            'assets/icons/add-user.svg',
                            width: 20,
                            height: 20,
                          ),
                          label: const Text('Chat Folders'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.black87,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 15,
                            ),
                            minimumSize: const Size(double.infinity, 0),
                            alignment: Alignment.centerLeft,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: SvgPicture.asset(
                            'assets/icons/add-user.svg',
                            width: 20,
                            height: 20,
                          ),
                          label: const Text('Language'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.black87,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 15,
                            ),
                            minimumSize: const Size(double.infinity, 0),
                            alignment: Alignment.centerLeft,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Menu Section 2
              SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: SvgPicture.asset(
                            'assets/icons/add-user.svg',
                            width: 20,
                            height: 20,
                          ),
                          label: const Text('Account'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.black87,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 15,
                            ),
                            minimumSize: const Size(double.infinity, 0),
                            alignment: Alignment.centerLeft,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: SvgPicture.asset(
                            'assets/icons/add-user.svg',
                            width: 20,
                            height: 20,
                          ),
                          label: const Text('Notification'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.black87,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 15,
                            ),
                            minimumSize: const Size(double.infinity, 0),
                            alignment: Alignment.centerLeft,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: SvgPicture.asset(
                            'assets/icons/add-user.svg',
                            width: 20,
                            height: 20,
                          ),
                          label: const Text('Chat Folders'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.black87,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 15,
                            ),
                            minimumSize: const Size(double.infinity, 0),
                            alignment: Alignment.centerLeft,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: SvgPicture.asset(
                            'assets/icons/add-user.svg',
                            width: 20,
                            height: 20,
                          ),
                          label: const Text('Language'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.black87,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 15,
                            ),
                            minimumSize: const Size(double.infinity, 0),
                            alignment: Alignment.centerLeft,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
