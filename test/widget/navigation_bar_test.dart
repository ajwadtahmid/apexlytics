import 'package:apexlytics/providers/navigation_provider.dart';
import 'package:apexlytics/utils/theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bottom bar as the theme draws it: the palette's colours, labels that
/// always show, and a pill behind the selected tab.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    int selected = 1,
    ValueChanged<int>? onTap,
    double textScale = 1,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.materialTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        bottomNavigationBar: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: onTap,
          destinations: [
            for (final t in AppTab.values)
              NavigationDestination(
                icon: Icon(t.icon),
                selectedIcon: Icon(t.activeIcon),
                label: t.label,
              ),
          ],
        ),
      ),
    ),
  );

  Color? labelColor(WidgetTester tester, String label) =>
      tester.widget<Text>(find.text(label)).style?.color;

  testWidgets('shows every label, the selected one in the accent colour', (
    tester,
  ) async {
    await pump(tester);

    for (final t in AppTab.values) {
      expect(find.text(t.label), findsOneWidget);
    }
    expect(labelColor(tester, AppTab.stats.label), AppTheme.accent);
    expect(labelColor(tester, AppTab.home.label), AppTheme.muted);
  });

  testWidgets('is about as tall as the bar it replaced', (tester) async {
    await pump(tester);

    expect(tester.getSize(find.byType(NavigationBar)).height, 64);
  });

  testWidgets('reports the tapped tab', (tester) async {
    final tapped = <int>[];
    await pump(tester, onTap: tapped.add);

    await tester.tap(find.text(AppTab.search.label));

    expect(tapped, [AppTab.values.indexOf(AppTab.search)]);
  });

  testWidgets('labels grow with the text size', (tester) async {
    await pump(tester);
    final normal = tester.getSize(find.text(AppTab.settings.label)).width;

    await pump(tester, textScale: 1.5);
    final large = tester.getSize(find.text(AppTab.settings.label)).width;

    expect(large, greaterThan(normal));
  });
}
