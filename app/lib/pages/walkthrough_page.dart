import 'package:flutter/material.dart';
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
  const WalkthroughPage({super.key, required this.title, required this.steps}) : assert(steps.length > 0);

  final String title;
  final List<WalkthroughStep> steps;

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
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: total,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) => _StepPage(step: widget.steps[i], position: i + 1, total: total),
                  ),
                ),
                _Footer(
                  index: _index,
                  total: total,
                  onBack: _index == 0 ? null : () => _go(_index - 1),
                  onNext: _last ? () => _end(WalkthroughEnd.finished) : () => _go(_index + 1),
                  last: _last,
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
  const _StepPage({required this.step, required this.position, required this.total});

  final WalkthroughStep step;
  final int position;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final height = MediaQuery.sizeOf(context).height;
    // The picture takes a third of the screen, never less than 170 or more than 300 px, so the text
    // below it keeps most of a short screen.
    final artHeight = (height * 0.34).clamp(170.0, 300.0);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                height: artHeight,
                child: StepArtView(art: step.art, label: step.artLabel),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(BrutalMetrics.gapL, BrutalMetrics.gapL, BrutalMetrics.gapL, BrutalMetrics.gapM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      Strings.walkStep(position, total).toUpperCase(),
                      style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 2, color: c.muted),
                    ),
                    const SizedBox(height: BrutalMetrics.gapS),
                    Semantics(
                      header: true,
                      child: Text(
                        step.title.toUpperCase(),
                        style: TextStyle(fontFamily: BrutalFonts.display, fontSize: 36, height: 1.05, color: c.ink),
                      ),
                    ),
                    const SizedBox(height: BrutalMetrics.gapM),
                    Text(step.body, style: TextStyle(fontSize: 16, height: 1.5, color: c.ink)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The progress bar and the Back / Next buttons.
class _Footer extends StatelessWidget {
  const _Footer({required this.index, required this.total, required this.onBack, required this.onNext, required this.last});

  final int index;
  final int total;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: c.line, width: BrutalMetrics.border),
        ),
      ),
      padding: const EdgeInsets.all(BrutalMetrics.gapM),
      child: Center(
        child: ConstrainedBox(
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
              const SizedBox(height: BrutalMetrics.gapM),
              Row(
                children: <Widget>[
                  Expanded(
                    child: BrutalButton(label: Strings.back, minHeight: BrutalMetrics.tapPlayer, onPressed: onBack),
                  ),
                  const SizedBox(width: BrutalMetrics.gapM),
                  Expanded(
                    flex: 2,
                    child: BrutalButton(
                      label: last ? Strings.walkDone : Strings.walkNext,
                      kind: BrutalButtonKind.primary,
                      heavy: true,
                      minHeight: BrutalMetrics.tapPlayer,
                      onPressed: onNext,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
