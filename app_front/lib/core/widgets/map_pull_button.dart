import 'package:flutter/material.dart';

/// Minimal drag-handle widget that opens the map when pulled down.
///
/// Replaces the previous full-width green button with a slim grey pill — the
/// kind you see on a bottom sheet. Two ways to trigger it:
///  - a simple tap, or
///  - press and **drag down**: the handle stretches and turns green, a hint
///    line appears, and on release past the threshold [onActivate] fires
///    (open the map).
///
/// While the user is dragging, [onDragStateChanged] is fired so the host scroll
/// view can be frozen (otherwise the page would scroll instead of the handle).
class MapPullButton extends StatefulWidget {
  final VoidCallback onActivate;
  final ValueChanged<bool>? onDragStateChanged;
  /// Continuous pull distance in px (0.._maxPull) while dragging, 0 on release.
  /// Lets the host grow the hero map as the handle is pulled.
  final ValueChanged<double>? onPull;
  final String label;

  const MapPullButton({
    super.key,
    required this.onActivate,
    this.onDragStateChanged,
    this.onPull,
    this.label = 'Carte interactive',
  });

  @override
  State<MapPullButton> createState() => _MapPullButtonState();
}

class _MapPullButtonState extends State<MapPullButton> {
  // Drag distance (px) at which releasing opens the map.
  static const double _threshold = 70;
  // Maximum visual travel of the pull.
  static const double _maxPull = 220;

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
    widget.onPull?.call(_dy);
  }

  void _onUp(PointerUpEvent e) => _finish(e.position.dy);
  void _onCancel(PointerCancelEvent e) => _finish(e.position.dy);

  void _finish(double endY) {
    final moved = (endY - _startY).abs();
    final pastThreshold = _dy >= _threshold;
    final isTap = moved < 8;
    _setDragging(false);
    setState(() => _dy = 0);
    widget.onPull?.call(0);
    if (isTap || pastThreshold) widget.onActivate();
  }

  void _setDragging(bool v) {
    if (_dragging == v) return;
    _dragging = v;
    widget.onDragStateChanged?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = (_dy / _threshold).clamp(0.0, 1.0);
    final ready = _dy >= _threshold;

    final mutedColor = isDark
        ? Colors.white.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.22);

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: _onCancel,
      child: Container(
        // Generous touch area while the visual stays a tiny grab handle.
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        // Drag handle pill only — grows and turns green as the user pulls.
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: 40 + progress * 20,
          height: 5,
          decoration: BoxDecoration(
            color: ready ? const Color(0xFF22B53A) : mutedColor,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}
