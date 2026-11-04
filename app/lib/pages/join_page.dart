import 'package:flutter/material.dart';
import 'package:poker_credits/model/join_link.dart';
import 'package:poker_credits/pages/player_page.dart';
import 'package:poker_credits/pages/scan_page.dart';
import 'package:poker_credits/pages/spectator_page.dart';
import 'package:poker_credits/platform/host_finder.dart';
import 'package:poker_credits/platform/qr_scanner.dart';
import 'package:poker_credits/provider/connection_provider.dart';
import 'package:poker_credits/provider/join_provider.dart';
import 'package:poker_credits/provider/settings_provider.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/describe.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/app_shell.dart';
import 'package:poker_credits/widget/brutal/brutal_banner.dart';
import 'package:poker_credits/widget/brutal/paper_backdrop.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_credits/widget/brutal/brutal_card.dart';
import 'package:poker_credits/widget/brutal/brutal_text_field.dart';
import 'package:poker_protocol/poker_protocol.dart';
import 'package:refena_flutter/refena_flutter.dart';

final RegExp _nameRule = RegExp(r'^[A-Za-z0-9 _-]{1,20}$');

/// Join a game: type the room code and a name; the app finds the host on the Wi-Fi by the code.
/// Scanning the host's QR code skips the search, and the host address can still be typed when the
/// network does not let the search through. A rejected join (bad name, full table) stays on this
/// page so it can be fixed and retried.
class JoinPage extends StatefulWidget {
  const JoinPage({super.key, this.initial});

  /// Pre-filled from a scanned code or a link.
  final JoinLink? initial;

  @override
  State<JoinPage> createState() => _JoinPageState();
}

class _JoinPageState extends State<JoinPage> with Refena {
  late final TextEditingController _code = TextEditingController(text: widget.initial?.roomCode ?? '');
  final TextEditingController _address = TextEditingController();
  late final TextEditingController _name = TextEditingController(text: ref.read(settingsProvider).defaultName);

  /// Address from a scanned code or link; used while the room code still matches it.
  late JoinLink? _known = widget.initial;
  bool _submitted = false;
  bool _attempting = false;
  bool _spectator = false;
  bool _handedOff = false;

  /// The address field is shown: by choice, after a search found nothing, or where searching is
  /// impossible (web).
  bool _showAddress = false;
  bool _notFound = false;
  HostSearch? _search;

  @override
  void dispose() {
    _search?.cancel();
    for (final controller in <TextEditingController>[_code, _address, _name]) {
      controller.dispose();
    }
    // Leaving the page while still trying to connect cancels the attempt. When it worked the
    // session lives on in the player or spectator page.
    if (_attempting && !_handedOff) ref.read(joinProvider).leave();
    super.dispose();
  }

  Future<void> _scan() async {
    final link = await Navigator.of(context).push<JoinLink>(MaterialPageRoute<JoinLink>(builder: (_) => const ScanPage()));
    if (link == null || !mounted) return;
    setState(() {
      _code.text = link.roomCode;
      _known = link;
      _notFound = false;
    });
  }

  void _join({required bool spectator}) {
    setState(() {
      _submitted = true;
      _notFound = false;
    });
    final code = JoinLink.normalizeRoomCode(_code.text);
    if (code == null || !_nameRule.hasMatch(_name.text.trim())) return;
    final known = _known;
    final typed = _showAddress ? JoinLink.normalizeAddress(_address.text) : null;
    if (_showAddress && typed == null && _address.text.trim().isNotEmpty) return;
    final String? address = typed ?? (known != null && known.roomCode == code ? known.hostAndPort : null);
    if (address != null) {
      _connect(
        JoinLink(hostAndPort: address, roomCode: code),
        spectator: spectator,
      );
      return;
    }
    final join = ref.read(joinProvider);
    if (!join.canFind) {
      setState(() => _showAddress = true);
      return;
    }
    setState(() {
      _spectator = spectator;
      _search = join.find(code);
    });
    final search = _search!;
    search.result.then((found) {
      if (!mounted || _search != search) return;
      setState(() => _search = null);
      if (found == null) {
        setState(() {
          _notFound = true;
          _showAddress = true;
        });
        return;
      }
      _connect(
        JoinLink(hostAndPort: found.hostAndPort, roomCode: code),
        spectator: spectator,
      );
    });
  }

  void _connect(JoinLink link, {required bool spectator}) {
    setState(() {
      _attempting = true;
      _spectator = spectator;
    });
    ref.read(joinProvider).join(link: link, name: _name.text, spectator: spectator);
  }

