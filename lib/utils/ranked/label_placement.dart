import 'dart:ui' show Offset, Rect, Size;

/// Which side of its dot a label sits on. The last four sit to the side but a
/// little up or down, for dots with a neighbour right beside them.
enum LabelSide {
  right,
  left,
  above,
  below,
  rightUp,
  rightDown,
  leftUp,
  leftDown,
}

/// Where each label goes: beside its dot on the first side that stays inside
/// [bounds] and clear of every dot and every label already placed. Null for a
/// label that fits nowhere, which is better left off than drawn over another.
///
/// [centers] and [sizes] run in priority order, so the earlier labels get the
/// good spots. [radius] is the dots' radius and [gap] the space between a dot
/// and its label.
List<Rect?> placeLabels({
  required List<Offset> centers,
  required List<Size> sizes,
  required Rect bounds,
  double radius = 7,
  double gap = 3,
}) {
  assert(centers.length == sizes.length);
  final dots = [
    for (final c in centers) Rect.fromCircle(center: c, radius: radius),
  ];
  final placed = <Rect>[];
  final reach = radius + gap;

  Rect beside(Offset c, Size s, LabelSide side) => switch (side) {
    LabelSide.right => Rect.fromLTWH(
      c.dx + reach,
      c.dy - s.height / 2,
      s.width,
      s.height,
    ),
    LabelSide.left => Rect.fromLTWH(
      c.dx - reach - s.width,
      c.dy - s.height / 2,
      s.width,
      s.height,
    ),
    LabelSide.above => Rect.fromLTWH(
      c.dx - s.width / 2,
      c.dy - reach - s.height,
      s.width,
      s.height,
    ),
    LabelSide.below => Rect.fromLTWH(
      c.dx - s.width / 2,
      c.dy + reach,
      s.width,
      s.height,
    ),
    LabelSide.rightUp => beside(
      c,
      s,
      LabelSide.right,
    ).shift(Offset(0, -s.height * 0.8)),
    LabelSide.rightDown => beside(
      c,
      s,
      LabelSide.right,
    ).shift(Offset(0, s.height * 0.8)),
    LabelSide.leftUp => beside(
      c,
      s,
      LabelSide.left,
    ).shift(Offset(0, -s.height * 0.8)),
    LabelSide.leftDown => beside(
      c,
      s,
      LabelSide.left,
    ).shift(Offset(0, s.height * 0.8)),
  };

  bool fits(Rect r) =>
      r.left >= bounds.left &&
      r.right <= bounds.right &&
      r.top >= bounds.top &&
      r.bottom <= bounds.bottom &&
      !dots.any(r.overlaps) &&
      !placed.any(r.overlaps);

  Rect? place(int i) {
    for (final side in LabelSide.values) {
      final r = beside(centers[i], sizes[i], side);
      if (fits(r)) {
        placed.add(r);
        return r;
      }
    }
    return null;
  }

  return [for (var i = 0; i < centers.length; i++) place(i)];
}

/// A label and where it ended up. [moved] is true when it could not sit beside
/// its dot and was put in free space, so the chart draws a line back to it.
class PlacedLabel {
  final Rect rect;
  final bool moved;
  const PlacedLabel(this.rect, {required this.moved});
}

/// Every label placed, none left off. Each goes beside its dot where there is
/// room (as [placeLabels]); one that cannot is put in the nearest free space
/// inside [bounds] instead, and marked [PlacedLabel.moved] so a leader line can
/// join it to its dot. Only if the area is full does a label overlap another,
/// next to its own dot.
List<PlacedLabel> placeAllLabels({
  required List<Offset> centers,
  required List<Size> sizes,
  required Rect bounds,
  double radius = 7,
  double gap = 3,
  double step = 6,
}) {
  final first = placeLabels(
    centers: centers,
    sizes: sizes,
    bounds: bounds,
    radius: radius,
    gap: gap,
  );
  final dots = [
    for (final c in centers) Rect.fromCircle(center: c, radius: radius + 2),
  ];
  final placed = <Rect>[for (final r in first) ?r];
  final out = <PlacedLabel>[];
  for (var i = 0; i < centers.length; i++) {
    final beside = first[i];
    if (beside != null) {
      out.add(PlacedLabel(beside, moved: false));
      continue;
    }
    final size = sizes[i];
    Rect? best;
    var bestDistance = double.infinity;
    for (var y = bounds.top; y + size.height <= bounds.bottom; y += step) {
      for (var x = bounds.left; x + size.width <= bounds.right; x += step) {
        final r = Rect.fromLTWH(x, y, size.width, size.height);
        if (dots.any(r.overlaps) ||
            placed.any((p) => p.inflate(2).overlaps(r))) {
          continue;
        }
        final d = (r.center - centers[i]).distance;
        if (d < bestDistance) {
          best = r;
          bestDistance = d;
        }
      }
    }
    // No free space at all: keep it by its dot, over whatever is there.
    best ??= Rect.fromLTWH(
      (centers[i].dx + radius + gap).clamp(
        bounds.left,
        (bounds.right - size.width).clamp(bounds.left, double.infinity),
      ),
      (centers[i].dy - size.height / 2).clamp(
        bounds.top,
        (bounds.bottom - size.height).clamp(bounds.top, double.infinity),
      ),
      size.width,
      size.height,
    );
    placed.add(best);
    out.add(PlacedLabel(best, moved: true));
  }
  return out;
}

/// The dots within [reach] of [tap], nearest first: what a tap on a crowd of
/// dots could mean.
List<int> dotsNear(Offset tap, List<Offset> centers, {required double reach}) {
  final near = [
    for (var i = 0; i < centers.length; i++)
      if ((centers[i] - tap).distance <= reach) i,
  ];
  near.sort(
    (a, b) =>
        (centers[a] - tap).distance.compareTo((centers[b] - tap).distance),
  );
  return near;
}

/// Where a leader line from a dot at [center] (radius [radius]) meets the label
/// at [label]: from the dot's edge to the nearest point of the label.
(Offset, Offset) leaderLine(Offset center, Rect label, double radius) {
  final end = Offset(
    center.dx.clamp(label.left, label.right),
    center.dy.clamp(label.top, label.bottom),
  );
  final d = end - center;
  final start = d.distance == 0 ? center : center + d / d.distance * radius;
  return (start, end);
}
