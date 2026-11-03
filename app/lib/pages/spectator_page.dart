import 'package:flutter/widgets.dart';
import 'package:poker_credits/pages/table_page.dart';

/// Read-only view of a game for somebody who joined to watch: the Table display without any
/// control. The server refuses every command from a spectator anyway; here there is nothing to
/// press.
class SpectatorPage extends StatelessWidget {
  const SpectatorPage({super.key});

  @override
  Widget build(BuildContext context) => const TablePage(watching: true);
}
