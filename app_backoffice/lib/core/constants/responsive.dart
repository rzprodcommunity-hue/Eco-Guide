import 'package:flutter/widgets.dart';

class Responsive {
  static const double mobileMax = 700;
  static const double tabletMax = 1100;

  static double width(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static bool isMobile(BuildContext context) => width(context) < mobileMax;

  static bool isTablet(BuildContext context) {
    final w = width(context);
    return w >= mobileMax && w < tabletMax;
  }

  static bool isDesktop(BuildContext context) => width(context) >= tabletMax;

  static bool isCompact(BuildContext context) => width(context) < tabletMax;

  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet ?? desktop;
    return desktop;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    return value<EdgeInsets>(
      context,
      mobile: const EdgeInsets.all(16),
      tablet: const EdgeInsets.all(20),
      desktop: const EdgeInsets.all(32),
    );
  }
}