  Future<void> _cancel() async {
    final search = _search;
    if (search != null) {
      search.cancel();
      setState(() => _search = null);
      return;
    }
    await ref.read(joinProvider).leave();
    if (mounted) setState(() => _attempting = false);
  }

  /// Opens the player or spectator page once the server has sent the first snapshot.
  void _handOffWhenReady(SessionState session) {
    if (!_attempting || _handedOff) return;
    if (!session.link.isLive || session.room.view == null) return;
    _handedOff = true;
    final watch = _spectator || session.role == Role.spectator;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => watch ? const SpectatorPage() : const PlayerPage()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.ref.watch(sessionProvider);
    _handOffWhenReady(session);

    String? problem;
    var connecting = false;
    if (_attempting) {
      final error = session.room.lastError;
      final failure = session.link.failure;
      if (error != null) {
        problem = errorText(error.code);
      } else if (failure != null) {
        problem = linkFailureText(failure);
      } else if (!session.link.isLive) {
        connecting = true;
        if (session.link.attempt >= 2) problem = Strings.cannotReach;
      }
    }
    final searching = _search != null;
    if (_notFound && problem == null) problem = Strings.hostNotFound;
    final busy = searching || _attempting && problem == null || connecting;
    final canFind = ref.read(joinProvider).canFind;
    final showAddress = _showAddress || !canFind;

    return PaperScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTopBar(title: Strings.joinTitle, onBack: () => Navigator.of(context).maybePop()),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(BrutalMetrics.gapM),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (searching) ...<Widget>[
                        const BrutalBanner(message: Strings.searchingHost),
                        const SizedBox(height: BrutalMetrics.gapM),
                      ] else if (problem != null) ...<Widget>[
                        BrutalBanner(message: problem, kind: connecting ? BrutalBannerKind.warning : BrutalBannerKind.error),
                        const SizedBox(height: BrutalMetrics.gapM),
                      ] else if (connecting) ...<Widget>[
                        const BrutalBanner(message: Strings.connecting),
                        const SizedBox(height: BrutalMetrics.gapM),
                      ],
                      if (qrScanSupported) ...<Widget>[
                        BrutalButton(
                          label: Strings.scanQr,
                          kind: BrutalButtonKind.info,
                          minHeight: BrutalMetrics.tapPlayer,
                          onPressed: busy ? null : _scan,
                        ),
                        const SizedBox(height: BrutalMetrics.gapM),
                      ],
                      BrutalCard(
                        header: Strings.joinGame,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            BrutalTextField(
                              label: Strings.joinCode,
                              controller: _code,
                              maxLength: 4,
                              textCapitalization: TextCapitalization.characters,
                              errorText: _submitted && JoinLink.normalizeRoomCode(_code.text) == null ? Strings.codeInvalid : null,
                            ),
                            const SizedBox(height: BrutalMetrics.gapM),
                            if (showAddress) ...<Widget>[
                              BrutalTextField(
                                label: Strings.joinAddress,
                                controller: _address,
                                keyboardType: TextInputType.url,
                                errorText: _submitted && _address.text.trim().isNotEmpty && JoinLink.normalizeAddress(_address.text) == null
                                    ? Strings.addressInvalid
                                    : null,
                              ),
                              const SizedBox(height: BrutalMetrics.gapM),
                            ],
                            BrutalTextField(
                              label: Strings.joinName,
                              controller: _name,
                              maxLength: 20,
                              errorText: _submitted && !_nameRule.hasMatch(_name.text.trim()) ? Strings.nameInvalid : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: BrutalMetrics.gapL),
                      BrutalButton(
                        label: Strings.joinButton,
                        kind: BrutalButtonKind.primary,
                        heavy: true,
                        minHeight: BrutalMetrics.tapPlayer,
                        onPressed: busy ? null : () => _join(spectator: false),
                      ),
                      const SizedBox(height: BrutalMetrics.gapM),
                      BrutalButton(
                        label: Strings.watchButton,
                        minHeight: BrutalMetrics.tapPlayer,
                        onPressed: busy ? null : () => _join(spectator: true),
                      ),
                      if (canFind) ...<Widget>[
                        const SizedBox(height: BrutalMetrics.gapM),
                        BrutalButton(
                          label: showAddress ? Strings.useCode : Strings.useAddress,
                          onPressed: busy ? null : () => setState(() => _showAddress = !showAddress),
                        ),
                      ],
                      if (busy) ...<Widget>[
                        const SizedBox(height: BrutalMetrics.gapM),
                        BrutalButton(label: Strings.cancel, kind: BrutalButtonKind.danger, onPressed: _cancel),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
