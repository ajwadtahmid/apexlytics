import 'package:apexlytics/models/map_rotation.dart';
import 'package:apexlytics/providers/api_provider.dart';
import 'package:apexlytics/providers/search_provider.dart';
import 'package:apexlytics/providers/settings_provider.dart';
import 'package:apexlytics/screens/home/widgets/map_rotation_card.dart';
import 'package:apexlytics/screens/search/favorites_pane.dart';
import 'package:apexlytics/services/api_service.dart';
import 'package:apexlytics/utils/formatting/season_utils.dart';
import 'package:apexlytics/utils/storage/api_cache_store.dart';
import 'package:apexlytics/widgets/graph_week_tab_strip.dart';
import 'package:apexlytics/widgets/segmented_capsule.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

void main() {
  setUpAll(useFfiDatabase);

  group('the two-option switch', () {
    Future<List<int>> pump(WidgetTester t, {int selected = 0}) async {
      final taps = <int>[];
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SegmentedCapsule(
                options: const ['Name', 'UID'],
                selected: selected,
                onChanged: taps.add,
              ),
            ),
          ),
        ),
      );
      return taps;
    }

    testWidgets('is 44 dp tall to touch, above and below the capsule', (
      t,
    ) async {
      final taps = await pump(t);
      final centre = t.getCenter(find.text('UID'));

      // Well outside the painted pill, still inside the target.
      await t.tapAt(centre + const Offset(0, 20));
      await t.tapAt(centre - const Offset(0, 20));

      expect(taps, [1, 1]);
    });

    testWidgets('stays as wide as its labels in a wide space', (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 700,
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: SegmentedCapsule(
                        options: const ['Legends', 'Guns'],
                        selected: 0,
                        onChanged: (_) {},
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Two labels and their padding, nothing like the 700 given.
      expect(t.getSize(find.byType(SegmentedCapsule)).width, lessThan(300));
    });

    testWidgets('tells a screen reader which option is on', (t) async {
      final handle = t.ensureSemantics();
      await pump(t);

      expect(
        t.getSemantics(find.text('Name')),
        isSemantics(label: 'Name', isButton: true, isSelected: true),
      );
      expect(
        t.getSemantics(find.text('UID')),
        isSemantics(label: 'UID', isButton: true, isSelected: false),
      );
      handle.dispose();
    });
  });

  group('the week chips', () {
    final start = DateTime.now().subtract(const Duration(days: 30));
    final weeks = [
      for (var i = 0; i < 4; i++)
        WeekRange(
          start: start.add(Duration(days: 7 * i)),
          end: start.add(Duration(days: 7 * (i + 1))),
        ),
    ];

    Future<List<int>> pump(WidgetTester t) async {
      final taps = <int>[];
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: WeekTabStrip(
                weeks: weeks,
                selectedIndex: 0,
                isCurrentSeason: true,
                onSelected: taps.add,
              ),
            ),
          ),
        ),
      );
      return taps;
    }

    testWidgets('are 44 dp tall to touch', (t) async {
      final taps = await pump(t);

      await t.tapAt(t.getCenter(find.text('W2')) + const Offset(0, 20));

      expect(taps, [1]);
    });

    testWidgets('tell a screen reader which week is on', (t) async {
      final handle = t.ensureSemantics();
      await pump(t);

      expect(
        t.getSemantics(find.text('W1')),
        isSemantics(label: 'W1', isButton: true, isSelected: true),
      );
      expect(
        t.getSemantics(find.text('W2')),
        isSemantics(label: 'W2', isButton: true, isSelected: false),
      );
      handle.dispose();
    });
  });

  testWidgets('the Home mode picker tells a screen reader which mode is on', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    MapMode mode() => MapMode(
      map: 'Olympus',
      remainingSecs: 1800,
      durationMins: 60,
      asset: '',
    );
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapRotationCard(
            rotation: MapRotation(
              battleRoyaleCurrent: mode(),
              battleRoyaleNext: mode(),
              rankedCurrent: mode(),
              rankedNext: mode(),
            ),
          ),
        ),
      ),
    );

    await t.tap(find.text('Pubs'));
    await t.pump(const Duration(milliseconds: 300));

    expect(
      t.getSemantics(find.text('Pubs')),
      isSemantics(isButton: true, isSelected: true),
    );
    expect(
      t.getSemantics(find.text('Ranked')),
      isSemantics(isButton: true, isSelected: false),
    );
    handle.dispose();
    await t.pumpWidget(const SizedBox());
  });

  group('Clear recent searches', () {
    var dbCounter = 0;
    const recents =
        '[{"query":"Alpha","platform":"PC","uid":"1000000000001"},'
        '{"query":"Bravo","platform":"PC","uid":"1000000000002"}]';

    Future<ProviderContainer> pumpPane(WidgetTester t) async {
      SharedPreferences.setMockInitialValues({'recent_searches': recents});
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          apiServiceProvider.overrideWithValue(
            ApiService(
              ApiCacheStore(
                overridePath:
                    'file:touch_targets_${dbCounter++}?mode=memory&cache=shared',
              ),
              httpClientAdapter: FakeHttpAdapter(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(body: FavoritesPane(onPick: (_) {})),
          ),
        ),
      );
      await t.pump();
      return container;
    }

    testWidgets('asks first, and keeps the list if you cancel', (t) async {
      final container = await pumpPane(t);

      await t.tap(find.text('Clear'));
      await t.pumpAndSettle();
      expect(find.text('Clear recent searches?'), findsOneWidget);
      expect(container.read(searchStateProvider).recents, hasLength(2));

      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(container.read(searchStateProvider).recents, hasLength(2));
    });

    testWidgets('clears the list once confirmed', (t) async {
      final container = await pumpPane(t);

      await t.tap(find.text('Clear'));
      await t.pumpAndSettle();
      await t.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Clear'),
        ),
      );
      await t.pumpAndSettle();

      expect(container.read(searchStateProvider).recents, isEmpty);
    });

    testWidgets('is 44 dp tall to touch', (t) async {
      await pumpPane(t);

      final button = find.ancestor(
        of: find.text('Clear'),
        matching: find.byType(TextButton),
      );
      expect(t.getSize(button).height, greaterThanOrEqualTo(44));
    });
  });
}
