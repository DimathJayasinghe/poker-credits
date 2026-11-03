import 'dart:io';

/// LAN IPv4 addresses of this device. Private ranges come first (192.168/16, 10/8, 172.16/12),
/// link-local and loopback are left out.
Future<List<String>> listLocalAddresses() async {
  final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false, includeLinkLocal: false);
  final addresses = <String>[
    for (final interface in interfaces)
      for (final address in interface.addresses) address.address,
  ];
  return rankLocalAddresses(addresses);
}

/// Orders [addresses] with the most likely LAN address first; drops link-local ones.
List<String> rankLocalAddresses(List<String> addresses) {
  int rank(String address) {
    if (address.startsWith('192.168.')) return 0;
    if (address.startsWith('10.')) return 1;
    final parts = address.split('.');
    final second = parts.length > 1 ? int.tryParse(parts[1]) : null;
    if (address.startsWith('172.') && second != null && second >= 16 && second <= 31) return 2;
    return 3;
  }

  final usable = addresses.where((a) => !a.startsWith('169.254.') && !a.startsWith('127.')).toList();
  usable.sort((a, b) => rank(a).compareTo(rank(b)));
  return usable;
}
