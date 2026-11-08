import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:poker_credits/net/socket_client.dart';
import 'package:poker_credits/platform/external_links.dart';
import 'package:poker_credits/platform/host_finder.dart';
import 'package:poker_credits/platform/host_keep_alive.dart';
import 'package:poker_credits/platform/host_server.dart';
import 'package:poker_credits/platform/server_address.dart';
import 'package:poker_credits/platform/sound_player.dart';
import 'package:poker_credits/platform/token_store.dart';
import 'package:poker_credits/platform/wake_lock.dart';
import 'package:poker_credits/provider/settings_provider.dart';
import 'package:poker_credits/util/haptics.dart';
import 'package:poker_credits/util/sound.dart';
import 'package:poker_protocol/poker_protocol.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Services behind the platform seam. Tests override these with fakes, so no test ever loads
/// the native library or touches the file system.
final hostServerProvider = Provider<HostServer>((ref) => createHostServer());
final tokenStoreProvider = Provider<TokenStore>((ref) => createTokenStore());
final wakeLockProvider = Provider<WakeLock>((ref) => createWakeLock());
final hapticsProvider = Provider<Haptics>((ref) => Haptics(enabled: () => ref.read(settingsProvider).vibration));
final soundPlayerProvider = Provider<SoundPlayer>((ref) => createSoundPlayer());
final soundProvider = Provider<Sound>(
  (ref) => Sound(
    player: ref.read(soundPlayerProvider),
    enabled: () => ref.read(settingsProvider).sound,
    // Unknown (tests, the first frame) counts as in front.
    foreground: () => const <AppLifecycleState?>{null, AppLifecycleState.resumed}.contains(WidgetsBinding.instance.lifecycleState),
  ),
);
final hostKeepAliveProvider = Provider<HostKeepAlive>((ref) => createHostKeepAlive());
final hostFinderProvider = Provider<HostFinder>((ref) => createHostFinder());
final externalLinksProvider = Provider<ExternalLinks>((ref) => const BrowserExternalLinks());
final localAddressesProvider = Provider<LocalAddressLister>((ref) => listLocalAddresses);

/// The app version shown in Settings. A missing plugin (tests) or any failure shows a dash.
final appVersionProvider = Provider<Future<String> Function()>(
  (ref) => () async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } on Object {
      return '-';
    }
  },
);

/// How long the loading screen stays up for a first launch; tests set it to zero.
final splashDurationProvider = Provider<Duration>((ref) => const Duration(milliseconds: 1600));

/// Local clock; overridden in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Creates the socket client for a session; overridden in tests with fake transports.
typedef RoomClientFactory = RoomClient Function(Uri uri, ClientMessage first);
final roomClientFactoryProvider = Provider<RoomClientFactory>(
  (ref) =>
      (uri, first) => RoomClient(uri: uri, firstMessage: first),
);
