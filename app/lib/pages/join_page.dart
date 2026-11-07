import 'dart:async';

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
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/describe.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/brutal_banner.dart';
import 'package:poker_credits/widget/brutal/fit_page.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_credits/widget/brutal/brutal_card.dart';
import 'package:poker_credits/widget/brutal/brutal_row.dart';
import 'package:poker_credits/widget/brutal/brutal_text_field.dart';
import 'package:poker_protocol/poker_protocol.dart';
import 'package:refena_flutter/refena_flutter.dart';

final RegExp _nameRule = RegExp(r'^[A-Za-z0-9 _-]{1,20}$');

/// Join a game: type the room code and a name; the app finds the host on the Wi-Fi by the code.
/// Scanning the host's QR code skips the search, and the host address can still be typed when the
/// network does not let the search through. A rejected join (bad name, full table) stays on this
/// page so it can be fixed and retried.
class JoinPage extends StatefulWidget {
  const JoinPage({super.key, this.initial, this.scanSupported});

  /// Pre-filled from a scanned code or a link.
  final JoinLink? initial;

  /// Whether the phone can scan a QR code; the platform decides when this is null.
  final bool? scanSupported;

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

  /// The scan for open games on the Wi-Fi, and what it has found so far.
  LobbyBrowse? _browse;
  StreamSubscription<List<DiscoveredLobby>>? _browseUpdates;
  List<DiscoveredLobby> _nearby = const <DiscoveredLobby>[];
  bool _scanning = false;
  bool _scanStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Once, and not when the room code came from a scanned code or a link: that player knows
    // where they are going.
    if (_scanStarted) return;
    _scanStarted = true;
    if (widget.initial == null && ref.read(joinProvider).canFind) _scanNearby();
  }

  void _scanNearby() {
    _browse?.cancel();
    unawaited(_browseUpdates?.cancel());
    final browse = ref.read(joinProvider).browse();
    _browse = browse;
    _nearby = const <DiscoveredLobby>[];
    _scanning = true;
    _browseUpdates = browse.lobbies.listen((lobbies) {
      if (mounted && _browse == browse) setState(() => _nearby = lobbies);
    });
    unawaited(
      browse.done.then((_) {
        if (mounted && _browse == browse) setState(() => _scanning = false);
      }),
    );
  }

  /// Fills the form from an open game; the player adds a name and presses Join.
  void _pickNearby(DiscoveredLobby lobby) {
    setState(() {
      _code.text = lobby.roomCode;
      _known = JoinLink(hostAndPort: lobby.hostAndPort, roomCode: lobby.roomCode, fingerprint: lobby.fingerprint);
      _notFound = false;
      _showAddress = false;
    });
  }

  @override
  void dispose() {
    _browse?.cancel();
    unawaited(_browseUpdates?.cancel());
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

  /// A message about a field goes away as soon as the field is fixed, not at the next press of Join.
  void _recheck(String _) {
    if (_submitted) setState(() {});
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
      // The pin only goes with the address it came with: a typed address starts without one.
      final pin = known != null && known.hostAndPort == address && known.roomCode == code ? known.fingerprint : null;
      _connect(
        JoinLink(hostAndPort: address, roomCode: code, fingerprint: pin),
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
        JoinLink(hostAndPort: found.hostAndPort, roomCode: code, fingerprint: found.fingerprint),
        spectator: spectator,
      );
    });
  }

  void _connect(JoinLink link, {required bool spectator}) {
    setState(() {
      _attempting = true;
      _spectator = spectator;
    });
    unawaited(ref.read(joinProvider).join(link: link, name: _name.text, spectator: spectator));
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

  Widget _nearbyCard(bool busy) {
    final c = BrutalTheme.of(context).colors;
    final picked = JoinLink.normalizeRoomCode(_code.text);
    return BrutalCard(
      header: Strings.nearbyTitle,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final lobby in _nearby)
            BrutalRow(
              label: lobby.hostName.isEmpty ? lobby.roomCode : lobby.hostName,
              caption: Strings.nearbySeats(lobby.roomCode, lobby.playerCount, lobby.maxPlayers, virtual: lobby.isVirtual),
              emphasis: picked == lobby.roomCode,
              onTap: busy ? null : () => _pickNearby(lobby),
            ),
          Padding(
            padding: const EdgeInsets.all(BrutalMetrics.gapM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (_scanning && _nearby.isEmpty)
                  Text(
                    Strings.nearbyLooking.toUpperCase(),
                    style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 13, color: c.muted),
                  )
                else if (!_scanning && _nearby.isEmpty)
                  Text(Strings.nearbyNone, style: TextStyle(fontSize: 14, height: 1.4, color: c.muted))
                else if (_nearby.isNotEmpty)
                  Text(Strings.nearbyPick, style: TextStyle(fontSize: 13, height: 1.4, color: c.muted)),
                if (!_scanning) ...<Widget>[
                  const SizedBox(height: BrutalMetrics.gapM),
                  BrutalButton(label: Strings.nearbyAgain, onPressed: busy ? null : () => setState(_scanNearby)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The games found on the Wi-Fi, drawn without a frame for a page that is short of height. The
  /// search button sits on the status line instead of under it.
  Widget _nearbyFlat(FitInfo info, bool busy) {
    final c = BrutalTheme.of(context).colors;
    final picked = JoinLink.normalizeRoomCode(_code.text);
    final status = _scanning && _nearby.isEmpty
        ? Text(
            Strings.nearbyLooking.toUpperCase(),
            style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 13, color: c.muted),
          )
        : Text(
            _nearby.isEmpty ? Strings.nearbyNoneShort : Strings.nearbyPick,
            style: TextStyle(fontSize: 13, height: 1.3, color: c.muted),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: BrutalMetrics.gapXs),
          child: Text(
            Strings.nearbyTitle.toUpperCase(),
            style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2, color: c.ink),
          ),
        ),
        for (final lobby in _nearby)
          BrutalRow(
            label: lobby.hostName.isEmpty ? lobby.roomCode : lobby.hostName,
            caption: Strings.nearbySeats(lobby.roomCode, lobby.playerCount, lobby.maxPlayers, virtual: lobby.isVirtual),
            emphasis: picked == lobby.roomCode,
            dense: true,
            onTap: busy ? null : () => _pickNearby(lobby),
          ),
        Row(
          children: <Widget>[
            Expanded(child: status),
            if (!_scanning) ...<Widget>[
              const SizedBox(width: BrutalMetrics.gapS),
              BrutalButton(label: Strings.nearbyAgain, onPressed: busy ? null : () => setState(_scanNearby)),
            ],
          ],
        ),
      ],
    );
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

    final scanSupported = widget.scanSupported ?? qrScanSupported;

    return FitPage(
      title: Strings.joinTitle,
      onBack: () => Navigator.of(context).maybePop(),
      compactBelow: 760,
      tightBelow: 560,
      footer: (context, info) {
        final height = info.roomy ? BrutalMetrics.tapPlayer : 52.0;
        if (busy) return BrutalButton(label: Strings.cancel, kind: BrutalButtonKind.danger, minHeight: height, onPressed: _cancel);
        final join = BrutalButton(
          label: Strings.joinButton,
          kind: BrutalButtonKind.primary,
          heavy: true,
          minHeight: height,
          onPressed: () => _join(spectator: false),
        );
        final watch = BrutalButton(label: Strings.watchButton, minHeight: height, onPressed: () => _join(spectator: true));
        if (info.sideBySide) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              join,
              SizedBox(height: info.gap),
              watch,
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(flex: 3, child: join),
              SizedBox(width: info.gap),
              Expanded(flex: 2, child: watch),
            ],
          ),
        );
      },
      builder: (context, info) {
        Widget gap() => SizedBox(height: info.gap);
        final banner = searching
            ? const BrutalBanner(message: Strings.searchingHost)
            : problem != null
            ? BrutalBanner(message: problem, kind: connecting ? BrutalBannerKind.warning : BrutalBannerKind.error)
            : connecting
            ? const BrutalBanner(message: Strings.connecting)
            : null;
        final nearby = !canFind ? null : (info.roomy ? _nearbyCard(busy) : _nearbyFlat(info, busy));
        final scan = !scanSupported
            ? null
            : BrutalButton(
                label: Strings.scanQr,
                kind: BrutalButtonKind.info,
                minHeight: info.roomy ? BrutalMetrics.tapPlayer : BrutalMetrics.tap,
                onPressed: busy ? null : _scan,
              );
        final code = BrutalTextField(
          label: Strings.joinCode,
          controller: _code,
          maxLength: 4,
          textCapitalization: TextCapitalization.characters,
          onChanged: _recheck,
          errorText: _submitted && JoinLink.normalizeRoomCode(_code.text) == null ? Strings.codeInvalid : null,
        );
        final name = BrutalTextField(
          label: Strings.joinName,
          controller: _name,
          maxLength: 20,
          onChanged: _recheck,
          errorText: _submitted && !_nameRule.hasMatch(_name.text.trim()) ? Strings.nameInvalid : null,
        );
        final address = !showAddress
            ? null
            : BrutalTextField(
                label: Strings.joinAddress,
                controller: _address,
                keyboardType: TextInputType.url,
                onChanged: _recheck,
                errorText: _submitted && _address.text.trim().isNotEmpty && JoinLink.normalizeAddress(_address.text) == null
                    ? Strings.addressInvalid
                    : null,
              );
        final toggle = !canFind
            ? null
            : BrutalButton(
                label: showAddress ? Strings.useCode : Strings.useAddress,
                onPressed: busy ? null : () => setState(() => _showAddress = !showAddress),
              );
        // The room code is four characters: it shares a line with the name instead of taking one.
        final codeAndName = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(flex: 2, child: code),
            SizedBox(width: info.gap),
            Expanded(flex: 3, child: name),
          ],
        );
        final form = FitSection(
          info: info,
          label: info.roomy ? Strings.joinGame : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (info.sideBySide) ...<Widget>[code, gap(), name] else codeAndName,
              if (address != null) ...<Widget>[gap(), address],
            ],
          ),
        );
        final above = <Widget>[?banner, ?nearby, ?scan];
        final below = <Widget>[form, ?toggle];
        Widget stack(List<Widget> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (var i = 0; i < items.length; i++) ...<Widget>[if (i > 0) gap(), items[i]],
          ],
        );
        if (info.sideBySide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: stack(above)),
              SizedBox(width: info.pad),
              Expanded(child: stack(below)),
            ],
          );
        }
        return stack(<Widget>[...above, ...below]);
      },
    );
  }
}
