import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/describe.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_protocol/poker_protocol.dart';

/// Strip with the latest actions, newest first.
class ActionTicker extends StatelessWidget {
  const ActionTicker({super.key, required this.actions, this.visible = 4, this.compact = false});

  final List<ActionPerformed> actions;

  /// How many recent actions to show.
  final int visible;

  /// Smaller type and padding, for a short screen.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final recent = actions.reversed.take(visible).toList();
    final text = recent.isEmpty ? Strings.noActionsYet : recent.map(describeAction).join('   |   ');
    return Semantics(
      liveRegion: true,
      label: recent.isEmpty ? Strings.noActionsYet : describeAction(recent.first),
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM, vertical: compact ? BrutalMetrics.gapXs : BrutalMetrics.gapS),
        decoration: BoxDecoration(
          color: c.paper,
          border: Border(
            top: BorderSide(color: c.ink, width: BrutalMetrics.border),
          ),
        ),
        child: Text(
          text.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: compact ? 14 : 16, letterSpacing: 0.5, color: c.ink),
        ),
      ),
    );
  }
}
