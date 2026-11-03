import 'dart:async';

import 'package:apexlytics/constants/map_constants.dart';
import 'package:apexlytics/constants/prefs_keys.dart';
import 'package:apexlytics/models/map_rotation.dart';
import 'package:apexlytics/models/news_article.dart';
import 'package:apexlytics/models/predator.dart';
import 'package:apexlytics/models/seasonal_maps.dart';
import 'package:apexlytics/models/server_status.dart';
import 'package:apexlytics/providers/alert_mute_provider.dart';
import 'package:apexlytics/providers/map_provider.dart';
import 'package:apexlytics/providers/news_provider.dart';
import 'package:apexlytics/providers/predator_provider.dart';
import 'package:apexlytics/providers/server_provider.dart';
import 'package:apexlytics/screens/home/home_screen.dart';
import 'package:apexlytics/services/notification_service.dart';
import 'package:apexlytics/utils/alert_silence.dart';
import 'package:apexlytics/utils/api_cache.dart' show ApiResult;
import 'package:flutter/material.dart';
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

MapMode _mode(String map) =>
    MapMode(map: map, remainingSecs: 3000, durationMins: 90, asset: '');

/// Home with a rotation, Ranked alerts on, and a mute pressed on one.
void main() {
  late ProviderContainer container;

  Future<void> open(WidgetTester tester, {required bool muted}) async {
    NotificationService.useFakePlugin(FakeNotificationPlugin());
    final (c, _) = await prefsContainer(
      values: {
        PrefsKeys.notifyRankedMapRotation: true,
        PrefsKeys.rankedNotifyMinutes: 10,
        if (muted)
          PrefsKeys.alertMuteUntil: encodeMutes({
            'ranked': DateTime.now().add(const Duration(hours: 2)),
          })!,
      },
      overrides: [
        mapRotationProvider.overrideWith(
          (ref) async => ApiResult(
            MapRotation(
              battleRoyaleCurrent: _mode('Olympus'),
              battleRoyaleNext: _mode("World's Edge"),
              rankedCurrent: _mode('Olympus'),
              rankedNext: _mode("World's Edge"),
            ),
          ),
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

  // The mute's expiry timer and the armed alerts' timers end with the test.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await NotificationService.cancelAll();
  }

  testWidgets('a muted mode shows a paused bell on Home', (tester) async {
    await open(tester, muted: true);

    expect(find.byIcon(Icons.notifications_paused), findsOneWidget);
    expect(find.byIcon(Icons.notifications_active), findsNothing);
    await close(tester);
  });

  testWidgets('a mode that is not muted keeps its ordinary bell', (
    tester,
  ) async {
    await open(tester, muted: false);

    expect(find.byIcon(Icons.notifications_active), findsOneWidget);
    expect(find.byIcon(Icons.notifications_paused), findsNothing);
    await close(tester);
  });

  testWidgets('tapping it says when the mute ends, and Unmute ends it', (
    tester,
  ) async {
    await open(tester, muted: true);

    await tester.tap(find.byIcon(Icons.notifications_paused));
    await tester.pump();
    await tester.pump(
      const Duration(milliseconds: 600),
    ); // the snack bar slides in
    expect(
      find.textContaining('Ranked alerts are muted until'),
      findsOneWidget,
    );

    await tester.tap(find.text('Unmute'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(container.read(alertMuteProvider), isEmpty);
    expect(find.byIcon(Icons.notifications_paused), findsNothing);
    expect(find.byIcon(Icons.notifications_active), findsOneWidget);
    await close(tester);
  });
}
