import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/services/coach/chat_tool_dispatcher.dart';
import 'package:mint_mobile/services/coach/tool_call_parser.dart';
import 'package:mint_mobile/services/navigation/route_planner.dart';
import 'package:mint_mobile/services/navigation/screen_registry.dart';
import 'package:mint_mobile/services/plan_generation_service.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/coach/chat_inline_inputs.dart';
import 'package:mint_mobile/widgets/coach/check_in_summary_card.dart';
import 'package:mint_mobile/widgets/coach/plan_preview_card.dart';
import 'package:mint_mobile/widgets/coach/rich_chat_widgets.dart';
import 'package:mint_mobile/widgets/coach/route_suggestion_card.dart';
import 'package:provider/provider.dart';

// ────────────────────────────────────────────────────────────
//  WIDGET RENDERER — S56 (restored + adapted for RagToolCall)
// ────────────────────────────────────────────────────────────
//
//  Transforms a RagToolCall (from Claude tool_use) into a Flutter
//  widget for inline display in the coach chat.
//
//  Claude chooses the tool + params → Backend returns them →
//  Flutter calls WidgetRenderer.build() → Rich widget in chat.
//
//  Also handles `ask_user_input` tool calls from Claude, which
//  display inline pickers (age, salary, canton, etc.) in the chat.
//  When the user answers, the onInputSubmitted callback fires to
//  update the profile and continue the conversation.
// ────────────────────────────────────────────────────────────

class WidgetRenderer {
  WidgetRenderer._();

  /// Build a rich chat widget from a Claude tool call.
  /// Returns null if the tool is unknown or params are invalid.
  ///
  /// [onInputSubmitted] — callback fired when the user responds to an
  /// `ask_user_input` picker. Parameters: (field, displayValue).
  /// The caller is responsible for updating the profile and sending
  /// the value as a chat message.
  static Widget? build(
    BuildContext context,
    RagToolCall call, {
    void Function(String field, String value)? onInputSubmitted,
  }) {
    switch (call.name) {
      case 'show_retirement_comparison':
        return _buildRetirementComparison(context, call.input);
      case 'show_budget_overview':
        return _buildBudgetOverview(context, call.input);
      case 'show_score_gauge':
        return _buildScoreGauge(context, call.input);
      case 'show_fact_card':
        return _buildFactCard(context, call.input);
      case 'show_choice_comparison':
        return _buildChoiceComparison(context, call.input);
      case 'show_pillar_breakdown':
        return _buildPillarBreakdown(context, call.input);
      case 'show_budget_snapshot':
        return _buildBudgetSnapshot(context, call.input);
      case 'show_comparison_card':
        return _buildComparisonCard(context, call.input);
      case 'ask_user_input':
        return _buildInputRequest(context, call.input, onInputSubmitted);
      case 'route_to_screen':
        return _buildRouteSuggestion(context, call.input);
      case 'generate_financial_plan':
        return _buildPlanPreviewCard(context, call.input);
      case 'record_check_in':
        return _buildCheckInSummaryCard(context, call.input);
      case 'generate_document':
        return _buildDocumentGenerationCard(context, call.input);
      default:
        return null;
    }
  }

  // ────────────────────────────────────────────────────────────
  //  ROUTE SUGGESTION — route_to_screen tool (T-02-03)
  // ────────────────────────────────────────────────────────────

