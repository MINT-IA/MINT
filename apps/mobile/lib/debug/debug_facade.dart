// Public entry point for the Tier 2 debug server.
//
// Conditional export: real implementation (with `dart:io HttpServer`) on
// targets that have `dart.library.io` (mobile / desktop), no-op stub
// elsewhere. Combined with the compile-time `kDebugMode` and
// `bool.fromEnvironment('MINT_DEBUG_ENDPOINT')` guards in `main.dart`,
// the release binary contains zero debug-server code.
//
// Usage from `main.dart`:
//
//   import 'package:mint_mobile/debug/debug_facade.dart' as mint_debug;
//
//   if (kDebugMode && _debugEndpointEnabled) {
//     await mint_debug.DebugServer.start(router: _appRouter);
//   }

export 'debug_server_stub.dart'
    if (dart.library.io) 'debug_server.dart';
