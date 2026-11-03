/// Platform seam: one app window per desktop user (ADR-014).
library;

export 'single_instance_stub.dart' if (dart.library.io) 'single_instance_io.dart';

/// Result of [claimSingleInstance].
abstract interface class InstanceClaim {
  /// Whether this process is the first instance and should keep running.
  bool get isPrimary;

  /// Runs [onSecondLaunch] whenever another launch is attempted (and exits that launch).
  void listen(void Function() onSecondLaunch);

  Future<void> release();

  /// Ends this process (used by a second launch after it told the first one to show itself).
  void exitProcess();
}
