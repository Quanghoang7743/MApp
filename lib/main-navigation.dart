import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mess_app/Views/app_contact_screen.dart';
import 'package:mess_app/Views/app_chat_list_screen.dart';
import 'package:mess_app/Views/app_search_screen.dart';
import 'package:mess_app/Views/app_setting_screen.dart';

class AppMainScreen extends StatefulWidget {
  const AppMainScreen({super.key});

  @override
  State<AppMainScreen> createState() => _AppMainScreenState();
}

class _AppMainScreenState extends State<AppMainScreen> {
  int selectIndex = 0;

  Widget _buildCurrentPage() {
    switch (selectIndex) {
      case 0:
        return const ContactScreen();
      case 1:
        return ChatListScreen(onToggleTheme: () {}, darkModeEnabled: false);
      case 2:
        return const SettingScreen();
      default:
        return ChatListScreen(onToggleTheme: () {}, darkModeEnabled: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 15, right: 15, bottom: 0),
          child: Row(
            children: [
              // Main Tab Navigation Capsule
              Expanded(
                child: Container(
                  height: 65,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 15,
                        spreadRadius: 2,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: List.generate(3, (index) {
                            bool isSelected = selectIndex == index;
                            String iconPath = '';
                            String label = '';
                            if (index == 0) {
                              iconPath = 'assets/icons/user-contact.svg';
                              label = 'Danh bạ';
                            } else if (index == 1) {
                              iconPath = 'assets/icons/message-chat.svg';
                              label = 'Nhắn tin';
                            } else if (index == 2) {
                              iconPath = 'assets/icons/setting.svg';
                              label = 'Cài đặt';
                            }

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectIndex = index;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSelected ? 22 : 12,
                                  vertical: 10,
                                ),

                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SvgPicture.asset(
                                      iconPath,
                                      width: 24,
                                      height: 24,
                                      colorFilter: ColorFilter.mode(
                                        isSelected
                                            ? const Color.fromARGB(
                                                255,
                                                91,
                                                129,
                                                255,
                                              )
                                            : Colors.black54,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? const Color.fromARGB(
                                                255,
                                                91,
                                                129,
                                                255,
                                              )
                                            : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Search Floating Button
              Container(
                height: 65,
                width: 65,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: IconButton(
                      icon: SvgPicture.asset(
                        'assets/icons/search.svg',
                        width: 24,
                        height: 24,
                        colorFilter: ColorFilter.mode(
                          Colors.black54,
                          BlendMode.srcIn,
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SearchScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _buildCurrentPage(),
    );
  }
}
