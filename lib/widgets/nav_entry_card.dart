import 'package:material_ui/material_ui.dart';

import '../utils/theme.dart';
import 'surface_card.dart';

/// A full-width tappable row, `[icon] Title  >`, that opens a detail screen.
class NavEntryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const NavEntryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  /// Side padding. Slightly under the page's own, so that on a 360 dp phone
  /// the longest title ('Performance') still fits beside its icon and every
  /// tile keeps the same height and type size.
  static const double _horizontalPadding = 12;

  static const _titleStyle = TextStyle(
    color: AppTheme.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  /// Whether the title's longest word fits beside the icon and chevron. When
  /// it doesn't, it would break mid-word, so the title moves under them
  /// instead. The tile's own width isn't known here (these sit in a row sized
  /// by its tallest member, which can't ask for it), so it is taken as half the
  /// screen less the page padding and the gap, which is how they are laid out.
  bool _fitsBesideIcon(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    var longest = 0.0;
    for (final word in title.split(' ')) {
      final painter = TextPainter(
        text: TextSpan(text: word, style: _titleStyle),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      if (painter.width > longest) longest = painter.width;
    }
    final tile =
        (MediaQuery.sizeOf(context).width - 2 * AppTheme.md - AppTheme.sm) / 2;
    // Padding both sides, the icon and its gap, the chevron.
    final room = tile - 2 * _horizontalPadding - 18 - AppTheme.sm - 20;
    // A little spare, as the tile is only estimated and a word that just
    // fits still breaks if the room is a dp short.
    return longest + 2 <= room;
  }

  @override
  Widget build(BuildContext context) {
    final stacked = !_fitsBesideIcon(context);
    final titleText = Text(title, style: _titleStyle);
    const chevron = Icon(Icons.chevron_right, size: 20, color: AppTheme.muted);
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _horizontalPadding,
            vertical: AppTheme.md,
          ),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 18, color: AppTheme.accent),
                        const Spacer(),
                        chevron,
                      ],
                    ),
                    const SizedBox(height: AppTheme.xs),
                    titleText,
                  ],
                )
              : Row(
                  children: [
                    Icon(icon, size: 18, color: AppTheme.accent),
                    const SizedBox(width: AppTheme.sm),
                    Expanded(child: titleText),
                    chevron,
                  ],
                ),
        ),
      ),
    );
  }
}
