import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ranked_match.dart';
import '../utils/ranked/ranked_period.dart';
import '../utils/ranked/shared_matches.dart';
import '../utils/storage/ranked_history_store.dart';
import 'ranked_provider.dart';
import 'settings_provider.dart';

/// The games the saved profiles played together in [splitId] (every split for
/// the Lifetime scope), newest first.
///
/// Reads only the history already on the device: it does not sync a profile,
/// so nothing is requested for it. Every saved profile is matched, not just the
/// ones on screen, so a game with a third saved profile in it can say so; the
/// page then narrows the result to the profiles it shows. The week is applied
/// by the page, after matching, so the games around a week's edge still count
/// as neighbours.
final sharedMatchesProvider = FutureProvider.autoDispose
    .family<List<SharedMatch>, String>((ref, splitId) async {
      final profiles = ref.watch(
        playerSettingsProvider.select((s) => s.profiles),
      );
      final uids = {
        for (final p in profiles)
          if (p.isSet) p.uid,
      };
      final store = ref.watch(rankedHistoryStoreProvider);
      final byUid = <String, List<RankedMatch>>{
        for (final uid in uids) uid: await _gamesFor(store, uid, splitId),
      };
      return findSharedMatches(byUid);
    });

/// [uid]'s games in [splitId], or in every split with ranked games for the
/// Lifetime scope: one split at a time, as the rest of the ranked code loads.
Future<List<RankedMatch>> _gamesFor(
  RankedHistoryStore store,
  String uid,
  String splitId,
) async {
  if (!isLifetimeSplit(splitId)) return store.getBySeason(uid, splitId);
  final counts = await store.rankedSeasonCounts(uid);
  return [for (final id in counts.keys) ...await store.getBySeason(uid, id)];
}
