import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/widget/brutal/brutal_pressable.dart';

/// A setting you turn on or off: label and one-line explanation on the left, a square switch on
/// the right. The whole row is the tap target.
class BrutalSwitchRow extends StatelessWidget {
  const BrutalSwitchRow({super.key, required this.label, required this.value, required this.onChanged, this.caption});

  final String label;
  final String? caption;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return Semantics(
      toggled: value,
      label: caption == null ? label : '$label. $caption',
      excludeSemantics: true,
      onTap: () => onChanged(!value),
      child: BrutalPressable(
        onTap: () => onChanged(!value),
        builder: (context, pressed) => AnimatedContainer(
          duration: BrutalTheme.duration(context, BrutalMetrics.fast),
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM, vertical: BrutalMetrics.gapS),
          decoration: BoxDecoration(
            color: pressed ? c.ink.withValues(alpha: 0.08) : c.paper.withValues(alpha: 0),
            border: Border(
              bottom: BorderSide(color: c.line, width: BrutalMetrics.border),
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      label,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: c.ink),
                    ),
                    if (caption != null) Text(caption!, style: TextStyle(fontSize: 12, height: 1.3, color: c.muted)),
                  ],
                ),
              ),
              const SizedBox(width: BrutalMetrics.gapM),
              AnimatedContainer(
                duration: BrutalTheme.duration(context, BrutalMetrics.fast),
                width: 52,
                height: 28,
                padding: const EdgeInsets.all(3),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: value ? c.ink : c.surface,
                  border: Border.all(color: c.line, width: BrutalMetrics.border),
                ),
                child: AnimatedContainer(
                  duration: BrutalTheme.duration(context, BrutalMetrics.fast),
                  width: pressed ? 24 : 18,
                  height: 18,
                  color: value ? c.paper : c.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
