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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final isCompact = availableWidth < 390;
          final sosSize = (availableWidth * 0.24)
              .clamp(isCompact ? 76.0 : 86.0, isCompact ? 88.0 : 108.0)
              .toDouble();
          final barHeight = isCompact ? 92.0 : 104.0;
          final totalHeight = sosSize + 44;
          final horizontalMargin = availableWidth < 390 ? 8.0 : 12.0;

          return SizedBox(
            height: totalHeight,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  left: horizontalMargin,
                  right: horizontalMargin,
                  bottom: 8,
                  child: Container(
                    height: barHeight,
                    padding: EdgeInsets.symmetric(
                      horizontal: availableWidth < 390 ? 6 : 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                        color: const Color(
                          0xFF97F2A7,
                        ).withValues(alpha: isDark ? 0.18 : 0.55),
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(
                            alpha: isDark ? 0.10 : 0.22,
                          ),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.28 : 0.06,
                          ),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: _tabItem(
                                  context,
                                  tab: EcoShortcutTab.home,
                                  icon: Icons.home_rounded,
                                  label: 'Home',
                                  isCompact: isCompact,
                                  isHighlighted: true,
                                ),
                              ),
                              Expanded(
                                child: _tabItem(
                                  context,
                                  tab: EcoShortcutTab.map,
                                  icon: Icons.map_rounded,
                                  label: 'Map',
                                  isCompact: isCompact,
                                ),
                              ),
                              Expanded(
                                child: _tabItem(
                                  context,
                                  tab: EcoShortcutTab.trails,
                                  icon: Icons.hiking_rounded,
                                  label: 'Trails',
                                  isCompact: isCompact,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: sosSize * (isCompact ? 0.42 : 0.54)),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: _tabItem(
                                  context,
                                  tab: EcoShortcutTab.quiz,
                                  icon: Icons.quiz_rounded,
                                  label: 'Quiz',
                                  isCompact: isCompact,
                                ),
                              ),
                              Expanded(
                                child: _tabItem(
                                  context,
                                  tab: EcoShortcutTab.services,
                                  icon: Icons.storefront_rounded,
                                  label: 'Services',
                                  isCompact: isCompact,
                                ),
                              ),
                              Expanded(
                                child: _tabItem(
                                  context,
                                  tab: EcoShortcutTab.settings,
                                  icon: Icons.settings_rounded,
                                  label: 'Params',
                                  isCompact: isCompact,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(top: 0, child: _sosCenterButton(context, sosSize)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tabItem(
    BuildContext context, {
    required EcoShortcutTab tab,
    required IconData icon,
    required String label,
    required bool isCompact,
    bool isHighlighted = false,
  }) {
    final selected = currentTab == tab;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedColor = isDark ? Colors.grey[400] : const Color(0xFF6A7FA2);
    final selectedColor = isHighlighted
        ? const Color(0xFF20B43A)
        : const Color(0xFF2B4D78);

    final iconSize = selected && isHighlighted
        ? (isCompact ? 25.0 : 30.0)
        : (isCompact ? 18.0 : 22.0);
    final textSize = selected && isHighlighted
        ? (isCompact ? 14.0 : 17.0)
        : (isCompact ? 11.0 : 13.0);
    final selectedPillWidth = isCompact ? 58.0 : 74.0;

    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () => _handleTabSelection(context, tab),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: selected && isHighlighted ? selectedPillWidth : null,
          constraints: BoxConstraints(
            minHeight: isCompact ? 50 : 60,
            maxHeight: isCompact ? 66 : 76,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: selected && isHighlighted ? 4 : 1,
            vertical: selected && isHighlighted ? 6 : 3,
          ),
          decoration: BoxDecoration(
            color: selected
                ? (isHighlighted
                      ? const Color(0xFFDDF6DD)
                      : const Color(0xFFF4F8FC))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color:
                          (isHighlighted
                                  ? const Color(0xFF8AE59E)
                                  : const Color(0xFFCAD7E8))
                              .withValues(alpha: isDark ? 0.12 : 0.45),
                      blurRadius: isHighlighted ? 18 : 8,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: iconSize,
                  color: selected ? selectedColor : unselectedColor,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    fontSize: textSize,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    color: selected ? selectedColor : unselectedColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sosCenterButton(BuildContext context, double size) {
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
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFF1833),
          border: Border.all(color: Colors.white, width: 6),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6A78).withValues(alpha: 0.52),
              blurRadius: 30,
              spreadRadius: 3,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          'SOS',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.29,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  void _handleTabSelection(BuildContext context, EcoShortcutTab tab) {
    onTabSelected(tab);
  }
}
