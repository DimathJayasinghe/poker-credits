import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/widget/brutal/app_shell.dart';
import 'package:poker_credits/widget/brutal/brutal_card.dart';
import 'package:poker_credits/widget/brutal/paper_backdrop.dart';

/// How much room a page has, and so how tightly it is drawn.
enum FitTier { comfortable, compact, tight }

/// What a [FitPage] tells its content about the room it has.
@immutable
class FitInfo {
  const FitInfo({required this.tier, required this.sideBySide, required this.width, required this.height, double? bodyHeight})
    : bodyHeight = bodyHeight ?? height;

  final FitTier tier;

  /// A phone on its side: much wider than tall. Content puts two columns next to each other
  /// instead of stacking them.
  final bool sideBySide;

  /// The room the content has.
  final double width;
  final double height;

  /// The height the content has before it would have to scroll: the area under the top bar less
  /// the footer and the padding.
  final double bodyHeight;

  FitInfo withBody(double bodyHeight) => FitInfo(tier: tier, sideBySide: sideBySide, width: width, height: height, bodyHeight: bodyHeight);

  bool get roomy => tier == FitTier.comfortable;
  bool get tight => tier == FitTier.tight;

  /// The space between blocks.
  double get gap => switch (tier) {
    FitTier.comfortable => BrutalMetrics.gapM,
    FitTier.compact => 12,
    FitTier.tight => BrutalMetrics.gapS,
  };

  /// The space around the page.
  double get pad => roomy ? BrutalMetrics.gapM : 12;
}

/// A screen outside a game: a fixed top bar, a body and an optional footer holding the main
/// action. The body never needs scrolling at a normal text size on any phone (docs/UI_DESIGN.md
/// "No scrolling"): it picks a [FitTier] from the height it has, and content draws itself denser
/// as the tier shrinks, or side by side on a phone held on its side. Scrolling is only the last
/// resort, for a text size above 1.3 or an open keyboard, and the footer stays in place then.
class FitPage extends StatelessWidget {
  const FitPage({
    super.key,
    required this.title,
    required this.builder,
    this.onBack,
    this.footer,
    this.actions = const <Widget>[],
    this.maxWidth = 520,
    this.compactBelow = 560,
    this.tightBelow = 430,
    this.padding,
    this.footerShare = 0.28,
  });

  final String title;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget Function(BuildContext context, FitInfo info) builder;

  /// The main action, kept at the bottom edge where a thumb reaches it, outside the scrolling area.
  final Widget Function(BuildContext context, FitInfo info)? footer;

  /// The widest the content gets (twice this on a phone on its side, where it has two columns).
  final double maxWidth;

  /// The height under the top bar (the body and the footer together) under which the page is
  /// drawn compact, and tight; before the text scale is counted.
  final double compactBelow;
  final double tightBelow;

  /// The space around the content; the tier's own when null. A page whose rows run edge to edge
  /// passes [EdgeInsets.zero] and pads its own text.
  final EdgeInsets? padding;

  /// The share of the width the footer gets as a pane on a phone held on its side.
  final double footerShare;