  /// Build a [RouteSuggestionCard] when Claude suggests navigating to a screen.
  ///
  /// The coach proposes; the user decides. No automatic push happens here.
  /// Route validation via [ToolCallParser.isValidRoute] whitelist (T-02-03).
  /// Invalid routes return [SizedBox.shrink()] — silently dropped.
  ///
  /// Prefill merge strategy (T-06-01):
  ///   1. Read backend prefill from tool call input (LLM-provided).
  ///   2. Ask [RoutePlanner] for Flutter-side prefill from [CoachProfile].
  ///   3. Merge: RoutePlanner values as base, backend values win on conflict.
  ///   4. Result → [RouteSuggestionCard.prefill] → GoRouter extra on tap.
  static Widget _buildRouteSuggestion(
      BuildContext context, Map<String, dynamic> p) {
    // STAB-01 / D-02: backend emits {intent, confidence, context_message}
    // WITHOUT an explicit route. Resolve via ChatToolDispatcher (which uses
    // MintScreenRegistry as the canonical intent→route map) before falling
    // back to the legacy `route` key.
    final explicitRoute = p['route'] as String? ?? '';
    final resolvedRoute = explicitRoute.isNotEmpty &&
            ToolCallParser.isValidRoute(explicitRoute)
        ? explicitRoute
        : ChatToolDispatcher.resolveRoute(p);
    if (resolvedRoute == null || resolvedRoute.isEmpty) {
      return const SizedBox.shrink();
    }
    final route = resolvedRoute;
    final contextMessage = p['context_message'] as String? ??
        p['narrative'] as String? ??
        '';
    final backendPrefill = p['prefill'] as Map<String, dynamic>?;

    // Flutter-side prefill fallback via RoutePlanner
    Map<String, dynamic>? mergedPrefill = backendPrefill;
    try {
      final profileProvider = context.read<CoachProfileProvider>();
      final profile = profileProvider.profile;
      if (profile != null) {
        final intent = p['intent'] as String?;
        if (intent != null) {
          final planner = RoutePlanner(
            registry: const MintScreenRegistry(),
            profile: profile,
          );
          final decision = planner.plan(intent);
          if (decision.prefill != null && decision.prefill!.isNotEmpty) {
            // Merge: backend prefill wins on conflict
            mergedPrefill = {
              ...decision.prefill!,
              if (backendPrefill != null) ...backendPrefill,
            };
          }
        }
      }
    } catch (_) {
      // Profile or RoutePlanner not available — use backend prefill only
    }

    final isPartial = mergedPrefill == null || mergedPrefill.isEmpty;

    return RouteSuggestionCard(
      contextMessage: contextMessage,
      route: route,
      prefill: mergedPrefill,
      isPartial: isPartial,
    );
  }

  static Widget _buildRetirementComparison(
      BuildContext context, Map<String, dynamic> p) {
    return ChatComparisonCard(
      title: 'Ton aper\u00e7u retraite',
      leftLabel: 'Aujourd\u2019hui',
      leftValue: 'CHF\u00a0${_fmt(p['today_monthly'])}/mois',
      rightLabel: '\u00c0 la retraite',
      rightValue: 'CHF\u00a0${_fmt(p['retirement_monthly'])}/mois',
      leftAmount: (p['today_monthly'] as num?)?.toDouble() ?? 0,
      rightAmount: (p['retirement_monthly'] as num?)?.toDouble() ?? 0,
      narrative: p['narrative'] as String?,
      onTap: () => context.push('/retraite'),
    );
  }

  static Widget _buildBudgetOverview(
      BuildContext context, Map<String, dynamic> p) {
    return ChatComparisonCard(
      title: 'Ton budget',
      leftLabel: 'Revenus',
      leftValue: 'CHF\u00a0${_fmt(p['income_monthly'])}/mois',
      rightLabel: 'D\u00e9penses',
      rightValue: 'CHF\u00a0${_fmt(p['expenses_monthly'])}/mois',
      leftAmount: (p['income_monthly'] as num?)?.toDouble() ?? 0,
      rightAmount: (p['expenses_monthly'] as num?)?.toDouble() ?? 0,
      narrative: p['narrative'] as String?,
      onTap: () => context.push('/budget'),
    );
  }

  static Widget _buildScoreGauge(
      BuildContext context, Map<String, dynamic> p) {
    return ChatGaugeCard(
      title: p['title'] as String? ?? 'Score',
      value: (p['value'] as num?)?.toDouble() ?? 0,
      maxValue: (p['max_value'] as num?)?.toDouble() ?? 100,
      valueLabel: p['label'] as String? ?? '\u2014',
      narrative: p['narrative'] as String?,
    );
  }

