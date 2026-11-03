/// Platform seam: which addresses other devices can use to reach this one (ADR-014).
library;

export 'server_address_stub.dart' if (dart.library.io) 'server_address_io.dart';

/// Lists the device's LAN IPv4 addresses, most likely first. Empty when unknown or on web.
typedef LocalAddressLister = Future<List<String>> Function();
