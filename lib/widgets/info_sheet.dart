import 'package:material_ui/material_ui.dart';

import '../utils/theme.dart';
import 'sheet_handle.dart';

/// A short "how to read this" bottom sheet: a handle, a [title], then one
/// paragraph per entry of [lines]. Scrolls when the text outgrows the screen.
///
/// A [warning], when given, sits in a tinted box under the title, for a limit
/// the reader should know before trusting what they see.
Future<void> showInfoSheet(
  BuildContext context, {
  required String title,
  required List<String> lines,
  String? warning,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: AppTheme.md),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppTheme.md),
            if (warning != null) ...[
              Container(
                padding: const EdgeInsets.all(AppTheme.md),
                decoration: BoxDecoration(
                  color: AppTheme.orange.withAlpha(25),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.orange.withAlpha(120)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 20,
                      color: AppTheme.orange,
                    ),
                    const SizedBox(width: AppTheme.sm),
                    Expanded(
                      child: Text(
                        warning,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.md),
            ],
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.sm),
                child: Text(line, style: AppTheme.captionLarge),
              ),
          ],
        ),
      ),
    ),
  );
}
