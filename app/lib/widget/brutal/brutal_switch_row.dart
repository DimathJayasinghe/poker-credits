import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';

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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM, vertical: BrutalMetrics.gapS),
          decoration: BoxDecoration(
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
                child: ColoredBox(color: value ? c.paper : c.ink, child: const SizedBox.square(dimension: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
