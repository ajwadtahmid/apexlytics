import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../providers/auto_backup_provider.dart';
import '../../../utils/formatting/format.dart'
    show formatBytes, formatClock, plural;
import '../../../utils/storage/auto_backup.dart';
import '../../../utils/theme.dart';
import '../../../widgets/widgets.dart' show SheetHandle;

/// The automatic backups row of the Data card. It shows the state and opens a
/// sheet holding everything about the feature: the switch, what it does and the
/// copies to restore from. Phones only; the caller leaves it out elsewhere.
class AutoBackupTile extends ConsumerWidget {
  /// Called with the copy the player picked to restore.
  final void Function(AutoBackupFile copy) onRestore;

  /// Exports a backup file, as "Export data" does.
  final VoidCallback onExport;

  const AutoBackupTile({
    super.key,
    required this.onRestore,
    required this.onExport,
  });

  static String _when(DateTime at) =>
      '${DateFormat('MMM d').format(at)}, ${formatClock(at)}';

  void _open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          // The same margins as the map alerts sheet.
          padding: const EdgeInsets.fromLTRB(
            AppTheme.md,
            AppTheme.md,
            AppTheme.md,
            AppTheme.lg,
          ),
          child: _Sheet(
            onRestore: (copy) {
              Navigator.pop(sheetContext);
              onRestore(copy);
            },
            onExport: () {
              Navigator.pop(sheetContext);
              onExport();
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(autoBackupEnabledProvider);
    final copies = ref.watch(autoBackupListProvider).asData?.value ?? const [];
    final status = !enabled
        ? 'Off'
        : copies.isEmpty
        ? 'No copy yet'
        : 'Last copy ${_when(copies.first.takenAt)}';
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      onTap: () => _open(context),
      child: Row(
        children: [
          const Icon(
            Icons.history,
            color: AppTheme.textPrimary,
            size: AppTheme.iconSizeMedium,
          ),
          const SizedBox(width: AppTheme.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Automatic backups', style: TextStyle(fontSize: 14)),
                Text(status, style: AppTheme.caption),
              ],
            ),
          ),
          Text(
            enabled ? 'On' : 'Off',
            style: TextStyle(
              color: enabled ? AppTheme.accent : AppTheme.muted,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: AppTheme.xs),
          const Icon(Icons.chevron_right, color: AppTheme.muted, size: 18),
        ],
      ),
    );
  }
}

class _Sheet extends ConsumerWidget {
  final void Function(AutoBackupFile copy) onRestore;
  final VoidCallback onExport;

  const _Sheet({required this.onRestore, required this.onExport});

  static const _label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppTheme.textPrimary,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(autoBackupEnabledProvider);
    final copies = ref.watch(autoBackupListProvider).asData?.value ?? const [];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetHandle(),
        const SizedBox(height: AppTheme.md),
        const Text(
          'Automatic backups',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppTheme.xs),
        Text(
          'Every ${kAutoBackupInterval.inDays} days, keeping the last '
          '$kAutoBackupKeep copies on this device.',
          style: const TextStyle(
            color: AppTheme.muted,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppTheme.md),
        Row(
          children: [
            const Icon(Icons.history, size: 16, color: AppTheme.textPrimary),
            const SizedBox(width: AppTheme.sm),
            const Expanded(child: Text('Back up automatically', style: _label)),
            Switch(
              value: enabled,
              activeThumbColor: AppTheme.accent,
              onChanged: (v) =>
                  ref.read(autoBackupEnabledProvider.notifier).set(v),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.sm),
        _UninstallWarning(onExport: onExport),
        const Divider(color: AppTheme.surface2, height: AppTheme.lg + 8),
        const Row(
          children: [
            Icon(
              Icons.download_outlined,
              size: 16,
              color: AppTheme.textPrimary,
            ),
            SizedBox(width: AppTheme.sm),
            Text('Restore from a copy', style: _label),
          ],
        ),
        const SizedBox(height: AppTheme.xs),
        Text(
          copies.isEmpty
              ? 'No copies yet. The first is made soon after the app opens.'
              : '${plural(copies.length, 'copy', 'copies')}. Your current data is '
                    'saved first.',
          style: AppTheme.caption,
        ),
        for (final copy in copies) ...[
          const SizedBox(height: AppTheme.sm),
          _CopyRow(copy: copy, onRestore: onRestore),
        ],
      ],
    );
  }
}

/// What these copies do not protect against, set apart so it is not missed.
class _UninstallWarning extends StatelessWidget {
  final VoidCallback onExport;

  const _UninstallWarning({required this.onExport});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.sm + 2),
      decoration: BoxDecoration(
        color: AppTheme.orange.withAlpha(24),
        border: Border.all(color: AppTheme.orange.withAlpha(90)),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: AppTheme.orange,
          ),
          const SizedBox(width: AppTheme.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Lost if you uninstall the app. ',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      TextSpan(
                        text:
                            'These copies stay on this phone, so export a file '
                            'too to keep your history safe.',
                      ),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppTheme.muted,
                  ),
                ),
                InkWell(
                  onTap: onExport,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: const Padding(
                    padding: EdgeInsets.only(top: AppTheme.xs + 2, bottom: 2),
                    child: Text(
                      'Export a file now',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One copy: when it was made and how big it is, and a way to restore it.
class _CopyRow extends StatelessWidget {
  final AutoBackupFile copy;
  final void Function(AutoBackupFile copy) onRestore;

  const _CopyRow({required this.copy, required this.onRestore});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface2,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: () => onRestore(copy),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Padding(
          // The left edge lines the date up with the labels above it, which
          // sit after a 16 px icon and its gap.
          padding: const EdgeInsets.fromLTRB(
            16 + AppTheme.sm,
            AppTheme.sm + 2,
            AppTheme.sm + 2,
            AppTheme.sm + 2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AutoBackupTile._when(copy.takenAt),
                      style: _Sheet._label,
                    ),
                    Text(formatBytes(copy.bytes), style: AppTheme.caption),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.md,
                  vertical: AppTheme.xs + 2,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.accent),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: const Text(
                  'Restore',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
