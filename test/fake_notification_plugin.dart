import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the notification plugin and records what it was asked to do.
class FakeNotificationPlugin extends Fake
    implements FlutterLocalNotificationsPlugin {
  /// Ids passed to [cancel], in order.
  final cancelled = <int>[];

  /// How many times [cancelAll] or [cancelAllPendingNotifications] ran.
  int cancelAllCalls = 0;

  /// How many times the platform was looked up, which is what asking for
  /// permission starts with.
  int permissionLookups = 0;

  @override
  Future<void> cancel({required int id, String? tag}) async =>
      cancelled.add(id);

  @override
  Future<void> cancelAll() async => cancelAllCalls++;

  @override
  Future<void> cancelAllPendingNotifications() async => cancelAllCalls++;

  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() {
    permissionLookups++;
    return null;
  }
}
