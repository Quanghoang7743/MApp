import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'app_home_login_screen.dart';
import 'package:mess_app/Views/widgets/setting_widgets/storege_cache.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeLoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            // mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
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
              // User Info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),

                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 35,
                              backgroundImage: user?['avatar_url'] != null
                                  ? NetworkImage(user!['avatar_url'])
                                  : null,
                              child: user?['avatar_url'] == null
                                  ? Icon(Icons.person, size: 35)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (user?['display_name'] ?? 'Chưa cập nhật')
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              // Text('0865770527', style: TextStyle(fontSize: 14)),
                              Text(
                                "@" + (user?['username'] ?? 'Chưa cập nhật'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
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
                          icon: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Color(0xFF007AFF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SvgPicture.asset(
                              'assets/icons/user-circle.svg',
                              width: 20,
                              height: 20,
                            ),
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
                          icon: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Color.fromARGB(255, 255, 196, 0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SvgPicture.asset(
                              'assets/icons/bell.svg',
                              width: 20,
                              height: 20,
                            ),
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
                          icon: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Color.fromARGB(255, 0, 145, 255),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SvgPicture.asset(
                              'assets/icons/folder.svg',
                              width: 20,
                              height: 20,
                            ),
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
                          icon: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Color.fromARGB(255, 174, 0, 255),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SvgPicture.asset(
                              'assets/icons/earth.svg',
                              width: 20,
                              height: 20,
                            ),
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
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const StorageCacheView(),
                              ),
                            );
                          },
                          icon: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Color.fromARGB(255, 174, 0, 255),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SvgPicture.asset(
                              'assets/icons/cloud.svg',
                              width: 20,
                              height: 20,
                            ),
                          ),
                          label: const Text('Dữ liệu trên máy'),
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
                          icon: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Color.fromARGB(255, 255, 157, 0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SvgPicture.asset(
                              'assets/icons/message.svg',
                              width: 20,
                              height: 20,
                            ),
                          ),
                          label: const Text('Ask a Question'),
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
                        // ElevatedButton.icon(
                        //   onPressed: () {},
                        //   icon: SvgPicture.asset(
                        //     'assets/icons/add-user.svg',
                        //     width: 20,
                        //     height: 20,
                        //   ),
                        //   label: const Text('Notification'),
                        //   style: ElevatedButton.styleFrom(
                        //     backgroundColor: Colors.transparent,
                        //     foregroundColor: Colors.black87,
                        //     shadowColor: Colors.transparent,
                        //     padding: const EdgeInsets.symmetric(
                        //       vertical: 16,
                        //       horizontal: 15,
                        //     ),
                        //     minimumSize: const Size(double.infinity, 0),
                        //     alignment: Alignment.centerLeft,
                        //     shape: const RoundedRectangleBorder(
                        //       borderRadius: BorderRadius.zero,
                        //     ),
                        //   ),
                        // ),
                        // ElevatedButton.icon(
                        //   onPressed: () {},
                        //   icon: SvgPicture.asset(
                        //     'assets/icons/add-user.svg',
                        //     width: 20,
                        //     height: 20,
                        //   ),
                        //   label: const Text('Chat Folders'),
                        //   style: ElevatedButton.styleFrom(
                        //     backgroundColor: Colors.transparent,
                        //     foregroundColor: Colors.black87,
                        //     shadowColor: Colors.transparent,
                        //     padding: const EdgeInsets.symmetric(
                        //       vertical: 16,
                        //       horizontal: 15,
                        //     ),
                        //     minimumSize: const Size(double.infinity, 0),
                        //     alignment: Alignment.centerLeft,
                        //     shape: const RoundedRectangleBorder(
                        //       borderRadius: BorderRadius.zero,
                        //     ),
                        //   ),
                        // ),
                        // ElevatedButton.icon(
                        //   onPressed: () {},
                        //   icon: SvgPicture.asset(
                        //     'assets/icons/add-user.svg',
                        //     width: 20,
                        //     height: 20,
                        //   ),
                        //   label: const Text('Language'),
                        //   style: ElevatedButton.styleFrom(
                        //     backgroundColor: Colors.transparent,
                        //     foregroundColor: Colors.black87,
                        //     shadowColor: Colors.transparent,
                        //     padding: const EdgeInsets.symmetric(
                        //       vertical: 16,
                        //       horizontal: 15,
                        //     ),
                        //     minimumSize: const Size(double.infinity, 0),
                        //     alignment: Alignment.centerLeft,
                        //     shape: const RoundedRectangleBorder(
                        //       borderRadius: BorderRadius.zero,
                        //     ),
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
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
                          onPressed: _logout,
                          icon: Container(
                            padding: EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              color: Color.fromARGB(255, 255, 235, 235),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SvgPicture.asset(
                              'assets/icons/logout.svg',
                              width: 30,
                              height: 30,
                              colorFilter: ColorFilter.mode(
                                Colors.red,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                          label: const Text(
                            'Logout',
                            style: TextStyle(color: Colors.red),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.red,
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
