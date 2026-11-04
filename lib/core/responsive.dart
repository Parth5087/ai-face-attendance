import 'package:flutter/material.dart';

extension ResponsiveContext on BuildContext {
  /// Returns true if the device is a tablet or desktop kiosk (shortestSide >= 600).
  bool get isTablet => MediaQuery.of(this).size.shortestSide >= 600;

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
