import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apexlytics/utils/theme.dart';

/// WCAG contrast ratio between two colours.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('signColor is green for a gain and red for a loss', () {
    expect(AppTheme.signColor(true), AppTheme.green);
    expect(AppTheme.signColor(false), AppTheme.red);
  });

  test('the app bar is not tinted orange once content scrolls under it', () {
    // Material 3 mixes the primary colour into a scrolled-under bar unless
    // the tint is switched off.
    expect(
      AppTheme.materialTheme.appBarTheme.surfaceTintColor,
      Colors.transparent,
    );
  });

  group('text on the orange fill', () {
    test('has the contrast a small label needs', () {
      expect(
        _contrast(AppTheme.onAccent, AppTheme.accent),
        greaterThanOrEqualTo(4.5),
      );
      // The white it replaces did not.
      expect(_contrast(Colors.white, AppTheme.accent), lessThan(4.5));
    });

    test('is what filled buttons use', () {
      final theme = AppTheme.materialTheme;
      final fg = theme.elevatedButtonTheme.style!.foregroundColor!.resolve({});
      expect(fg, AppTheme.onAccent);
      expect(theme.colorScheme.onPrimary, AppTheme.onAccent);
    });
  });
}
