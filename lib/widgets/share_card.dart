import 'package:flutter/material.dart';
import '../utils/app_logger.dart';
import '../utils/notifications.dart';
import '../utils/share_image.dart';
import '../utils/theme.dart';
import 'legend_asset_image.dart' show legendImageKey;
import 'pill_segments.dart';

/// The logical width every shareable card is laid out at. At a pixel ratio of
/// 3 the shared image is 1080 px wide.
const double kShareCardWidth = 360;

/// The card height: 9:16, the shape of a phone's screen, for a story or a chat.
const double kShareCardHeight = 640;

/// How a card dresses its legend, in the order they are offered: [poster] shows
/// it whole, with the figures on a dark panel along the bottom; [split] gives
/// the top of the card to the portrait and a big title, and the rest to the
/// figures, centred and large; [overlay] fades it in behind the figures.
enum ShareCardStyle { poster, split, overlay }

/// Tells the [ShareCardFrame] below it which [ShareCardStyle] to draw in, so a
/// card does not have to pass it down.
class ShareCardStyleScope extends InheritedWidget {
  final ShareCardStyle style;
  const ShareCardStyleScope({
    super.key,
    required this.style,
    required super.child,
  });

  static ShareCardStyle of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ShareCardStyleScope>()
          ?.style ??
      ShareCardStyle.overlay;

  @override
  bool updateShouldNotify(ShareCardStyleScope old) => style != old.style;
}

/// What a card gives the [ShareCardStyle.split] layout: a big [title] over the
/// portrait with a [subtitle] under it, then in the panel below an optional
/// [badge] beside the player's name, an optional [headline], and the [stats]
/// as centred figures.
class ShareCardSplit {
  final String title;
  final String? subtitle;
  final Widget? badge;
  final Widget? headline;
  final List<ShareTile> stats;

  /// The title's size; a long one, like a record's name, asks for less.
  final double titleSize;
  const ShareCardSplit({
    required this.title,
    this.titleSize = 38,
    this.subtitle,
    this.badge,
    this.headline,
    required this.stats,
  });
}

/// The frame around a shareable card's [child]: who it is for and what it
/// shows on top, an optional faded legend portrait behind, and the Apexlytics
/// mark at the bottom right, on a dark gradient.
///
/// With a [name] it leads, in white and large, and [label] sits under it small
/// and muted. Without one (the player hid it) [label] leads instead. [child]
/// fills the space between that header and the mark.
class ShareCardFrame extends StatelessWidget {
  final String label;
  final String? name;

  /// A legend whose portrait is faded in on the right. Null for none.
  final String? legend;
  final double height;

  /// A line at the bottom left, level with the Apexlytics mark at the right.
  final Widget? footer;

