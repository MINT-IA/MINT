/// GoalSelectionService — explicit goal selection by the user.
///
/// Allows the user to declare "right now, I care most about X" rather
/// than relying on MINT's auto-detection from profile data.
///
/// Stored in SharedPreferences. Null = auto-detect (CapEngine decides).
///
/// Compliance:
///   - No user-facing strings (all via ARB / l10n layers).
///   - No identifiable data stored.
library;

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key for the persisted selected goal intent tag.
const _kSelectedGoalKey = 'goal_selection_selected_intent_tag';

/// A goal the user can explicitly select.
class SelectableGoal {
  /// Intent tag used by PulseScreen / MintStateEngine (matches _ActiveGoal).
  final String intentTag;

  /// ARB key for the title (resolved via S.of(context)!).
  final String titleKey;

  /// ARB key for the description (resolved via S.of(context)!).
  final String descriptionKey;

  /// Material icon codepoint name for display.
  final String iconName;

  /// Whether this goal is relevant to the current profile.
  ///
  /// Irrelevant goals are filtered out — shown only when profile matches.
  final bool isRelevant;

  const SelectableGoal({
    required this.intentTag,
    required this.titleKey,
    required this.descriptionKey,
    required this.iconName,
    required this.isRelevant,
  });
}

/// Service for explicit goal selection.
///
/// All methods are static — no instantiation needed.
class GoalSelectionService {
  GoalSelectionService._();

  /// Returns the list of selectable goals, filtered by profile relevance.
  ///
  /// [profile] — current CoachProfile used for relevance checks.
  /// [l]       — localization instance (unused here — keys are ARB-resolved
  ///             by the widget layer, kept for symmetry with CapEngine API).
  ///
  /// Goals are always ordered: retirement → budget → tax → housing →
  /// debt → birth → self-employment.
  static List<SelectableGoal> availableGoals(
    CoachProfile profile,
    S l,
  ) {
    final age = profile.age;
    final isOwner = profile.housingStatus == 'proprio' ||
        profile.housingStatus == 'proprietaire';
    final isSalarie = profile.employmentStatus == 'salarie' ||
        profile.employmentStatus == 'employe';
    final hasDebt = profile.dettes.hasDette;

    return [
      // ── Retirement: always if age > 25 ───────────────────────────────────
      SelectableGoal(
        intentTag: 'retirement_choice',
        titleKey: 'goalRetirementTitle',
        descriptionKey: 'goalRetirementDesc',
        iconName: 'beach_access_outlined',
        isRelevant: age > 25,
      ),

      // ── Budget: always available ──────────────────────────────────────────
      const SelectableGoal(
        intentTag: 'budget_overview',
        titleKey: 'goalBudgetTitle',
        descriptionKey: 'goalBudgetDesc',
        iconName: 'account_balance_wallet_outlined',
        isRelevant: true,
      ),

      // ── Tax optimisation: always available ───────────────────────────────
      const SelectableGoal(
        intentTag: 'tax_optimization_3a',
        titleKey: 'goalTaxTitle',
        descriptionKey: 'goalTaxDesc',
        iconName: 'savings_outlined',
        isRelevant: true,
      ),

      // ── Housing: if no property and age < 55 ─────────────────────────────
      SelectableGoal(
        intentTag: 'housing_purchase',
        titleKey: 'goalHousingTitle',
        descriptionKey: 'goalHousingDesc',
        iconName: 'home_outlined',
        isRelevant: !isOwner && age < 55,
      ),

      // ── Debt: if declared debt or negative budget ─────────────────────────
      SelectableGoal(
        intentTag: 'debt_check',
        titleKey: 'goalDebtTitle',
        descriptionKey: 'goalDebtDesc',
        iconName: 'trending_down_outlined',
        isRelevant: hasDebt,
      ),

      // ── Birth: if age 25-45 ───────────────────────────────────────────────
      SelectableGoal(
        intentTag: 'life_event_birth',
        titleKey: 'goalBirthTitle',
        descriptionKey: 'goalBirthDesc',
        iconName: 'child_care_outlined',
        isRelevant: age >= 25 && age <= 45,
      ),

      // ── Self-employment: if currently salarié ────────────────────────────
      SelectableGoal(
        intentTag: 'self_employment',
        titleKey: 'goalIndependentTitle',
        descriptionKey: 'goalIndependentDesc',
        iconName: 'business_center_outlined',
        isRelevant: isSalarie,
      ),
    ].where((g) => g.isRelevant).toList();
  }

  /// Returns the currently selected goal intent tag, or null if none.
  ///
  /// Null means MINT auto-detects the goal from the profile.
  static Future<String?> getSelectedGoal(SharedPreferences prefs) async {
    return prefs.getString(_kSelectedGoalKey);
  }

  /// Persists [intentTag] as the user's explicit goal.
  static Future<void> setSelectedGoal(
    String intentTag,
    SharedPreferences prefs,
  ) async {
    await prefs.setString(_kSelectedGoalKey, intentTag);
  }

  /// Clears the explicit selection — reverts to auto-detect.
  static Future<void> clearSelectedGoal(SharedPreferences prefs) async {
    await prefs.remove(_kSelectedGoalKey);
  }

  /// Resolves an ARB title key to the localized string.
  ///
  /// Used by the widget layer to display goal titles.
  static String resolveTitle(String titleKey, S l) {
    switch (titleKey) {
      case 'goalRetirementTitle':
        return l.goalRetirementTitle;
      case 'goalBudgetTitle':
        return l.goalBudgetTitle;
      case 'goalTaxTitle':
        return l.goalTaxTitle;
      case 'goalHousingTitle':
        return l.goalHousingTitle;
      case 'goalDebtTitle':
        return l.goalDebtTitle;
      case 'goalBirthTitle':
        return l.goalBirthTitle;
      case 'goalIndependentTitle':
        return l.goalIndependentTitle;
      default:
        return titleKey;
    }
  }

  /// Resolves an ARB description key to the localized string.
  static String resolveDescription(String descriptionKey, S l) {
    switch (descriptionKey) {
      case 'goalRetirementDesc':
        return l.goalRetirementDesc;
      case 'goalBudgetDesc':
        return l.goalBudgetDesc;
      case 'goalTaxDesc':
        return l.goalTaxDesc;
      case 'goalHousingDesc':
        return l.goalHousingDesc;
      case 'goalDebtDesc':
        return l.goalDebtDesc;
      case 'goalBirthDesc':
        return l.goalBirthDesc;
      case 'goalIndependentDesc':
        return l.goalIndependentDesc;
      default:
        return descriptionKey;
    }
  }
}
