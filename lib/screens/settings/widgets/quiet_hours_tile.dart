import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/settings_provider.dart';
import '../../../utils/formatting/format.dart' show formatClock;
import '../../../utils/theme.dart';

/// The quiet hours row of the alerts sheet: a switch, and once it is on the two
/// times that bound the window. Off until the player switches it on.
class QuietHoursTile extends ConsumerWidget {
  const QuietHoursTile({super.key});

  static String _time(int minuteOfDay) =>
      formatClock(DateTime(2000, 1, 1, minuteOfDay ~/ 60, minuteOfDay % 60));

  Future<void> _pick(
    BuildContext context,
    int current,
    ValueChanged<int> onPicked,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked != null) onPicked(picked.hour * 60 + picked.minute);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quiet = ref.watch(playerSettingsProvider.select((s) => s.quietHours));
    final notifier = ref.read(playerSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.bedtime_outlined,
              size: 16,
              color: AppTheme.textPrimary,
            ),
            const SizedBox(width: AppTheme.sm),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quiet hours',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'No alerts between these times. They are skipped, not '
                    'delayed.',
                    style: AppTheme.caption,
                  ),
                ],
              ),
            ),
            Switch(
              value: quiet.enabled,
              activeThumbColor: AppTheme.accent,
              onChanged: notifier.setAlertQuietEnabled,
            ),
          ],
        ),
        if (quiet.enabled)
          Row(
            children: [
              Expanded(
                child: _TimeField(
                  label: 'From',
                  value: _time(quiet.startMinute),
                  onTap: () => _pick(
                    context,
                    quiet.startMinute,
                    notifier.setAlertQuietStartMinute,
                  ),
                ),
              ),
              Expanded(
                child: _TimeField(
                  label: 'To',
                  value: _time(quiet.endMinute),
                  onTap: () => _pick(
                    context,
                    quiet.endMinute,
                    notifier.setAlertQuietEndMinute,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.sm),
        child: Row(
          children: [
            Text(label, style: AppTheme.captionLarge),
            const SizedBox(width: AppTheme.sm),
            Flexible(
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppTheme.accent),
              ),
            ),
            const SizedBox(width: AppTheme.xs),
            const Icon(Icons.chevron_right, size: 16, color: AppTheme.muted),
          ],
        ),
      ),
    );
  }
}
