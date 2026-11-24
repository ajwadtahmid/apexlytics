import 'package:material_ui/material_ui.dart';

import '../models/player_stats.dart';
import '../utils/theme.dart';

/// What a player's presence dot can say. Colour tells the states apart, and the
/// same words are given beside the dot or to a screen reader.
enum Presence {
  /// In a match: a solid orange dot.
  inGame,

  /// Online but not in a match: a solid green dot.
  online,

  /// Not online: a solid grey dot.
  offline,

  /// Not looked up yet, so nothing is known: a hollow grey ring.
  unknown,

  /// The lookup failed: a solid red dot.
  failed,
}

/// The presence [stats] reports.
Presence presenceOf(PlayerStats stats) => stats.isInGame
    ? Presence.inGame
    : stats.isOnline
    ? Presence.online
    : Presence.offline;

String _label(Presence presence) => switch (presence) {
  Presence.inGame => 'In game',
  Presence.online => 'Online',
  Presence.offline => 'Offline',
  Presence.unknown => 'Status not known yet',
  Presence.failed => 'Failed to load',
};

/// A player's presence as a small shape. Pass [decorative] when the same words
/// are printed beside it, so a screen reader doesn't say them twice.
class PresenceDot extends StatelessWidget {
  final Presence presence;
  final double size;
  final bool decorative;

  const PresenceDot({
    super.key,
    required this.presence,
    this.size = 12,
    this.decorative = false,
  });

  @override
  Widget build(BuildContext context) {
    final dot = CustomPaint(
      size: Size.square(size),
      painter: _PresencePainter(presence),
    );
    if (decorative) return ExcludeSemantics(child: dot);
    return Semantics(label: _label(presence), child: dot);
  }
}

class _PresencePainter extends CustomPainter {
  final Presence presence;
  const _PresencePainter(this.presence);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final stroke = 1.6 * size.width / 12;

    Paint fill(Color c) => Paint()..color = c;

    switch (presence) {
      case Presence.inGame:
        canvas.drawCircle(center, radius, fill(AppTheme.accent2));
      case Presence.online:
        canvas.drawCircle(center, radius, fill(AppTheme.green));
      case Presence.offline:
        canvas.drawCircle(center, radius, fill(AppTheme.muted));
      case Presence.unknown:
        // A ring is drawn inside the dot's own bounds.
        canvas.drawCircle(
          center,
          radius - stroke / 2,
          Paint()
            ..color = AppTheme.muted
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke,
        );
      case Presence.failed:
        canvas.drawCircle(center, radius, fill(AppTheme.red));
    }
  }

  @override
  bool shouldRepaint(_PresencePainter old) => old.presence != presence;
}
