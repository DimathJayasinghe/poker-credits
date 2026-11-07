/// Dart facade over the embedded Rust poker server.
///
/// Native platforms only: it loads a native library through `dart:ffi`, so web-safe code must
/// never import it (ADR-014). The app reaches it through `app/lib/platform/host_server*.dart`.
library;

export 'src/bridge_exception.dart';
export 'src/bridge_init.dart';
export 'src/rust/api/server.dart'
    show
        RsCardMode,
        RsCreatedRoom,
        RsRoomConfig,
        RsRoomError,
        RsServerConfig,
        RsServerError,
        RsServerErrorKind,
        RsServerEvent,
        RsServerEventKind;
export 'src/server_controller.dart';
