import 'package:flutter/material.dart';

/// Helper utility for dual-mode responsive layout:
/// - Mobile Mode (< 600px shortestSide)
/// - Tablet Kiosk Mode (>= 600px shortestSide)
class ResponsiveHelper {
  static const double tabletBreakpoint = 600.0;

  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.shortestSide >= tabletBreakpoint;
  }

  static bool isMobile(BuildContext context) {
    return !isTablet(context);
  }

  static T value<T>(BuildContext context, {required T mobile, required T tablet}) {
    return isTablet(context) ? tablet : mobile;
  }
}

extension ResponsiveContext on BuildContext {
  /// Returns true if the device is a tablet or desktop kiosk (shortestSide >= 600).
  bool get isTablet => ResponsiveHelper.isTablet(this);

  /// Returns true if the device is a mobile handheld (< 600).
  bool get isMobile => ResponsiveHelper.isMobile(this);

  /// Helper to return responsive value based on device size.
  T responsive<T>({required T mobile, required T tablet}) {
    return ResponsiveHelper.value(this, mobile: mobile, tablet: tablet);
  }

  /// Width of current screen.
  double get screenWidth => MediaQuery.of(this).size.width;

  /// Height of current screen.
  double get screenHeight => MediaQuery.of(this).size.height;

  /// System padding (notch, status bar, navigation bar).
  EdgeInsets get screenPadding => MediaQuery.of(this).padding;

  /// Status bar height (top padding).
  double get topInset => MediaQuery.of(this).padding.top;

  /// Navigation bar / gesture indicator height (bottom padding).
  double get bottomInset => MediaQuery.of(this).padding.bottom;
}
