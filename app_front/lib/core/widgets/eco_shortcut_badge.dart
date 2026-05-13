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

    const barHeight = 96.0;
    const sosSize = 86.0;
    const sosOverhang = 46.0;
    const bumpHeight = 36.0;

    return SafeArea(
      top: false,
      bottom: false,
      child: SizedBox(
        height: barHeight + sosOverhang,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // Navbar background drawn directly with CustomPaint (curve + shadow)
            Positioned.fill(
              child: CustomPaint(
                painter: _NavbarPainter(
                  notchRadius: sosSize / 2 + 8,
                  topRadius: 34,
                  bumpHeight: bumpHeight,
                  // Top inset so the bump starts at sosOverhang height from top
                  topInset: sosOverhang - bumpHeight,
                  fillColor: isDark ? const Color(0xFF1C5E20) : Colors.white,
                  shadowColor: Colors.black
                      .withValues(alpha: isDark ? 0.45 : 0.28),
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
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
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
                              onTap: () => onTabSelected(EcoShortcutTab.services),
                              isDark: isDark,
                            ),
                          ),
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

class _NavbarPainter extends CustomPainter {
  final double notchRadius;
  final double topRadius;
  final double bumpHeight;
  final double topInset;
  final Color fillColor;
  final Color shadowColor;

  _NavbarPainter({
    required this.notchRadius,
    required this.topRadius,
    required this.bumpHeight,
    this.topInset = 0,
    required this.fillColor,
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
      bumpLeft + bumpHalfWidth * 0.5, flatTopY,
      centerX - notchRadius * 0.7, apexY,
      centerX, apexY,
    );
    path.cubicTo(
      centerX + notchRadius * 0.7, apexY,
      bumpRight - bumpHalfWidth * 0.5, flatTopY,
      bumpRight, flatTopY,
    );
    path.lineTo(size.width - topRadius, flatTopY);
    path.quadraticBezierTo(
        size.width, flatTopY, size.width, flatTopY + topRadius);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
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

    // 3. Draw the filled white shape on top
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // 4. Draw a subtle stroke at the top of the curve for definition
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
      old.fillColor != fillColor ||
      old.shadowColor != shadowColor;
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
                  color: selected
                      ? _green
                      : (isDark ? const Color(0xFFCBD5E1) : _unselected),
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
                        : (isDark ? const Color(0xFFCBD5E1) : _unselected),
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
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;
  late final AnimationController _glowController;
  late final Animation<double> _glowAnim;

  static const _red = Color(0xFFE53935);
  static const _darkRed = Color(0xFFB71C1C);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.96, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _glowAnim = Tween<double>(begin: 0, end: 1).animate(_glowController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
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
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Soft glow that pulses (stays within the button size visually)
            AnimatedBuilder(
              animation: _glowAnim,
              builder: (context, _) {
                final t = _glowAnim.value;
                return Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _red.withValues(alpha: 0.25 + 0.35 * t),
                        blurRadius: 18 + 12 * t,
                        spreadRadius: 2 + 4 * t,
                      ),
                    ],
                  ),
                );
              },
            ),
            // Main button — same look as green one, just red, gentle pulse
            ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_red, _darkRed],
                  ),
                  border: Border.all(color: Colors.white, width: 5),
                  boxShadow: [
                    BoxShadow(
                      color: _red.withValues(alpha: 0.55),
                      blurRadius: 28,
                      spreadRadius: 4,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
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
                    fontSize: widget.size * 0.32,
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
            ),
          ],
        ),
      ),
    );
  }
}