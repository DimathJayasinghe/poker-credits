import 'package:flutter/material.dart';
import 'package:poker_credits/model/app_settings.dart';
import 'package:poker_credits/provider/services.dart';
import 'package:poker_credits/provider/settings_provider.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/app_shell.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_credits/widget/brutal/brutal_dialog.dart';
import 'package:poker_credits/widget/brutal/brutal_row.dart';
import 'package:poker_credits/widget/brutal/brutal_segmented.dart';
import 'package:poker_credits/widget/brutal/brutal_switch_row.dart';
import 'package:poker_credits/widget/brutal/brutal_text_field.dart';
import 'package:poker_protocol/poker_protocol.dart';
import 'package:refena_flutter/refena_flutter.dart';

final RegExp _nameRule = RegExp(r'^[A-Za-z0-9 _-]{1,20}$');

/// The Settings destination. Every change is saved at once; nothing needs a Save button.
class SettingsView extends StatefulWidget {
  const SettingsView({super.key, this.onGameForgotten});

  /// Called after the saved game was forgotten, so the home screen stops offering it.
  final VoidCallback? onGameForgotten;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> with Refena {
  late final TextEditingController _name = TextEditingController(text: ref.read(settingsProvider).defaultName);
  bool _nameBad = false;
  bool _hasSavedGame = false;
  String? _notice;
  String _version = '';

  @override
  void initState() {
    super.initState();
    // Two independent reads: a slow version lookup must not hide the saved-game row.
    ensureRef((ref) async {
      final stored = await ref.read(tokenStoreProvider).read();
      if (mounted) setState(() => _hasSavedGame = stored != null);
    });
    ensureRef((ref) async {
      final version = await ref.read(appVersionProvider)();
      if (mounted) setState(() => _version = version);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _change(AppSettings Function(AppSettings) change) => ref.notifier(settingsProvider).update(change);

  void _nameChanged(String value) {
    final trimmed = value.trim();
    final valid = trimmed.isEmpty || _nameRule.hasMatch(trimmed);
    setState(() => _nameBad = !valid);
    if (valid) _change((s) => s.copyWith(defaultName: trimmed));
  }

  Future<void> _forget() async {
    final confirmed = await showBrutalDialog<bool>(
      context: context,
      title: Strings.forgetTitle,
      content: Text(Strings.forgetBody, style: TextStyle(color: BrutalTheme.of(context).colors.ink)),
      actions: <Widget>[
        BrutalButton(label: Strings.cancel, onPressed: () => Navigator.of(context).pop(false)),
        BrutalButton(label: Strings.forgetConfirm, kind: BrutalButtonKind.danger, onPressed: () => Navigator.of(context).pop(true)),
      ],
    );
    if (confirmed != true || !mounted) return;
    await ref.read(tokenStoreProvider).clear();
    if (!mounted) return;
    setState(() {
      _hasSavedGame = false;
      _notice = Strings.forgetDone;
    });
    widget.onGameForgotten?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final settings = context.ref.watch(settingsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const AppTopBar(title: Strings.settingsTitle),
        Expanded(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const _Section(Strings.sectionAppearance),
                    Padding(
                      padding: const EdgeInsets.all(BrutalMetrics.gapM),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            Strings.themeLabel,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: c.ink),
                          ),
                          const SizedBox(height: BrutalMetrics.gapS),
                          BrutalSegmented<ThemeChoice>(
                            semanticLabel: Strings.themeLabel,
                            value: settings.theme,
                            options: const <(ThemeChoice, String)>[
                              (ThemeChoice.system, Strings.themeSystem),
                              (ThemeChoice.light, Strings.themeLight),
                              (ThemeChoice.dark, Strings.themeDark),
                            ],
                            onChanged: (v) => _change((s) => s.copyWith(theme: v)),
                          ),
                        ],
                      ),
                    ),
                    BrutalSwitchRow(
                      label: Strings.textureLabel,
                      caption: Strings.textureCaption,
                      value: settings.texture,
                      onChanged: (v) => _change((s) => s.copyWith(texture: v)),
                    ),
                    const _Section(Strings.sectionTable),
                    BrutalSwitchRow(
                      label: Strings.soundLabel,
                      caption: Strings.soundCaption,
                      value: settings.sound,
                      onChanged: (v) => _change((s) => s.copyWith(sound: v)),
                    ),
                    BrutalSwitchRow(
                      label: Strings.vibrationLabel,
                      caption: Strings.vibrationCaption,
                      value: settings.vibration,
                      onChanged: (v) => _change((s) => s.copyWith(vibration: v)),
                    ),
                    BrutalSwitchRow(
                      label: Strings.keepAwakeLabel,
                      caption: Strings.keepAwakeCaption,
                      value: settings.keepAwake,
                      onChanged: (v) => _change((s) => s.copyWith(keepAwake: v)),
                    ),
                    const _Section(Strings.sectionYou),
                    Padding(
                      padding: const EdgeInsets.all(BrutalMetrics.gapM),
                      child: BrutalTextField(
                        label: Strings.defaultNameLabel,
                        hintText: Strings.defaultNameHint,
                        controller: _name,
                        maxLength: 20,
                        onChanged: _nameChanged,
                        errorText: _nameBad ? Strings.nameInvalid : null,
                      ),
                    ),
                    const _Section(Strings.sectionData),
                    BrutalRow(
                      label: Strings.forgetGame,
                      caption: _notice ?? (_hasSavedGame ? Strings.forgetGameCaption : Strings.forgetGameNothing),
                      onTap: _hasSavedGame ? _forget : null,
                    ),
                    const _Section(Strings.sectionAbout),
                    _Fact(Strings.versionLabel, _version.isEmpty ? '-' : _version),
                    const _Fact(Strings.protocolLabel, 'v$protocolVersion'),
                    BrutalRow(
                      label: Strings.licences,
                      onTap: () => showLicensePage(context: context, applicationName: Strings.appName, applicationVersion: _version),
                    ),
                    const SizedBox(height: BrutalMetrics.gapXl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A caption cell that starts a group of settings.
class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return Semantics(
      header: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM, vertical: BrutalMetrics.gapS),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(
            top: BorderSide(color: c.line, width: BrutalMetrics.border),
            bottom: BorderSide(color: c.line, width: BrutalMetrics.border),
          ),
        ),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 2, color: c.muted),
        ),
      ),
    );
  }
}

/// A read-only line: label left, value right.
class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM, vertical: BrutalMetrics.gapM),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: c.line, width: BrutalMetrics.border),
          ),
        ),
        // A Wrap, so a long value drops under its label at large text sizes instead of overflowing.
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: BrutalMetrics.gapM,
          runSpacing: BrutalMetrics.gapXs,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: c.ink),
            ),
            Text(value, style: TextStyle(fontSize: 14, color: c.muted)),
          ],
        ),
      ),
    );
  }
}
