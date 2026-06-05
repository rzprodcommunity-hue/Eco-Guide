import 'package:flutter/material.dart';

/// Returns the appropriate tile URL based on the current theme.
/// Dark mode → satellite imagery (ESRI World Imagery)
/// Light mode → standard Google road map
String mapTileUrlForTheme(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark
      ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
      : 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
}

/// The only two map styles available across the whole app: a standard road
/// map and satellite imagery. Every map that exposes a style toggle (the
/// dashboard mini-map, the full interactive map and the navigation map)
/// shares this single set — no other variants.
enum AppMapStyle {
  standard(
    'Standard',
    Icons.map_outlined,
    'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
    19,
  ),
  satellite(
    'Satellite',
    Icons.satellite_alt_outlined,
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    18,
  );

  const AppMapStyle(this.label, this.icon, this.urlTemplate, this.maxZoom);

  final String label;
  final IconData icon;
  final String urlTemplate;
  final double maxZoom;

  /// The other style — used by the toggle buttons (only two, so just flip).
  AppMapStyle get next =>
      this == AppMapStyle.standard ? AppMapStyle.satellite : AppMapStyle.standard;
}

/// App-wide selected map style, shared and kept in sync across the mini-map,
/// the full interactive map and the navigation map. This is what makes the
/// user's choice persist when going from one map to another (e.g. pulling the
/// mini-map open into the big map keeps satellite if satellite was selected).
final ValueNotifier<AppMapStyle> appMapStyle =
    ValueNotifier<AppMapStyle>(AppMapStyle.standard);

bool _appMapStyleAutoSet = false;

/// Picks a sensible default exactly once for the whole app session:
/// satellite in dark mode, standard otherwise. Because it self-guards, calling
/// it from several screens is harmless and it never overrides a user's choice.
void ensureMapStyleDefault(BuildContext context) {
  if (_appMapStyleAutoSet) return;
  _appMapStyleAutoSet = true;
  if (Theme.of(context).brightness == Brightness.dark) {
    appMapStyle.value = AppMapStyle.satellite;
  }
}