  /// What the split style draws instead of [child]. Without it, that style
  /// falls back to the overlay.
  final ShareCardSplit? split;
  final Widget child;
  const ShareCardFrame({
    super.key,
    required this.label,
    this.name,
    this.legend,
    this.height = kShareCardHeight,
    this.footer,
    this.split,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final style = ShareCardStyleScope.of(context);
    final art = legend;
    final layout = split;
    return Container(
      width: kShareCardWidth,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.surface2, AppTheme.bg],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.accent.withAlpha(90)),
      ),
      clipBehavior: Clip.antiAlias,
      child: art == null
          ? _overlay(null)
          : switch (style) {
              ShareCardStyle.poster => _poster(art),
              ShareCardStyle.split when layout != null => _split(art, layout),
              _ => _overlay(art),
            },
    );
  }

  /// The name and what the card is of, at the top.
  Widget _header() {
    final who = name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (who != null) ...[
          Text(
            who,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTheme.caption),
        ] else
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  Widget _footerRow() => Row(
    children: [
      Expanded(child: footer ?? const SizedBox.shrink()),
      const SizedBox(width: AppTheme.sm),
      const _Brand(),
    ],
  );

  /// The portrait faded in on the right, behind the figures, with a soft dark
  /// wash over its top and left so the header and the headline stay legible
  /// whichever legend it is.
  Widget _overlay(String? art) {
    return Stack(
      children: [
        if (art != null) ...[
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 250,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Colors.transparent, Colors.white.withAlpha(150)],
                stops: const [0, 0.65],
              ).createShader(rect),
              child: _portrait(art, const Alignment(0.2, -1)),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppTheme.bg.withAlpha(125), Colors.transparent],
                  stops: const [0, 0.4],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [AppTheme.bg.withAlpha(85), Colors.transparent],
                  stops: const [0, 0.6],
                ),
              ),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.all(AppTheme.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: AppTheme.md),
              Expanded(child: child),
              const SizedBox(height: AppTheme.sm),
              _footerRow(),
            ],
          ),
        ),
      ],
    );
  }

  /// The portrait across the whole card, with the header over its top and the
  /// figures on a dark panel that fades up from the bottom, so the legend is
  /// never under a number.
  Widget _poster(String art) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _portrait(art, const Alignment(0, -1)),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 150,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppTheme.bg.withAlpha(200), Colors.transparent],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.lg,
            AppTheme.lg,
            AppTheme.lg,
            0,
          ),
          child: Align(alignment: Alignment.topLeft, child: _header()),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
              AppTheme.lg,
              _posterFade,
              AppTheme.lg,
              AppTheme.lg,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.bg.withAlpha(0),
                  AppTheme.bg.withAlpha(228),
                  AppTheme.bg.withAlpha(246),
                ],
                stops: const [0, 0.22, 1],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The figures take the height they need, not what is left.
                IntrinsicHeight(child: child),
                const SizedBox(height: AppTheme.sm),
                _footerRow(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The top of the card is the portrait under a big title; below a thin
  /// orange line, on a soft orange glow, the player's name and the figures,
  /// centred. The figures shrink together if there are too many to fit.
  Widget _split(String art, ShareCardSplit s) {
    const artHeight = 250.0;
    final who = name;
    return Column(
      children: [
        SizedBox(
          height: artHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _portrait(art, const Alignment(0, -1)),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppTheme.bg.withAlpha(190), Colors.transparent],
                    stops: const [0, 0.55],
                  ),
                ),
              ),
              Positioned(
                left: AppTheme.lg,
                right: AppTheme.lg,
                top: AppTheme.md,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        s.title.toUpperCase(),
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: s.titleSize,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    if (s.subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppTheme.xs),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            s.subtitle!.toUpperCase(),
                            maxLines: 1,
                            style: const TextStyle(
                              color: AppTheme.accent,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(height: 2, color: AppTheme.accent),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -1),
                radius: 0.95,
                colors: [AppTheme.accent.withAlpha(30), AppTheme.bg],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.lg,
                AppTheme.md,
                AppTheme.lg,
                AppTheme.md,
              ),
              child: Column(
                children: [
                  if (who != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (s.badge != null) ...[
                          s.badge!,
                          const SizedBox(width: AppTheme.sm),
                        ],
                        Flexible(
                          child: Text(
                            who,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: kShareCardWidth - 2 - 2 * AppTheme.lg,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (s.headline != null) ...[
                                s.headline!,
                                const SizedBox(height: AppTheme.md),
                              ],
                              _SplitStats(stats: s.stats),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.sm),
                  _footerRow(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// How far the poster's bottom panel fades in above its content.
  static const double _posterFade = 56;

  Widget _portrait(String art, Alignment alignment) => Image.asset(
    'assets/legends/${legendImageKey(art)}.webp',
    fit: BoxFit.cover,
    alignment: alignment,
    cacheWidth: 1080,
    errorBuilder: (_, _, _) => const SizedBox.shrink(),
  );
}

/// The Apexlytics mark at the bottom right of a card: the app icon and its name.
class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Image.asset(
            'assets/logos/logo.png',
            width: 22,
            height: 22,
            cacheWidth: 66,
            errorBuilder: (_, _, _) => const SizedBox(width: 22, height: 22),
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'APEXLYTICS',
          style: TextStyle(
            color: AppTheme.accent,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

/// One figure on a card, in a rounded tile with an icon: a small muted label
/// over the value. Two fit across a card.
class ShareTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  const ShareTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  /// Two tiles side by side across the card's padding and its 1 px border, with
  /// a gap between. A pixel of slack keeps them from wrapping on rounding.
  static const double width =
      (kShareCardWidth - 2 - 2 * AppTheme.lg - AppTheme.sm - 1) / 2;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.sm + 2,
        vertical: AppTheme.sm,
      ),
      decoration: BoxDecoration(
        color: AppTheme.bg.withAlpha(190),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.surface2),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.accent),
          const SizedBox(width: AppTheme.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.captionSmall,
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color ?? AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The split style's figures: two to a row, each an icon and a small label over
/// a large value, centred. A last odd one sits in the middle.
class _SplitStats extends StatelessWidget {
  final List<ShareTile> stats;
  const _SplitStats({required this.stats});

  Widget _cell(ShareTile t) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(t.icon, size: 15, color: AppTheme.accent),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                t.label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            t.value,
            maxLines: 1,
            style: TextStyle(
              color: t.color ?? Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < stats.length; i += 2) ...[
          if (i > 0) const SizedBox(height: AppTheme.md),
          Row(
            children: [
              Expanded(child: _cell(stats[i])),
              if (i + 1 < stats.length)
                Expanded(child: _cell(stats[i + 1]))
              else
                const Spacer(),
            ],
          ),
        ],
      ],
    );
  }
}

/// A card's preview with the name switch and the Share button (Save image where
/// a file can't be shared), for a screen to put wherever it likes.
/// [cardBuilder] gets whether the player's name should appear; the choice is on
/// by default, and a card never carries a UID.
class ShareCardPanel extends StatefulWidget {
  final Widget Function(bool showName) cardBuilder;

  /// Offered when the card can carry the player's name.
  final bool offerNameToggle;

  /// Offered when the card has a legend portrait to dress two ways.
  final bool offerStyle;

  /// A test seam in place of the system share sheet.
  final Future<bool> Function(GlobalKey key)? onShare;

  /// A test seam in place of the save dialog, used where the platform can't
  /// share a file. Resolves to the path saved to, or null when cancelled.
  final Future<String?> Function(GlobalKey key)? onSave;

  /// Anything to put between the preview and the name switch, such as the
  /// choice of what goes on the card.
  final Widget? controls;

  const ShareCardPanel({
    super.key,
    required this.cardBuilder,
    this.offerNameToggle = true,
    this.offerStyle = true,
    this.onShare,
    this.onSave,
    this.controls,
  });

  @override
  State<ShareCardPanel> createState() => _ShareCardPanelState();
}

class _ShareCardPanelState extends State<ShareCardPanel> {
  final _boundary = GlobalKey();
  bool _showName = true;
  bool _sharing = false;

  /// Asked afresh each visit, like the name.
  ShareCardStyle _style = ShareCardStyle.poster;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await (widget.onShare ?? shareBoundary)(_boundary);
    } catch (e, st) {
      log.w('Sharing the card failed', error: e, stackTrace: st);
      if (mounted) context.showMessage("Couldn't share the card.");
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// Where sharing a file isn't possible: asks where to keep the image instead.
  Future<void> _save() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final path = await (widget.onSave ?? saveBoundary)(_boundary);
      if (path != null && mounted) context.showMessage('Saved to $path');
    } catch (e, st) {
      log.w('Saving the card failed', error: e, stackTrace: st);
      if (mounted) context.showMessage("Couldn't save the card.");
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canShare = canShareFiles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Scaled down on a narrow screen; the shared image is the card at its
        // own size either way.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: RepaintBoundary(
            key: _boundary,
            // The card looks the same whatever text size the phone uses.
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.noScaling),
              child: ShareCardStyleScope(
                style: _style,
                child: widget.cardBuilder(_showName),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.md),
        if (widget.offerStyle) ...[
          const _LookLabel('Style'),
          PillSegments(
            selected: _style.index,
            onChanged: (i) => setState(() => _style = ShareCardStyle.values[i]),
            options: [
              PillOption(
                label: 'Poster',
                semanticLabel: 'Poster style: the whole legend, figures below',
                icon: (c) => Icon(Icons.image_outlined, size: 16, color: c),
              ),
              PillOption(
                label: 'Split',
                semanticLabel:
                    'Split style: the legend on top, big figures below',
                icon: (c) => Icon(Icons.horizontal_split, size: 16, color: c),
              ),
              PillOption(
                label: 'Overlay',
                semanticLabel: 'Overlay style: the legend behind the figures',
                icon: (c) => Icon(Icons.layers_outlined, size: 16, color: c),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.md),
        ],
        if (widget.controls != null) ...[
          widget.controls!,
          const SizedBox(height: AppTheme.sm),
        ],
        if (widget.offerNameToggle)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show my name'),
            subtitle: const Text(
              'Your player ID is never included.',
              style: AppTheme.caption,
            ),
            value: _showName,
            onChanged: (v) => setState(() => _showName = v),
          ),
        FilledButton.icon(
          onPressed: _sharing ? null : (canShare ? _share : _save),
          icon: Icon(canShare ? Icons.ios_share : Icons.save_alt, size: 18),
          label: Text(canShare ? 'Share' : 'Save image'),
        ),
      ],
    );
  }
}

class _LookLabel extends StatelessWidget {
  final String text;
  const _LookLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppTheme.xs),
    child: Text(text, style: AppTheme.caption),
  );
}

/// Previews a shareable card on its own screen and shares it as an image: a
/// [ShareCardPanel] under [title]. See the panel for the parameters.
class ShareCardScreen extends StatelessWidget {
  final String title;
  final Widget Function(bool showName) cardBuilder;
  final bool offerNameToggle;
  final bool offerStyle;
  final Future<bool> Function(GlobalKey key)? onShare;
  final Future<String?> Function(GlobalKey key)? onSave;

  const ShareCardScreen({
    super.key,
    required this.title,
    required this.cardBuilder,
    this.offerNameToggle = true,
    this.offerStyle = true,
    this.onShare,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.md),
          children: [
            ShareCardPanel(
              cardBuilder: cardBuilder,
              offerNameToggle: offerNameToggle,
              offerStyle: offerStyle,
              onShare: onShare,
              onSave: onSave,
            ),
          ],
        ),
      ),
    );
  }
}
