import 'package:flutter/material.dart';

/// Animated gradient "EcoBot" floating action button.
///
/// Replaces the plain [FloatingActionButton.extended] with a branded pill that
/// has a soft pulsing glow, a robot icon and an "online" status dot.
class EcoChatbotFab extends StatefulWidget {
  final VoidCallback onPressed;

  const EcoChatbotFab({super.key, required this.onPressed});

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
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF22B53A).withValues(alpha: 0.32 + t * 0.18),
                blurRadius: 16 + t * 12,
                spreadRadius: t * 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: widget.onPressed,
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF22B53A), Color(0xFF0E7A23)],
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 18, 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon + online dot
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.smart_toy_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        Positioned(
                          right: -1,
                          top: -1,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFF7CFF8E),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF0E7A23),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EcoBot',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          height: 1.0,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Assistant',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                          fontSize: 10,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
