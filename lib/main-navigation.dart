import 'package:doctor_app/Views/app_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppMainScreen extends StatefulWidget {
  const AppMainScreen({super.key});

  @override
  State<AppMainScreen> createState() => _AppMainScreenState();
}

class _AppMainScreenState extends State<AppMainScreen> {
    int selectIndex = 0;
    final List page = [
      const AppHomeScreen(),
      const Scaffold(),
      const Scaffold()
    ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectIndex,
        unselectedItemColor: Colors.black26,
        selectedItemColor: Color(0xFF1C274C),
        type: BottomNavigationBarType.fixed,
        onTap: (value) {
          setState(() {});
          selectIndex = value;
        },
        elevation: 0,
        backgroundColor: Colors.white,
        items: [
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/icons/homeIcon.svg',
              width: 24,
              height: 24,
            ),
            label: 'Trang chu',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/icons/AIIcon.svg',
              width: 24,
              height: 24,
            ),
            label: 'Chuẩn đoán AI',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/icons/MenuIcon.svg',
              width: 24,
              height: 24,
            ),
            label: 'Menu',
          ),
        ],
      ),
      body: page[selectIndex],
    );
  }
}
