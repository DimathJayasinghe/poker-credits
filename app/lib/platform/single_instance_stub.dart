import 'package:poker_credits/platform/single_instance.dart';

/// Web and mobile: no restriction.
Future<InstanceClaim> claimSingleInstance() async => const _Always();

final class _Always implements InstanceClaim {
  const _Always();

  @override
  bool get isPrimary => true;

  @override
  void listen(void Function() onSecondLaunch) {}

  @override
  Future<void> release() async {}
}
