import 'package:flutter/material.dart';

import '../../screens/sos/sos_button.dart';

/// The single, shared SOS button used across the app — styled exactly like the
/// one in the bottom navigation bar (see [EcoShortcutBadge]): three nested red
/// radial-gradient shells with a glowing red shadow and a bold "SOS" label.
///
/// Tapping it opens the SOS page, unless an [onTap] override is provided
/// (e.g. to add haptic feedback before navigating).
class EcoSosButton extends StatelessWidget {
  /// Outer diameter of the button.
  final double size;

  /// Optional tap override. When null, the button opens the SOS screen.
  final VoidCallback? onTap;

  const EcoSosButton({super.key, this.size = 56, this.onTap});

  void _openSos(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SosScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = size;

    return GestureDetector(
      onTap: onTap ?? () => _openSos(context),
      // ── Outer shell ──────────────────────────────────────────────────────
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
              color: const Color(0xFFE53935).withValues(alpha: 0.40),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          // ── Middle shell ───────────────────────────────────────────────
          child: Container(
            width: s * 0.914,
            height: s * 0.914,
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
              // ── Inner face ─────────────────────────────────────────────
              child: Container(
                width: s * 0.843,
                height: s * 0.843,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: Alignment(0, -0.40),
                    radius: 0.65,
                    colors: [
                      Color(0xFFFF8C81),
                      Color(0xFFEF4945),
                      Color(0xFFC62828),
                    ],
                    stops: [0.0, 0.40, 1.0],
                  ),
                ),
                child: Center(
                  child: Text(
                    'SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: s * 0.26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: s * 0.03,
                      height: 1.0,
                      shadows: const [
                        Shadow(
                          color: Colors.black38,
                          blurRadius: 0,
                          offset: Offset(0, 1),
                        ),
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
  }
}
