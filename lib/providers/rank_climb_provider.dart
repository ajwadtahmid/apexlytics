import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/ranked/rank_climb.dart';
import 'ranked_provider.dart';

/// The climb through [uid]'s ranked games in one split. Reads the same split
/// of matches the Stats page loads, so it adds no request and keeps to one
/// split at a time.
final rankClimbProvider = FutureProvider.autoDispose
    .family<RankClimb, ({String uid, String splitId})>((ref, arg) async {
      final matches = await ref.watch(rankedSplitMatchesProvider(arg).future);
      return RankClimb.of(matches);
    });
