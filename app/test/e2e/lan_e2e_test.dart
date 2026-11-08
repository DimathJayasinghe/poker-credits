// End to end over real sockets (ADR-019): the real Rust server from the native library, real TLS
// 1.3, and the app's own providers, socket client, host finder and certificate pinning. Two or
// three "phones" run in this one process, each with its own state, talking over 127.0.0.1.
//
// What this cannot show: a screen, a real Wi-Fi, a real phone. Those stay in
// docs/RELEASE_CHECKLIST.md. Run with:
//
//   cargo build -p rust_lib_poker_bridge
//   cd app && POKER_BRIDGE_LIB=$PWD/../target/debug/librust_lib_poker_bridge.so fvm flutter test test/e2e
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/model/sound_cues.dart';
import 'package:poker_bridge/poker_bridge.dart';
import 'package:poker_credits/net/connection_state.dart';
import 'package:poker_credits/net/pin.dart';
import 'package:poker_credits/model/hosting.dart';
import 'package:poker_credits/platform/secure_channel.dart';
import 'package:poker_credits/model/join_link.dart';
import 'package:poker_credits/platform/host_finder.dart';
import 'package:poker_credits/platform/token_store.dart';
import 'package:poker_credits/provider/connection_provider.dart';
import 'package:poker_credits/provider/host_provider.dart';
import 'package:poker_credits/provider/join_provider.dart';
import 'package:poker_protocol/poker_protocol.dart';

import 'support/device.dart';

