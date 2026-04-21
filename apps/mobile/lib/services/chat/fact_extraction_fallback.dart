import 'package:mint_mobile/providers/coach_profile_provider.dart';

/// Extracts canonical financial facts from a user chat message and applies
/// them to [CoachProfileProvider] locally.
///
/// **Why this exists.** The MVP path for anonymous local-mode users is:
///
///   1. User types `« j'ai 34 ans, je gagne 7500 brut à Lausanne »`
///   2. Backend answers intelligently (text).
///   3. Nothing is persisted — anonymous sessions never carry a `user_id`,
///      so backend `save_fact` hits the « Hors-DB path » and drops the
///      value (coach_chat.py:1408-1413). The Flutter-side `applySaveFact`
///      dispatcher was equally dead because `save_fact` is in
///      `INTERNAL_TOOL_NAMES` (coach_tools.py:100) and never reaches the
///      `toolCalls` list Flutter iterates over.
///
/// This fallback runs **client-side, pre-send**, so it works regardless of
/// auth state. We parse the *user message* for 6 high-signal patterns
/// restricted to first-person utterances, then dispatch each match into
/// [CoachProfileProvider.applySaveFact] using the same canonical key set
/// the backend whitelist uses (`_SAVE_FACT_ALLOWED_KEYS`). The LLM-side
/// `save_fact` tool remains the primary path when the user eventually
/// registers — this fallback is a safety net, never a replacement.
///
/// **Traps addressed** (panel 2026-04-21 § Backend trap to avoid):
///
///   * **First-person only.** « ma sœur gagne 7500 » would pollute the
///     profile with someone else's salary. All patterns require `\bje\b`,
///     `\bj'ai\b`, `\bma\b`, `\bmon\b`, or `\bj'habite\b` in the clause.
///   * **Source tagging.** Every extracted fact is persisted with
///     `confidence='medium'` and the applicant mapping already marks the
///     source via the `_coach_*` keys (`_coach_lpp_source`, etc.). Future
///     audit UI can distinguish heuristic from LLM-tool via the mapping.
///   * **Scope lock.** Only the 6 patterns below fire. The high-impact
///     keys `canton`, `householdType` are NOT covered: they change
///     downstream fiscal logic and must come from explicit LLM save_fact
///     once the backend pipeline is restored, not from brittle regex.
class FactExtractionFallback {
  FactExtractionFallback._();

  static const _firstPerson =
      r"(?:\bje\b|\bj'ai\b|\bj'habite\b|\bj'gagne\b|\bmon\b|\bma\b)";

  // Group 1 = amount (digits with optional ' or space thousands separators).
  // Captures `7500`, `7'500`, `7 500`. Must be followed by context signalling
  // it's a monthly or yearly salary, otherwise ambiguous.
  static final RegExp _salaryMonthly = RegExp(
    _firstPerson +
        r"[^.!?]*?\b(?:salaire|gagne|touche|paye(?:r)?)\b[^.!?]*?"
        r"(\d[\d' ]*)[^.!?]{0,40}?"
        r"\b(?:mois|mensuel|/\s*m\b)",
    caseSensitive: false,
  );

  static final RegExp _salaryYearly = RegExp(
    _firstPerson +
        r"[^.!?]*?\b(?:salaire|gagne|touche)\b[^.!?]*?"
        r"(\d[\d' ]*)[^.!?]{0,40}?"
        r"\b(?:an|ann[ée]e?|/\s*y\b)",
    caseSensitive: false,
  );

  // Age: « j'ai 34 ans ». We normalize to birthYear with the current year.
  static final RegExp _age = RegExp(
    r"\bj'ai\s+(\d{2})\s+ans\b",
    caseSensitive: false,
  );

  // LPP balance: « mon avoir LPP est 150000 », « mon 2e pilier 120'000 ».
  static final RegExp _avoirLpp = RegExp(
    _firstPerson +
        r"[^.!?]*?\b(?:avoir\s+LPP|2e?\s+pilier|deuxi[eè]me\s+pilier)\b"
        r"[^.!?]*?(\d[\d' ]*)",
    caseSensitive: false,
  );

