import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/locale_provider.dart';
import 'eco_sos_button.dart';

enum EcoShortcutTab { home, map, trails, quiz, services, settings }

class EcoShortcutBadge extends StatelessWidget {
  final EcoShortcutTab currentTab;
  final ValueChanged<EcoShortcutTab> onTabSelected;

  const EcoShortcutBadge({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
  });

  // Layout constants — fully-rounded pill, SOS inline with the tabs.
  static const _barH = 64.0;
  static const _sosSize = 52.0;
  // Outer margin from the screen edges.
  static const _hMargin = 14.0;
  // Inner padding INSIDE the pill — tweak to push the icons / SOS away from
  // (or closer to) the rounded ends.
  static const _innerHPadding = 18.0;
  // Vertical nudge for the SOS button relative to the bar centre. Negative
  // values lift it up, positive values push it down.
  static const _sosVerticalOffset = -2.0;
  // Fully rounded ends — a real pill shape.
  static const _barRadius = _barH / 2;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lp = context.watch<LocaleProvider>();
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final tabs = <(EcoShortcutTab, IconData, String)>[
      (EcoShortcutTab.home, Icons.home_rounded, lp.t('tab.home')),
      (EcoShortcutTab.map, Icons.map_rounded, lp.t('tab.map')),
      (EcoShortcutTab.trails, Icons.hiking_rounded, lp.t('tab.trails')),
      (EcoShortcutTab.settings, Icons.settings_rounded, lp.t('tab.params')),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _hMargin,
        0,
        _hMargin,
        bottomInset > 0 ? bottomInset : 10,
      ),
      child: SizedBox(
        height: _barH,
        child: DecoratedBox(
          // Light luminous halo around the pill — soft and far-reaching, with a
          // small dark drop for grounding.
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_barRadius),
            boxShadow: [
              // Subtle grounding drop shadow only — no foggy white h(lo.
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_barRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? const [Color(0xFF1F2A24), Color(0xFF161E1A)]
                        : const [Colors.white, Color(0xFFF4F7F5)],
                  ),
                  borderRadius: BorderRadius.circular(_barRadius),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.05),
                    width: 0.8,
                  ),
                ),
                // Extra inset on the rounded ends so icons clear the curves.
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: _innerHPadding),
                  child: Row(
                    children: [
                      Expanded(child: _item(tabs[0], isDark)),
                      Expanded(child: _item(tabs[1], isDark)),
                      // SOS now sits inline with the other tabs. The vertical
                      // offset lets it sit above / below the row centre.
                      SizedBox(
                        width: _sosSize + 6,
                        child: Center(
                          child: Transform.translate(
                            offset: const Offset(0, _sosVerticalOffset),
                            child: EcoSosButton(size: _sosSize),
                          ),
                        ),
                      ),
                      Expanded(child: _item(tabs[2], isDark)),
                      Expanded(child: _item(tabs[3], isDark)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _item((EcoShortcutTab, IconData, String) t, bool isDark) => _TabItem(
        icon: t.$2,
        label: t.$3,
        selected: currentTab == t.$1,
        onTap: () => onTabSelected(t.$1),
        isDark: isDark,
      );
}

// ── Tab item ─────────────────────────────────────────────────────────────────

class _TabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;

  static const _green = Color(0xFF0E7A23);
  static const _muted = Color(0xFF8A9BB0);

  const _TabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? _green : _muted;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          // Only the icon colour changes on selection — no background tint.
          AnimatedScale(
            scale: selected ? 1.12 : 1.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
              letterSpacing: selected ? 0.2 : 0.0,
            ),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// The SOS button is now the shared `EcoSosButton` widget (see
// core/widgets/eco_sos_button.dart) so every SOS button across the app uses
// the exact same design.
