import 'package:material_ui/material_ui.dart';
import '../utils/theme.dart';

class IconTextRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final double iconSize;
  final Color? iconColor;
  final TextStyle? textStyle;
  final double gap;

  const IconTextRow({
    super.key,
    required this.icon,
    required this.text,
    this.iconSize = 16,
    this.iconColor,
    this.textStyle,
    this.gap = AppTheme.sm,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: iconColor),
        SizedBox(width: gap),
        Text(text, style: textStyle),
      ],
    );
  }
}