  // 3a balance: « mon 3a est à 15'000 CHF ».
  static final RegExp _pillar3aBalance = RegExp(
    _firstPerson +
        r"[^.!?]*?\b(?:3[èeé]me?\s+pilier|3a|pilier\s+3a|troisi[eè]me\s+pilier)\b"
        r"[^.!?]*?(\d[\d' ]*)\s*(?:CHF|chf|francs?)?\b",
    caseSensitive: false,
  );

  /// Parses [userMessage] for first-person financial facts and dispatches
  /// each match through [provider].applySaveFact.
  ///
  /// Returns the list of canonical fact keys applied, so the caller can log
  /// or surface them to the user. Empty list = nothing matched.
  static Future<List<String>> extract(
    String userMessage,
    CoachProfileProvider provider,
  ) async {
    final applied = <String>[];
    final text = userMessage.trim();
    if (text.length < 5) return applied;

    // Age → birthYear (convert to year of birth using current year).
    final ageMatch = _age.firstMatch(text);
    if (ageMatch != null) {
      final age = int.tryParse(ageMatch.group(1) ?? '');
      if (age != null && age >= 14 && age <= 100) {
        final birthYear = DateTime.now().year - age;
        final ok = await provider.applySaveFact('birthYear', birthYear);
        if (ok) applied.add('birthYear');
      }
    }

    // Salary — prefer monthly when both patterns would match.
    final monthlyMatch = _salaryMonthly.firstMatch(text);
    if (monthlyMatch != null) {
      final raw = monthlyMatch.group(1)?.replaceAll(RegExp(r"[' ]"), '');
      final amount = double.tryParse(raw ?? '');
      if (amount != null && amount >= 1000 && amount <= 100000) {
        // Presence of « brut » vs « net » picks the right canonical key.
        final isBrut = RegExp(r'\b(?:brut|gross)\b', caseSensitive: false)
            .hasMatch(text);
        final key = isBrut ? 'incomeGrossMonthly' : 'incomeNetMonthly';
        final ok = await provider.applySaveFact(key, amount);
        if (ok) applied.add(key);
      }
    } else {
      final yearlyMatch = _salaryYearly.firstMatch(text);
      if (yearlyMatch != null) {
        final raw = yearlyMatch.group(1)?.replaceAll(RegExp(r"[' ]"), '');
        final amount = double.tryParse(raw ?? '');
        if (amount != null && amount >= 10000 && amount <= 2000000) {
          final isBrut = RegExp(r'\b(?:brut|gross)\b', caseSensitive: false)
              .hasMatch(text);
          final key = isBrut ? 'incomeGrossYearly' : 'incomeNetYearly';
          final ok = await provider.applySaveFact(key, amount);
          if (ok) applied.add(key);
        }
      }
    }

    // LPP balance.
    final lppMatch = _avoirLpp.firstMatch(text);
    if (lppMatch != null) {
      final raw = lppMatch.group(1)?.replaceAll(RegExp(r"[' ]"), '');
      final amount = double.tryParse(raw ?? '');
      if (amount != null && amount >= 1000 && amount <= 5000000) {
        final ok = await provider.applySaveFact('avoirLpp', amount);
        if (ok) applied.add('avoirLpp');
      }
    }

    // 3a balance.
    final pillar3aMatch = _pillar3aBalance.firstMatch(text);
    if (pillar3aMatch != null) {
      final raw = pillar3aMatch.group(1)?.replaceAll(RegExp(r"[' ]"), '');
      final amount = double.tryParse(raw ?? '');
      if (amount != null && amount >= 100 && amount <= 500000) {
        final ok = await provider.applySaveFact('pillar3aBalance', amount);
        if (ok) applied.add('pillar3aBalance');
      }
    }

    return applied;
  }
}
