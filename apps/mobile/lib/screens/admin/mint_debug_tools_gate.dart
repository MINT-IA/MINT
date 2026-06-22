// Dev-only admin surface per D-03 + D-10 (CONTEXT v4).
library;

import 'package:flutter/foundation.dart';
import 'package:mint_mobile/screens/admin/admin_gate.dart';

class MintDebugToolsGate {
  MintDebugToolsGate._();

  static const String _compileTimeValue = String.fromEnvironment(
    'ENABLE_DEBUG_TOOLS',
    defaultValue: 'false',
  );
  static const bool _compileTimeEnabled =
      _compileTimeValue == 'true' || _compileTimeValue == '1';

  static bool get isAvailable =>
      !kReleaseMode && AdminGate.isAvailable && _compileTimeEnabled;
}
