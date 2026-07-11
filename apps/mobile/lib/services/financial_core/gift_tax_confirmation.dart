/// Constants for gift-tax flows where MINT deliberately does not compute a
/// cantonal tariff.
///
/// Gift tax is cantonal and sometimes communal. Until MINT has an
/// authoritative, sourced tariff table, scenario services must return a
/// confirmation state instead of inventing a rate or a CHF amount.
///
/// Source stance checked 2026-07-11:
/// - ch.ch: cantons regulate gift tax; spouse/registered partner and
///   descendants are usually exempt, but cantonal exceptions apply.
/// - MINT product rule: spouse can render green exemption; descendants stay
///   to-confirm until a sourced canton tariff table exists.
class GiftTaxConfirmation {
  const GiftTaxConfirmation._();

  static const double noComputedRate = 0.0;
  static const double noComputedAmount = 0.0;
}
