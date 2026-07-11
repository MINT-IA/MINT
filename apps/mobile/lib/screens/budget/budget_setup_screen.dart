import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:provider/provider.dart';

/// Structured fixed-charges entry form — MVP P0-MVP-3.
///
/// The previous Mon argent "Commencer" CTA routed straight to the coach
/// with `topic=budget`, which produced a dead-end loop: the coach chat
/// couldn't reliably persist financial values (save_fact is stripped
/// before reaching Flutter and anonymous users hit `Hors-DB path`), so
/// users could spend ten turns in a chat about their rent without any
/// field ever landing on `CoachProfile.depenses`.
///
/// This screen is the explicit, deterministic alternative. Seven fixed-
/// charge fields, two required, five optional behind a progressive
/// disclosure. No sliders, no pickers, no categorisation tree — just
/// `TextField` + numeric keyboard, per `feedback_no_sliders_ux` and
/// `feedback_modern_inputs_no_sliders`.
///
/// Pre-fills each field from persisted canonical answers only, so previously
/// captured values (scan, wizard, coach-chat inline) stay visible and editable
/// without promoting `CoachProfile` defaults/estimates to user facts.
///
/// The chat remains available as an explicit fallback link at the
/// bottom — doctrine `chat_is_everything` is respected ("all data
/// *can* go through chat"), not bent into "must".
class BudgetSetupScreen extends StatefulWidget {
  final String? initialFocus;

  const BudgetSetupScreen({super.key, this.initialFocus});

  @override
  State<BudgetSetupScreen> createState() => _BudgetSetupScreenState();
}

class _BudgetSetupScreenState extends State<BudgetSetupScreen> {
  final _housing = TextEditingController();
  final _lamal = TextEditingController();
  final _transport = TextEditingController();
  final _telecom = TextEditingController();
  final _electricity = TextEditingController();
  final _medical = TextEditingController();
  final _other = TextEditingController();
  final _housingFocus = FocusNode();
  int? _lamalFranchise;
  bool _showOptional = false;
  bool _saving = false;

  // Median Swiss monthly values used as field placeholders. These are
  // informative examples, not defaults — the field stays empty until
  // the user types. Numbers held tight: rounded to readable amounts, no
  // decimals, within the statistically-observed range for a single
  // Swiss adult (OFS household-budget survey 2023). Not LSFin advice,
  // purely illustrative guidance per feedback_no_vague_language.
  static const _placeholderHousing = '2400';
  static const _placeholderLamal = '380';
  static const _placeholderTransport = '200';
  static const _placeholderTelecom = '80';
  static const _placeholderElectricity = '90';
  static const _placeholderMedical = '120';
  static const _placeholderOther = '250';
  static const _lamalFranchiseLevels = [300, 500, 1000, 1500, 2000, 2500];

