import 'package:flutter/foundation.dart';

import 'startup_route_override_platform_stub.dart'
    if (dart.library.io) 'startup_route_override_platform_io.dart' as platform;

String mintInitialLocation({String fallback = '/'}) {
  return fallback;
}

const bool _mintRuntimeProofSemanticsCompileTimeEnabled =
    bool.fromEnvironment('MINT_ENABLE_RUNTIME_PROOF_SEMANTICS');
const bool _mintRuntimeProofInputsCompileTimeEnabled =
    bool.fromEnvironment('MINT_ENABLE_RUNTIME_PROOF_SEMANTICS');

bool mintRuntimeProofSemanticsCompileTimeEnabled() {
  return kDebugMode || _mintRuntimeProofSemanticsCompileTimeEnabled;
}

Future<String?> readMintDebugInitialRoute() async {
  if (!await _mintRuntimeProofInputsEnabled()) return null;
  return platform.readMintTestInitialRoute();
}

Future<int?> readMintDebugPropertyValueSeed() async {
  if (!await _mintRuntimeProofInputsEnabled()) return null;
  return platform.readMintTestPropertyValue();
}

Future<int?> readMintDebugRevenueAnnualSeed() async {
  if (!await _mintRuntimeProofInputsEnabled()) return null;
  return platform.readMintTestRevenueAnnual();
}

Future<String?> readMintDebugCantonSeed() async {
  if (!await _mintRuntimeProofInputsEnabled()) return null;
  return platform.readMintTestCanton();
}

Future<bool> readMintDebugPropertyValueStaleSeed() async {
  if (!await _mintRuntimeProofInputsEnabled()) return false;
  return platform.readMintTestPropertyStale();
}

DateTime mintRuntimeProofStalePropertyValueDate(DateTime now) {
  return now.toUtc().subtract(const Duration(days: 30 * 30));
}

Future<String?> readMintDebugTransmitPropertyFixtureSeed() async {
  if (!await _mintRuntimeProofInputsEnabled()) return null;
  return platform.readMintTestTransmitPropertyFixture();
}

Future<String?> readMintDebugReportFixtureSeed() async {
  if (!await _mintRuntimeProofInputsEnabled()) return null;
  return platform.readMintTestReportFixture();
}

Future<bool> readMintRuntimeProofSemanticsEnabled() async {
  if (mintRuntimeProofSemanticsCompileTimeEnabled()) return true;
  return platform.readMintRuntimeProofSemanticsFlag();
}

Future<bool> _mintRuntimeProofInputsEnabled() async {
  if (_mintRuntimeProofInputsCompileTimeEnabled) return true;
  return platform.readMintRuntimeProofSemanticsFlag();
}

@visibleForTesting
Future<bool> mintRuntimeProofInputsEnabledForTest() {
  return _mintRuntimeProofInputsEnabled();
}
