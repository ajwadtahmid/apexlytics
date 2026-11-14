import 'package:material_ui/material_ui.dart';

import '../utils/bug_report.dart' show BugReportChannel;
import '../utils/theme.dart';

/// Asks whether a bug report may carry the user's own player (ID, platform and
/// name), so the developer can reproduce a problem with the same account data.
/// It is unticked to begin with, and the answer is not remembered: it is asked
/// on every report.
///
/// Completes with whether to include the player, or null when the user backs
/// out of the report.
Future<bool?> showBugReportPlayerDialog(
  BuildContext context, {
  required BugReportChannel channel,
  required String uid,
  required String platform,
  required String name,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _BugReportPlayerDialog(
      channel: channel,
      uid: uid,
      platform: platform,
      name: name,
    ),
  );
}

class _BugReportPlayerDialog extends StatefulWidget {
  final BugReportChannel channel;
  final String uid;
  final String platform;
  final String name;

  const _BugReportPlayerDialog({
    required this.channel,
    required this.uid,
    required this.platform,
    required this.name,
  });

  @override
  State<_BugReportPlayerDialog> createState() => _BugReportPlayerDialogState();
}

class _BugReportPlayerDialogState extends State<_BugReportPlayerDialog> {
  bool _include = false;

  @override
  Widget build(BuildContext context) {
    final github = widget.channel == BugReportChannel.github;
    final shown = [
      if (widget.name.isNotEmpty) widget.name,
      widget.uid,
      widget.platform,
    ].join(' · ');
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Add your player to the report?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'With your player details, the developer can reproduce a '
              'problem using the same account data you see. Leave this off '
              'to send the report without them.',
              style: AppTheme.captionLarge,
            ),
            const SizedBox(height: AppTheme.sm),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppTheme.accent,
              value: _include,
              onChanged: (v) => setState(() => _include = v ?? false),
              title: const Text('Include my player ID, platform and name'),
              subtitle: Text(shown, style: AppTheme.caption),
            ),
            const SizedBox(height: AppTheme.sm),
            Text(
              github
                  ? 'A GitHub report is a public issue: anyone can read what '
                        'you include.'
                  : 'An email report goes only to the developer.',
              style: AppTheme.caption,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _include),
          child: const Text(
            'Continue',
            style: TextStyle(color: AppTheme.accent),
          ),
        ),
      ],
    );
  }
}
