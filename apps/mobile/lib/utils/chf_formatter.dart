/// Swiss CHF formatting utility — single source of truth.
///
/// Formats a double value as a Swiss-style CHF string with
/// apostrophe thousands separator (e.g. "4'280").
///
/// Usage:
///   formatChf(4280.50)  → "4'281"
///   formatChfWithPrefix(4280.50) → "CHF 4'281"
String formatChf(double value) {
  final intVal = value.round();
  final str = intVal.abs().toString();
  final buffer = StringBuffer();
  if (intVal < 0) buffer.write('-');
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) {
      buffer.write("'");
    }
    buffer.write(str[i]);
  }
  return buffer.toString();
}

/// Format with "CHF " prefix.
String formatChfWithPrefix(double value) => 'CHF\u00a0${formatChf(value)}';

/// Nullable CHF — returns em-dash for null, "CHF 0" for zero.
String formatChfOrDash(double? value) {
  if (value == null) return '\u2014';
  if (value == 0) return 'CHF\u00a00';
  return formatChfWithPrefix(value);
}

/// Nullable CHF with /mois suffix — returns em-dash for null.
String formatChfMonthly(double? value) {
  if (value == null) return '\u2014';
  if (value == 0) return 'CHF\u00a00/mois';
  return '${formatChfWithPrefix(value)}/mois';
}

/// Format percentage from decimal (0.452 → "45.2%"). Em-dash for null.
String formatPctOrDash(double? value) {
  if (value == null) return '\u2014';
  return '${(value * 100).toStringAsFixed(1)}%';
}

/// Compact CHF formatter — omits "CHF" prefix for space-constrained contexts.
/// Examples: 680'000 → "680k" | 1'200'000 → "1.2M" | 800 → "CHF 800"
String formatChfCompact(double value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
  return formatChfWithPrefix(value);
}
