import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which session headers are collapsed, keyed by [gameSessionKey].
/// Held in memory only, so a session stays collapsed while the app is open —
/// across tab switches and screen changes — and everything is expanded again
/// on restart.
final collapsedGameSessionsProvider =
    NotifierProvider<CollapsedGameSessions, Set<String>>(
      CollapsedGameSessions.new,
    );

class CollapsedGameSessions extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void toggle(String key) {
    state = state.contains(key) ? ({...state}..remove(key)) : {...state, key};
  }
}

/// Key for the session named [sessionId] within [scope] (the Games tab, or
/// one legend/map page), so collapsing a session in one list doesn't collapse
/// it in another.
String gameSessionKey(String scope, String sessionId) => '$scope|$sessionId';
