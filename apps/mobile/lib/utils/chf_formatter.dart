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

/// Compact CHF formatter — omits "CHF" prefix for space-constrained contexts.
/// Examples: 680'000 → "680k" | 1'200'000 → "1.2M" | 800 → "CHF 800"
String formatChfCompact(double value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
  return formatChfWithPrefix(value);
}
