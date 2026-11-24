import 'package:material_ui/material_ui.dart';

import '../utils/theme.dart';

/// A soft orange box with a small icon and a line or two of text, for a
/// warning that should be noticed but doesn't block anything. [trailing] sits
/// at the right (a close button, for instance). [onTap] makes the whole box
/// tappable. [centerIcon] centres the icon beside a text of several lines
/// instead of aligning it with the first.
class WarningNote extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool centerIcon;

  const WarningNote({
    super.key,
    required this.icon,
    required this.text,
    this.trailing,
    this.onTap,
    this.centerIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radiusSm);
    return Material(
      color: AppTheme.tintSoft(AppTheme.accent2),
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.md,
            vertical: AppTheme.sm,
          ),
          child: Row(
            crossAxisAlignment: centerIcon
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: centerIcon ? 0 : 1),
                child: Icon(icon, size: 16, color: AppTheme.accent2),
              ),
              const SizedBox(width: AppTheme.sm),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(color: AppTheme.accent2, fontSize: 12),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
