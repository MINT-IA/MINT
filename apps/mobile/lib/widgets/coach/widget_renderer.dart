import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/services/backend_coach_service.dart';
import 'package:mint_mobile/widgets/coach/chat_inline_inputs.dart';
import 'package:mint_mobile/widgets/coach/rich_chat_widgets.dart';

// ────────────────────────────────────────────────────────────
//  WIDGET RENDERER — S56
// ────────────────────────────────────────────────────────────
//
//  Transforms a WidgetCall (from Claude tool_use) into a Flutter
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
    WidgetCall call, {
    void Function(String field, String value)? onInputSubmitted,
  }) {
    switch (call.tool) {
      case 'show_retirement_comparison':
        return _buildRetirementComparison(context, call.params);
      case 'show_budget_overview':
        return _buildBudgetOverview(context, call.params);
      case 'show_score_gauge':
        return _buildScoreGauge(context, call.params);
      case 'show_fact_card':
        return _buildFactCard(context, call.params);
      case 'show_choice_comparison':
        return _buildChoiceComparison(context, call.params);
      case 'show_pillar_breakdown':
        return _buildPillarBreakdown(context, call.params);
      case 'ask_user_input':
        return _buildInputRequest(context, call.params, onInputSubmitted);
      default:
        return null;
    }
  }

  static Widget _buildRetirementComparison(
      BuildContext context, Map<String, dynamic> p) {
    return ChatComparisonCard(
      title: 'Ton apercu retraite',
      leftLabel: 'Aujourd\'hui',
      leftValue: 'CHF ${_fmt(p['today_monthly'])}/mois',
      rightLabel: 'A la retraite',
      rightValue: 'CHF ${_fmt(p['retirement_monthly'])}/mois',
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
      leftValue: 'CHF ${_fmt(p['income_monthly'])}/mois',
      rightLabel: 'Depenses',
      rightValue: 'CHF ${_fmt(p['expenses_monthly'])}/mois',
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
      valueLabel: p['label'] as String? ?? '—',
      narrative: p['narrative'] as String?,
    );
  }

  static Widget _buildFactCard(
      BuildContext context, Map<String, dynamic> p) {
    final route = p['route'] as String?;
    return ChatFactCard(
      eyebrow: p['eyebrow'] as String? ?? '',
      value: p['value'] as String? ?? '—',
      description: p['description'] as String? ?? '',
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
      leftValue: 'CHF ${_fmt(avs + lpp)}/mois',
      rightLabel: '3e pilier',
      rightValue: p3a > 0 ? 'CHF ${_fmt(p3a)}/mois' : 'Non declare',
      leftAmount: avs + lpp,
      rightAmount: p3a > 0 ? p3a : total * 0.1,
      narrative: p['narrative'] as String?,
      onTap: () => context.push('/retraite'),
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
    final field = p['field'] as String? ?? '';
    final message = p['message'] as String?;

    switch (field) {
      case 'age':
        return ChatAgePicker(
          label: message,
          initialAge: 35,
          onSelected: (age) {
            onInputSubmitted?.call('age', '$age');
          },
        );

      case 'salary':
        return ChatAmountInput(
          label: message ?? 'Ton revenu brut annuel',
          onSubmitted: (amount) {
            onInputSubmitted?.call('salary', '${amount.round()}');
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
