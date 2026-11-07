import 'package:flutter/material.dart';
import 'package:poker_credits/model/app_settings.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_credits/widget/brutal/brutal_text_field.dart';
import 'package:poker_credits/widget/brutal/fit_page.dart';

/// Shown once on the first run, after the terms and the intro (and whatever tour or lesson the
/// player took) and before Home: asks for the name other players see, so it is filled in on every
/// host, join and solo form from then on. Skipping is one tap and never blocks anything; the name
/// can always be set later in Settings.
class NamePage extends StatefulWidget {
  const NamePage({super.key, required this.onDone});

  /// Called with the name to keep, or `null` when the player skipped.
  final ValueChanged<String?> onDone;

  @override
  State<NamePage> createState() => _NamePageState();
}

class _NamePageState extends State<NamePage> {
  final TextEditingController _name = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    setState(() => _submitted = true);
    final name = _name.text.trim();
    if (AppSettings.isValidName(name)) widget.onDone(name);
  }

  @override
  Widget build(BuildContext context) {
    return FitPage(
      title: Strings.nameStepTitle,
      maxWidth: 640,
      compactBelow: 700,
      tightBelow: 520,
      padding: EdgeInsets.zero,
      footer: (context, info) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          BrutalButton(
            label: Strings.nameStepSave,
            kind: BrutalButtonKind.primary,
            heavy: true,
            minHeight: info.roomy ? BrutalMetrics.tapPlayer : 52,
            onPressed: _save,
          ),
          SizedBox(height: info.gap),
          BrutalButton(label: Strings.nameStepSkip, onPressed: () => widget.onDone(null)),
        ],
      ),
      builder: (context, info) {
        final c = BrutalTheme.of(context).colors;
        final field = Padding(
          padding: EdgeInsets.symmetric(horizontal: BrutalMetrics.gapL, vertical: info.gap),
          child: BrutalTextField(
            label: Strings.hostName,
            controller: _name,
            maxLength: 20,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) {
              if (_submitted) setState(() {});
            },
            onSubmitted: (_) => _save(),
            errorText: _submitted && !AppSettings.isValidName(_name.text) ? Strings.nameInvalid : null,
          ),
        );
        final header = FitHeader(info: info, headline: Strings.nameStepHeadline, body: Strings.nameStepBody, bodyShort: Strings.nameStepBodyShort);
        if (info.sideBySide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: header),
              Expanded(child: field),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            header,
            Container(height: BrutalMetrics.border, color: c.line),
            field,
          ],
        );
      },
    );
  }
}
