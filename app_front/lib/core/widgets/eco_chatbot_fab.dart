import 'package:flutter/material.dart';

/// Compact, circular "EcoBot" floating action button.
///
/// A small branded round button (icon only) with a soft pulsing glow and an
/// "online" status dot — sits above the bottom navigation bar without
/// overlapping the page content.
class EcoChatbotFab extends StatefulWidget {
  final VoidCallback onPressed;

  /// Diameter of the round button.
  final double size;

  const EcoChatbotFab({super.key, required this.onPressed, this.size = 54});

  @override
  State<EcoChatbotFab> createState() => _EcoChatbotFabState();
}

class _EcoChatbotFabState extends State<EcoChatbotFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color:
                    const Color(0xFF22B53A).withValues(alpha: 0.26 + t * 0.14),
                blurRadius: 12 + t * 8,
                spreadRadius: t * 1.4,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        );
      },
      child: SizedBox(
        width: size,
        height: size,
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onPressed,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Mascot centered on the white circle (whole character shown,
                // small inset). Falls back to an icon if the asset is missing.
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.all(size * 0.12),
                    child: Image.asset(
                      'assets/images/bot.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF22B53A), Color(0xFF0E7A23)],
                          ),
                        ),
                        child: const Icon(
                          Icons.smart_toy_outlined,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),
                // Crisp green ring around the edge.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF1B8A2C),
                        width: 3,
                      ),
                    ),
                  ),
                ),
                // "online" status dot.
                Positioned(
                  right: size * 0.06,
                  top: size * 0.11,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: const Color(0xFF34D058),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
