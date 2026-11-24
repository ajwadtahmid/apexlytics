import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/low_power_provider.dart';
import '../utils/theme.dart';
import 'warning_note.dart';

/// Warns that "Keep screen on" can't work in iOS Low Power Mode. [dismissible]
/// makes it a closable banner (Home, Stats), shown only while the Settings
/// switch for it is on ([lowPowerBannerProvider]) and with the full
/// explanation. Otherwise it is a one-line note under the setting itself, which
/// only says Low Power Mode is on ([lowPowerWarningProvider]).
class LowPowerWarning extends ConsumerWidget {
  final bool dismissible;
  const LowPowerWarning({super.key, this.dismissible = false});

  static const _short = "Low Power Mode is on. Keep screen on won't work.";

  static const _message =
      'Low Power Mode is on. iOS then turns the screen off after 30 seconds, '
      "so Keep screen on can't work, and history isn't recorded while the "
      'screen is off. Turn Low Power Mode off while you play.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show = ref.watch(
      dismissible ? lowPowerBannerProvider : lowPowerWarningProvider,
    );
    if (!show) return const SizedBox.shrink();
    if (dismissible && ref.watch(lowPowerBannerDismissedProvider)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.md),
      child: WarningNote(
        icon: Icons.battery_alert_outlined,
        text: dismissible ? _message : _short,
        trailing: dismissible
            ? InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                onTap: ref
                    .read(lowPowerBannerDismissedProvider.notifier)
                    .dismiss,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close, size: 14, color: AppTheme.accent2),
                ),
              )
            : null,
      ),
    );
  }
}
