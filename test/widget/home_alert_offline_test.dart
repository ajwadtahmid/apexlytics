import 'dart:async';

import 'package:apexlytics/constants/prefs_keys.dart';
import 'package:apexlytics/models/map_rotation.dart';
import 'package:apexlytics/models/news_article.dart';
import 'package:apexlytics/models/predator.dart';
import 'package:apexlytics/models/seasonal_maps.dart';
import 'package:apexlytics/models/server_status.dart';
import 'package:apexlytics/constants/map_constants.dart';
import 'package:apexlytics/providers/map_provider.dart';
import 'package:apexlytics/providers/news_provider.dart';
import 'package:apexlytics/providers/predator_provider.dart';
import 'package:apexlytics/providers/server_provider.dart';
import 'package:apexlytics/providers/settings_provider.dart';
import 'package:apexlytics/screens/home/home_screen.dart';
import 'package:apexlytics/services/notification_service.dart';
import 'package:apexlytics/utils/api_cache.dart' show ApiResult;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_notification_plugin.dart';
import '../helpers.dart';

class _Seasonal extends SeasonalMapsNotifier {
  @override
  Future<SeasonalMaps> build() async => SeasonalMaps(
    ranked: const [AppMap(id: '3', name: 'Olympus')],
    pubs: const [AppMap(id: '2', name: "World's Edge")],
  );
}

class _NoNews extends NewsNotifier {
  @override
  Future<ApiResult<List<NewsArticle>>> build() =>
      Completer<ApiResult<List<NewsArticle>>>().future;
}

/// Home when the map rotation cannot be loaded: the phone is offline.
void main() {
  late ProviderContainer container;
  late FakeNotificationPlugin plugin;

  Future<void> openOffline(WidgetTester tester) async {
    plugin = FakeNotificationPlugin();
    NotificationService.useFakePlugin(plugin);
    final (c, _) = await prefsContainer(
      values: {
        PrefsKeys.notifyRankedMapRotation: true,
        PrefsKeys.rankedNotifyMinutes: 10,
        PrefsKeys.notifyPubsMapRotation: true,
        PrefsKeys.pubsNotifyMinutes: 10,
      },
      overrides: [
        mapRotationProvider.overrideWith(
          (ref) => Future<ApiResult<MapRotation>>.error(StateError('offline')),
        ),
        serverStatusProvider.overrideWith(
          (ref) => Completer<ApiResult<ServerStatus>>().future,
        ),
        newsProvider.overrideWith(_NoNews.new),
        seasonalMapsProvider.overrideWith(_Seasonal.new),
        predatorProvider.overrideWith(
          (ref) => Completer<ApiResult<PredatorResponse>>().future,
        ),
      ],
    );
    container = c;
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  // Home's retry timer for a failed rotation ends with the widget.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  List<int> block(int base) => [for (var i = 0; i < 12; i++) base + i];

  testWidgets('turning a mode off still cancels its alerts', (tester) async {
    await openOffline(tester);
    final settings = container.read(playerSettingsProvider.notifier);

    await settings.setNotifyRankedMapRotation(false);
    await tester.pump();
    await tester.pump();

    expect(plugin.cancelled, block(NotificationService.rankedIdBase));
    await close(tester);
  });

  testWidgets('so does choosing no lead time for it', (tester) async {
    await openOffline(tester);
    final settings = container.read(playerSettingsProvider.notifier);

    await settings.setPubsNotifyMinutesBefore(0);
    await tester.pump();
    await tester.pump();

    expect(plugin.cancelled, block(NotificationService.pubsIdBase));
    await close(tester);
  });

  testWidgets('changing the favourite maps cancels what was armed for it', (
    tester,
  ) async {
    await openOffline(tester);
    final settings = container.read(playerSettingsProvider.notifier);

    await settings.setFavoriteRankedMapNames(['Olympus']);
    await tester.pump();
    await tester.pump();

    // The old plan named maps that are no longer wanted; the next fetch plans
    // the new one.
    expect(plugin.cancelled, block(NotificationService.rankedIdBase));
    await close(tester);
  });

  testWidgets('a change to a setting that is off cancels nothing', (
    tester,
  ) async {
    await openOffline(tester);
    final settings = container.read(playerSettingsProvider.notifier);

    await settings.setWildcardNotifyMinutesBefore(15);
    await tester.pump();
    await tester.pump();

    expect(plugin.cancelled, isEmpty);
    await close(tester);
  });
}
