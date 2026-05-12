import 'package:flutter/material.dart';

import '../../screens/sos/sos_button.dart';

enum EcoShortcutTab { home, map, trails, quiz, services, settings }

class EcoShortcutBadge extends StatelessWidget {
  final EcoShortcutTab currentTab;
  final ValueChanged<EcoShortcutTab> onTabSelected;

  const EcoShortcutBadge({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
  });

  static const _green = Color(0xFF22B53A);
  static const _darkGreen = Color(0xFF15972C);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const barHeight = 96.0;
    const sosSize = 86.0;
    const sosOverhang = 46.0;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: barHeight + sosOverhang,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: barHeight,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF111827) : Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(34),
                    topRight: Radius.circular(34),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.35 : 0.10),
                      blurRadius: 26,
                      offset: const Offset(0, -4),
                    ),
                    BoxShadow(
                      color: _green.withOpacity(0.10),
                      blurRadius: 28,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _TabItem(
                              tab: EcoShortcutTab.home,
                              icon: Icons.home_rounded,
                              label: 'Home',
                              currentTab: currentTab,
                              onTap: () => onTabSelected(EcoShortcutTab.home),
                              isDark: isDark,
                            ),
                          ),
                          Expanded(
                            child: _TabItem(
                              tab: EcoShortcutTab.map,
                              icon: Icons.map_rounded,
                              label: 'Map',
                              currentTab: currentTab,
                              onTap: () => onTabSelected(EcoShortcutTab.map),
                              isDark: isDark,
                            ),
                          ),
                          Expanded(
                            child: _TabItem(
                              tab: EcoShortcutTab.trails,
                              icon: Icons.hiking_rounded,
                              label: 'Trails',
                              currentTab: currentTab,
                              onTap: () => onTabSelected(EcoShortcutTab.trails),
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: sosSize - 6),

                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _TabItem(
                              tab: EcoShortcutTab.quiz,
                              icon: Icons.quiz_rounded,
                              label: 'Quiz',
                              currentTab: currentTab,
                              onTap: () => onTabSelected(EcoShortcutTab.quiz),
                              isDark: isDark,
                            ),
                          ),
                          Expanded(
                            child: _TabItem(
                              tab: EcoShortcutTab.services,
                              icon: Icons.storefront_rounded,
                              label: 'Services',
                              currentTab: currentTab,
                              onTap: () => onTabSelected(EcoShortcutTab.services),
                              isDark: isDark,
                            ),
                          ),
                          Expanded(
                            child: _TabItem(
                              tab: EcoShortcutTab.settings,
                              icon: Icons.settings_rounded,
                              label: 'Params',
                              currentTab: currentTab,
                              onTap: () => onTabSelected(EcoShortcutTab.settings),
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              top: 0,
              child: _SosButton(size: sosSize),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final EcoShortcutTab tab;
  final IconData icon;
  final String label;
  final EcoShortcutTab currentTab;
  final VoidCallback onTap;
  final bool isDark;

  static const _green = Color(0xFF22B53A);
  static const _selectedBg = Color(0xFFDFF8E4);
  static const _selectedBgDark = Color(0xFF163B21);
  static const _unselected = Color(0xFF64748B);

  const _TabItem({
    required this.tab,
    required this.icon,
    required this.label,
    required this.currentTab,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final selected = currentTab == tab;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          height: 74,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? _selectedBgDark : _selectedBg)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _green.withOpacity(isDark ? 0.18 : 0.20),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  icon,
                  size: selected ? 28 : 26,
                  color: selected ? _green : _unselected,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: selected ? 14 : 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? _green : _unselected,
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

class _SosButton extends StatelessWidget {
  final double size;

  const _SosButton({required this.size});

  static const _green = Color(0xFF22B53A);
  static const _darkGreen = Color(0xFF15972C);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const SosScreen(),
          fullscreenDialog: true,
        ),
      ),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _green,
              _darkGreen,
            ],
          ),
          border: Border.all(
            color: Colors.white,
            width: 5,
          ),
          boxShadow: [
            BoxShadow(
              color: _green.withOpacity(0.38),
              blurRadius: 24,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          'SOS',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.32,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            shadows: const [
              Shadow(
                color: Color(0x55000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}