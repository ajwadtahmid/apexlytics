import 'dart:convert';

import 'package:apexlytics/constants/prefs_keys.dart';
import 'package:apexlytics/providers/api_provider.dart';
import 'package:apexlytics/providers/best_metric_provider.dart';
import 'package:apexlytics/providers/entity_trend_overrides_provider.dart';
import 'package:apexlytics/providers/entity_trend_window_provider.dart';
import 'package:apexlytics/providers/ranked_provider.dart';
import 'package:apexlytics/providers/search_provider.dart';
import 'package:apexlytics/providers/settings_provider.dart';
import 'package:apexlytics/providers/storage_usage_provider.dart';
import 'package:apexlytics/screens/settings/widgets/cache_settings_section.dart';
import 'package:apexlytics/services/api_service.dart';
import 'package:apexlytics/utils/formatting/format.dart';
import 'package:apexlytics/utils/formatting/snapshot_types.dart';
import 'package:apexlytics/utils/ranked/best_metric.dart';
import 'package:apexlytics/utils/storage/api_cache_store.dart';
import 'package:apexlytics/utils/theme.dart';
import 'package:apexlytics/utils/storage/ranked_history_store.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show inMemoryDatabasePath;

import '../helpers.dart';

void main() {
  setUpAll(useFfiDatabase);

  late RankedHistoryStore store;
  late ApiService api;
  late ProviderContainer container;
  var dbCounter = 0;

  /// The database works in real time, which the test's fake clock does not
  /// move: give it a moment, then let the widgets take in what came back.
  Future<void> letStorageFinish(WidgetTester t) async {
    for (var i = 0; i < 3; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await t.pump();
    }
  }

  /// The Data card over [games] recorded games and [cached] saved responses.
  Future<void> pump(WidgetTester t, {int games = 0, int cached = 0}) async {
    // In memory and shared by every store opened that way: empty it first.
    store = RankedHistoryStore(overridePath: inMemoryDatabasePath);
    await t.runAsync(store.deleteAll);
    await t.runAsync(
      () => store.upsertAll('1', [
        for (var i = 0; i < games; i++)
          buildMatch(uid: '1', start: 1782090000 + i * 1000),
      ]),
    );
    final cacheStore = ApiCacheStore(
      overridePath:
          'file:data_section_cache_${dbCounter++}?mode=memory&cache=shared',
    );
    await t.runAsync(() async {
      for (var i = 0; i < cached; i++) {
        await cacheStore.upsert('/path$i', '{"n":$i,"pad":"${'x' * 500}"}', 1);
      }
      api = ApiService(cacheStore, httpClientAdapter: FakeHttpAdapter());
      // Primed in the background at construction; wait for it to land.
      for (var i = 0; i < 100 && api.cacheUsage.entries < cached; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    final (c, _) = await prefsContainer(
      overrides: [
        rankedHistoryStoreProvider.overrideWithValue(store),
        apiServiceProvider.overrideWithValue(api),
      ],
    );
    container = c;
    await container
        .read(playerSettingsProvider.notifier)
        .setPlayer('Aceu', '1000000000001', 'PC');
    // Counted for real, before the widgets ask.
    await t.runAsync(() async {
      final keep = container.listen(storageUsageProvider, (_, _) {});
      addTearDown(keep.close);
      await container.read(storageUsageProvider.future);
    });
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: CacheSettingsSection()),
          ),
        ),
      ),
    );
    await t.pump();
  }

  group('formatBytes', () {
    test('uses bytes, then KB, then MB', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(312), '312 B');
      expect(formatBytes(1024), '1 KB');
      expect(formatBytes(48 * 1024 + 100), '48 KB');
      expect(formatBytes(1024 * 1024), '1.0 MB');
      expect(formatBytes((3.24 * 1024 * 1024).round()), '3.2 MB');
    });
  });

  group('under Export data', () {
    testWidgets('says how many games, how much space, and the last backup', (
      t,
    ) async {
      await pump(t, games: 3);

      expect(
        find.textContaining(
          RegExp(r'^3 games · \d+(\.\d)? (B|KB|MB) · Last export: never$'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('says so when there is none', (t) async {
      await pump(t);

      expect(
        find.text('No games saved yet · Last export: never'),
        findsOneWidget,
      );
    });

    testWidgets('says "1 game", not "1 games"', (t) async {
      await pump(t, games: 1);

      expect(find.textContaining('1 game ·'), findsOneWidget);
    });

    testWidgets('puts a separator in a long history', (t) async {
      await pump(t, games: 1200);

      expect(find.textContaining('1,200 games ·'), findsOneWidget);
    });

    testWidgets('has no line of its own above the rows', (t) async {
      await pump(t, games: 3);

      expect(find.byIcon(Icons.history), findsNothing);
      expect(
        t.getTopLeft(find.text('Export data')).dy,
        lessThan(t.getTopLeft(find.text('Import data')).dy),
      );
    });
  });

  group('the card', () {
    testWidgets('is Export, Import and Clear data, nothing more', (t) async {
      await pump(t, games: 3, cached: 2);

      expect(find.text('Export data'), findsOneWidget);
      expect(find.text('Import data'), findsOneWidget);
      expect(find.text('Clear data'), findsOneWidget);
      expect(find.text('Clear cached responses'), findsNothing);
      expect(find.text('Clear profiles & favorites'), findsNothing);
      expect(find.text('Clear all data'), findsNothing);
    });
  });

  testWidgets('the Clear data row is red, the others are not', (t) async {
    await pump(t, cached: 3);

    Color? label(String text) => t.widget<Text>(find.text(text)).style?.color;
    expect(label('Clear data'), AppTheme.red);
    expect(label('Import data'), isNot(AppTheme.red));
  });

  group('Clear data', () {
    Future<void> openSheet(WidgetTester t) async {
      await t.tap(find.text('Clear data'));
      await t.pumpAndSettle();
    }

    testWidgets('lists the ways to clear, mildest first', (t) async {
      await pump(t, cached: 3);
      await openSheet(t);

      expect(find.byType(BottomSheet), findsOneWidget);
      final cached = t.getTopLeft(find.text('Clear cached responses')).dy;
      final profiles = t.getTopLeft(find.text('Clear profiles & favorites')).dy;
      final removed = t
          .getTopLeft(find.text('Clear history of removed players'))
          .dy;
      final all = t.getTopLeft(find.text('Clear all data')).dy;
      expect(cached, lessThan(profiles));
      expect(profiles, lessThan(removed));
      expect(removed, lessThan(all));
      expect(find.text('Saved profiles and favorite players'), findsOneWidget);
      expect(find.text('Everything, including match history'), findsOneWidget);
    });

    testWidgets('scrolls, so it fits a short screen', (t) async {
      await pump(t);
      // Wide enough for the test font, short enough to need scrolling.
      t.view.physicalSize = const Size(800, 300);
      await openSheet(t);

      expect(t.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
    });

    testWidgets('closes before it asks', (t) async {
      await pump(t, cached: 3);
      await openSheet(t);

      await t.tap(find.text('Clear profiles & favorites'));
      await t.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Clear profiles & favorites?'), findsOneWidget);
    });

    testWidgets('Clear profiles & favorites removes the profile only', (
      t,
    ) async {
      await pump(t, games: 2, cached: 3);
      await openSheet(t);

      await t.tap(find.text('Clear profiles & favorites'));
      await t.pumpAndSettle();
      await t.tap(find.text('Clear'));
      await t.pump();
      await letStorageFinish(t);

      expect(container.read(playerSettingsProvider).profiles, isEmpty);
      expect(api.cacheUsage.entries, 3);
      expect(await t.runAsync(() => store.countStartedSince(null)), 2);
    });

    testWidgets('Clear all data puts the view choices back, in memory as well '
        'as on disk, and nothing returns with the next change', (t) async {
      await pump(t, games: 2);
      await container
          .read(bestMetricProvider.notifier)
          .set(BestMetric.totalKills);
      await container.read(entityTrendWindowProvider.notifier).set(50);
      await container
          .read(entityTrendOverridesProvider.notifier)
          .set('legend:Axle', 25);
      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.containsKey(PrefsKeys.entityTrendOverrides), isTrue);
      await openSheet(t);

      await t.tap(find.text('Clear all data'));
      await t.pumpAndSettle();
      await t.tap(find.text('Continue'));
      await t.pumpAndSettle();
      await t.tap(find.text('Erase everything'));
      await t.pump();
      await letStorageFinish(t);

      // Gone from disk, and no longer what the app is holding.
      for (final key in [
        PrefsKeys.bestMetric,
        PrefsKeys.entityTrendGames,
        PrefsKeys.entityTrendOverrides,
      ]) {
        expect(prefs.containsKey(key), isFalse, reason: key);
      }
      expect(container.read(bestMetricProvider), kDefaultBestMetric);
      expect(container.read(entityTrendWindowProvider), 0);
      expect(container.read(entityTrendOverridesProvider), isEmpty);

      // The next change saves only itself, not the legend erased with the rest.
      await container
          .read(entityTrendOverridesProvider.notifier)
          .set('legend:Wraith', 10);
      expect(jsonDecode(prefs.getString(PrefsKeys.entityTrendOverrides)!), {
        'legend:Wraith': 10,
      });
    });

    testWidgets('Clear profiles & favorites leaves the view choices alone', (
      t,
    ) async {
      await pump(t, games: 2);
      await container
          .read(entityTrendOverridesProvider.notifier)
          .set('legend:Axle', 25);
      await container
          .read(bestMetricProvider.notifier)
          .set(BestMetric.totalKills);
      await openSheet(t);

      await t.tap(find.text('Clear profiles & favorites'));
      await t.pumpAndSettle();
      await t.tap(find.text('Clear'));
      await t.pump();
      await letStorageFinish(t);

      expect(container.read(bestMetricProvider), BestMetric.totalKills);
      expect(container.read(entityTrendOverridesProvider), {'legend:Axle': 25});
    });

    testWidgets('Clear history of removed players keeps the saved profile and '
        'favorites, and clears everyone else', (t) async {
      await pump(t, games: 2);
      final notifier = container.read(searchStateProvider.notifier);
      await notifier.toggleFavorite(
        const PlayerRef(
          query: 'Rival',
          platform: 'PC',
          uid: '1000000000003',
          searchedByUid: false,
        ),
      );
      // Players with data on the device: the profile (…01), a favorite (…03),
      // a removed one with games (…02), one with only RP readings (…04), and
      // the "1" the screen's two seeded games belong to.
      await t.runAsync(() async {
        await store.upsertAll('1000000000001', [
          buildMatch(uid: '1000000000001', start: 1782090000),
        ]);
        await store.upsertAll('1000000000002', [
          buildMatch(uid: '1000000000002', start: 1782090000),
        ]);
        await store.upsertAll('1000000000003', [
          buildMatch(uid: '1000000000003', start: 1782090000),
        ]);
        await store.appendSnapshotFor(
          '1000000000004',
          StatSnapshot(timestamp: DateTime(2026, 9, 1), rp: 1200),
        );
      });
      final prefs = container.read(sharedPreferencesProvider);
      await prefs.setString(PrefsKeys.legendStatsKeyFor('1000000000002'), '{}');
      await prefs.setString(PrefsKeys.legendStatsKeyFor('1000000000003'), '{}');
      await openSheet(t);

      await t.tap(find.text('Clear history of removed players'));
      await letStorageFinish(t);
      await t.pumpAndSettle();
      expect(find.text('Clear history of removed players?'), findsOneWidget);
      expect(find.textContaining('3 players'), findsOneWidget);
      await t.tap(find.text('Clear'));
      await t.pump();
      await letStorageFinish(t);

      final left = await t.runAsync(
        () => store.uidsWithHistoryExcept(<String>{}),
      );
      expect(left, {'1000000000001', '1000000000003'});
      expect(
        prefs.containsKey(PrefsKeys.legendStatsKeyFor('1000000000002')),
        isFalse,
      );
      expect(
        prefs.containsKey(PrefsKeys.legendStatsKeyFor('1000000000003')),
        isTrue,
      );
      expect(container.read(playerSettingsProvider).profiles, isNotEmpty);
    });

    testWidgets('Clear history of removed players says so when there is none', (
      t,
    ) async {
      await pump(t);
      await openSheet(t);

      await t.tap(find.text('Clear history of removed players'));
      await letStorageFinish(t);
      await t.pumpAndSettle();

      expect(
        find.text('No saved history from removed players.'),
        findsOneWidget,
      );
      expect(find.text('Clear history of removed players?'), findsNothing);
    });

    testWidgets('Clear all data asks twice before it does anything', (t) async {
      await pump(t, games: 2);
      await openSheet(t);

      await t.tap(find.text('Clear all data'));
      await t.pumpAndSettle();
      expect(find.text('Clear all data?'), findsOneWidget);
      await t.tap(find.text('Continue'));
      await t.pumpAndSettle();
      expect(find.text('This cannot be undone'), findsOneWidget);
      // Backing out at the second question leaves everything.
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();

      expect(await t.runAsync(() => store.countStartedSince(null)), 2);
      expect(container.read(playerSettingsProvider).name, 'Aceu');
    });

    testWidgets('Clear profiles & favorites also clears recent searches, in '
        'memory and on disk', (t) async {
      await pump(t, games: 2);
      const looked = PlayerRef(
        query: 'Rival123',
        platform: 'PC',
        searchedByUid: false,
      );
      await container.read(searchStateProvider.notifier).recordRecent(looked);
      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.containsKey(PrefsKeys.recentSearches), isTrue);
      await openSheet(t);

      await t.tap(find.text('Clear profiles & favorites'));
      await t.pumpAndSettle();
      await t.tap(find.text('Clear'));
      await t.pump();
      await letStorageFinish(t);

      expect(container.read(searchStateProvider).recents, isEmpty);
      expect(prefs.containsKey(PrefsKeys.recentSearches), isFalse);
    });

    testWidgets('Clear all data also clears recent searches, and the next '
        'lookup does not bring the old one back', (t) async {
      await pump(t, games: 2);
      const old = PlayerRef(
        query: 'Rival123',
        platform: 'PC',
        searchedByUid: false,
      );
      const next = PlayerRef(
        query: 'Newcomer',
        platform: 'PC',
        searchedByUid: false,
      );
      await container.read(searchStateProvider.notifier).recordRecent(old);
      await openSheet(t);

      await t.tap(find.text('Clear all data'));
      await t.pumpAndSettle();
      await t.tap(find.text('Continue'));
      await t.pumpAndSettle();
      await t.tap(find.text('Erase everything'));
      await t.pump();
      await letStorageFinish(t);

      expect(container.read(searchStateProvider).recents, isEmpty);

      await container.read(searchStateProvider.notifier).recordRecent(next);
      expect(container.read(searchStateProvider).recents, [next]);
    });
  });

  group('Clear cached responses', () {
    Future<void> openSheet(WidgetTester t) async {
      await t.tap(find.text('Clear data'));
      await t.pumpAndSettle();
    }

    testWidgets('shows how much is saved', (t) async {
      await pump(t, cached: 3);
      await openSheet(t);

      expect(
        find.textContaining(
          RegExp(r'^3 saved responses, \d+(\.\d)? (B|KB|MB)$'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('says when nothing is saved', (t) async {
      await pump(t);
      await openSheet(t);

      expect(find.text('Nothing saved'), findsOneWidget);
    });

    testWidgets('asks first, and Cancel keeps everything', (t) async {
      await pump(t, cached: 3);
      await openSheet(t);

      await t.tap(find.text('Clear cached responses'));
      await t.pumpAndSettle();
      expect(find.text('Clear cached responses?'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();

      expect(api.cacheUsage.entries, 3);
    });

    testWidgets('clears the responses and nothing else', (t) async {
      await pump(t, games: 2, cached: 3);
      await openSheet(t);
      final bytesBefore = api.cacheUsage.bytes;

      await t.tap(find.text('Clear cached responses'));
      await t.pumpAndSettle();
      await t.tap(find.text('Clear'));
      await t.pump();
      await letStorageFinish(t);

      expect(api.cacheUsage.entries, 0);
      expect(
        find.text('Cleared 3 saved responses (${formatBytes(bytesBefore)}).'),
        findsOneWidget,
      );
      // The match history and the profile stay.
      expect(await t.runAsync(() => store.countStartedSince(null)), 2);
      expect(container.read(playerSettingsProvider).name, 'Aceu');
    });

    testWidgets('says so when there was nothing to clear', (t) async {
      await pump(t);
      await openSheet(t);

      await t.tap(find.text('Clear cached responses'));
      await t.pumpAndSettle();
      await t.tap(find.text('Clear'));
      await t.pump();
      await letStorageFinish(t);

      expect(find.text('Nothing was saved.'), findsOneWidget);
    });
  });
}