void main() {
  final skip = e2eSkipReason;
  final devices = <Device>[];

  setUpAll(loadLanAddress);

  Device phone(
    String name, {
    Directory? dir,
    MemoryTokenStore? tokens,
    List<String> searchAddresses = const <String>['127.0.0.1'],
    HostFinder Function(HostFinder real)? wrapFinder,
  }) {
    final device = Device(name, dir: dir, tokens: tokens, searchAddresses: searchAddresses, wrapFinder: wrapFinder);
    devices.add(device);
    return device;
  }

  tearDown(() async {
    for (final device in devices.reversed) {
      await device.dispose();
    }
    devices.clear();
    // The next test binds the same fixed port: let the sockets close.
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });

  group('joining', () {
    test('a guest joins by the QR code: encrypted, pinned, seated', () async {
      final host = phone('host');
      final room = await host.host(hostName: 'Dimath');
      expect(room.fingerprint, isNotNull);
      expect(host.session.serverUri, 'wss://127.0.0.1:${room.port}/v1/ws#pin=${room.fingerprint}');

      final ana = phone('ana');
      await ana.joinSeated(Device.qrOf(room), 'Ana');

      expect(ana.session.serverUri, startsWith('wss://'));
      expect(pinOf(Uri.parse(ana.session.serverUri!)), room.fingerprint);
      await eventually('the host sees Ana', () => host.view!.seats.any((s) => s.name == 'Ana'));
      expect(ana.view!.seats.map((s) => s.name), containsAll(<String>['Dimath', 'Ana']));
      expect((await ana.stored)?.serverUri, ana.session.serverUri);
      // Found on the emulator: the host showed every new guest as offline until the next state update.
      await eventually('the host sees Ana as connected', () => host.view!.seats.any((s) => s.name == 'Ana' && s.isConnected));
    }, skip: skip);

    test('the host sees a guest go offline when the guest leaves the app, and come back', () async {
      final host = phone('host');
      final room = await host.host();
      final ana = phone('ana');
      await ana.joinSeated(Device.qrOf(room), 'Ana');
      bool anaOnline() => host.view!.seats.any((s) => s.name == 'Ana' && s.isConnected);
      await eventually('Ana shows online', anaOnline);

      ana.kill();
      await eventually('Ana shows offline once her socket is gone', () => !anaOnline(), timeout: const Duration(seconds: 15));

      final back = phone('ana2', tokens: ana.tokens);
      expect(await back.container.read(joinProvider).restore(), isTrue);
      await eventually('Ana shows online again', anaOnline);
    }, skip: skip);

    test('a guest joins by a typed address: the first certificate is taken and kept', () async {
      final host = phone('host');
      final room = await host.host();
      final ana = phone('ana');
      await ana.joinSeated(Device.qrOf(room, pinned: false), 'Ana');
      expect(pinOf(Uri.parse(ana.session.serverUri!)), room.fingerprint, reason: 'trust on first use, then pinned');
    }, skip: skip);

    test('a guest finds the host by room code and the lobby list, and gets its fingerprint', () async {
      final host = phone('host');
      final room = await host.host(hostName: 'Dimath');
      final ana = phone('ana');

      final started = Stopwatch()..start();
      final found = await ana.container.read(joinProvider).find(room.roomCode).result;
      final searchMs = started.elapsedMilliseconds;
      expect(found, isNotNull, reason: 'the search by code found the host over TLS');
      expect(found!.hostAndPort, '127.0.0.1:${room.port}');
      expect(found.fingerprint, room.fingerprint);

      final lobbies = await ana.container.read(joinProvider).browse().lobbies.firstWhere((l) => l.isNotEmpty).timeout(const Duration(seconds: 5));
      expect(lobbies.any((DiscoveredLobby l) => l.roomCode == room.roomCode && l.fingerprint == room.fingerprint), isTrue);

      final probe = Stopwatch()..start();
      final pin = await ana.finder.fingerprintOf('127.0.0.1:${room.port}');
      // ignore: avoid_print
      print('latency over loopback: search by code $searchMs ms, certificate probe ${probe.elapsedMilliseconds} ms');
      expect(pin, room.fingerprint);
    }, skip: skip);
  });

  group('playing', () {
    test('three phones play a hand over TLS and no chip is lost', () async {
      final host = phone('host');
      final room = await host.host(hostName: 'Dimath');
      final ana = phone('ana');
      final bob = phone('bob');
      await ana.joinSeated(Device.qrOf(room), 'Ana');
      await bob.joinSeated(Device.qrOf(room, pinned: false), 'Bob');
      await eventually('everybody sees three seats', () => <Device>[host, ana, bob].every((d) => (d.view?.seats.length ?? 0) == 3));

      host.container.notifier(sessionProvider).send(const StartHand());
      await eventually('the hand is dealt', () => host.view!.handNumber == 1 && host.view!.phase == WirePhase.preFlop);

      // Whoever is asked folds. The dealer folds, the small blind folds, the big blind wins.
      await eventually('the hand ends', () {
        for (final device in <Device>[host, ana, bob]) {
          device.actFold();
        }
        return host.view!.phase == WirePhase.nextHandPrep;
      }, timeout: const Duration(seconds: 15));

      Map<String, int> chips(Device device) => <String, int>{for (final seat in device.view!.seats) seat.name: seat.chips};
      await eventually(
        'every phone shows the final chips',
        () => chips(ana)['Bob'] == 1005 && chips(bob)['Bob'] == 1005 && chips(host)['Bob'] == 1005,
      );
      expect(chips(host), <String, int>{'Dimath': 1000, 'Ana': 995, 'Bob': 1005}, reason: 'the small blind paid the big blind; no chip is lost');
      expect(chips(ana), chips(host));
      expect(chips(bob), chips(host));

      // Sound effects from the real server's messages: the table's phone plays the table, a guest
      // only its own part, and the winner hears the win.
      expect(host.sound.cues, containsAll(<SoundCue>[SoundCue.shuffle, SoundCue.fold, SoundCue.potWon]));
      expect(bob.sound.cues, contains(SoundCue.win));
      for (final guest in <Device>[ana, bob]) {
        expect(guest.sound.cues, isNot(contains(SoundCue.shuffle)), reason: 'the riffle is the table\'s');
      }
      expect(ana.sound.cues, isNot(contains(SoundCue.potWon)));
      expect(ana.sound.cues, isNot(contains(SoundCue.win)), reason: 'Bob won the pot');
    }, skip: skip);

    test('a spectator watches over TLS and has no seat', () async {
      final host = phone('host');
      final room = await host.host();
      final eve = phone('eve');
      await eve.container.read(joinProvider).join(link: Device.qrOf(room), name: 'Eve', spectator: true);
      await eventually('the spectator sees the table', () => eve.link.isLive && eve.view != null);
      expect(eve.session.isSeated, isFalse);
      expect(eve.view!.seats.map((s) => s.name), <String>['Host']);
    }, skip: skip);
  });

  group('connection loss and recovery', () {
    test('a guest whose socket drops comes back to the same seat, same pin', () async {
      final host = phone('host');
      final room = await host.host();
      final ana = phone('ana');
      await ana.joinSeated(Device.qrOf(room), 'Ana');
      final seatId = ana.session.playerId;
      final uri = ana.session.serverUri;

      ana.container.notifier(sessionProvider).reconnect();
      await eventually('the guest is live again', () => ana.link.isLive && ana.view != null);
      expect(ana.session.isSeated, isTrue);
      expect(ana.session.playerId, seatId);
      expect(ana.session.serverUri, uri);
      expect(host.view!.seats.where((s) => s.name == 'Ana').length, 1, reason: 'resumed, not joined twice');
    }, skip: skip);

    test('the host app is killed and reopened: same certificate, guests resume their seats', () async {
      final dir = Directory.systemTemp.createTempSync('pc-e2e-persist-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final first = phone('host1', dir: dir);
      final room = await first.host(hostName: 'Dimath');
      final ana = phone('ana');
      await ana.joinSeated(Device.qrOf(room), 'Ana');
      final tokens = await first.stored;

      // The process dies: the server stops, nothing is said to the guests.
      await first.server.stop();
      await eventually('the guest notices', () => !ana.link.isLive);

      // Reopened: a new process with the same data folder and the stored session.
      final second = phone('host2', dir: dir);
      await second.tokens.write(tokens!);
      expect(await second.container.notifier(hostProvider).restore(), isTrue);
      expect(second.hosting.room!.fingerprint, room.fingerprint, reason: 'the identity file survived');
      expect(second.hosting.room!.port, room.port);

      await eventually('the host screen is back', () => second.link.isLive && second.view != null);
      await eventually('the guest resumed by itself', () => ana.link.isLive && ana.view != null, timeout: const Duration(seconds: 20));
      expect(ana.session.isSeated, isTrue);
      expect(second.view!.seats.map((s) => s.name), containsAll(<String>['Dimath', 'Ana']));
    }, skip: skip);

    test('the host comes back with a new certificate: the guest stops, keeps its seat data, and does not loop', () async {
      final dir = Directory.systemTemp.createTempSync('pc-e2e-lost-id-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final first = phone('host1', dir: dir);
      final room = await first.host();
      final ana = phone('ana');
      await ana.joinSeated(Device.qrOf(room), 'Ana');
      final guestSession = await ana.stored;
      final hostSession = await first.stored;
      await first.server.stop();

      // The certificate file is gone (cleared data, a reinstall that kept the room files).
      File('${dir.path}/tls-identity.bin').deleteSync();
      final second = phone('host2', dir: dir);
      await second.tokens.write(hostSession!);
      expect(await second.container.notifier(hostProvider).restore(), isTrue);
      expect(second.hosting.room!.fingerprint, isNot(room.fingerprint));
      await eventually('the host screen is back', () => second.link.isLive);

      await eventually(
        'the guest refuses the new certificate',
        () => ana.link.failure == LinkFailure.hostNotTrusted,
        timeout: const Duration(seconds: 20),
      );
      expect(ana.link.phase, LinkPhase.failed);
      expect((await ana.stored)?.sessionToken, guestSession!.sessionToken, reason: 'the guest keeps its credentials');
      final attempts = ana.link.attempt;
      await staysTrue('the guest does not retry', () => ana.link.phase == LinkPhase.failed && ana.link.attempt == attempts);
      expect(second.view!.seats.where((s) => s.name == 'Ana').length, 1, reason: 'nothing was sent to the new certificate');
    }, skip: skip);

    test('the host switches apps and the server is gone: coming back restarts it on the same port and pin', () async {
      final host = phone('host');
      final room = await host.host();
      final ana = phone('ana');
      await ana.joinSeated(Device.qrOf(room), 'Ana');

      await host.server.stop();
      await eventually('everybody notices', () => !ana.link.isLive && !host.link.isLive);
      await host.container.notifier(hostProvider).onForeground();
      expect(host.server.fingerprint, room.fingerprint);
      expect(host.server.port, room.port);
      await eventually('the host is live again', () => host.link.isLive && host.view != null, timeout: const Duration(seconds: 20));
      await eventually('the guest is live again', () => ana.link.isLive && ana.view != null, timeout: const Duration(seconds: 20));
      expect(ana.session.isSeated, isTrue);
    }, skip: skip);
  });

  group('who the guest will talk to', () {
    test('a QR code with the wrong fingerprint is refused before anything is sent', () async {
      final host = phone('host');
      final room = await host.host();
      final ana = phone('ana');
      final forged = JoinLink(hostAndPort: '127.0.0.1:${room.port}', roomCode: room.roomCode, fingerprint: 'A' * 43);
      await ana.container.read(joinProvider).join(link: forged, name: 'Ana');
      await eventually('the guest is told the host is not trusted', () => ana.link.failure == LinkFailure.hostNotTrusted);
      expect(host.view!.seats.map((s) => s.name), <String>['Host'], reason: 'the host never saw the guest');
      expect(await ana.stored, isNull, reason: 'no session was made');
    }, skip: skip);

    test('a plain-HTTP host (an older version) is reported as outdated, not retried forever', () async {
      final dir = Directory.systemTemp.createTempSync('pc-e2e-plain-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final plain = ServerController();
      await initBridge(libraryPath: nativeLibraryPath);
      await plain.start(RsServerConfig(port: 0, exposeOnLan: false, dataDir: dir.path, serverName: 'old'));
      addTearDown(plain.stop);
      expect(plain.fingerprint, isNull);

      final ana = phone('ana');
      // A guest who typed the address of a server that cannot speak TLS.
      await ana.container
          .read(joinProvider)
          .join(
            link: JoinLink(hostAndPort: '127.0.0.1:${plain.port}', roomCode: 'ABCD'),
            name: 'Ana',
          );
      await eventually(
        'the guest learns the host is outdated',
        () => ana.link.failure == LinkFailure.hostOutdated,
        timeout: const Duration(seconds: 20),
      );
      expect(ana.link.phase, LinkPhase.failed);
    }, skip: skip);

    test('a room code nobody hosts is "room not found", not a hang', () async {
      final host = phone('host');
      final room = await host.host();
      final ana = phone('ana');
      await ana.container
          .read(joinProvider)
          .join(
            link: JoinLink(hostAndPort: '127.0.0.1:${room.port}', roomCode: 'ZZZZ', fingerprint: room.fingerprint),
            name: 'Ana',
          );
      await eventually('the guest is told there is no such room', () => ana.link.failure == LinkFailure.roomGone);
    }, skip: skip);
  });

  group('taps and timing', () {
    test('tapping Join twice makes one seat', () async {
      final host = phone('host');
      final room = await host.host();
      final ana = phone('ana');
      final join = ana.container.read(joinProvider);
      final link = Device.qrOf(room);
      await Future.wait(<Future<void>>[join.join(link: link, name: 'Ana'), join.join(link: link, name: 'Ana')]);
      await eventually('seated', () => ana.session.isSeated);
      await staysTrue(
        'still one seat for Ana',
        () => host.view!.seats.where((s) => s.name == 'Ana').length <= 1,
        duration: const Duration(seconds: 1),
      );
      expect(host.view!.seats.where((s) => s.name == 'Ana').length, 1);
    }, skip: skip);

    test('cancelling while the host is being looked at connects nothing', () async {
      final host = phone('host');
      final room = await host.host();
      final ana = phone('ana', wrapFinder: (real) => SlowFinder(real, const Duration(milliseconds: 400)));
      final join = ana.container.read(joinProvider);
      final pending = join.join(link: Device.qrOf(room, pinned: false), name: 'Ana');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await join.leave();
      await pending;
      await Future<void>.delayed(const Duration(milliseconds: 800));
      expect(ana.session.isAttached, isFalse);
      expect(host.view!.seats.map((s) => s.name), <String>['Host']);
    }, skip: skip);

    test('a slow first look at the certificate still joins (and is asked again once)', () async {
      final host = phone('host');
      final room = await host.host();
      final ana = phone('ana', wrapFinder: (real) => SlowFinder(real, const Duration(milliseconds: 250)));
      await ana.joinSeated(Device.qrOf(room, pinned: false), 'Ana');
      expect(pinOf(Uri.parse(ana.session.serverUri!)), room.fingerprint);
    }, skip: skip);
  });

  group('the host port', () {
    test('port 7878 is taken: the host uses 7879 and a guest still finds it by code', () async {
      final squatter = await ServerSocket.bind(InternetAddress.anyIPv4, 7878);
      addTearDown(squatter.close);
      final host = phone('host');
      final room = await host.host();
      expect(room.port, 7879);
      final ana = phone('ana');
      final found = await ana.container.read(joinProvider).find(room.roomCode).result;
      expect(found?.hostAndPort, '127.0.0.1:7879');
      await ana.joinSeated(JoinLink(hostAndPort: found!.hostAndPort, roomCode: room.roomCode, fingerprint: found.fingerprint), 'Ana');
    }, skip: skip);
  });

  group('the end of a game', () {
    test('the host ends the game: guests are told and stop trying', () async {
      final host = phone('host');
      final room = await host.host();
      final ana = phone('ana');
      await ana.joinSeated(Device.qrOf(room), 'Ana');
      host.container.notifier(sessionProvider).send(const EndGame());
      await eventually(
        'the guest is told the room is over',
        () => ana.session.room.ended != null || ana.link.failure != null || ana.link.phase == LinkPhase.closed,
      );
      final attempts = ana.link.attempt;
      await staysTrue('the guest does not keep reconnecting', () => ana.link.attempt <= attempts + 1, duration: const Duration(seconds: 2));
    }, skip: skip);
  });

  group('on the real network address of this machine', () {
    test('guests reach the host through its LAN address: encrypted, pinned, and never in the clear', () async {
      final lan = lanAddress;
      if (lan == null) return markTestSkipped('this machine has no private network address');
      final host = phone('host', searchAddresses: <String>[lan]);
      final room = await host.host();
      final ana = phone('ana', searchAddresses: <String>[lan]);
      await ana.joinSeated(Device.qrOf(room, address: lan), 'Ana');
      expect(ana.session.serverUri, startsWith('wss://$lan:'));

      // The plain address of the same host is refused by the app itself, before any byte is sent.
      await expectLater(openChannel(Uri.parse('ws://$lan:${room.port}/v1/ws')), throwsA(isA<InsecureAddress>()));
      // And nothing answers in the clear.
      expect(await ana.finder.speaksPlainHttp('$lan:${room.port}'), isFalse);

      // A web page that rebinds a name to this host is refused (DNS rebinding): the Host header
      // must be an address.
      final client = HttpClient()..badCertificateCallback = (cert, host, port) => true;
      addTearDown(() => client.close(force: true));
      final request = await client.getUrl(Uri.parse('https://$lan:${room.port}/health'));
      request.headers.host = 'rebind.example';
      final response = await request.close();
      await response.drain<void>();
      expect(response.statusCode, 400);
    }, skip: skip);

    test('the host comes back on another port: the guest finds it by room code, same certificate, and resumes', () async {
      final lan = lanAddress;
      if (lan == null) return markTestSkipped('this machine has no private network address');
      final dir = Directory.systemTemp.createTempSync('pc-e2e-moved-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final first = phone('host1', dir: dir, searchAddresses: <String>[lan]);
      final room = await first.host();
      expect(room.port, 7878);
      final ana = phone('ana', searchAddresses: <String>[lan]);
      await ana.joinSeated(Device.qrOf(room, address: lan), 'Ana');
      final tokens = await first.stored;

      await first.server.stop();
      // Something else took 7878 meanwhile (it closes every connection it gets).
      final squatter = await ServerSocket.bind(InternetAddress.anyIPv4, 7878);
      squatter.listen((socket) => socket.destroy());
      addTearDown(squatter.close);

      final second = phone('host2', dir: dir, searchAddresses: <String>[lan]);
      await second.tokens.write(tokens!);
      expect(await second.container.notifier(hostProvider).restore(), isTrue);
      expect(second.hosting.room!.port, 7879);

      await eventually(
        'the guest searched, found the host on the new port and resumed',
        () => ana.link.isLive && ana.view != null && ana.session.serverUri!.contains(':7879/'),
        timeout: const Duration(seconds: 40),
      );
      expect(pinOf(Uri.parse(ana.session.serverUri!)), room.fingerprint);
      expect(ana.session.isSeated, isTrue);
      expect((await ana.stored)!.serverUri, contains(':7879/'), reason: 'the new address is remembered');
    }, skip: skip);
  });

  group('the app being killed', () {
    test('a guest whose app was killed and reopened resumes the same seat from its stored session', () async {
      final host = phone('host');
      final room = await host.host();
      final tokens = MemoryTokenStore();
      final before = phone('ana1', tokens: tokens);
      await before.joinSeated(Device.qrOf(room), 'Ana');
      final seatId = before.session.playerId;
      final stored = (await tokens.read())!;
      expect(stored.serverUri, startsWith('wss://'));
      expect(stored.serverUri, contains('#pin='));

      before.kill();
      final after = phone('ana2', tokens: tokens);
      expect(await after.container.read(joinProvider).restore(), isTrue);
      await eventually('the reopened app is back at the table', () => after.link.isLive && after.session.isSeated);
      expect(after.session.playerId, seatId);
      expect(host.view!.seats.where((s) => s.name == 'Ana').length, 1);
    }, skip: skip);
  });

  group('the host phone is in a bad way', () {
    test('both usual ports are taken: the host gets another port and a guest joins by the QR code', () async {
      final a = await ServerSocket.bind(InternetAddress.anyIPv4, 7878);
      final b = await ServerSocket.bind(InternetAddress.anyIPv4, 7879);
      addTearDown(a.close);
      addTearDown(b.close);
      final host = phone('host');
      final room = await host.host();
      expect(room.port, isNot(anyOf(7878, 7879)));
      final ana = phone('ana');
      expect(await ana.container.read(joinProvider).find(room.roomCode).result, isNull, reason: 'a search by code only knows the two usual ports');
      await ana.joinSeated(Device.qrOf(room), 'Ana');
    }, skip: skip);

    test('a folder the app cannot write to is a clear "storage" failure, not a crash', () async {
      // The data folder would have to be made inside a folder that is read-only. (A read-only data
      // folder itself is simply repaired: the app owns it and makes it private again.)
      final parent = Directory.systemTemp.createTempSync('pc-e2e-readonly-');
      addTearDown(() {
        Process.runSync('chmod', <String>['-R', '700', parent.path]);
        parent.deleteSync(recursive: true);
      });
      Process.runSync('chmod', <String>['500', parent.path]);
      var writable = true;
      try {
        File('${parent.path}/probe').writeAsStringSync('x');
      } on FileSystemException {
        writable = false;
      }
      // Running as root ignores the permission; then there is nothing to prove.
      if (writable) return markTestSkipped('this user can write to a read-only folder');

      final host = phone('host', dir: Directory('${parent.path}/data'));
      await host.container.notifier(hostProvider).start(hostName: 'Host', config: e2eTable);
      expect(host.hosting.phase, HostPhase.failed);
      expect(host.hosting.error?.failure, HostFailure.storage);
      expect(host.session.isAttached, isFalse);

      // The port was not left bound: the same phone hosts fine once the folder is fixed.
      Process.runSync('chmod', <String>['700', parent.path]);
      await host.container.notifier(hostProvider).start(hostName: 'Host', config: e2eTable);
      expect(host.hosting.phase, HostPhase.ready);
    }, skip: skip);
  });
}
