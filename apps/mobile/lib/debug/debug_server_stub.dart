// Release-build stub for `DebugServer`. Selected by the conditional
// import in `lib/debug/debug_facade.dart` when `dart.library.io` is not
// available (e.g. dart-define-disabled or web target). Real impl lives
// in `lib/debug/debug_server.dart`.
//
// The body is intentionally empty so the tree-shaker can strip both
// this class and any caller path. NEVER add behaviour here — debug
// server logic belongs in the real file only.

class DebugServer {
  DebugServer._();

  static const String schemaVersion = 'v1';
  static DebugServer? get instance => null;

  static Future<DebugServer?> start({
    required Object router,
    int port = 8181,
  }) async =>
      null;
}
