/// Conditional export for flutter_gemma.
///
/// - On native platforms (dart:io available): re-exports the real package.
/// - On web (dart:io unavailable): re-exports web-safe stubs.
///
/// Usage in SLM files:
///   import 'package:mint_mobile/services/slm/gemma_interop.dart';
/// instead of:
///   import 'package:flutter_gemma/flutter_gemma.dart';
library;

export 'gemma_stub.dart'
    if (dart.library.io) 'package:flutter_gemma/flutter_gemma.dart';
