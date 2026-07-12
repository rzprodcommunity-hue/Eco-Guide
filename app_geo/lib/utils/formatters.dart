import 'package:intl/intl.dart';

String formatDistance(double meters) {
  if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
  return '${(meters / 1000).toStringAsFixed(2)} km';
}

/// [speed] is in m/s. Output in km/h.
String formatSpeed(double speed) {
  final kmh = speed * 3.6;
  return '${kmh.toStringAsFixed(1)} km/h';
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  String two(int v) => v.toString().padLeft(2, '0');
  if (h > 0) return '${two(h)}:${two(m)}:${two(s)}';
  return '${two(m)}:${two(s)}';
}

String formatDateTime(DateTime dt) =>
    DateFormat('dd/MM/yyyy HH:mm').format(dt.toLocal());
