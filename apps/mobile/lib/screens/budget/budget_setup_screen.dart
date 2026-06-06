import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:provider/provider.dart';

/// Structured cashflow entry form — MVP P0-MVP-3.
///
/// The previous Mon argent "Commencer" CTA routed straight to the coach
/// with `topic=budget`, which produced a dead-end loop: the coach chat
/// couldn't reliably persist financial values (save_fact is stripped
/// before reaching Flutter and anonymous users hit `Hors-DB path`), so
/// users could spend ten turns in a chat about their rent without any
/// field ever landing on `CoachProfile.depenses`.
///
/// This screen is the explicit, deterministic alternative. One resources
/// field plus seven fixed-charge fields, three required, five behind a
/// disclosure. No sliders, no pickers, no categorisation tree — just
/// `TextField` + numeric keyboard, per `feedback_no_sliders_ux` and
/// `feedback_modern_inputs_no_sliders`.
///
/// Pre-fills each field from `ReportPersistenceService.loadAnswers`
/// via the current `CoachProfile` so previously captured values
/// (scan, wizard, coach-chat inline) stay visible and editable
/// (`feedback_profile_prefill_architecture`).
///
/// The chat remains available as an explicit fallback link at the
/// bottom — doctrine `chat_is_everything` is respected ("all data
/// *can* go through chat"), not bent into "must".
class BudgetSetupScreen extends StatefulWidget {
  const BudgetSetupScreen({super.key});

  @override
  State<BudgetSetupScreen> createState() => _BudgetSetupScreenState();
}

class _BudgetSetupScreenState extends State<BudgetSetupScreen> {
  final _income = TextEditingController();
  final _housing = TextEditingController();
  final _lamal = TextEditingController();
  final _transport = TextEditingController();
  final _telecom = TextEditingController();
  final _electricity = TextEditingController();
  final _medical = TextEditingController();
  final _other = TextEditingController();
  bool _showOptional = false;
  bool _saving = false;

  // Median Swiss monthly values used as field placeholders. These are
  // informative examples, not defaults — the field stays empty until
  // the user types. Numbers held tight: rounded to readable amounts, no
  // decimals, within the statistically-observed range for a single
  // Swiss adult (OFS household-budget survey 2023). Not LSFin advice,
  // purely illustrative guidance per feedback_no_vague_language.
  static const _placeholderIncome = '6000';
  static const _placeholderHousing = '2400';
  static const _placeholderLamal = '380';
  static const _placeholderTransport = '200';
  static const _placeholderTelecom = '80';
  static const _placeholderElectricity = '90';
  static const _placeholderMedical = '120';
  static const _placeholderOther = '250';
  static const _maxMonthlyIncome = 100000.0;
  static const _maxMonthlyHousing = 20000.0;
  static const _maxMonthlyLamal = 3000.0;
  static const _maxMonthlyOtherCharge = 10000.0;