  @override
  void initState() {
    super.initState();
    _showOptional = widget.initialFocus == 'lamal';
    // Pre-fill from the ledger answers, not from CoachProfile.depenses:
    // CoachProfile may contain derived/default amounts for calculations, while
    // this screen must only display facts the user has actually supplied.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final answers = await ReportPersistenceService.loadAnswers();
      if (!mounted) return;
      _housing.text = _formatAnswerAmount(answers['q_housing_cost_period_chf']);
      _lamal.text = _formatAnswerAmount(answers['q_lamal_premium_monthly_chf']);
      _transport.text =
          _formatAnswerAmount(answers['_coach_depenses_transport']);
      _telecom.text = _formatAnswerAmount(answers['_coach_depenses_telecom']);
      _electricity.text =
          _formatAnswerAmount(answers['_coach_depenses_electricite']);
      _medical.text =
          _formatAnswerAmount(answers['_coach_depenses_frais_medicaux']);
      _other.text = _formatAnswerAmount(answers['_coach_depenses_autres']);
      setState(() {
        _lamalFranchise = _coerceFranchise(answers['q_lamal_franchise']);
      });
      if (widget.initialFocus == 'housing') {
        _housingFocus.requestFocus();
      }
    });

    // Live total ticker — rebuild on every field change so the user sees
    // the running sum without tapping Save. Addresses deep-walk P2
    // crack #14 (Budget setup: pas de total live pendant saisie).
    for (final c in [
      _housing,
      _lamal,
      _transport,
      _telecom,
      _electricity,
      _medical,
      _other,
    ]) {
      c.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  double get _liveTotal {
    double sum = 0;
    for (final c in [
      _housing,
      _lamal,
      _transport,
      _telecom,
      _electricity,
      _medical,
      _other,
    ]) {
      sum += _parseAmount(c.text) ?? 0;
    }
    return sum;
  }

  @override
  void dispose() {
    _housingFocus.dispose();
    for (final c in [
      _housing,
      _lamal,
      _transport,
      _telecom,
      _electricity,
      _medical,
      _other,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _formatAmount(double? value) =>
      (value == null || value == 0) ? '' : value.toStringAsFixed(0);

  String _formatAnswerAmount(dynamic value) =>
      _formatAmount(_coerceAmount(value));

  double? _coerceAmount(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return _parseAmount(value);
    return null;
  }

  int? _coerceFranchise(dynamic value) {
    if (value is int && _lamalFranchiseLevels.contains(value)) return value;
    if (value is num) {
      final parsed = value.round();
      return _lamalFranchiseLevels.contains(parsed) ? parsed : null;
    }
    if (value is String) {
      final cleaned = value.trim().replaceAll(RegExp(r"[' ]"), '');
      final parsed = int.tryParse(cleaned);
      return _lamalFranchiseLevels.contains(parsed) ? parsed : null;
    }
    return null;
  }

  String _formatFranchise(int value) {
    final amount = value.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => "'",
        );
    return 'CHF $amount';
  }

  double? _parseAmount(String raw) {
    final cleaned = raw.trim().replaceAll(RegExp(r"[' ]"), '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  Future<void> _save() async {
    final housing = _parseAmount(_housing.text);
    final lamal = _parseAmount(_lamal.text);
    final requiresHousing = widget.initialFocus != 'lamal';
    final requiresLamal = widget.initialFocus != 'housing';
    if ((requiresLamal && lamal == null) ||
        (requiresHousing && housing == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context)!.budgetSetupRequired)),
      );
      return;
    }
    setState(() => _saving = true);
    final provider = context.read<CoachProfileProvider>();
    final answers = <String, dynamic>{};
    if (lamal != null) {
      answers['q_lamal_premium_monthly_chf'] = lamal;
    }
    if (housing != null) {
      answers['q_housing_cost_period_chf'] = housing;
      answers['q_pay_frequency'] = 'monthly';
    }
    if (_lamalFranchise != null) {
      answers['q_lamal_franchise'] = _lamalFranchise.toString();
    }
    final transport = _parseAmount(_transport.text);
    if (transport != null) answers['_coach_depenses_transport'] = transport;
    final telecom = _parseAmount(_telecom.text);
    if (telecom != null) answers['_coach_depenses_telecom'] = telecom;
    final electricity = _parseAmount(_electricity.text);
    if (electricity != null) {
      answers['_coach_depenses_electricite'] = electricity;
    }
    final medical = _parseAmount(_medical.text);
    if (medical != null) {
      answers['_coach_depenses_frais_medicaux'] = medical;
    }
    final other = _parseAmount(_other.text);
    if (other != null) answers['_coach_depenses_autres'] = other;

    await provider.mergeAnswers(answers);
    if (!mounted) return;
    // Refresh BudgetProvider so the Mon argent « Ton budget ce mois »
    // card re-derives inputs from the updated CoachProfile.depenses and
    // swaps from the empty budget-definition state to the computed
    // plan (revenu / charges fixes / reste). Without this the user
    // enters their charges and the card still shows « Commencer » —
    // silent failure, identical to the save_fact bug.
    final updated = provider.profile;
    if (updated != null) {
      await context.read<BudgetProvider>().refreshFromProfile(updated);
    }
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(s.budgetSetupTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(MintSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.budgetSetupSubtitle,
                style:
                    MintTextStyles.bodyMedium(color: MintColors.textSecondary),
              ),
              const SizedBox(height: MintSpacing.lg),
              _field(
                s.budgetSetupHousing,
                _housing,
                required: widget.initialFocus != 'lamal',
                placeholder: _placeholderHousing,
                fieldKey: const Key('budget_setup_housing_input'),
                semanticsIdentifier: 'budget_setup_housing_input',
                focusNode: _housingFocus,
              ),
              _field(
                s.budgetSetupLamal,
                _lamal,
                required: true,
                placeholder: _placeholderLamal,
                fieldKey: const Key('budget_setup_lamal_input'),
                semanticsIdentifier: 'budget_setup_lamal_input',
              ),
              _franchiseField(s),
              if (_showOptional) ...[
                _field(s.budgetSetupTransport, _transport,
                    placeholder: _placeholderTransport),
                _field(s.budgetSetupTelecom, _telecom,
                    placeholder: _placeholderTelecom),
                _field(s.budgetSetupElectricity, _electricity,
                    placeholder: _placeholderElectricity),
                _field(
                  s.budgetSetupMedical,
                  _medical,
                  placeholder: _placeholderMedical,
                  fieldKey: const Key('budget_setup_medical_input'),
                  semanticsIdentifier: 'budget_setup_medical_input',
                ),
                _field(s.budgetSetupOther, _other,
                    placeholder: _placeholderOther),
              ] else
                Semantics(
                  identifier: 'budget_setup_add_optional_cta',
                  button: true,
                  child: TextButton.icon(
                    key: const Key('budget_setup_add_optional_cta'),
                    onPressed: () => setState(() => _showOptional = true),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(s.budgetSetupAddOthers),
                  ),
                ),
              if (_liveTotal > 0) ...[
                const SizedBox(height: MintSpacing.md),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: MintColors.craie,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    s.budgetSetupTotalFixed(_formatAmount(_liveTotal)),
                    style: MintTextStyles.labelLarge(
                        color: MintColors.textPrimary),
                  ),
                ),
              ],
              const SizedBox(height: MintSpacing.lg),
              Semantics(
                identifier: 'budget_setup_save_cta',
                button: true,
                child: FilledButton(
                  key: const Key('budget_setup_save_cta'),
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(s.budgetSetupSave),
                ),
              ),
              const SizedBox(height: MintSpacing.md),
              Center(
                child: TextButton(
                  onPressed: () => context.push('/coach/chat?topic=budget'),
                  child: Text(
                    s.budgetSetupChatFallback,
                    style: MintTextStyles.bodyMedium(
                        color: MintColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController c, {
    bool required = false,
    String? placeholder,
    Key? fieldKey,
    String? semanticsIdentifier,
    FocusNode? focusNode,
  }) {
    final s = S.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style:
                      MintTextStyles.labelLarge(color: MintColors.textPrimary)),
              if (required) ...[
                const SizedBox(width: 6),
                Text('*',
                    style: MintTextStyles.labelLarge(color: MintColors.error)),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Semantics(
            identifier: semanticsIdentifier,
            child: TextField(
              key: fieldKey,
              controller: c,
              focusNode: focusNode,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: false),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r"[0-9' ]")),
              ],
              decoration: InputDecoration(
                hintText: placeholder ?? s.budgetSetupFieldPlaceholder,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _franchiseField(S s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.budgetSetupLamalFranchise,
              style: MintTextStyles.labelMedium(color: MintColors.textPrimary)),
          const SizedBox(height: 8),
          Semantics(
            identifier: 'budget_setup_lamal_franchise_input',
            container: true,
            child: DropdownButtonFormField<int>(
              key: const Key('budget_setup_lamal_franchise_input'),
              initialValue: _lamalFranchise,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: MintColors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: MintColors.border.withValues(alpha: 0.6),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: MintColors.border.withValues(alpha: 0.6),
                  ),
                ),
              ),
              items: [
                for (final level in _lamalFranchiseLevels)
                  DropdownMenuItem<int>(
                    value: level,
                    child: Text(_formatFranchise(level)),
                  ),
              ],
              onChanged: (value) => setState(() => _lamalFranchise = value),
            ),
          ),
        ],
      ),
    );
  }
}
