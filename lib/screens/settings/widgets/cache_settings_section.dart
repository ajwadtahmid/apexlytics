import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../providers/alert_mute_provider.dart';
import '../../../providers/api_provider.dart';
import '../../../providers/backup_status_provider.dart';
import '../../../providers/best_metric_provider.dart';
import '../../../providers/entity_trend_overrides_provider.dart';
import '../../../providers/entity_trend_window_provider.dart';
import '../../../providers/legend_list_options_provider.dart';
import '../../../providers/navigation_provider.dart';
import '../../../providers/news_provider.dart';
import '../../../providers/pick_rate_options_provider.dart';
import '../../../providers/player_provider.dart' show myPlayerStatsProvider;
import '../../../providers/recap_tiles_provider.dart';
import '../../../providers/predator_provider.dart';
import '../../../providers/server_provider.dart';
import '../../../providers/storage_usage_provider.dart';
import '../../../providers/sessions_shown_provider.dart';
import '../../../providers/owner_provider.dart';
import '../../../providers/ranked_provider.dart';
import '../../../providers/search_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/background_service.dart';
import '../../../providers/notification_provider.dart';
import '../../../services/notification_service.dart';
import '../../../utils/app_logger.dart';
import '../../../utils/backup_reminder.dart';
import '../../../utils/error_messages.dart';
import '../../../utils/formatting/format.dart'
    show formatBytes, formatNumber, plural;
import '../../../utils/notifications.dart';
import '../../../utils/share_image.dart' show clearSharedCardCopies;
import '../../../utils/storage/checked_prefs.dart' show removeAllChecked;
import '../../../utils/storage/former_profile_uids.dart';
import '../../../utils/storage/backup_service.dart';
import '../../../utils/storage/ranked_history_store.dart';
import '../../../utils/storage/rp_snapshot_storage.dart';
import '../../../utils/theme.dart';
import '../../../widgets/widgets.dart';

class CacheSettingsSection extends ConsumerWidget {
  const CacheSettingsSection({super.key});

  /// Under Export data: what there is to back up, and when it last was.
  static String _exportLine(StorageUsage? u, DateTime? lastBackup) {
    final backup = lastBackup == null
        ? 'Never backed up'
        : 'Backed up ${backupAgeLabel(lastBackup, DateTime.now())}';
    if (u == null) return backup;
    final saved = u.games == 0
        ? 'No games saved yet'
        : '${plural(u.games, 'game')} · ${formatBytes(u.historyBytes)}';
    return '$saved · $backup';
  }

