import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:line_icons/line_icons.dart';

import 'chat_page.dart';
import 'timeline_page.dart';
import 'bereal_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = [
    ChatPage(),
    BeRealPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10),
            child: GNav(
              rippleColor: colorScheme.primaryContainer.withOpacity(0.4),
              hoverColor: colorScheme.primaryContainer.withOpacity(0.2),
              gap: 8,
              activeColor: Colors.white,
              iconSize: 24,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              duration: const Duration(milliseconds: 400),
              tabBackgroundColor: colorScheme.primary.withOpacity(0.4),
              color: Colors.white.withOpacity(0.6),
              tabs: const [
                GButton(icon: LineIcons.comment, text: 'Chat'),
                GButton(icon: LineIcons.camera, text: 'BeReal'),
                GButton(icon: LineIcons.user, text: 'Profile'),
              ],
              selectedIndex: _selectedIndex,
              onTabChange: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}
