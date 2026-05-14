import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
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

    const barHeight = 68.0;
    const sosSize = 62.0;
    const sosOverhang = 32.0;
    const bumpHeight = 24.0;

    final navBg = isDark ? AppTheme.darkNavbar : AppTheme.cardBeige;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          child: SizedBox(
            height: barHeight + sosOverhang,
            child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // Solid fill clipped to navbar shape
              Positioned.fill(
                child: ClipPath(
                  clipper: _NavbarClipper(
                    notchRadius: sosSize / 2 + 8,
                    topRadius: 34,
                    bumpHeight: bumpHeight,
                    topInset: sosOverhang - bumpHeight,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Solid beige/dark background
                      Container(color: navBg),
                      // Thin top border for definition
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 1.0,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.07),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Row of tab items on top
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: barHeight,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  child: Row(
                    children: [
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
                            Expanded(
                              child: _TabItem(
                                tab: EcoShortcutTab.trails,
                                icon: Icons.hiking_rounded,
                                label: lp.t('tab.trails'),
                                currentTab: currentTab,
                                onTap: () =>
                                    onTabSelected(EcoShortcutTab.trails),
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
                                label: lp.t('tab.quiz'),
                                currentTab: currentTab,
                                onTap: () => onTabSelected(EcoShortcutTab.quiz),
                                isDark: isDark,
                              ),
                            ),
                            Expanded(
                              child: _TabItem(
                                tab: EcoShortcutTab.services,
                                icon: Icons.storefront_rounded,
                                label: lp.t('tab.services'),
                                currentTab: currentTab,
                                onTap: () =>
                                    onTabSelected(EcoShortcutTab.services),
                                isDark: isDark,
                              ),
                            ),
                            Expanded(
                              child: _TabItem(
                                tab: EcoShortcutTab.settings,
                                icon: Icons.settings_rounded,
                                label: lp.t('tab.params'),
                                currentTab: currentTab,
                                onTap: () =>
                                    onTabSelected(EcoShortcutTab.settings),
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

              Positioned(top: 0, child: _SosButton(size: sosSize)),
            ],
          ),
        ),
      ),
        // Fill system navigation bar area with matching background
        Container(
          width: double.infinity,
          height: bottomInset > 0 ? bottomInset : 4,
          color: navBg,
        ),
      ],
    );
  }
}

// Clips content to the navbar shape
class _NavbarClipper extends CustomClipper<Path> {
  final double notchRadius;
  final double topRadius;
  final double bumpHeight;
  final double topInset;

  _NavbarClipper({
    required this.notchRadius,
    required this.topRadius,
    required this.bumpHeight,
    this.topInset = 0,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final centerX = size.width / 2;
    final bumpHalfWidth = notchRadius + 70;
    final apexY = topInset;
    final flatTopY = topInset + bumpHeight;
    final bumpLeft = centerX - bumpHalfWidth;
    final bumpRight = centerX + bumpHalfWidth;

    path.moveTo(0, flatTopY + topRadius);
    path.quadraticBezierTo(0, flatTopY, topRadius, flatTopY);
    path.lineTo(bumpLeft, flatTopY);
    path.cubicTo(
      bumpLeft + bumpHalfWidth * 0.5,
      flatTopY,
      centerX - notchRadius * 0.7,
      apexY,
      centerX,
      apexY,
    );
    path.cubicTo(
      centerX + notchRadius * 0.7,
      apexY,
      bumpRight - bumpHalfWidth * 0.5,
      flatTopY,
      bumpRight,
      flatTopY,
    );
    path.lineTo(size.width - topRadius, flatTopY);
    path.quadraticBezierTo(
      size.width,
      flatTopY,
      size.width,
      flatTopY + topRadius,
    );
    const br = 28.0;
    path.lineTo(size.width, size.height - br);
    path.quadraticBezierTo(
      size.width,
      size.height,
      size.width - br,
      size.height,
    );
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

class _TabItem extends StatelessWidget {
  final EcoShortcutTab tab;
  final IconData icon;
  final String label;
  final EcoShortcutTab currentTab;
  final VoidCallback onTap;
  final bool isDark;

  static const _green = Color(0xFF0E7A23);
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
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: const BoxDecoration(
            color: Colors.transparent,
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
                  color: selected
                      ? _green
                      : (isDark ? const Color(0xFF6B7280) : _unselected),
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
                    color: selected
                        ? _green
                        : (isDark ? const Color(0xFF6B7280) : _unselected),
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

class _SosButton extends StatefulWidget {
  final double size;

  const _SosButton({required this.size});

  @override
  State<_SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<_SosButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shadowController;
  late final Animation<double> _shadowAnim;


  @override
  void initState() {
    super.initState();
    _shadowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _shadowAnim = CurvedAnimation(
      parent: _shadowController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _shadowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final mid = s * (128 / 140);
    final inner = s * (118 / 140);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const SosScreen(),
          fullscreenDialog: true,
        ),
      ),
      child: AnimatedBuilder(
        animation: _shadowAnim,
        builder: (context, _) {
          final t = _shadowAnim.value;
          return SizedBox(
            width: s,
            height: s,
            child: Container(
              width: s,
              height: s,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(0, -0.36),
                  radius: 0.75,
                  colors: [Color(0xFFFF7065), Color(0xFFE53935), Color(0xFFBD2723)],
                  stops: [0.0, 0.55, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE53935).withValues(alpha: 0.30 + t * 0.25),
                    blurRadius: 18 + t * 18,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: mid,
                  height: mid,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(0, -0.30),
                      radius: 0.65,
                      colors: [Color(0xFFC42924), Color(0xFFC62828), Color(0xFFBC2724)],
                      stops: [0.0, 0.70, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                        spreadRadius: -3,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: inner,
                      height: inner,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          center: Alignment(0, -0.40),
                          radius: 0.65,
                          colors: [Color(0xFFFF8C81), Color(0xFFEF4945), Color(0xFFC62828)],
                          stops: [0.0, 0.40, 1.0],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'SOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: s * 0.28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: s * 0.014,
                            height: 1,
                            shadows: const [
                              Shadow(color: Colors.black38, blurRadius: 0, offset: Offset(0, 1)),
                              Shadow(color: Colors.black26, blurRadius: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
