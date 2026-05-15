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
