import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:poker_credits/model/walkthrough.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/app_shell.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_credits/widget/brutal/paper_backdrop.dart';
import 'package:poker_credits/widget/walkthrough/step_art.dart';

/// A skippable, swipeable walkthrough: one picture, one title and a few sentences per step.
/// Pops with a [WalkthroughEnd] when the player finishes or skips (or leaves with the back
/// gesture, which counts as skipping).
class WalkthroughPage extends StatefulWidget {
  const WalkthroughPage({super.key, required this.title, required this.steps, this.followUp}) : assert(steps.length > 0);

  final String title;
  final List<WalkthroughStep> steps;

  /// Offered on the last step, above Done.
  final WalkthroughFollowUp? followUp;

  @override
  State<WalkthroughPage> createState() => _WalkthroughPageState();
}

class _WalkthroughPageState extends State<WalkthroughPage> {
  final PageController _pages = PageController();
  int _index = 0;

  bool get _last => _index == widget.steps.length - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int to) {
    final target = to.clamp(0, widget.steps.length - 1);
    if (target == _index) return;
    _pages.animateToPage(target, duration: BrutalTheme.duration(context, BrutalMetrics.base), curve: Curves.easeOut);
  }

  void _end(WalkthroughEnd how) => Navigator.of(context).pop(how);

  /// Replaces this walkthrough with the follow-up one, so leaving it returns to where this was opened.
  void _followUp() {
    final next = widget.followUp;
    if (next == null) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<WalkthroughEnd>(
        builder: (_) => WalkthroughPage(title: next.title, steps: next.steps),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final total = widget.steps.length;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _end(WalkthroughEnd.skipped);
      },
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => _last ? _end(WalkthroughEnd.finished) : _go(_index + 1),
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go(_index - 1),
          const SingleActivator(LogicalKeyboardKey.escape): () => _end(WalkthroughEnd.skipped),
        },
        child: Focus(
          autofocus: true,
          child: PaperScaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AppTopBar(
                  title: widget.title,
                  onBack: () => _end(WalkthroughEnd.skipped),
                  actions: <Widget>[
                    TopBarCell(
                      semanticLabel: Strings.walkSkip,
                      width: 96,
                      onTap: () => _end(WalkthroughEnd.skipped),
                      child: Text(
                        Strings.walkSkip.toUpperCase(),
                        style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.5, color: c.ink),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      // A phone on its side has width and no height: the buttons move to a pane
                      // beside the step instead of sitting under it.
                      final screen = MediaQuery.sizeOf(context);
                      final side = screen.width >= 600 && screen.height < 460;
                      final footer = _Footer(
                        index: _index,
                        total: total,
                        pane: side,
                        onBack: _index == 0 ? null : () => _go(_index - 1),
                        onNext: _last ? () => _end(WalkthroughEnd.finished) : () => _go(_index + 1),
                        last: _last,
                        followUpLabel: _last ? widget.followUp?.label : null,
                        onFollowUp: _followUp,
                      );
                      final pages = PageView.builder(
                        controller: _pages,
                        itemCount: total,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (context, i) => _StepPage(step: widget.steps[i], position: i + 1, total: total, side: side),
                      );
                      if (side) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Expanded(child: pages),
                            SizedBox(width: (box.maxWidth * 0.34).clamp(220.0, 320.0), child: footer),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Expanded(child: pages),
                          footer,
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepPage extends StatelessWidget {
  const _StepPage({required this.step, required this.position, required this.total, required this.side});

  final WalkthroughStep step;
  final int position;
  final int total;
  final bool side;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final height = MediaQuery.sizeOf(context).height / (textScale < 1 ? 1 : textScale);
    final roomy = !side && height >= 700;
    final text = Padding(
      padding: EdgeInsets.fromLTRB(
        BrutalMetrics.gapL,
        roomy ? BrutalMetrics.gapL : BrutalMetrics.gapM,
        BrutalMetrics.gapL,
        roomy ? BrutalMetrics.gapM : BrutalMetrics.gapS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            Strings.walkStep(position, total).toUpperCase(),
            style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 2, color: c.muted),
          ),
          SizedBox(height: roomy ? BrutalMetrics.gapS : BrutalMetrics.gapXs),
          Semantics(
            header: true,
            child: Text(
              step.title.toUpperCase(),
              style: TextStyle(
                fontFamily: BrutalFonts.display,
                fontSize: roomy ? BrutalType.headline : (side ? 22 : (height >= 560 ? 28 : 24)),
                height: 1.05,
                color: c.ink,
              ),
            ),
          ),
          SizedBox(height: roomy ? BrutalMetrics.gapM : BrutalMetrics.gapS),
          Text(
            step.body,
            style: TextStyle(
              fontFamily: BrutalFonts.mono,
              fontSize: roomy ? BrutalType.bodyLarge : (side ? 13 : BrutalType.body),
              height: roomy ? BrutalType.bodyHeight : 1.4,
              color: c.ink,
            ),
          ),
        ],
      ),
    );
    // The picture takes whatever height the words leave and is left out when that is too little
    // to read it. The strip behind it stays, so a step looks the same with or without it.
    final art = DecoratedBox(
      decoration: BoxDecoration(
        color: c.felt,
        border: Border(
          bottom: BorderSide(color: c.line, width: BrutalMetrics.border),
        ),
      ),
      child: _ArtSlot(
        minHeight: 96,
        child: StepArtView(art: step.art, label: step.artLabel, bare: true),
      ),
    );
    if (side) {
      // Beside the words, and only at the normal text size: bigger text needs the whole width.
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (textScale <= 1.0) Expanded(flex: 2, child: art),
          Expanded(
            flex: 3,
            child: SingleChildScrollView(child: Center(child: text)),
          ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 680, minHeight: box.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(child: art),
                  text,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Holds [child] only when it has at least [minHeight] to be drawn in. It asks for no height of
/// its own, so the words around it decide how much is left.
class _ArtSlot extends SingleChildRenderObjectWidget {
  const _ArtSlot({required this.minHeight, super.child});

  final double minHeight;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderArtSlot(minHeight);

  @override
  void updateRenderObject(BuildContext context, _RenderArtSlot renderObject) => renderObject.minHeight = minHeight;
}

class _RenderArtSlot extends RenderProxyBox {
  _RenderArtSlot(this._minHeight);

  double _minHeight;
  bool _shown = false;

  set minHeight(double value) {
    if (value == _minHeight) return;
    _minHeight = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicHeight(double width) => 0;

  @override
  double computeMaxIntrinsicHeight(double width) => 0;

  @override
  void performLayout() {
    _shown = constraints.maxHeight >= _minHeight && child != null;
    if (_shown) {
      child!.layout(constraints, parentUsesSize: true);
      size = child!.size;
    } else {
      // Laid out at no height, so the tree stays consistent, but neither painted nor described.
      child?.layout(BoxConstraints.tightFor(width: constraints.maxWidth, height: 0));
      size = constraints.constrain(Size(constraints.maxWidth, 0));
    }
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_shown) super.visitChildrenForSemantics(visitor);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_shown) super.paint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => _shown && super.hitTestChildren(result, position: position);
}

/// The progress bar and the Back / Next buttons: along the bottom edge, or in a pane on the right
/// ([pane]) on a phone held on its side.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.index,
    required this.total,
    required this.pane,
    required this.onBack,
    required this.onNext,
    required this.last,
    required this.followUpLabel,
    required this.onFollowUp,
  });

  final int index;
  final int total;
  final bool pane;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final bool last;
  final String? followUpLabel;
  final VoidCallback onFollowUp;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final roomy = !pane && MediaQuery.sizeOf(context).height / (textScale < 1 ? 1 : textScale) >= 700;
    final button = roomy ? BrutalMetrics.tapPlayer : 52.0;
    final pad = roomy ? BrutalMetrics.gapM : 12.0;
    final line = BorderSide(color: c.line, width: BrutalMetrics.border);
    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // One cell per step; the ones reached are filled.
          Semantics(
            label: Strings.walkStep(index + 1, total),
            excludeSemantics: true,
            child: Row(
              children: <Widget>[
                for (var i = 0; i < total; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: i <= index ? c.ink : Colors.transparent,
                        border: Border.all(color: c.line, width: 1),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: pad),
          if (followUpLabel != null) ...<Widget>[
            BrutalButton(label: followUpLabel!, minHeight: button, onPressed: onFollowUp),
            const SizedBox(height: BrutalMetrics.gapS),
          ],
          Row(
            children: <Widget>[
              Expanded(
                child: BrutalButton(label: Strings.back, minHeight: button, onPressed: onBack),
              ),
              SizedBox(width: pad),
              Expanded(
                flex: 2,
                child: BrutalButton(
                  label: last ? Strings.walkDone : Strings.walkNext,
                  kind: BrutalButtonKind.primary,
                  heavy: true,
                  minHeight: button,
                  onPressed: onNext,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return Container(
      decoration: BoxDecoration(
        border: pane ? Border(left: line) : Border(top: line),
      ),
      padding: EdgeInsets.all(pad),
      child: pane ? Center(child: SingleChildScrollView(child: content)) : Center(child: content),
    );
  }
}
