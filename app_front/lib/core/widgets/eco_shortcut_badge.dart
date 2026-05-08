import 'package:flutter/material.dart';

import '../../screens/sos/sos_button.dart';

enum EcoShortcutTab {
  home,
  map,
  trails,
  quiz,
  services,
  settings,
}

class EcoShortcutBadge extends StatelessWidget {
  final EcoShortcutTab currentTab;
  final ValueChanged<EcoShortcutTab> onTabSelected;

  const EcoShortcutBadge({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFF5FFF6)],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.green.withValues(alpha: 0.24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _tabItem(
                    context,
                    tab: EcoShortcutTab.home,
                    icon: Icons.home_rounded,
                    label: 'Home',
                  ),
                  _tabItem(
                    context,
                    tab: EcoShortcutTab.map,
                    icon: Icons.map_rounded,
                    label: 'Map',
                  ),
                  _tabItem(
                    context,
                    tab: EcoShortcutTab.trails,
                    icon: Icons.hiking_rounded,
                    label: 'Trails',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 2),
            _sosCenterButton(context),
            const SizedBox(width: 2),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _tabItem(
                    context,
                    tab: EcoShortcutTab.quiz,
                    icon: Icons.quiz_rounded,
                    label: 'Quiz',
                  ),
                  _tabItem(
                    context,
                    tab: EcoShortcutTab.services,
                    icon: Icons.storefront_rounded,
                    label: 'Services',
                  ),
                  _tabItem(
                    context,
                    tab: EcoShortcutTab.settings,
                    icon: Icons.settings_rounded,
                    label: 'Params',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabItem(
    BuildContext context, {
    required EcoShortcutTab tab,
    required IconData icon,
    required String label,
  }) {
    final selected = currentTab == tab;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _handleTabSelection(context, tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.green.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.16),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.green : const Color(0xFF64748B),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.green : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sosCenterButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const SosScreen(),
            fullscreenDialog: true,
          ),
        );
      },
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2DBE45), Color(0xFF1E9A35)],
          ),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: const Icon(Icons.sos_rounded, color: Colors.white, size: 32),
      ),
    );
  }

  void _handleTabSelection(BuildContext context, EcoShortcutTab tab) {
    onTabSelected(tab);
  }
}
