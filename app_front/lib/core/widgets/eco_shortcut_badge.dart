import 'dart:ui' as ui;

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

  static const _green = Color(0xFF22B53A);
  static const _darkGreen = Color(0xFF15972C);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lp = context.watch<LocaleProvider>();

    const barHeight = 68.0;
    const sosSize = 74.0;
    const sosOverhang = 32.0;
    const bumpHeight = 24.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: SafeArea(
        top: false,
        bottom: false,
        child: SizedBox(
          height: barHeight + sosOverhang,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // Shadow layer (no fill)
              Positioned.fill(
                child: CustomPaint(
                  painter: _NavbarPainter(
                    notchRadius: sosSize / 2 + 8,
                    topRadius: 34,
                    bumpHeight: bumpHeight,
                    topInset: sosOverhang - bumpHeight,
                    shadowColor: const Color(
                      0xFF22B53A,
                    ).withValues(alpha: isDark ? 0.25 : 0.20),
                  ),
                ),
              ),
              // Glassmorphism: clip → blur backdrop → semi-transparent tint
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
                      // Layer 1: blur the content behind
                      BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                        child: Container(color: Colors.transparent),
                      ),
                      // Layer 2: semi-transparent tint on top of blur
                      Container(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.28),
                      ),
                      // Layer 3: thin top border for glass edge
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 0.8,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.10)
                              : Colors.white.withValues(alpha: 0.70),
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
    );
  }
}

class _NavbarPainter extends CustomPainter {
  final double notchRadius;
  final double topRadius;
  final double bumpHeight;
  final double topInset;
  final Color shadowColor;

  _NavbarPainter({
    required this.notchRadius,
    required this.topRadius,
    required this.bumpHeight,
    this.topInset = 0,
    required this.shadowColor,
  });

  Path _buildPath(Size size) {
    final path = Path();
    final centerX = size.width / 2;
    final bumpHalfWidth = notchRadius + 70; // wider than SOS+glow
    // Bump apex sits at y=topInset, flat top at y=topInset+bumpHeight
    final apexY = topInset;
    final flatTopY = topInset + bumpHeight;

    final bumpLeft = centerX - bumpHalfWidth;
    final bumpRight = centerX + bumpHalfWidth;

    path.moveTo(0, flatTopY + topRadius);
    path.quadraticBezierTo(0, flatTopY, topRadius, flatTopY);
    path.lineTo(bumpLeft, flatTopY);
    // smooth hill up to apex
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
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);

    // 1. Draw a blurred shadow ABOVE the path (translated up + blurred)
    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.save();
    canvas.translate(0, -4);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    // 2. Also use built-in drawShadow as a backup
    canvas.drawShadow(path, shadowColor, 16, true);

    // 3. Draw a subtle stroke at the top of the curve for definition
    final strokePaint = Paint()
      ..color = shadowColor.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _NavbarPainter old) =>
      old.notchRadius != notchRadius ||
      old.topRadius != topRadius ||
      old.bumpHeight != bumpHeight ||
      old.shadowColor != shadowColor;
}

// Clips content to the navbar shape (same path as _NavbarPainter)
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

  static const _green = Color(0xFF22B53A);
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

  static const _redTop = Color(0xFFFF5252);
  static const _redMid = Color(0xFFE53935);
  static const _redBottom = Color(0xFF8B0000);

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
            width: widget.size,
            height: widget.size,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // 3D radial gradient: bright top-left → deep dark bottom-right
                gradient: const RadialGradient(
                  center: Alignment(-0.35, -0.45),
                  radius: 1.1,
                  colors: [_redTop, _redMid, _redBottom],
                  stops: [0.0, 0.45, 1.0],
                ),
                boxShadow: [
                  // Animated outer glow
                  BoxShadow(
                    color: _redMid.withValues(alpha: 0.20 + 0.18 * t),
                    blurRadius: 16 + 8 * t,
                    spreadRadius: 1 + 2 * t,
                  ),
                  // Deep bottom shadow for 3D lift
                  BoxShadow(
                    color: _redBottom.withValues(alpha: 0.45 + 0.10 * t),
                    blurRadius: 12 + 4 * t,
                    offset: Offset(0, 5 + 2 * t),
                    spreadRadius: 1,
                  ),
                  // Subtle dark base shadow
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Inner highlight arc for 3D sheen
                  Positioned(
                    top: widget.size * 0.10,
                    left: widget.size * 0.18,
                    child: Container(
                      width: widget.size * 0.45,
                      height: widget.size * 0.22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(widget.size),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.28),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // SOS text
                  Text(
                    'SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: widget.size * 0.30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      shadows: const [
                        Shadow(
                          color: Color(0x88000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
