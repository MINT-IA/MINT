// ────────────────────────────────────────────────────────────
//  CANTONAL TAX DEADLINES — Phase 04 / Moteur d'Anticipation
// ────────────────────────────────────────────────────────────
//
// Static map of cantonal tax declaration deadlines (26 cantons).
//
// Note: Deadlines may vary by year. Always display an educational
// disclaimer: "Verifie aupres de ton administration fiscale cantonale."
//
// Most cantons default to March 31. Known exceptions are listed.
// Extensions are possible in all cantons (noted where relevant).
//
// Source: Cantonal tax administrations, 2025/2026 calendars.
// Design: Pure static data, zero async (ANT-08).
// ────────────────────────────────────────────────────────────

/// A cantonal tax declaration deadline.
class CantonalDeadline {
  /// Month of the deadline (1-12).
  final int month;

  /// Day of the deadline (1-31).
  final int day;

  /// Optional educational note about extensions.
  final String? extensionNote;

  const CantonalDeadline(this.month, this.day, {this.extensionNote});
}

/// Default deadline used for cantons not explicitly listed.
const _defaultDeadline = CantonalDeadline(3, 31);

/// Tax declaration deadlines per canton.
///
/// Most cantons: March 31.
/// Known exceptions: TI (April 30), NW/OW (end of April), etc.
///
/// Disclaimer: These are standard deadlines. Extensions are
/// available in most cantons upon request. "Verifie aupres de
/// ton administration fiscale cantonale."
const Map<String, CantonalDeadline> cantonalTaxDeadlines = {
  // Suisse Romande
  'VD': CantonalDeadline(3, 31),
  'GE': CantonalDeadline(3, 31),
  'NE': CantonalDeadline(3, 31),
  'JU': CantonalDeadline(3, 31),
  'VS': CantonalDeadline(3, 31),
  'FR': CantonalDeadline(3, 31),

  // Deutschschweiz
  'ZH': CantonalDeadline(3, 31),
  'BE': CantonalDeadline(3, 31),
  'LU': CantonalDeadline(3, 31),
  'ZG': CantonalDeadline(3, 31),
  'AG': CantonalDeadline(3, 31),
  'SG': CantonalDeadline(3, 31),
  'TG': CantonalDeadline(3, 31),
  'SH': CantonalDeadline(3, 31),
  'AR': CantonalDeadline(3, 31),
  'AI': CantonalDeadline(3, 31),
  'GL': CantonalDeadline(3, 31),
  'GR': CantonalDeadline(3, 31),
  'SO': CantonalDeadline(3, 31),
  'BL': CantonalDeadline(3, 31),
  'BS': CantonalDeadline(3, 31),
  'SZ': CantonalDeadline(3, 31),
  'UR': CantonalDeadline(3, 31),

  // Extended deadlines
  'NW': CantonalDeadline(4, 30,
      extensionNote: 'Prolongation automatique possible'),
  'OW': CantonalDeadline(4, 30,
      extensionNote: 'Prolongation automatique possible'),

  // Svizzera Italiana
  'TI': CantonalDeadline(4, 30,
      extensionNote: 'Prolongation possible sur demande'),
};

/// Look up a canton's tax deadline, defaulting to March 31.
CantonalDeadline getCantonalDeadline(String canton) {
  return cantonalTaxDeadlines[canton.toUpperCase()] ?? _defaultDeadline;
}