  @override
  void initState() {
    super.initState();
    // Pre-fill from current profile. mounted guard unnecessary here — widget
    // is just built. We intentionally use `read` because this is a one-shot
    // hydration, not a subscription.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final profile = context.read<CoachProfileProvider>().profile;
      if (profile == null) return;
      final d = profile.depenses;
      _income.text = _formatAmount(BudgetInputs.monthlyNetFromCoachProfile(
        profile,
      ));
      _housing.text = _prefillAmount(profile, 'housingCost', d.loyer);
      _lamal.text = _prefillAmount(profile, 'lamalPremium', d.assuranceMaladie);
      _transport.text = _prefillAmount(profile, 'transport', d.transport);
      _telecom.text = _prefillAmount(profile, 'telecom', d.telecom);
      _electricity.text = _prefillAmount(profile, 'electricity', d.electricite);
      _medical.text = _prefillAmount(profile, 'medicalCosts', d.fraisMedicaux);
      _other.text =
          _prefillAmount(profile, 'otherFixedCosts', d.autresDepensesFixes);
    });

    // Live total ticker — rebuild on every field change so the user sees
    // the running sum without tapping Save. Addresses deep-walk P2
    // crack #14 (Budget setup: pas de total live pendant saisie).
    for (final c in [
      _income,
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
    for (final c in [
      _income,
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

  String _prefillAmount(CoachProfile profile, String field, double? value) {
    if (value != null && !_isPlausiblePrefill(field, value)) return '';
    if (profile.userProvidedFields.isEmpty ||
        profile.userProvidedFields.contains(field)) {
      return _formatAmount(value);
    }
    return '';
  }

  bool _isPlausiblePrefill(String field, double value) {
    final max = switch (field) {
      'housingCost' => _maxMonthlyHousing,
      'lamalPremium' => _maxMonthlyLamal,
      _ => _maxMonthlyOtherCharge,
    };
    return _isPlausibleMonthlyCharge(value, max);
  }

  double? _parseAmount(String raw) {
    final cleaned = raw.trim().replaceAll(RegExp(r"[' ]"), '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  bool _isPlausibleMonthlyCharge(double value, double max) {
    return value >= 0 && value <= max;
  }

  bool _isPlausibleMonthlyIncome(double value) {
    return value > 0 && value <= _maxMonthlyIncome;
  }

  bool _hasImplausibleMonthlyCharge({
    required double housing,
    required double lamal,
    double? transport,
    double? telecom,
    double? electricity,
    double? medical,
    double? other,
  }) {
    if (!_isPlausibleMonthlyCharge(housing, _maxMonthlyHousing)) return true;
    if (!_isPlausibleMonthlyCharge(lamal, _maxMonthlyLamal)) return true;
    for (final value in [transport, telecom, electricity, medical, other]) {
      if (value != null &&
          !_isPlausibleMonthlyCharge(value, _maxMonthlyOtherCharge)) {
        return true;
      }
    }
    return false;
  }

  BudgetInputs _directInputsFromProfile(
    CoachProfile profile, {
    required double income,
    required double housing,
    required double lamal,
    double? transport,
    double? telecom,
    double? electricity,
    double? medical,
    double? other,
  }) {
    final base = BudgetInputs.fromCoachProfile(profile);
    final otherFixedCosts = [
      transport,
      telecom,
      electricity,
      medical,
      other,
    ].fold<double>(0, (sum, value) => sum + (value ?? 0));
    final monthlyCharges = housing + lamal + otherFixedCosts;
    final emergencyFundMonths = monthlyCharges > 0
        ? profile.patrimoine.epargneLiquide / monthlyCharges
        : base.emergencyFundMonths;

    return BudgetInputs(
      payFrequency: PayFrequency.monthly,
      netIncome: income,
      housingCost: housing,
      debtPayments: base.debtPayments,
      taxProvision: base.taxProvision,
      healthInsurance: lamal,
      otherFixedCosts: otherFixedCosts,
      isTaxEstimated: base.isTaxEstimated,
      isHealthEstimated: false,
      isHousingMissing: false,
      isHealthMissing: false,
      isOtherFixedMissing: otherFixedCosts <= 0,
      style: base.style,
      emergencyFundMonths: emergencyFundMonths,
    );
  }

  BudgetInputs _directInputs({
    required double income,
    required double housing,
    required double lamal,
    double? transport,
    double? telecom,
    double? electricity,
    double? medical,
    double? other,
  }) {
    final otherFixedCosts = [
      transport,
      telecom,
      electricity,
      medical,
      other,
    ].fold<double>(0, (sum, value) => sum + (value ?? 0));
    return BudgetInputs(
      payFrequency: PayFrequency.monthly,
      netIncome: income,
      housingCost: housing,
      debtPayments: 0,
      healthInsurance: lamal,
      otherFixedCosts: otherFixedCosts,
      isTaxEstimated: false,
      isHealthEstimated: false,
      isHousingMissing: false,
      isHealthMissing: false,
      isOtherFixedMissing: otherFixedCosts <= 0,
      emergencyFundMonths: 0,
    );
  }

  Future<void> _save() async {
    final income = _parseAmount(_income.text);
    final housing = _parseAmount(_housing.text);
    final lamal = _parseAmount(_lamal.text);
    if (income == null || housing == null || lamal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context)!.budgetSetupRequired)),
      );
      return;
    }
    final transport = _parseAmount(_transport.text);
    final telecom = _parseAmount(_telecom.text);
    final electricity = _parseAmount(_electricity.text);
    final medical = _parseAmount(_medical.text);
    final other = _parseAmount(_other.text);
    if (!_isPlausibleMonthlyIncome(income) ||
        _hasImplausibleMonthlyCharge(
          housing: housing,
          lamal: lamal,
          transport: transport,
          telecom: telecom,
          electricity: electricity,
          medical: medical,
          other: other,
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context)!.budgetSetupAmountTooHigh)),
      );
      return;
    }
    setState(() => _saving = true);
    final provider = context.read<CoachProfileProvider>();
    final profileBeforeSave = provider.profile;
    final answers = <String, dynamic>{
      'q_net_income_period_chf': income,
      'q_housing_cost_period_chf': housing,
      'q_pay_frequency': 'monthly',
      'q_lamal_premium_monthly_chf': lamal,
      '_coach_depenses_transport': transport,
      '_coach_depenses_telecom': telecom,
      '_coach_depenses_electricite': electricity,
      '_coach_depenses_frais_medicaux': medical,
      '_coach_depenses_autres': other,
    };

    await provider.mergeAnswers(answers);
    if (!mounted) return;
    // Refresh BudgetProvider so the Mon argent « Ton budget ce mois »
    // card re-derives inputs from the updated CoachProfile.depenses and
    // swaps from the empty "Définis ton budget" state to the computed
    // plan (revenu / charges fixes / reste). Without this the user
    // enters their charges and the card still shows « Commencer » —
    // silent failure, identical to the save_fact bug.
    final profileForBudget = provider.profile ?? profileBeforeSave;
    final budgetProvider = context.read<BudgetProvider>();
    if (profileForBudget != null) {
      await budgetProvider.setInputs(
        _directInputsFromProfile(
          profileForBudget,
          income: income,
          housing: housing,
          lamal: lamal,
          transport: transport,
          telecom: telecom,
          electricity: electricity,
          medical: medical,
          other: other,
        ),
      );
    } else {
      await budgetProvider.setInputs(
        _directInputs(
          income: income,
          housing: housing,
          lamal: lamal,
          transport: transport,
          telecom: telecom,
          electricity: electricity,
          medical: medical,
          other: other,
        ),
      );
    }
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Semantics(
      key: const Key('budget_setup_screen'),
      identifier: 'budget_setup_screen',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        appBar: AppBar(title: Text(s.budgetSetupTitle)),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(MintSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.budgetSetupSubtitle,
                  style: MintTextStyles.bodyMedium(
                      color: MintColors.textSecondary),
                ),
                const SizedBox(height: MintSpacing.lg),
                _field(s.budgetSetupIncome, _income,
                    key: const ValueKey('budgetIncomeField'),
                    required: true,
                    placeholder: _placeholderIncome),
                _field(s.budgetSetupHousing, _housing,
                    key: const ValueKey('budgetHousingField'),
                    required: true,
                    placeholder: _placeholderHousing),
                _field(s.budgetSetupLamal, _lamal,
                    key: const ValueKey('budgetLamalField'),
                    required: true,
                    placeholder: _placeholderLamal),
                if (_showOptional) ...[
                  _field(s.budgetSetupTransport, _transport,
                      key: const ValueKey('budgetTransportField'),
                      placeholder: _placeholderTransport),
                  _field(s.budgetSetupTelecom, _telecom,
                      key: const ValueKey('budgetTelecomField'),
                      placeholder: _placeholderTelecom),
                  _field(s.budgetSetupElectricity, _electricity,
                      key: const ValueKey('budgetElectricityField'),
                      placeholder: _placeholderElectricity),
                  _field(s.budgetSetupMedical, _medical,
                      key: const ValueKey('budgetMedicalField'),
                      placeholder: _placeholderMedical),
                  _field(s.budgetSetupOther, _other,
                      key: const ValueKey('budgetOtherField'),
                      placeholder: _placeholderOther),
                ] else
                  TextButton.icon(
                    onPressed: () => setState(() => _showOptional = true),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(s.budgetSetupAddOthers),
                  ),
                if (_liveTotal > 0) ...[
                  const SizedBox(height: MintSpacing.md),
                  Semantics(
                    key: const Key('budget_setup_live_total'),
                    identifier: 'budget_setup_live_total',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
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
                  ),
                  const SizedBox(height: MintSpacing.xs),
                  Semantics(
                    key: const Key('budget_setup_live_total_hint'),
                    identifier: 'budget_setup_live_total_hint',
                    child: Text(
                      s.budgetSetupTotalFixedHint,
                      style: MintTextStyles.bodySmall(
                          color: MintColors.textMuted),
                    ),
                  ),
                ],
                const SizedBox(height: MintSpacing.lg),
                Semantics(
                  key: const Key('budget_setup_save_button'),
                  identifier: 'budget_setup_save_button',
                  button: true,
                  child: /* // lint-ignore: prefer_mint_cta */ FilledButton(
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
                                strokeWidth: 2, color: MintColors.white),
                          )
                        : Text(s.budgetSetupSave),
                  ),
                ),
                const SizedBox(height: MintSpacing.md),
                Center(
                  child: Semantics(
                    key: const Key('budget_setup_chat_fallback'),
                    identifier: 'budget_setup_chat_fallback',
                    button: true,
                    child: /* // lint-ignore: prefer_mint_cta */ TextButton(
                      onPressed: () => context.push('/coach/chat?topic=budget'),
                      child: Text(
                        s.budgetSetupChatFallback,
                        style: MintTextStyles.bodyMedium(
                            color: MintColors.textSecondary),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController c, {
    Key? key,
    bool required = false,
    String? placeholder,
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
            key: Key('${_fieldSemanticsIdentifier(key, label)}_semantics'),
            identifier: _fieldSemanticsIdentifier(key, label),
            textField: true,
            child: TextField(
              key: key,
              controller: c,
              onTap: () {
                c.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: c.text.length,
                );
              },
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: false),
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
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

  String _fieldSemanticsIdentifier(Key? key, String label) {
    if (key == const ValueKey('budgetHousingField')) {
      return 'budget_housing_field';
    }
    if (key == const ValueKey('budgetIncomeField')) {
      return 'budget_income_field';
    }
    if (key == const ValueKey('budgetLamalField')) {
      return 'budget_lamal_field';
    }
    if (key == const ValueKey('budgetTransportField')) {
      return 'budget_transport_field';
    }
    if (key == const ValueKey('budgetTelecomField')) {
      return 'budget_telecom_field';
    }
    if (key == const ValueKey('budgetElectricityField')) {
      return 'budget_electricity_field';
    }
    if (key == const ValueKey('budgetMedicalField')) {
      return 'budget_medical_field';
    }
    if (key == const ValueKey('budgetOtherField')) {
      return 'budget_other_field';
    }
    return label;
  }
}
