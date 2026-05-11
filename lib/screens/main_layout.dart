import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/app_data_provider.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'discover_screen.dart';
import 'events_screen.dart';
import 'chat_list_screen.dart';
import 'profile_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final List<Widget> _screens = [
    const HomeScreen(),
    const DiscoverScreen(),
    const ChatListScreen(),
    const EventsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppData>(context);
    final currentIndex = provider.selectedTabIndex;

    return Scaffold(
      extendBody: true, // Allows content to be visible behind the nav bar
      backgroundColor: AppTheme.bg,
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildFloatingNavBar(context, provider, currentIndex),
    );
  }

  Widget _buildFloatingNavBar(BuildContext context, AppData provider, int currentIndex) {
    final bottomNotch = MediaQuery.of(context).padding.bottom;
    
    return Container(
      // Dynamic height accounting for phone's bottom indicator
      height: 70 + bottomNotch,
      padding: EdgeInsets.only(bottom: bottomNotch > 0 ? bottomNotch : 16, left: 16, right: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withOpacity(0.05),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(Icons.radar, provider.t('radar'), 0, currentIndex, () {
                  HapticFeedback.selectionClick();
                  provider.setTabIndex(0);
                }),
                _buildNavItem(Icons.explore_outlined, provider.t('discovery'), 1, currentIndex, () {
                  HapticFeedback.selectionClick();
                  provider.setTabIndex(1);
                }),
                _buildNavItem(Icons.chat_bubble_outline, provider.t('chat'), 2, currentIndex, () {
                  HapticFeedback.selectionClick();
                  provider.setTabIndex(2);
                }),
                _buildNavItem(Icons.event_outlined, provider.t('events'), 3, currentIndex, () {
                  HapticFeedback.selectionClick();
                  provider.setTabIndex(3);
                }),
                _buildNavItem(Icons.person_outline, provider.t('profile'), 4, currentIndex, () {
                  HapticFeedback.selectionClick();
                  provider.setTabIndex(4);
                }),
              ],
            ),
          ),
        ),
      ),
    ).animate().slideY(begin: 1.0, end: 0, duration: 800.ms, curve: Curves.easeOutBack);
  }

  Widget _buildNavItem(IconData icon, String label, int index, int currentIndex, VoidCallback onTap) {
    final isActive = currentIndex == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 300),
                scale: isActive ? 1.1 : 1.0,
                child: Icon(
                  icon,
                  size: isActive ? 26 : 24,
                  color: isActive ? AppTheme.accent : Colors.white54,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Space Mono',
                    fontSize: isActive ? 9 : 8,
                    letterSpacing: 1,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: isActive ? AppTheme.accent : Colors.white54,
                  ),
                ),
              ),
              if (isActive)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                  ),
                ).animate().scale(duration: 200.ms),
            ],
          ),
        ),
      ),
    );
  }
}