  static String _cacheLine(StorageUsage? u) => u == null
      ? 'Counting…'
      : u.cachedResponses == 0
      ? 'Nothing saved'
      : '${plural(u.cachedResponses, 'saved response')}, '
            '${formatBytes(u.cacheBytes)}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Counted afresh each time Settings is opened: games and responses are
    // saved while it is out of view.
    ref.listen(currentTabProvider, (_, tab) {
      if (tab == AppTab.settings) ref.invalidate(storageUsageProvider);
    });
    final usage = ref.watch(storageUsageProvider).asData?.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel(label: 'Data', icon: Icons.storage),
        SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ActionRow(
                icon: Icons.upload_outlined,
                label: 'Export data',
                onTap: () => exportData(context, ref),
                subtitle: _exportLine(usage, ref.watch(lastBackupProvider)),
              ),
              const Divider(color: AppTheme.surface2, height: 24),
              ActionRow(
                icon: Icons.download_outlined,
                label: 'Import data',
                onTap: () => _importData(context, ref),
              ),
              const Divider(color: AppTheme.surface2, height: 24),
              ActionRow(
                icon: Icons.delete_sweep_outlined,
                label: 'Clear data',
                onTap: () => _openClearSheet(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// "Clear data": the ways to clear, mildest first, each asking before it does
  /// anything.
  void _openClearSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.lg),
          child: Consumer(
            builder: (_, sheetRef, _) {
              final usage = sheetRef.watch(storageUsageProvider).asData?.value;
              // Close the sheet, then ask: the question belongs to the page.
              void choose(void Function() ask) {
                Navigator.pop(sheetContext);
                ask();
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: AppTheme.md),
                  const Text(
                    'Clear data',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppTheme.md),
                  ActionRow(
                    icon: Icons.cleaning_services_outlined,
                    label: 'Clear cached responses',
                    subtitle: _cacheLine(usage),
                    onTap: () => choose(() {
                      _confirm(
                        context,
                        title: 'Clear cached responses?',
                        body:
                            'Removes the saved copies of server data (stats, news, '
                            'Pred cutoffs, lookups) that the app shows when it is '
                            'offline, and fetches them again. Your profiles, '
                            'favorites, settings and match history are kept.',
                        confirmLabel: 'Clear',
                        confirmColor: AppTheme.accent,
                        onConfirm: () => _clearCachedResponses(context, ref),
                      );
                    }),
                  ),
                  const Divider(color: AppTheme.surface2, height: 24),
                  ActionRow(
                    icon: Icons.person_remove_outlined,
                    label: 'Clear profiles & favorites',
                    subtitle: 'Saved profiles and favorite players',
                    color: AppTheme.orange,
                    onTap: () => choose(() {
                      _confirm(
                        context,
                        title: 'Clear profiles & favorites?',
                        body:
                            'Your saved profiles and favorite players will be '
                            'removed. Your settings, RP history and match history '
                            'are kept.',
                        confirmLabel: 'Clear',
                        confirmColor: AppTheme.orange,
                        onConfirm: () =>
                            _clearProfilesAndFavorites(context, ref),
                      );
                    }),
                  ),
                  const Divider(color: AppTheme.surface2, height: 24),
                  ActionRow(
                    icon: Icons.history_toggle_off,
                    label: 'Clear history of removed players',
                    subtitle:
                        'Match and RP history of players you no longer save',
                    color: AppTheme.orange,
                    onTap: () => choose(
                      () => unawaited(_askClearRemovedPlayers(context, ref)),
                    ),
                  ),
                  const Divider(color: AppTheme.surface2, height: 24),
                  ActionRow(
                    icon: Icons.delete_outline,
                    label: 'Clear all data',
                    subtitle: 'Everything, including match history',
                    color: AppTheme.red,
                    onTap: () => choose(() {
                      // Two confirmations: ranked history is forward-only, so a
                      // mis-tap here destroys accrual that can't be re-fetched.
                      _confirm(
                        context,
                        title: 'Clear all data?',
                        body:
                            'Everything will be removed: your profiles, favorites, '
                            'settings, RP history and recorded match history.',
                        confirmLabel: 'Continue',
                        onConfirm: () async {
                          if (!context.mounted) return;
                          await _confirm(
                            context,
                            title: 'This cannot be undone',
                            body:
                                'Recorded match history only accrues while the app '
                                'is open, so it cannot be downloaded again. Export a '
                                'backup first if you might want it back.\n\n'
                                'Permanently erase all data?',
                            confirmLabel: 'Erase everything',
                            onConfirm: () async {
                              // Only an owner device has a token to decide on.
                              final removeOwnerToken =
                                  ref.read(ownerUnlockedProvider)
                                  ? await _askRemoveOwnerToken(context)
                                  : true;
                              if (removeOwnerToken == null ||
                                  !context.mounted) {
                                return;
                              }
                              await _clearAll(
                                context,
                                ref,
                                removeOwnerToken: removeOwnerToken,
                              );
                            },
                          );
                        },
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Drops the saved server responses and nothing else, then has what is on
  /// screen fetch again, so stale-looking data is replaced and not just
  /// forgotten.
  Future<void> _clearCachedResponses(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final api = ref.read(apiServiceProvider);
    final before = api.cacheUsage;
    await api.clearCache();
    ref.invalidate(myPlayerStatsProvider);
    ref.invalidate(predatorProvider);
    ref.invalidate(newsProvider);
    ref.invalidate(serverStatusProvider);
    ref.invalidate(storageUsageProvider);
    if (!context.mounted) return;
    context.showMessage(
      before.entries == 0
          ? 'Nothing was saved.'
          : 'Cleared ${plural(before.entries, 'saved response')} '
                '(${formatBytes(before.bytes)}).',
    );
  }

  /// Whose saved data stays through "Clear history of removed players": the
  /// saved profiles and the favourites.
  Set<String> _keptUids(WidgetRef ref) => {
    for (final p in ref.read(playerSettingsProvider).profiles)
      if (p.uid.isNotEmpty) p.uid,
    for (final f in ref.read(searchStateProvider).favorites)
      if (f.hasUid) f.uid!,
  };

  /// The players, other than those kept, that still have match history, RP
  /// history or other saved data on the device.
  Future<Set<String>> _removedPlayersWithData(WidgetRef ref) async {
    final keep = _keptUids(ref);
    final prefs = ref.read(sharedPreferencesProvider);
    final inDatabase = await ref
        .read(rankedHistoryStoreProvider)
        .uidsWithHistoryExcept(keep);
    return {
      ...inDatabase,
      for (final key in scopedKeysExcept(prefs, keep)) uidOfScopedKey(key)!,
    };
  }

  Future<void> _askClearRemovedPlayers(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final players = await _removedPlayersWithData(ref);
    if (!context.mounted) return;
    if (players.isEmpty) {
      context.showMessage('No saved history from removed players.');
      return;
    }
    await _confirm(
      context,
      title: 'Clear history of removed players?',
      body:
          'Removes the saved match history, RP history and stats of '
          '${plural(players.length, 'player')} who ${players.length == 1 ? 'is' : 'are'} '
          'no longer a saved profile or favorite. Your profiles and '
          'favorites keep theirs. This cannot be undone.',
      confirmLabel: 'Clear',
      confirmColor: AppTheme.orange,
      onConfirm: () => _clearRemovedPlayers(context, ref, players.length),
    );
  }

  Future<void> _clearRemovedPlayers(
    BuildContext context,
    WidgetRef ref,
    int count,
  ) async {
    final keep = _keptUids(ref);
    final prefs = ref.read(sharedPreferencesProvider);
    await ref.read(rankedHistoryStoreProvider).deleteHistoryExcept(keep);
    await removeAllChecked(prefs, scopedKeysExcept(prefs, keep));
    await retainProfileUids(prefs, keep);
    // These read through caches that the deletes above do not reset.
    resetSnapshotCache();
    invalidatePlayerDerivedProviders(ref);
    ref.invalidate(storageUsageProvider);
    if (context.mounted) {
      context.showMessage('Cleared the history of ${plural(count, 'player')}.');
    }
  }

  /// Drops saved profiles, favourites and recent searches, keeping everything
  /// else.
  Future<void> _clearProfilesAndFavorites(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await ref.read(playerSettingsProvider.notifier).clearProfilesAndFavorites();
    final search = ref.read(searchStateProvider.notifier);
    await search.clearFavorites();
    await search.clearRecents();
    if (context.mounted) {
      context.showMessage('Profiles & favorites cleared.');
    }
  }

  /// Third "Clear all data" question, owner devices only: true removes the owner token,
  /// false keeps it, null if dismissed.
  Future<bool?> _askRemoveOwnerToken(BuildContext context) => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Keep owner mode?'),
      content: const Text(
        'This device is unlocked as the owner. Keep the owner token so it '
        'stays unlocked after the erase, or remove it too.',
        style: TextStyle(color: AppTheme.muted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            'Remove token',
            style: TextStyle(color: AppTheme.red),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text(
            'Keep token',
            style: TextStyle(color: AppTheme.green),
          ),
        ),
      ],
    ),
  );

  /// Puts the choices the player made about how things look (how to rank, sort
  /// and window them, the recap tiles) back to their defaults. The sweep has
  /// erased their saved copies, but each provider still holds its value in
  /// memory: left alone, the old choice would go on showing, and the next
  /// change would save the old ones again with it.
  void _resetViewChoices(WidgetRef ref) {
    ref.invalidate(alertMuteProvider);
    ref.invalidate(bestMetricProvider);
    ref.invalidate(entityTrendWindowProvider);
    ref.invalidate(entityTrendOverridesProvider);
    ref.invalidate(sessionsShownProvider);
    ref.invalidate(recapTilesProvider);
    ref.invalidate(legendListOptionsProvider);
    ref.invalidate(pickRateOptionsProvider);
  }

  /// Erases every persisted surface: prefs (bar first-run state), the ranked
  /// match database, and the API cache. The owner token goes only if [removeOwnerToken].
  ///
  /// Every step runs even if an earlier one fails, and the message names
  /// whatever didn't clear. Match history goes first on purpose: clearing
  /// settings first and then failing on history would remove the profile
  /// that shows it while the history stayed on disk, unseen. This order
  /// fails the other way — data still visible, profile still there, and a
  /// retry finishes the job.
  Future<void> _clearAll(
    BuildContext context,
    WidgetRef ref, {
    required bool removeOwnerToken,
  }) async {
    final failed = <String>[];
    Future<void> step(String what, Future<void> Function() run) async {
      try {
        await run();
      } catch (e) {
        // The type only: a storage error's text can carry the SQL arguments
        // (a player's UID or name), and warnings reach crash reports.
        log.w('Clear all data: "$what" failed (${e.runtimeType})');
        failed.add(what);
      }
    }

    await step(
      'match & RP history',
      () => ref.read(rankedHistoryStoreProvider).deleteAll(),
    );
    await step('profiles, favorites & settings', () async {
      final search = ref.read(searchStateProvider.notifier);
      await search.clearFavorites();
      await search.clearRecents();
      await ref
          .read(playerSettingsProvider.notifier)
          .clearAll(keepOwnerUnlock: !removeOwnerToken);
    });
    // clearAll() only sweeps prefs; the token lives in secure storage. lock() also resets the flag.
    if (removeOwnerToken) {
      await step(
        'owner token',
        () => ref.read(ownerUnlockedProvider.notifier).lock(),
      );
    }
    await step(
      'cached responses',
      () => ref.read(apiServiceProvider).clearCache(),
    );
    await step('shared card copies', clearSharedCardCopies);
    // clearAll() wipes every notification pref, but nothing else tears down
    // alerts already scheduled with the OS or resets the background-fetch
    // cadence — without this, up to a dozen map-rotation alerts per enabled
    // mode (some surviving a reboot) keep firing after the user erased
    // everything.
    await step('scheduled map alerts', () async {
      await NotificationService.cancelAll();
      await BackgroundService.updateInterval(0);
    });
    // These read through caches that deleteAll() alone won't invalidate, so
    // they'd otherwise keep serving erased data until relaunch. Done even
    // after a partial failure: what did clear must stop showing.
    resetSnapshotCache();
    invalidatePlayerDerivedProviders(ref);
    _resetViewChoices(ref);
    ref.invalidate(lastBackupProvider);
    if (!context.mounted) return;
    if (failed.isEmpty) {
      context.showMessage('All data cleared.');
    } else {
      context.showError(
        "Couldn't clear ${failed.join(' or ')}. Everything else was cleared "
        '— try again to finish.',
      );
    }
  }

  // Picks and parses the file first, then confirms with the specific
  // contents (profile/match counts, how many matches are actually new). An
  // operation that merges two histories together irreversibly deserves more
  // than a generic "this will restore settings and profiles" dialog.
  Future<void> _importData(BuildContext context, WidgetRef ref) async {
    final rankedStore = ref.read(rankedHistoryStoreProvider);
    final previewResult = await previewBackup(rankedStore: rankedStore);
    if (!context.mounted) return;

    switch (previewResult) {
      case PreviewCancelled():
        return;
      case PreviewError(:final message):
        context.showError(message);
      case PreviewReady(:final preview):
        await _confirmAndCommit(context, ref, preview, rankedStore);
    }
  }

  Future<void> _confirmAndCommit(
    BuildContext context,
    WidgetRef ref,
    BackupPreview preview,
    RankedHistoryStore rankedStore,
  ) async {
    final replaced = preview.profilesReplacedBy(
      ref.read(sharedPreferencesProvider),
    );
    final confirmed = await showConfirmDialog(
      context,
      title: 'Import backup?',
      body: _summarize(preview, replaced),
      confirmLabel: 'Import',
      confirmColor: AppTheme.accent,
    );
    if (!confirmed || !context.mounted) return;

    final prefs = ref.read(sharedPreferencesProvider);
    final importResult = await commitBackupImport(
      preview,
      prefs,
      rankedStore: rankedStore,
    );
    if (!context.mounted) return;

    switch (importResult) {
      case ImportSuccess(:final skippedRows):
        ref.invalidate(playerSettingsProvider);
        ref.invalidate(searchStateProvider);
        // Same UID as before restore, so these families' cached values would
        // otherwise survive and the Ranked section of Stats would show stale data.
        invalidatePlayerDerivedProviders(ref);
        // The same counts the preview dialog showed.
        context.showMessage(
          'Backup restored: ${_profilesLabel(preview.profileCount)}, '
          '${plural(preview.matchCount, 'match')}.'
          '${skippedRows > 0 ? ' $skippedRows unreadable ${skippedRows == 1 ? 'entry was' : 'entries were'} skipped.' : ''}',
        );
        // A restore turns alerts on through the saved settings, so on a new
        // device the system has not been asked yet and every alert would be
        // skipped without a word.
        if (ref.read(playerSettingsProvider).anyMapAlertActive) {
          try {
            await NotificationService.requestPermissions();
          } catch (e) {
            // No notification plugin to ask: the same as being refused.
            log.w('Notification permission request failed', error: e);
          }
          ref.invalidate(notificationsEnabledProvider);
        }
      case ImportError(:final message):
        context.showError(message);
    }
  }

  String _profilesLabel(int count) => plural(count, 'profile');

  // A heads-up, not a hard limit — restoring past this is still expected to
  // work fine, but it's large enough that "may take a moment" is honest.
  static const _largeBackupWarningBytes = 15 * 1024 * 1024; // 15 MB

  String _summarize(BackupPreview preview, List<String> replacedProfiles) {
    final exportedAt = preview.exportedAt;
    final profiles = _profilesLabel(preview.profileCount);
    return [
      if (exportedAt != null)
        'Exported ${DateFormat('MMM d, yyyy').format(exportedAt.toLocal())}.',
      '$profiles, ${plural(preview.matchCount, 'match')} '
          '(${formatNumber(preview.newMatchCount)} new to this device).',
      if (preview.sizeBytes > _largeBackupWarningBytes)
        'This is a large backup (${formatBytes(preview.sizeBytes)}) — '
            'restoring may take a moment.',
      "This will restore the backup's settings and profiles, and merge its "
          'match history into your current data.',
      if (replacedProfiles.isNotEmpty)
        'Your saved profiles will be replaced by the backup\'s, so '
            '${replacedProfiles.join(', ')} will no longer be listed. Their '
            'match history stays on this device; re-add the player to see it '
            'again.',
    ].join('\n\n');
  }

  /// Destructive-action dialog. [onConfirm] runs after the sheet is dismissed,
  /// and the returned future completes only once it has - so a caller can
  /// chain a second [_confirm] inside it to build a two-step confirmation.
  Future<void> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required Future<void> Function() onConfirm,
    String confirmLabel = 'Confirm',
    Color confirmColor = AppTheme.red,
  }) async {
    final confirmed = await showConfirmDialog(
      context,
      title: title,
      body: body,
      confirmLabel: confirmLabel,
      confirmColor: confirmColor,
    );
    if (!confirmed) return;
    try {
      await onConfirm();
    } catch (e) {
      if (context.mounted) context.showError(friendlyError(e));
    }
  }
}

/// Exports a backup and says how it went. Shared by the Data section and the
/// backup reminder, so both record the date the same way.
Future<void> exportData(BuildContext context, WidgetRef ref) async {
  try {
    final prefs = ref.read(sharedPreferencesProvider);
    final fileName = await exportBackup(
      prefs,
      rankedStore: ref.read(rankedHistoryStoreProvider),
    );
    if (fileName == null) return;
    await ref.read(lastBackupProvider.notifier).markBackedUp();

    if (context.mounted) {
      // iOS hands the file to the share sheet; everywhere else it is saved
      // where the user chose. The message names only the file, never its
      // location.
      context.showMessage(
        'Backup ${backupGoesThroughShareSheet ? 'shared' : 'saved'}: '
        '$fileName',
        duration: const Duration(seconds: 4),
      );
    }
  } catch (e) {
    if (context.mounted) {
      context.showError('Export failed: ${friendlyError(e)}');
    }
  }
}
