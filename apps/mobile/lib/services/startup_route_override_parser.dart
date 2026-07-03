const String mintTestInitialRouteKey = 'MINT_TEST_INITIAL_ROUTE';
const String mintTestPropertyValueKey = 'MINT_TEST_PROPERTY_VALUE';
const String mintTestPropertyStaleKey = 'MINT_TEST_PROPERTY_STALE';
const String mintTestRevenueAnnualKey = 'MINT_TEST_REVENUE_ANNUAL';
const String mintTestCantonKey = 'MINT_TEST_CANTON';
const String mintTestTransmitPropertyFixtureKey =
    'MINT_TEST_TRANSMIT_PROPERTY_FIXTURE';
const String mintTestReportFixtureKey = 'MINT_TEST_REPORT_FIXTURE';
const String mintRuntimeProofSemanticsKey =
    'MINT_ENABLE_RUNTIME_PROOF_SEMANTICS';

String? parseMintTestInitialRoute({
  required List<String> arguments,
  required Map<String, String> environment,
}) {
  final envRoute = _normalizeMintInitialRoute(_readMintTestValue(
    key: mintTestInitialRouteKey,
    arguments: arguments,
    environment: environment,
  ));
  if (envRoute != null) return envRoute;

  return null;
}

int? parseMintTestPropertyValue({
  required List<String> arguments,
  required Map<String, String> environment,
}) {
  final raw = _readMintTestValue(
    key: mintTestPropertyValueKey,
    arguments: arguments,
    environment: environment,
  );
  if (raw == null) return null;
  final value = int.tryParse(raw.trim());
  if (value == null || value <= 0 || value > 1000000000) return null;
  return value;
}

int? parseMintTestRevenueAnnual({
  required List<String> arguments,
  required Map<String, String> environment,
}) {
  final raw = _readMintTestValue(
    key: mintTestRevenueAnnualKey,
    arguments: arguments,
    environment: environment,
  );
  if (raw == null) return null;
  final value = int.tryParse(raw.trim());
  if (value == null || value <= 0 || value > 10000000) return null;
  return value;
}

String? parseMintTestCanton({
  required List<String> arguments,
  required Map<String, String> environment,
}) {
  final raw = _readMintTestValue(
    key: mintTestCantonKey,
    arguments: arguments,
    environment: environment,
  );
  final value = raw?.trim().toUpperCase();
  if (value == null || !_swissCantonCodes.contains(value)) return null;
  return value;
}

bool parseMintTestPropertyStale({
  required List<String> arguments,
  required Map<String, String> environment,
}) {
  final raw = _readMintTestValue(
    key: mintTestPropertyStaleKey,
    arguments: arguments,
    environment: environment,
  );
  final normalized = raw?.trim().toLowerCase();
  return normalized == 'true' ||
      normalized == '1' ||
      normalized == 'yes' ||
      normalized == 'on';
}

String? parseMintTestTransmitPropertyFixture({
  required List<String> arguments,
  required Map<String, String> environment,
}) {
  final raw = _readMintTestValue(
    key: mintTestTransmitPropertyFixtureKey,
    arguments: arguments,
    environment: environment,
  );
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  if (!RegExp(r'^[a-z0-9_:-]+$').hasMatch(value)) return null;
  return value;
}

String? parseMintTestReportFixture({
  required List<String> arguments,
  required Map<String, String> environment,
}) {
  final raw = _readMintTestValue(
    key: mintTestReportFixtureKey,
    arguments: arguments,
    environment: environment,
  );
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  if (!RegExp(r'^[a-z0-9_:-]+$').hasMatch(value)) return null;
  return value;
}

bool parseMintRuntimeProofSemanticsEnabled({
  required List<String> arguments,
  required Map<String, String> environment,
}) {
  final raw = _readMintTestValue(
    key: mintRuntimeProofSemanticsKey,
    arguments: arguments,
    environment: environment,
  );
  final normalized = raw?.trim().toLowerCase();
  return normalized == 'true' ||
      normalized == '1' ||
      normalized == 'yes' ||
      normalized == 'on';
}

String? _readMintTestValue({
  required String key,
  required List<String> arguments,
  required Map<String, String> environment,
}) {
  final envValue = environment[key];
  if (envValue != null) return envValue;

  for (var i = 0; i < arguments.length; i += 1) {
    final arg = arguments[i];
    for (final prefix in _inlinePrefixes(key)) {
      if (arg.startsWith(prefix)) {
        return arg.substring(prefix.length);
      }
    }
    if (_separateKeys(key).contains(arg) && i + 1 < arguments.length) {
      return arguments[i + 1];
    }
  }

  return null;
}

List<String> _inlinePrefixes(String key) => [
      '$key=',
      '--$key=',
      '-$key=',
    ];

Set<String> _separateKeys(String key) => {
      key,
      '--$key',
      '-$key',
    };

String? _normalizeMintInitialRoute(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  if (!value.startsWith('/') || value.startsWith('//')) return null;
  if (value.contains('://')) return null;
  if (RegExp(r'[\s\x00-\x1F\x7F]').hasMatch(value)) return null;
  return value;
}

const Set<String> _swissCantonCodes = {
  'AG',
  'AI',
  'AR',
  'BE',
  'BL',
  'BS',
  'FR',
  'GE',
  'GL',
  'GR',
  'JU',
  'LU',
  'NE',
  'NW',
  'OW',
  'SG',
  'SH',
  'SO',
  'SZ',
  'TG',
  'TI',
  'UR',
  'VD',
  'VS',
  'ZG',
  'ZH',
};
