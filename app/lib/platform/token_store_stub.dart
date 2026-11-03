import 'package:poker_credits/platform/token_store.dart';

/// Web: tokens live in memory only until a browser store is added with the web build.
TokenStore createTokenStore() => MemoryTokenStore();