  static FitInfo infoFor(BoxConstraints box, double textScale, {required double compactBelow, required double tightBelow}) {
    final height = box.maxHeight / (textScale < 1 ? 1 : textScale);
    final tier = height >= compactBelow ? FitTier.comfortable : (height >= tightBelow ? FitTier.compact : FitTier.tight);
    return FitInfo(tier: tier, sideBySide: box.maxWidth >= 600 && box.maxHeight < 460, width: box.maxWidth, height: box.maxHeight);
  }

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return PaperScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTopBar(title: title, onBack: onBack, actions: actions),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final info = infoFor(box, textScale, compactBelow: compactBelow, tightBelow: tightBelow);
                final width = info.sideBySide ? maxWidth * 1.7 : maxWidth;
                final inset = padding ?? EdgeInsets.all(info.pad);
                final body = LayoutBuilder(
                  builder: (context, bodyBox) => SingleChildScrollView(
                    padding: inset,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: width),
                        child: builder(context, info.withBody(bodyBox.maxHeight - inset.vertical)),
                      ),
                    ),
                  ),
                );
                final hairline = BorderSide(color: c.line, width: BrutalMetrics.border);
                if (footer == null) return body;
                if (info.sideBySide) {
                  // On its side the phone has width to spare and no height: the main action gets
                  // a pane of its own on the right, and the body keeps the whole height.
                  final pane = (box.maxWidth * footerShare).clamp(190.0, 360.0);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(child: body),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: c.paper,
                          border: Border(left: hairline),
                        ),
                        child: SizedBox(
                          width: pane,
                          child: LayoutBuilder(
                            builder: (context, paneBox) => SingleChildScrollView(
                              padding: EdgeInsets.all(info.pad),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minHeight: paneBox.maxHeight - info.pad * 2),
                                child: Center(child: footer!(context, info)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(child: body),
                    // The footer stays in place, but at a huge text size it may not eat the whole
                    // screen: it takes at most 60 % of the height and scrolls inside that.
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: box.maxHeight * 0.6),
                      child: SingleChildScrollView(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: c.paper,
                            border: Border(top: hairline),
                          ),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(info.pad, info.gap, info.pad, info.pad),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: width),
                                child: footer!(context, info),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled group of controls. Roomy pages draw it as a card with a caption strip; a page that
/// is short drops the frame and keeps the label, so the controls get the height. [hint] is the
/// one line that says what the chosen option means.
class FitSection extends StatelessWidget {
  const FitSection({super.key, required this.info, required this.child, this.label, this.hint});

  final FitInfo info;
  final String? label;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final hintText = hint == null ? null : Text(hint!, style: TextStyle(fontSize: 13, height: 1.3, color: c.muted));
    if (info.roomy) {
      return BrutalCard(
        header: label,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            child,
            if (hintText != null) ...<Widget>[const SizedBox(height: BrutalMetrics.gapS), hintText],
          ],
        ),
      );
    }
    final labelText = label == null
        ? null
        : Text(
            label!.toUpperCase(),
            style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2, color: c.ink),
          );
    // Tight: the hint shares the label's line, which saves a line of height.
    final inline = info.tight && labelText != null && hint != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (inline)
          Padding(
            padding: const EdgeInsets.only(bottom: BrutalMetrics.gapXs),
            child: Row(
              children: <Widget>[
                labelText,
                const SizedBox(width: BrutalMetrics.gapS),
                Expanded(
                  child: Text(
                    hint!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 13, color: c.muted),
                  ),
                ),
              ],
            ),
          )
        else if (labelText != null)
          Padding(
            padding: const EdgeInsets.only(bottom: BrutalMetrics.gapXs),
            child: labelText,
          ),
        child,
        if (hintText != null && !inline) ...<Widget>[const SizedBox(height: BrutalMetrics.gapXs), hintText],
      ],
    );
  }
}

/// The headline and the line under it at the top of a page of rows (Support, the first-run
/// intro). The headline and the body get smaller as the tier does; a shorter body can stand in
/// for the full one when the page is short of height.
class FitHeader extends StatelessWidget {
  const FitHeader({super.key, required this.info, required this.headline, required this.body, this.bodyShort, this.bodyTiny});

  final FitInfo info;
  final String headline;
  final String body;

  /// Used on a compact page, and [bodyTiny] on a tight one; each falls back to the next longer.
  final String? bodyShort;
  final String? bodyTiny;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final top = info.roomy ? BrutalMetrics.gapXl : BrutalMetrics.gapM;
    final bottom = info.roomy ? BrutalMetrics.gapL : BrutalMetrics.gapM;
    final text = info.roomy ? body : (info.tight ? (bodyTiny ?? bodyShort ?? body) : (bodyShort ?? body));
    return Padding(
      padding: EdgeInsets.fromLTRB(BrutalMetrics.gapL, top, BrutalMetrics.gapL, bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              headline.toUpperCase(),
              style: TextStyle(
                fontFamily: BrutalFonts.display,
                fontSize: info.roomy ? BrutalType.headline : (info.tight ? 24 : 28),
                height: 1.05,
                color: c.ink,
              ),
            ),
          ),
          SizedBox(height: info.roomy ? BrutalMetrics.gapM : BrutalMetrics.gapS),
          Text(
            text,
            style: TextStyle(
              fontFamily: BrutalFonts.mono,
              fontSize: info.roomy ? BrutalType.body : 13,
              height: info.roomy ? BrutalType.bodyHeight : 1.4,
              color: c.muted,
            ),
          ),
        ],
      ),
    );
  }
}
