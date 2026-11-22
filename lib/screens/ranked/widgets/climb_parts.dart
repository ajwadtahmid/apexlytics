import 'package:material_ui/material_ui.dart';

import '../../../constants/rank_constants.dart';
import '../../../utils/theme.dart';

/// The badge of the division at [rung] of the ladder, or empty space where it
/// has none (Rookie), so the rows line up.
class ClimbBadge extends StatelessWidget {
  final int rung;
  final double size;
  const ClimbBadge(this.rung, this.size, {super.key});

  @override
  Widget build(BuildContext context) {
    final path = kRankLadder[rung].assetPath;
    if (path == null) return SizedBox(width: size, height: size);
    return ExcludeSemantics(
      child: Image.asset(
        path,
        width: size,
        height: size,
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
        errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
      ),
    );
  }
}

/// A short label in a tinted, outlined box: FIRST, NOW, PEAK.
class ClimbTag extends StatelessWidget {
  final String text;
  final Color color;
  const ClimbTag(this.text, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      border: Border.all(color: color.withValues(alpha: 0.7)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
    ),
  );
}

/// A figure over its label, in a row of them.
class ClimbFigure extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const ClimbFigure(
    this.value,
    this.label, {
    super.key,
    this.color = AppTheme.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.captionSmall,
          ),
        ],
      ),
    );
  }
}

/// A round arrow, green up or red down, for a promotion or a demotion.
class ClimbArrow extends StatelessWidget {
  final bool up;
  final double size;
  const ClimbArrow({super.key, required this.up, this.size = 26});

  @override
  Widget build(BuildContext context) {
    final color = up ? AppTheme.green : AppTheme.red;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Icon(
        up ? Icons.arrow_upward : Icons.arrow_downward,
        size: size * 0.55,
        color: color,
      ),
    );
  }
}
