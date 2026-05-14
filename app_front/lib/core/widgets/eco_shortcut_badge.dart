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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lp = context.watch<LocaleProvider>();
    final bottomInset = MediaQuery.of(context).padding.bottom;

    const barHeight = 72.0;
    const sosSize = 68.0;
    const sosOverhang = 32.0;
    const bumpHeight = 22.0;
    const notchR = sosSize / 2 + 10;

    // Glass background colors
    final barColor = isDark
        ? const Color(0xFF1C2820).withValues(alpha: 0.94)
        : Colors.white.withValues(alpha: 0.90);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: barHeight + sosOverhang,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // ── Frosted glass background ──────────────────────────
              Positioned.fill(
                child: ClipPath(
                  clipper: _NavbarClipper(
                    notchRadius: notchR,
                    topRadius: 24,
                    bumpHeight: bumpHeight,
                    topInset: sosOverhang - bumpHeight,
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: Container(color: barColor),
                  ),
                ),
              ),

              // ── Arch gradient shimmer ─────────────────────────────
              Positioned.fill(
                child: ClipPath(
                  clipper: _NavbarClipper(
                    notchRadius: notchR,
                    topRadius: 24,
                    bumpHeight: bumpHeight,
                    topInset: sosOverhang - bumpHeight,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      height: sosOverhang + 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: isDark ? 0.06 : 0.55),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Top border line ───────────────────────────────────
              Positioned.fill(
                child: ClipPath(
                  clipper: _NavbarClipper(
                    notchRadius: notchR,
                    topRadius: 24,
                    bumpHeight: bumpHeight,
                    topInset: sosOverhang - bumpHeight,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.09)
                              : Colors.white.withValues(alpha: 0.80),
                          width: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Tab row ───────────────────────────────────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SizedBox(
                  height: barHeight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                    child: Row(
                      children: [
                        // Left pair
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: _TabItem(
                                  tab: EcoShortcutTab.home,
                                  icon: Icons.home_rounded,
                                  label: lp.t('tab.home'),
                                  currentTab: currentTab,
                                  onTap: () => onTabSelected(EcoShortcutTab.home),
                                  isDark: isDark,
                                ),
                              ),
                              _Divider(isDark: isDark),
                              Expanded(
                                child: _TabItem(
                                  tab: EcoShortcutTab.map,
                                  icon: Icons.map_rounded,
                                  label: lp.t('tab.map'),
                                  currentTab: currentTab,
                                  onTap: () => onTabSelected(EcoShortcutTab.map),
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // SOS gap
                        const SizedBox(width: sosSize + 8),

                        // Right pair
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: _TabItem(
                                  tab: EcoShortcutTab.trails,
                                  icon: Icons.hiking_rounded,
                                  label: lp.t('tab.trails'),
                                  currentTab: currentTab,
                                  onTap: () => onTabSelected(EcoShortcutTab.trails),
                                  isDark: isDark,
                                ),
                              ),
                              _Divider(isDark: isDark),
                              Expanded(
                                child: _TabItem(
                                  tab: EcoShortcutTab.settings,
                                  icon: Icons.settings_rounded,
                                  label: lp.t('tab.params'),
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
              ),

              // ── SOS button ────────────────────────────────────────
              Positioned(top: 0, child: _SosButton(size: sosSize)),
            ],
          ),
        ),

        // System nav bar fill
        Container(
          width: double.infinity,
          height: bottomInset > 0 ? bottomInset : 4,
          color: isDark
              ? const Color(0xFF1C2820).withValues(alpha: 0.94)
              : Colors.white.withValues(alpha: 0.90),
        ),
      ],
    );
  }
}

// ── Navbar clipper ────────────────────────────────────────────────────────────

class _NavbarClipper extends CustomClipper<Path> {
  final double notchRadius;
  final double topRadius;
  final double bumpHeight;
  final double topInset;

  const _NavbarClipper({
    required this.notchRadius,
    required this.topRadius,
    required this.bumpHeight,
    this.topInset = 0,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final cx = size.width / 2;
    final bumpHW = notchRadius + 86;
    final apexY = topInset;
    final flatY = topInset + bumpHeight;

    path.moveTo(0, flatY + topRadius);
    path.quadraticBezierTo(0, flatY, topRadius, flatY);
    path.lineTo(cx - bumpHW, flatY);
    path.cubicTo(
      cx - bumpHW + bumpHW * 0.48, flatY,
      cx - notchRadius * 0.72, apexY,
      cx, apexY,
    );
    path.cubicTo(
      cx + notchRadius * 0.72, apexY,
      cx + bumpHW - bumpHW * 0.48, flatY,
      cx + bumpHW, flatY,
    );
    path.lineTo(size.width - topRadius, flatY);
    path.quadraticBezierTo(size.width, flatY, size.width, flatY + topRadius);

    const br = 28.0;
    path.lineTo(size.width, size.height - br);
    path.quadraticBezierTo(size.width, size.height, size.width - br, size.height);
    path.lineTo(br, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - br);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _NavbarClipper old) =>
      old.notchRadius != notchRadius ||
      old.topRadius != topRadius ||
      old.bumpHeight != bumpHeight ||
      old.topInset != topInset;
}

// ── Subtle divider ────────────────────────────────────────────────────────────

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
            isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.10),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

// ── Tab item ──────────────────────────────────────────────────────────────────

class _TabItem extends StatelessWidget {
  final EcoShortcutTab tab;
  final IconData icon;
  final String label;
  final EcoShortcutTab currentTab;
  final VoidCallback onTap;
  final bool isDark;

  static const _green = Color(0xFF0E7A23);
  static const _unselected = Color(0xFF8A9BB0);

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

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            // Icon with scale + subtle bounce
            AnimatedScale(
              scale: selected ? 1.18 : 1.0,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: selected
                      ? (isDark
                          ? _green.withValues(alpha: 0.20)
                          : _green.withValues(alpha: 0.10))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: selected
                      ? _green
                      : (isDark ? _unselected : _unselected),
                ),
              ),
            ),

            const SizedBox(height: 2),

            // Label
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? _green
                    : (isDark ? _unselected : _unselected),
                letterSpacing: selected ? 0.2 : 0.0,
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),

            const SizedBox(height: 4),

            // Active dot indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              width: selected ? 18 : 0,
              height: selected ? 3 : 0,
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(2),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: _green.withValues(alpha: 0.45),
                          blurRadius: 6,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── SOS button ────────────────────────────────────────────────────────────────

class _SosButton extends StatefulWidget {
  final double size;
  const _SosButton({required this.size});

  @override
  State<_SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<_SosButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

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
        animation: _pulseAnim,
        builder: (_, _) {
          return SizedBox(
            width: s + 16,
            height: s + 16,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer pulse ring
                Container(
                  width: s + 14 + _pulseAnim.value * 6,
                  height: s + 14 + _pulseAnim.value * 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE53935).withValues(
                        alpha: 0.18 - _pulseAnim.value * 0.12,
                      ),
                      width: 2,
                    ),
                  ),
                ),
                // Inner glow halo
                Container(
                  width: s + 6,
                  height: s + 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE53935).withValues(
                      alpha: 0.12 + _pulseAnim.value * 0.08,
                    ),
                  ),
                ),
                // Main button
                _buildButton(s),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildButton(double s) {
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(0, -0.30),
          radius: 0.85,
          colors: [
            Color(0xFFFF6B60),
            Color(0xFFE53935),
            Color(0xFFC62828),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
        border: Border.all(color: Colors.white, width: 3.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE53935).withValues(alpha: 0.35),
            blurRadius: 16,
            spreadRadius: 0,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
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
          ],
        ),
      ),
    );
  }
}
