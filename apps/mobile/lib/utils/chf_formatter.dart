/// Swiss CHF formatting utility — single source of truth.
///
/// CHF amounts are ALWAYS formatted in Swiss style (1'234.00) regardless of
/// locale, because CHF is a Swiss currency and Swiss formatting is the standard.
/// This is intentional per CLAUDE.md §7 (Design System).
/// Formats a double value as a Swiss-style CHF string with
/// apostrophe thousands separator (e.g. "4'280").
///
/// Usage:
///   formatChf(4280.50)  → "4'281"
///   formatChfWithPrefix(4280.50) → "CHF 4'281"
String formatChf(double value) {
  // FIX-078: Guard against NaN and Infinity.
  if (!value.isFinite) return '—';
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

/// Nullable CHF — returns em-dash for null, "0 CHF" for zero.
/// Uses suffix format ("1'234 CHF") consistent with Swiss convention.
String formatChfOrDash(double? value) {
  if (value == null) return '\u2014';
  if (value == 0) return '0\u00a0CHF';
  return '${formatChf(value)}\u00a0CHF';
}

/// Nullable CHF with /mois suffix — returns em-dash for null.
/// Uses suffix format ("1'234 CHF/mois").
String formatChfMonthly(double? value) {
  if (value == null) return '\u2014';
  if (value == 0) return '0\u00a0CHF/mois';
  return '${formatChf(value)}\u00a0CHF/mois';
}

/// Format percentage from decimal (0.452 → "45,2%"). Em-dash for null.
/// Uses comma as decimal separator (Swiss French convention).
String formatPctOrDash(double? value) {
  if (value == null) return '\u2014';
  final formatted = (value * 100).toStringAsFixed(1).replaceAll('.', ',');
  return '$formatted\u00a0%';
}

/// Format a percentage value with comma decimal separator (Swiss French).
/// Input is already in percent (e.g. 5.3 → "5,3").
String formatPct(double value) {
  return value.toStringAsFixed(1).replaceAll('.', ',');
}

/// Format CHF with centimes precision (e.g., "4'280.50").
/// Use for tax reports and PDF export where centime accuracy matters.
String formatChfPrecise(double value) {
  if (!value.isFinite) return '—';
  final parts = value.abs().toStringAsFixed(2).split('.');
  final intPart = parts[0];
  final decPart = parts[1];
  final formatted = intPart.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'), (m) => "${m[1]}'");
  return "${value < 0 ? '-' : ''}$formatted.$decPart";
}

/// Format CHF with centimes precision and "CHF " prefix.
String formatChfPreciseWithPrefix(double value) =>
    'CHF\u00a0${formatChfPrecise(value)}';

/// Compact CHF formatter — omits "CHF" prefix for space-constrained contexts.
/// Examples: 680'000 → "680k" | 1'200'000 → "1.2M" | 800 → "CHF 800"
String formatChfCompact(double value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
  return formatChfWithPrefix(value);
}
