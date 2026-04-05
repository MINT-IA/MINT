import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/coach/tool_call_parser.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/widgets/coach/chat_inline_inputs.dart';
import 'package:mint_mobile/widgets/coach/rich_chat_widgets.dart';
import 'package:mint_mobile/widgets/coach/route_suggestion_card.dart';

// ────────────────────────────────────────────────────────────
//  WIDGET RENDERER — S56 (restored + adapted)
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
  static Widget _buildRouteSuggestion(
      BuildContext context, Map<String, dynamic> p) {
    final route = p['route'] as String? ?? '';
    final contextMessage = p['context_message'] as String? ??
        p['narrative'] as String? ??
        '';
    final prefill = p['prefill'] as Map<String, dynamic>?;
    final isPartial = p['is_partial'] as bool? ?? false;
    if (!ToolCallParser.isValidRoute(route)) return const SizedBox.shrink();
    return RouteSuggestionCard(
      contextMessage: contextMessage,
      route: route,
      prefill: prefill,
      isPartial: isPartial,
    );
  }

  static Widget _buildRetirementComparison(
      BuildContext context, Map<String, dynamic> p) {
    final l = S.of(context);
    return ChatComparisonCard(
      title: l?.widgetRetirementTitle ?? 'Ton aper\u00e7u retraite',
      leftLabel: l?.widgetRetirementToday ?? 'Aujourd\u2019hui',
      leftValue: 'CHF\u00a0${_fmt(p['today_monthly'])}/mois',
      rightLabel: l?.widgetRetirementFuture ?? '\u00c0 la retraite',
      rightValue: 'CHF\u00a0${_fmt(p['retirement_monthly'])}/mois',
      leftAmount: (p['today_monthly'] as num?)?.toDouble() ?? 0,
      rightAmount: (p['retirement_monthly'] as num?)?.toDouble() ?? 0,
      narrative: p['narrative'] as String?,
      onTap: () => context.push('/retraite'),
    );
  }

  static Widget _buildBudgetOverview(
      BuildContext context, Map<String, dynamic> p) {
    final l = S.of(context);
    return ChatComparisonCard(
      title: l?.widgetBudgetTitle ?? 'Ton budget',
      leftLabel: l?.widgetBudgetIncome ?? 'Revenus',
      leftValue: 'CHF\u00a0${_fmt(p['income_monthly'])}/mois',
      rightLabel: l?.widgetBudgetExpenses ?? 'D\u00e9penses',
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
      title: p['title'] as String? ?? S.of(context)?.widgetScoreFallback ?? 'Score',
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

    final l = S.of(context);
    return ChatComparisonCard(
      title: l?.widgetPillarTitle ?? 'Tes 3 piliers',
      leftLabel: l?.widgetPillarAvsLpp ?? 'AVS + LPP',
      leftValue: 'CHF\u00a0${_fmt(avs + lpp)}/mois',
      rightLabel: l?.widgetPillar3a ?? '3e pilier',
      rightValue: p3a > 0 ? 'CHF\u00a0${_fmt(p3a)}/mois' : (l?.widgetPillarNotDeclared ?? 'Non d\u00e9clar\u00e9'),
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

    final l = S.of(context);

    if (retirementFree != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChatComparisonCard(
            title: l?.budgetSnapshotTitle ?? 'Ton budget vivant',
            leftLabel: l?.budgetSnapshotPresentLabel ?? 'Libre aujourd\u2019hui',
            leftValue: 'CHF\u00a0${_fmt(presentFree)}/mois',
            rightLabel: l?.budgetSnapshotRetirementLabel ?? 'Libre retraite',
            rightValue: 'CHF\u00a0${_fmt(retirementFree)}/mois',
            leftAmount: presentFree,
            rightAmount: retirementFree,
            narrative: gap != null
                ? '${l?.budgetSnapshotGapLabel ?? "\u00c9cart"}\u00a0: CHF\u00a0${_fmt(gap.abs())}/mois'
                : narrative,
            onTap: () => context.push('/retraite'),
          ),
          if (confidence != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ChatFactCard(
                eyebrow: l?.budgetSnapshotConfidenceLabel ?? 'Fiabilit\u00e9',
                value: '$confidence\u00a0%',
                description: confidence < 50
                    ? (l?.budgetSnapshotConfidenceLow ?? 'Ajoute des donn\u00e9es pour affiner.')
                    : (l?.budgetSnapshotConfidenceOk ?? 'Estimation cr\u00e9dible.'),
              ),
            ),
          if (leverNow != null || leverLater != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ChatFactCard(
                eyebrow: l?.budgetSnapshotLeverLabel ?? 'Levier',
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
      eyebrow: l?.widgetBudgetLabel ?? 'Budget',
      value: 'CHF\u00a0${_fmt(presentFree)}/mois',
      description: narrative ?? (l?.budgetSnapshotFreeLabel ?? 'Ton libre mensuel'),
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
          label: message ?? S.of(context)?.onboardingSmartSalaryLabel ?? S.of(context)?.widgetInputSalaryFallback ?? 'Salary',
          onSubmitted: (amount) {
            onInputSubmitted?.call('salaireBrut', '${amount.round()}');
          },
        );

      case 'avoirLpp':
        return ChatAmountInput(
          label: message ?? S.of(context)?.widgetInputLppLabel ?? 'Avoir LPP (CHF)',
          onSubmitted: (amount) {
            onInputSubmitted?.call('avoirLpp', '${amount.round()}');
          },
        );

      case 'epargne3a':
        return ChatAmountInput(
          label: message ?? S.of(context)?.widgetInput3aLabel ?? '\u00c9pargne 3a (CHF)',
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
}
