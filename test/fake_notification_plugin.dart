import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the notification plugin and records what it was asked to do.
class FakeNotificationPlugin extends Fake
    implements FlutterLocalNotificationsPlugin {
  /// Ids passed to [cancel], in order.
  final cancelled = <int>[];

  /// What [show] was asked to post, as `(id, body, payload)`.
  final shown = <(int, String?, String?)>[];

  /// The details each of those was posted with, in the same order.
  final shownDetails = <NotificationDetails?>[];

  /// What [pendingNotificationRequests] reports: the alerts "armed" in the test.
  final pending = <PendingNotificationRequest>[];

  /// How many times [cancelAll] or [cancelAllPendingNotifications] ran.
  int cancelAllCalls = 0;

  /// How many times the platform was looked up, which is what asking for
  /// permission starts with.
  int permissionLookups = 0;

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails,
    String? payload,
  }) async {
    shown.add((id, body, payload));
    shownDetails.add(notificationDetails);
  }

  @override
  Future<void> cancel({required int id, String? tag}) async =>
      cancelled.add(id);

  @override
  Future<List<PendingNotificationRequest>>
  pendingNotificationRequests() async => List.of(pending);

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
