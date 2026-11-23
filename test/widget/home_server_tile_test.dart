import 'dart:async';

import 'package:apexlytics/models/map_rotation.dart';
import 'package:apexlytics/models/news_article.dart';
import 'package:apexlytics/models/predator.dart';
import 'package:apexlytics/models/seasonal_maps.dart';
import 'package:apexlytics/models/server_status.dart';
import 'package:apexlytics/providers/map_provider.dart';
import 'package:apexlytics/providers/news_provider.dart';
import 'package:apexlytics/providers/predator_provider.dart';
import 'package:apexlytics/providers/server_provider.dart';
import 'package:apexlytics/providers/settings_provider.dart'
    show sharedPreferencesProvider;
import 'package:apexlytics/screens/home/home_screen.dart';
import 'package:apexlytics/services/notification_service.dart';
import 'package:apexlytics/utils/api_cache.dart' show ApiResult;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_notification_plugin.dart';

class _Seasonal extends SeasonalMapsNotifier {
  @override
  Future<SeasonalMaps> build() async =>
      SeasonalMaps(ranked: const [], pubs: const []);
}

class _NoNews extends NewsNotifier {
  @override
  Future<ApiResult<List<NewsArticle>>> build() =>
      Completer<ApiResult<List<NewsArticle>>>().future;
}

/// When the map rotation fails because the connection is gone, the Server Status
/// tile is asked again, so it can say when it was last checked instead of
/// keeping an old reading on screen as if it were current.
void main() {
  late ProviderContainer container;
  var serverFetches = 0;

  Future<void> open(WidgetTester tester, {required Object failure}) async {
    serverFetches = 0;
    NotificationService.useFakePlugin(FakeNotificationPlugin());
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      // The app retries a failed provider after a few seconds; here the failure
      // is seen at once.
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        mapRotationProvider.overrideWith(
          (ref) => Future<ApiResult<MapRotation>>.error(failure),
        ),
        serverStatusProvider.overrideWith((ref) {
          serverFetches++;
          return Completer<ApiResult<ServerStatus>>().future;
        }),
        newsProvider.overrideWith(_NoNews.new),
        seasonalMapsProvider.overrideWith(_Seasonal.new),
        predatorProvider.overrideWith(
          (ref) => Completer<ApiResult<PredatorResponse>>().future,
        ),
      ],
    );
    addTearDown(container.dispose);
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

  DioException lostConnection() => DioException(
    requestOptions: RequestOptions(path: '/maprotation'),
    type: DioExceptionType.connectionError,
  );

  testWidgets('a lost connection asks for the server status again, once', (
    tester,
  ) async {
    await open(tester, failure: lostConnection());
    // Once for the tile as Home opened, once because the connection is gone.
    expect(serverFetches, 2);

    // The next try of the rotation fails the same way: no further request.
    container.invalidate(mapRotationProvider);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(serverFetches, 2);
    await close(tester);
  });

  testWidgets('another kind of failure does not', (tester) async {
    await open(tester, failure: StateError('not the connection'));
    expect(serverFetches, 1);
    await close(tester);
  });
}
