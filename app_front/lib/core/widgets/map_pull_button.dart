import 'package:flutter/material.dart';

/// Full-width 3D button that opens the map.
///
/// Two ways to trigger it:
///  - a simple tap, or
///  - press and **drag down**: a word is progressively revealed while pulling,
///    and on release past the threshold it calls [onActivate] (open the map).
///
/// While the user is dragging, [onDragStateChanged] is fired so the host scroll
/// view can be frozen (otherwise the page would scroll instead of the button).
class MapPullButton extends StatefulWidget {
  final VoidCallback onActivate;
  final ValueChanged<bool>? onDragStateChanged;
  final String label;

  const MapPullButton({
    super.key,
    required this.onActivate,
    this.onDragStateChanged,
    this.label = 'Carte interactive',
  });

  @override
  State<MapPullButton> createState() => _MapPullButtonState();
}

class _MapPullButtonState extends State<MapPullButton> {
  // Drag distance (px) at which releasing opens the map.
  static const double _threshold = 56;
  // Maximum visual travel of the pull.
  static const double _maxPull = 104;

  double _startY = 0;
  double _dy = 0;
  bool _dragging = false;

  void _onDown(PointerDownEvent e) {
    _startY = e.position.dy;
    _dy = 0;
    _setDragging(true);
  }

  void _onMove(PointerMoveEvent e) {
    final delta = e.position.dy - _startY;
    setState(() => _dy = delta.clamp(0.0, _maxPull));
  }

  void _onUp(PointerUpEvent e) => _finish(e.position.dy);
  void _onCancel(PointerCancelEvent e) => _finish(e.position.dy);

  void _finish(double endY) {
    final moved = (endY - _startY).abs();
    final pastThreshold = _dy >= _threshold;
    final isTap = moved < 8;
    _setDragging(false);
    setState(() => _dy = 0);
    if (isTap || pastThreshold) widget.onActivate();
  }

  void _setDragging(bool v) {
    if (_dragging == v) return;
    _dragging = v;
    widget.onDragStateChanged?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dy / _threshold).clamp(0.0, 1.0);
    // How far the face sinks toward its base (the 3D press effect).
    final pressed = (_dy / _maxPull * 6).clamp(0.0, 6.0);
    final ready = _dy >= _threshold;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: _onCancel,
      child: Container(
        // Room for the 3D bottom lip / glow.
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: ready
                ? const [Color(0xFF2ED456), Color(0xFF12922B)]
                : const [Color(0xFF26C24A), Color(0xFF0E7A23)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            // Solid 3D lip that compresses as the button is pressed.
            BoxShadow(
              color: const Color(0xFF094D15),
              offset: Offset(0, 6 - pressed),
              blurRadius: 0,
            ),
            // Ambient drop shadow.
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              offset: Offset(0, 10 - pressed),
              blurRadius: 14,
            ),
            // Coloured glow that intensifies while pulling.
            BoxShadow(
              color: const Color(0xFF22B53A)
                  .withValues(alpha: 0.30 + progress * 0.25),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.map_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Transform.translate(
                    offset: Offset(0, progress * 4),
                    child: Icon(
                      ready
                          ? Icons.keyboard_double_arrow_down_rounded
                          : Icons.expand_more_rounded,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 22,
                    ),
                  ),
                ],
              ),
              // Word revealed progressively while pulling down.
              ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: progress,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      ready
                          ? 'Relâchez pour ouvrir la carte'
                          : 'Tirez vers le bas…',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
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
