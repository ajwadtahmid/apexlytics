import 'package:material_ui/material_ui.dart';

import '../../../utils/formatting/format.dart'
    show formatSessionSpan, formatNumber, plural;
import '../../../utils/ranked/split_coverage.dart';
import '../../../utils/theme.dart';
import '../../../widgets/control_pill.dart' show ControlPill;

/// A small note at the end of the period label saying games are missing from
/// what the app recorded. Nothing at all when [coverage] has no gaps. Tapping
/// it opens the gaps. [recorded] is how many games the totals are built from.
class CoveragePill extends StatelessWidget {
  final SplitCoverage coverage;
  final int recorded;
  const CoveragePill({
    super.key,
    required this.coverage,
    required this.recorded,
  });

  @override
  Widget build(BuildContext context) {
    if (coverage.complete) return const SizedBox.shrink();
    final n = coverage.missing;
    return Semantics(
      button: true,
      label: 'At least ${plural(n, 'game')} missing. Show where.',
      onTap: () => _open(context),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        // The pill is small; the touch area a little larger, as a compact
        // control pill's is, so the heading it sits in does not grow.
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: ControlPill.compactHitHeight,
          ),
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.sm,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: AppTheme.tint(AppTheme.accent2),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 12,
                    color: AppTheme.accent2,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$n+ missing',
                    style: const TextStyle(
                      color: AppTheme.accent2,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _GapsSheet(coverage: coverage, recorded: recorded),
    );
  }
}

class _GapsSheet extends StatelessWidget {
  final SplitCoverage coverage;
  final int recorded;
  const _GapsSheet({required this.coverage, required this.recorded});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            AppTheme.lg,
            0,
            AppTheme.lg,
            AppTheme.lg,
          ),
          children: [
            Text(
              'At least ${plural(coverage.missing, 'game')} '
              '${coverage.missing == 1 ? 'is' : 'are'} missing',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppTheme.xs),
            Text(
              'Totals and averages cover the ${formatNumber(recorded)} games '
              'the app recorded.',
              style: AppTheme.captionLarge,
            ),
            const SizedBox(height: AppTheme.md),
            for (final gap in coverage.gaps)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        formatSessionSpan(gap.from, gap.to),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: AppTheme.sm),
                    Text(
                      'at least ${plural(gap.missing, 'game')}',
                      style: AppTheme.captionLarge,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppTheme.sm),
            const Text(
              'Found from breaks in your RP between one game and the next. A '
              'missed game worth exactly 0 RP cannot be seen, and an RP change '
              'outside a game, such as a penalty, also shows here. The app only '
              'records games while it syncs, so open it between sessions to '
              'keep the record whole.',
              style: AppTheme.captionSmall,
            ),
          ],
        ),
      ),
    );
  }
}