  static Widget _buildFactCard(
      BuildContext context, Map<String, dynamic> p) {
    final route = p['route'] as String?;
    return ChatFactCard(
      eyebrow: p['eyebrow'] as String? ?? p['title'] as String? ?? '',
      value: p['value'] as String? ?? p['highlight_value'] as String? ?? '\u2014',
      description: p['description'] as String? ?? p['content'] as String? ?? '',
      onTap: route != null ? () => context.push(route) : null,
    );
  }

  static Widget _buildChoiceComparison(
      BuildContext context, Map<String, dynamic> p) {
    final route = p['route'] as String?;
    return ChatChoiceComparison(
      title: p['title'] as String? ?? '',
      leftTitle: p['left_title'] as String? ?? '',
      leftValue: p['left_value'] as String? ?? '',
      leftDescription: p['left_description'] as String? ?? '',
      rightTitle: p['right_title'] as String? ?? '',
      rightValue: p['right_value'] as String? ?? '',
      rightDescription: p['right_description'] as String? ?? '',
      onTap: route != null ? () => context.push(route) : null,
    );
  }

  static Widget _buildPillarBreakdown(
      BuildContext context, Map<String, dynamic> p) {
    final avs = (p['avs_monthly'] as num?)?.toDouble() ?? 0;
    final lpp = (p['lpp_monthly'] as num?)?.toDouble() ?? 0;
    final p3a = (p['pillar_3a_monthly'] as num?)?.toDouble() ?? 0;
    final total = avs + lpp + p3a;

    return ChatComparisonCard(
      title: 'Tes 3 piliers',
      leftLabel: 'AVS + LPP',
      leftValue: 'CHF\u00a0${_fmt(avs + lpp)}/mois',
      rightLabel: '3e pilier',
      rightValue: p3a > 0 ? 'CHF\u00a0${_fmt(p3a)}/mois' : 'Non d\u00e9clar\u00e9',
      leftAmount: avs + lpp,
      rightAmount: p3a > 0 ? p3a : total * 0.1,
      narrative: p['narrative'] as String?,
      onTap: () => context.push('/retraite'),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  COMPARISON CARD — show_comparison_card tool
  // ────────────────────────────────────────────────────────────

  static Widget _buildComparisonCard(
      BuildContext context, Map<String, dynamic> p) {
    final route = p['route'] as String?;
    return ChatComparisonCard(
      title: p['title'] as String? ?? '',
      leftLabel: p['left_label'] as String? ?? '',
      leftValue: p['left_value'] as String? ?? '',
      rightLabel: p['right_label'] as String? ?? '',
      rightValue: p['right_value'] as String? ?? '',
      leftAmount: (p['left_amount'] as num?)?.toDouble() ?? 0,
      rightAmount: (p['right_amount'] as num?)?.toDouble() ?? 0,
      narrative: p['narrative'] as String?,
      onTap: route != null ? () => context.push(route) : null,
    );
  }

  // ────────────────────────────────────────────────────────────
  //  BUDGET SNAPSHOT — show_budget_snapshot tool
  // ────────────────────────────────────────────────────────────

  static Widget _buildBudgetSnapshot(
      BuildContext context, Map<String, dynamic> p) {
    final presentFree = (p['present_free'] as num?)?.toDouble() ?? 0;
    final retirementFree = (p['retirement_free'] as num?)?.toDouble();
    final gap = (p['gap'] as num?)?.toDouble();
    final confidence = (p['confidence'] as num?)?.toInt();
    final narrative = p['narrative'] as String?;
    final leverNow = p['lever_now'] as String?;
    final leverLater = p['lever_later'] as String?;

    if (retirementFree != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChatComparisonCard(
            title: 'Ton budget vivant',
            leftLabel: 'Libre aujourd\u2019hui',
            leftValue: 'CHF\u00a0${_fmt(presentFree)}/mois',
            rightLabel: 'Libre retraite',
            rightValue: 'CHF\u00a0${_fmt(retirementFree)}/mois',
            leftAmount: presentFree,
            rightAmount: retirementFree,
            narrative: gap != null
                ? '\u00c9cart\u00a0: CHF\u00a0${_fmt(gap.abs())}/mois'
                : narrative,
            onTap: () => context.push('/retraite'),
          ),
          if (confidence != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ChatFactCard(
                eyebrow: 'Fiabilit\u00e9',
                value: '$confidence\u00a0%',
                description: confidence < 50
                    ? 'Ajoute des donn\u00e9es pour affiner.'
                    : 'Estimation cr\u00e9dible.',
              ),
            ),
          if (leverNow != null || leverLater != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ChatFactCard(
                eyebrow: 'Levier',
                value: leverNow ?? leverLater ?? '',
                description: leverLater != null && leverNow != null
                    ? leverLater
                    : narrative ?? '',
              ),
            ),
        ],
      );
    }

    return ChatFactCard(
      eyebrow: 'Budget',
      value: 'CHF\u00a0${_fmt(presentFree)}/mois',
      description: narrative ?? 'Ton libre mensuel',
      onTap: () => context.push('/budget'),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  INPUT REQUEST — ask_user_input tool
  // ────────────────────────────────────────────────────────────

  /// Build an inline input picker based on the `field` parameter.
  /// Claude calls `ask_user_input` with {field, message} when it
  /// needs a missing profile value. The picker appears inline in the
  /// chat. When the user selects a value, [onInputSubmitted] fires.
  static Widget? _buildInputRequest(
    BuildContext context,
    Map<String, dynamic> p,
    void Function(String field, String value)? onInputSubmitted,
  ) {
    final field = p['field_key'] as String? ?? p['field'] as String? ?? '';
    final message = p['prompt_text'] as String? ?? p['message'] as String?;

    switch (field) {
      case 'name':
        // Name is collected via normal text input, not a picker.
        return null;

      case 'age':
        return ChatAgePicker(
          label: message,
          initialAge: 35,
          onSelected: (age) {
            onInputSubmitted?.call('age', '$age');
          },
        );

      case 'salary':
      case 'salaireBrut':
        return ChatAmountInput(
          label: message ?? 'Ton revenu brut annuel',
          onSubmitted: (amount) {
            onInputSubmitted?.call('salaireBrut', '${amount.round()}');
          },
        );

      case 'avoirLpp':
        return ChatAmountInput(
          label: message ?? 'Avoir LPP (CHF)',
          onSubmitted: (amount) {
            onInputSubmitted?.call('avoirLpp', '${amount.round()}');
          },
        );

      case 'epargne3a':
        return ChatAmountInput(
          label: message ?? '\u00c9pargne 3a (CHF)',
          onSubmitted: (amount) {
            onInputSubmitted?.call('epargne3a', '${amount.round()}');
          },
        );

      case 'canton':
        return ChatCantonPicker(
          label: message,
          onSelected: (canton) {
            onInputSubmitted?.call('canton', canton);
          },
        );

      case 'civil_status':
        return ChatChoiceButtons(
          label: message,
          choices: const [
            'C\u00e9libataire',
            'Mari\u00e9\u00b7e',
            'Divorc\u00e9\u00b7e',
            'En concubinage',
          ],
          onSelected: (choice) {
            onInputSubmitted?.call('civil_status', choice);
          },
        );

      case 'employment_status':
        return ChatChoiceButtons(
          label: message,
          choices: const [
            'Salari\u00e9\u00b7e',
            'Ind\u00e9pendant\u00b7e',
            'Sans emploi',
          ],
          onSelected: (choice) {
            onInputSubmitted?.call('employment_status', choice);
          },
        );

      case 'children':
        return ChatChoiceButtons(
          label: message,
          choices: const ['0', '1', '2', '3', '4+'],
          onSelected: (choice) {
            onInputSubmitted?.call('children', choice);
          },
        );

      case 'choice':
        final choices = (p['choices'] as List<dynamic>?)
            ?.map((c) => c.toString())
            .toList();
        if (choices == null || choices.isEmpty) return null;
        return ChatChoiceButtons(
          label: message,
          choices: choices,
          onSelected: (choice) {
            onInputSubmitted?.call('choice', choice);
          },
        );

      default:
        return null;
    }
  }

  static String _fmt(dynamic n) {
    if (n == null) return '\u2014';
    final num value = n is num ? n : 0;
    final rounded = value.round();
    return rounded.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => "${m[1]}'");
  }

  // ────────────────────────────────────────────────────────────
  //  PLAN PREVIEW CARD — generate_financial_plan tool (T-04-04)
  // ────────────────────────────────────────────────────────────

  /// Build a [PlanPreviewCard] for the `generate_financial_plan` tool call.
  ///
  /// T-04-04: Numbers come from the PERSISTED plan (calculator-backed via
  /// [FinancialPlanProvider]), NOT from [call.input] (LLM output).
  /// Only [coachNarrative] may be sourced from [call.input['narrative']].
  ///
  /// If no persisted plan exists yet, triggers [PlanGenerationService.generate()]
  /// asynchronously via Future.microtask, persists via [FinancialPlanProvider.setPlan()],
  /// and shows a fallback preview card while generation is in progress.
  /// The chat rebuilds automatically when the provider notifies listeners.
  static Widget _buildPlanPreviewCard(
    BuildContext context,
    Map<String, dynamic> p,
  ) {
    final planProvider =
        Provider.of<FinancialPlanProvider>(context, listen: false);

    // ── 1. If a calculator-backed plan already exists, use it (T-04-04) ──
    if (planProvider.hasPlan) {
      final plan = planProvider.currentPlan!;
      final narrative = p['narrative'] as String?;
      if (narrative != null && narrative.isNotEmpty) {
        return PlanPreviewCard.fromPlan(
          plan.copyWith(coachNarrative: narrative),
        );
      }
      return PlanPreviewCard.fromPlan(plan);
    }

    // ── 2. No plan yet — trigger generation via PlanGenerationService ──
    final goal = p['goal'] as String? ?? p['goal_description'] as String? ?? '';
    final narrative =
        p['narrative'] as String? ?? 'Plan en cours de calcul\u2026';
    final monthlyAmount =
        (p['monthly_amount'] as num?)?.toDouble() ??
        (p['monthly_target'] as num?)?.toDouble() ??
        0.0;

    // Fire-and-forget: generate plan and persist. Provider will notify
    // listeners, causing the chat to rebuild with the real plan.
    try {
      final profileProvider = context.read<CoachProfileProvider>();
      final profile = profileProvider.profile;
      if (profile != null) {
        Future.microtask(() async {
          try {
            final plan = await PlanGenerationService.generate(
              goalDescription: goal,
              goalCategory: 'goal_general',
              targetDate: DateTime.now().add(const Duration(days: 365)),
              profile: profile,
              coachNarrative: narrative,
              goalAmount: monthlyAmount > 0 ? monthlyAmount * 12 : null,
            );
            planProvider.setPlan(plan);
          } catch (_) {
            // Generation failed — fallback card remains visible
          }
        });
      }
    } catch (_) {
      // Profile provider not available — show fallback
    }

    // ── 3. Show fallback preview while generation is in progress ──
    return PlanPreviewCard(
      goalDescription: goal,
      monthlyTarget: monthlyAmount,
      milestones: const [],
      coachNarrative: narrative,
      disclaimer:
          'Outil \u00e9ducatif \u2014 ne constitue pas un conseil financier (LSFin).',
      projectedMid: monthlyAmount * 12,
      confidenceLevel: 0,
    );
  }

  // ────────────────────────────────────────────────────────────
  //  CHECK-IN SUMMARY — record_check_in tool (T-05-01)
  // ────────────────────────────────────────────────────────────

  /// Build a [CheckInSummaryCard] for the `record_check_in` tool call.
  ///
  /// T-05-04 (Tampering mitigation): Validates all required fields before
  /// creating MonthlyCheckIn. Returns null on invalid input — no card,
  /// no persistence.
  ///
  /// Persists the check-in to [CoachProfileProvider] BEFORE displaying
  /// the card (T-05-04: persist before display).
  static Widget? _buildCheckInSummaryCard(
    BuildContext context,
    Map<String, dynamic> input,
  ) {
    final month = input['month'] as String?;
    final versementsRaw = input['versements'] as Map<String, dynamic>?;
    final summaryMessage = input['summary_message'] as String?;

    // T-05-04: Validate all required fields and numeric types
    if (month == null || versementsRaw == null || summaryMessage == null) {
      return null;
    }

    // T-05-04: Validate versements are numeric map
    Map<String, double> versements;
    try {
      versements = versementsRaw.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      );
    } catch (_) {
      // Non-numeric versements value — reject the tool call
      return null;
    }

    // Persist check-in to CoachProfile BEFORE displaying card (T-05-04)
    final provider = context.read<CoachProfileProvider>();
    final checkIn = MonthlyCheckIn(
      month: DateTime.tryParse('$month-01') ?? DateTime.now(),
      versements: versements,
      completedAt: DateTime.now(),
    );
    provider.addCheckIn(checkIn);

    return CheckInSummaryCard(
      summaryMessage: summaryMessage,
      versements: versements,
      month: month,
    );
  }

