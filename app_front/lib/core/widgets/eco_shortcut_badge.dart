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
          final sosSize = (availableWidth * 0.25).clamp(82.0, 108.0).toDouble();
          final barHeight = (sosSize * 0.76).clamp(76.0, 88.0).toDouble();
          final totalHeight = sosSize + 36;
          final horizontalMargin = availableWidth < 390 ? 8.0 : 12.0;
          final itemWidth =
              ((availableWidth - (horizontalMargin * 2) - (sosSize * 0.58)) / 6)
                  .clamp(40.0, 68.0)
                  .toDouble();

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
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _tabItem(
                                context,
                                tab: EcoShortcutTab.home,
                                icon: Icons.home_rounded,
                                label: 'Home',
                                width: itemWidth,
                                isHighlighted: true,
                              ),
                              _tabItem(
                                context,
                                tab: EcoShortcutTab.map,
                                icon: Icons.map_rounded,
                                label: 'Map',
                                width: itemWidth,
                              ),
                              _tabItem(
                                context,
                                tab: EcoShortcutTab.trails,
                                icon: Icons.hiking_rounded,
                                label: 'Trails',
                                width: itemWidth,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: sosSize * 0.58),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _tabItem(
                                context,
                                tab: EcoShortcutTab.quiz,
                                icon: Icons.quiz_rounded,
                                label: 'Quiz',
                                width: itemWidth,
                              ),
                              _tabItem(
                                context,
                                tab: EcoShortcutTab.services,
                                icon: Icons.storefront_rounded,
                                label: 'Services',
                                width: itemWidth,
                              ),
                              _tabItem(
                                context,
                                tab: EcoShortcutTab.settings,
                                icon: Icons.settings_rounded,
                                label: 'Params',
                                width: itemWidth,
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
    required double width,
    bool isHighlighted = false,
  }) {
    final selected = currentTab == tab;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedColor = isDark ? Colors.grey[400] : const Color(0xFF6A7FA2);
    final selectedColor = isHighlighted
        ? const Color(0xFF20B43A)
        : const Color(0xFF2B4D78);

    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => _handleTabSelection(context, tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            horizontal: selected && isHighlighted ? 6 : 2,
            vertical: selected && isHighlighted ? 9 : 4,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: selected && isHighlighted ? 28 : 20,
                color: selected ? selectedColor : unselectedColor,
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: selected && isHighlighted ? 16 : 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    color: selected ? selectedColor : unselectedColor,
                  ),
                ),
              ),
            ],
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
