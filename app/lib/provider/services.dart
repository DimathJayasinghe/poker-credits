import 'package:poker_credits/net/socket_client.dart';
import 'package:poker_credits/platform/host_server.dart';
import 'package:poker_credits/platform/server_address.dart';
import 'package:poker_credits/platform/token_store.dart';
import 'package:poker_credits/platform/wake_lock.dart';
import 'package:poker_credits/util/haptics.dart';
import 'package:poker_credits/util/sound.dart';
import 'package:poker_protocol/poker_protocol.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Services behind the platform seam. Tests override these with fakes, so no test ever loads
/// the native library or touches the file system.
final hostServerProvider = Provider<HostServer>((ref) => createHostServer());
final tokenStoreProvider = Provider<TokenStore>((ref) => createTokenStore());
final wakeLockProvider = Provider<WakeLock>((ref) => createWakeLock());
final hapticsProvider = Provider<Haptics>((ref) => const Haptics());
final soundProvider = Provider<Sound>((ref) => const Sound());
final localAddressesProvider = Provider<LocalAddressLister>((ref) => listLocalAddresses);

/// Local clock; overridden in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Creates the socket client for a session; overridden in tests with fake transports.
typedef RoomClientFactory = RoomClient Function(Uri uri, ClientMessage first);
final roomClientFactoryProvider = Provider<RoomClientFactory>(
  (ref) =>
      (uri, first) => RoomClient(uri: uri, firstMessage: first),
);
