/// AI-powered Weekly Recap narrator.
///
/// Takes a structured WeeklyRecap + CoachProfile and generates
/// a personalized narrative summary via the coach LLM.
///
/// Fallback: if LLM unavailable, returns template-based summary.
///
/// See: MINT_FINAL_EXECUTION_SYSTEM.md Phase 3.2
library;

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/recap/weekly_recap_service.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart' show formatChf;

/// Generates an AI-narrated weekly recap.
class AiRecapNarrator {
  AiRecapNarrator._();

  /// Generate a personalized narrative from structured recap data.
  ///
  /// Uses the coach LLM to create a warm, actionable summary.
  /// Falls back to template if LLM is unavailable.
  static Future<String> narrate({
    required WeeklyRecap recap,
    required CoachProfile profile,
    required LlmConfig config,
  }) async {
    final prompt = _buildPrompt(recap, profile);

    try {
      if (!config.hasApiKey) {
        return templateFallback(recap, profile);
      }

      final response = await CoachLlmService.chat(
        userMessage: '$_systemPrompt\n\n$prompt',
        profile: profile,
        history: const [],
        config: config,
      );

      if (response.message.trim().isEmpty) {
        return templateFallback(recap, profile);
      }

      return response.message.trim();
    } catch (_) {
      return templateFallback(recap, profile);
    }
  }

  static const _systemPrompt = '''Tu es le coach MINT. Rédige un résumé hebdomadaire personnalisé.

Règles:
- Ton calme, précis, encourageant (pas scolaire)
- 3-5 phrases maximum
- Commence par le fait le plus marquant de la semaine
- Termine par la prochaine action la plus utile
- Utilise "tu" (informel)
- Ne jamais dire "garanti", "optimal", "meilleur", "parfait"
- Si les données sont incomplètes, dis-le honnêtement
- Pas de formules creuses — chaque phrase doit avoir une info concrète

Format: texte brut, pas de markdown, pas de bullet points.''';

  static String _buildPrompt(WeeklyRecap recap, CoachProfile profile) {
    final buf = StringBuffer();
    buf.writeln('Données de la semaine du ${_formatDate(recap.weekStart)} au ${_formatDate(recap.weekEnd)}:');
    buf.writeln();

    if (recap.budget != null) {
      final b = recap.budget!;
      buf.writeln('Budget: revenus ~CHF ${formatChf(b.totalIncome)}, dépenses ~CHF ${formatChf(b.totalSpent)}, épargne CHF ${formatChf(b.savedAmount)} (${(b.savingsRate * 100).round()}%)');
    } else {
      buf.writeln('Budget: données insuffisantes');
    }

    buf.writeln('Jours actifs: ${recap.actions.length}/7');

    if (recap.progress != null) {
      final p = recap.progress!;
      buf.writeln('Confiance: ${p.confidenceBefore.round()} → ${p.confidenceAfter.round()} (${p.delta >= 0 ? '+' : ''}${p.delta.round()} pts)');
    }

    if (recap.highlights.isNotEmpty) {
      buf.writeln('Points forts: ${recap.highlights.take(3).join(', ')}');
    }

    if (recap.nextWeekFocus != null) {
      buf.writeln('Focus suggéré: ${recap.nextWeekFocus}');
    }

    buf.writeln();
    buf.writeln('Profil: ${profile.age} ans, canton ${profile.canton}, ${recap.activeGoals} objectif(s) actif(s).');

    return buf.toString();
  }

  /// Template-based fallback when LLM is unavailable.
  /// Public for use when BYOK is not configured.
  static String templateFallback(WeeklyRecap recap, CoachProfile profile) {
    final buf = StringBuffer();

    if (recap.actions.isNotEmpty) {
      buf.write('Cette semaine, tu as été actif ${recap.actions.length} jour(s) sur MINT. ');
    } else {
      buf.write('Cette semaine a été calme sur MINT. ');
    }

    if (recap.budget != null && recap.budget!.savedAmount > 0) {
      buf.write('Ton épargne estimée est de CHF\u00a0${formatChf(recap.budget!.savedAmount)}. ');
    }

    if (recap.progress != null && recap.progress!.delta > 0) {
      buf.write('Ta confiance a progressé de +${recap.progress!.delta.round()}\u00a0pts. ');
    }

    if (recap.nextWeekFocus != null) {
      buf.write('La semaine prochaine, concentre-toi sur ${recap.nextWeekFocus}.');
    }

    return buf.toString().trim();
  }

  static String _formatDate(DateTime d) =>
      '${d.day}.${d.month.toString().padLeft(2, '0')}';
}