  // ────────────────────────────────────────────────────────────
  //  DOCUMENT GENERATION — generate_document tool (STAB-02)
  // ────────────────────────────────────────────────────────────

  /// Build a minimal inline card announcing a pending document generation.
  ///
  /// STAB-02 / D-03: the backend emits `generate_document` with
  /// `{document_type, context}`. The full document generation pipeline
  /// (FormPrefillService / LetterGenerationService + AgentValidationGate +
  /// DocumentCard) is heavier and requires async work; for STAB-02 we
  /// surface a tappable chip card so the tool call is user-visible instead
  /// of hitting `SizedBox.shrink()`. Tapping routes the user to `/documents`
  /// where the full pipeline runs.
  static Widget _buildDocumentGenerationCard(
    BuildContext context,
    Map<String, dynamic> p,
  ) {
    final documentType = p['document_type'] as String? ?? '';
    final contextMessage = p['context'] as String? ??
        p['narrative'] as String? ??
        '';

    final label = _documentTypeLabel(documentType);

    return Container(
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MintColors.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.description_outlined,
                size: 18,
                color: MintColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: MintTextStyles.labelMedium(
                  color: MintColors.textPrimary,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (contextMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              contextMessage,
              style: MintTextStyles.bodySmall(
                color: MintColors.textSecondary,
              ).copyWith(height: 1.4),
            ),
          ],
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push('/documents'),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: MintColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pr\u00e9parer le document',
                    style: MintTextStyles.labelSmall(
                      color: MintColors.primary,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: MintColors.primary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Outil \u00e9ducatif \u2014 MINT pr\u00e9pare, tu valides. '
            'Ne constitue pas un conseil financier (LSFin).',
            style: MintTextStyles.micro(
              color: MintColors.textMuted,
            ).copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  static String _documentTypeLabel(String type) {
    switch (type) {
      case 'fiscal_declaration':
        return 'D\u00e9claration fiscale';
      case 'pension_fund_letter':
        return 'Lettre caisse de pension';
      case 'lpp_buyback_request':
        return 'Demande de rachat LPP';
      default:
        return 'Document';
    }
  }
}
