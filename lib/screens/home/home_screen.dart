import 'package:flutter/material.dart';
import '../../core/widgets/eco_shortcut_badge.dart';
import 'dashboard_screen.dart';
import '../map/interactive_map_screen.dart';
import '../trails/trails_list_screen.dart';
import '../poi/poi_list_screen.dart';
import '../quiz/quiz_screen.dart';
import '../offline/offline_trails_screen.dart';
import '../services/local_services_screen.dart';
import '../settings/settings_screen.dart';
import '../sos/sos_button.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentIndex;
  DateTime? _lastBackPressAt;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 7);
  }

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  EcoShortcutTab _badgeTabFromIndex(int index) {
    switch (index) {
      case 1:
        return EcoShortcutTab.map;
      case 2:
        return EcoShortcutTab.trails;
      case 4:
        return EcoShortcutTab.quiz;
      case 6:
        return EcoShortcutTab.services;
      case 7:
        return EcoShortcutTab.settings;
      default:
        return EcoShortcutTab.home;
    }
  }

  void _onBadgeTabSelected(EcoShortcutTab tab) {
    switch (tab) {
      case EcoShortcutTab.home:
        _navigateToTab(0);
      case EcoShortcutTab.map:
        _navigateToTab(1);
      case EcoShortcutTab.trails:
        _navigateToTab(2);
      case EcoShortcutTab.quiz:
        _navigateToTab(4);
      case EcoShortcutTab.services:
        _navigateToTab(6);
      case EcoShortcutTab.settings:
        _navigateToTab(7);
    }
  }

  Future<bool> _onWillPop() async {
    if (_currentIndex != 0) {
      _navigateToTab(0);
      return false;
    }

    final now = DateTime.now();
    final shouldExit =
        _lastBackPressAt != null &&
        now.difference(_lastBackPressAt!) <= const Duration(seconds: 2);

    if (shouldExit) {
      return true;
    }

    _lastBackPressAt = now;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        content: const Row(
          children: [
            Icon(Icons.exit_to_app, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Appuyez encore une fois sur Retour pour quitter',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      DashboardScreen(
        onNavigateToMap: () => _navigateToTab(1),
        onNavigateToTrails: () => _navigateToTab(2),
        onNavigateToPois: () => _navigateToTab(3),
        onNavigateToOffline: () => _navigateToTab(5),
        onNavigateToQuiz: () => _navigateToTab(4),
        onNavigateToSos: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SosScreen(),
              fullscreenDialog: true,
            ),
          );
        },
      ),
      const InteractiveMapScreen(),
      const TrailsListScreen(),
      const PoiListScreen(),
      const QuizScreen(),
      const OfflineTrailsScreen(),
      const LocalServicesScreen(),
      const SettingsScreen(),
    ];

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
        bottomNavigationBar: EcoShortcutBadge(
          currentTab: _badgeTabFromIndex(_currentIndex),
          onTabSelected: _onBadgeTabSelected,
        ),
      ),
    );
  }
}
