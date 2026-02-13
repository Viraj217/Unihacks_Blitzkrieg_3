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
    TimelinePage(),
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
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              color: colorScheme.primary.withOpacity(0.06),
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10),
            child: GNav(
              rippleColor: colorScheme.primaryContainer.withOpacity(0.4),
              hoverColor: colorScheme.primaryContainer.withOpacity(0.2),
              gap: 8,
              activeColor: colorScheme.primary,
              iconSize: 24,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              duration: const Duration(milliseconds: 400),
              tabBackgroundColor: colorScheme.primaryContainer.withOpacity(0.3),
              color: Colors.grey[400],
              tabs: const [
                GButton(icon: LineIcons.comment, text: 'Chat'),
                GButton(icon: LineIcons.stream, text: 'Timeline'),
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
