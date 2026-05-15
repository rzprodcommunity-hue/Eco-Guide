import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/locale_provider.dart';
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

  // Layout constants
  static const _barH = 64.0;
  static const _sosSize = 56.0;
  static const _overhang = 22.0;
  static const _bumpH = 24.0;
  static const _notchR = _sosSize / 2 + 10.0;

  static const _clipper = _NavbarClipper(
    notchRadius: _notchR,
    bumpHeight: _bumpH,
    topInset: _overhang - _bumpH,
  );

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _barH + _overhang,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // ── Glass background + shimmer + top border (single clip) ──
              Positioned.fill(
                child: ClipPath(
                  clipper: _clipper,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: isDark
                                  ? const [
                                      Color(0xFF223028),
                                      Color(0xFF18221C),
                                    ]
                                  : const [
                                      Colors.white,
                                      Color(0xFFF4F7F5),
                                    ],
                            ),
                          ),
                        ),
                      ),
                      // Arch shimmer
                      Align(
                        alignment: Alignment.topCenter,
                        child: IgnorePointer(
                          child: Container(
                            height: _overhang + 6,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: isDark ? 0.07 : 0.55),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Hairline top border
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.09)
                                  : Colors.black.withValues(alpha: 0.05),
                              width: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Tab row ────────────────────────────────────────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _barH,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      _pair(tabs[0], tabs[1], isDark),
                      const SizedBox(width: _sosSize + 16),
                      _pair(tabs[2], tabs[3], isDark),
                    ],
                  ),
                ),
              ),

              // ── SOS button ─────────────────────────────────────────────
              const Positioned(top: 0, child: _SosButton(size: _sosSize)),
            ],
          ),
        ),

        // Safe-area fill
        Container(
          width: double.infinity,
          height: bottomInset > 0 ? bottomInset : 4,
          color: isDark
              ? const Color(0xFF18221C)
              : const Color(0xFFF4F7F5),
        ),
      ],
    );
  }

  Widget _pair(
    (EcoShortcutTab, IconData, String) a,
    (EcoShortcutTab, IconData, String) b,
    bool isDark,
  ) {
    return Expanded(
      child: Row(
        children: [
          Expanded(child: _item(a, isDark)),
          _Divider(isDark: isDark),
          Expanded(child: _item(b, isDark)),
        ],
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

// ── Navbar clipper ───────────────────────────────────────────────────────────

class _NavbarClipper extends CustomClipper<Path> {
  final double notchRadius;
  final double bumpHeight;
  final double topInset;

  const _NavbarClipper({
    required this.notchRadius,
    required this.bumpHeight,
    this.topInset = 0,
  });

  @override
  Path getClip(Size size) {
    const topR = 24.0;
    const botR = 0.0;
    final cx = size.width / 2;
    final bumpHW = notchRadius + 86;
    final apexY = topInset;
    final flatY = topInset + bumpHeight;

    return Path()
      ..moveTo(0, flatY + topR)
      ..quadraticBezierTo(0, flatY, topR, flatY)
      ..lineTo(cx - bumpHW, flatY)
      ..cubicTo(
        cx - bumpHW + bumpHW * 0.48, flatY,
        cx - notchRadius * 0.72, apexY,
        cx, apexY,
      )
      ..cubicTo(
        cx + notchRadius * 0.72, apexY,
        cx + bumpHW - bumpHW * 0.48, flatY,
        cx + bumpHW, flatY,
      )
      ..lineTo(size.width - topR, flatY)
      ..quadraticBezierTo(size.width, flatY, size.width, flatY + topR)
      ..lineTo(size.width, size.height - botR)
      ..quadraticBezierTo(size.width, size.height, size.width - botR, size.height)
      ..lineTo(botR, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - botR)
      ..close();
  }

  @override
  bool shouldReclip(covariant _NavbarClipper old) =>
      old.notchRadius != notchRadius ||
      old.bumpHeight != bumpHeight ||
      old.topInset != topInset;
}

// ── Divider ──────────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            (isDark ? Colors.white : Colors.black)
                .withValues(alpha: isDark ? 0.12 : 0.10),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
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
          AnimatedScale(
            scale: selected ? 1.15 : 1.0,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: selected
                    ? _green.withValues(alpha: isDark ? 0.22 : 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 26, color: color),
            ),
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

// ── SOS button ───────────────────────────────────────────────────────────────

class _SosButton extends StatefulWidget {
  final double size;
  const _SosButton({required this.size});

  @override
  State<_SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<_SosButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  late final Animation<double> _t =
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const SosScreen(),
          fullscreenDialog: true,
        ),
      ),
      child: AnimatedBuilder(
        animation: _t,
        builder: (_, __) {
          final t = _t.value;
          return SizedBox(
            width: s + 16,
            height: s + 16,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer pulse ring
                Container(
                  width: s + 14 + t * 6,
                  height: s + 14 + t * 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE53935)
                          .withValues(alpha: 0.20 - t * 0.14),
                      width: 2,
                    ),
                  ),
                ),
                // Inner halo
                Container(
                  width: s + 6,
                  height: s + 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE53935)
                        .withValues(alpha: 0.12 + t * 0.08),
                  ),
                ),
                // Main button
                _button(s),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _button(double s) => Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(0, -0.30),
            radius: 0.85,
            colors: [Color(0xFFFF6B60), Color(0xFFE53935), Color(0xFFC62828)],
            stops: [0.0, 0.55, 1.0],
          ),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE53935).withValues(alpha: 0.40),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'SOS',
            style: TextStyle(
              color: Colors.white,
              fontSize: s * 0.28,
              fontWeight: FontWeight.w900,
              letterSpacing: s * 0.020,
              height: 1.0,
              shadows: const [
                Shadow(
                  color: Color(0x55000000),
                  blurRadius: 6,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      );
}