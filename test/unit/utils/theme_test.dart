import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apexlytics/utils/theme.dart';

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
}
