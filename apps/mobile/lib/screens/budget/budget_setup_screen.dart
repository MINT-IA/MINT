import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
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
  static const _placeholderHousing = '2400';
  static const _placeholderLamal = '380';
  static const _placeholderTransport = '200';
  static const _placeholderTelecom = '80';
  static const _placeholderElectricity = '90';
  static const _placeholderMedical = '120';
  static const _placeholderOther = '250';

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
      _housing.text = _formatAmount(d.loyer);
      _lamal.text = _formatAmount(d.assuranceMaladie);
      _transport.text = _formatAmount(d.transport);
      _telecom.text = _formatAmount(d.telecom);
      _electricity.text = _formatAmount(d.electricite);
      _medical.text = _formatAmount(d.fraisMedicaux);
      _other.text = _formatAmount(d.autresDepensesFixes);
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

  double? _parseAmount(String raw) {
    final cleaned = raw.trim().replaceAll(RegExp(r"[' ]"), '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  Future<void> _save() async {
    final housing = _parseAmount(_housing.text);
    final lamal = _parseAmount(_lamal.text);
    if (housing == null || lamal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context)!.budgetSetupRequired)),
      );
      return;
    }
    setState(() => _saving = true);
    final provider = context.read<CoachProfileProvider>();
    final answers = <String, dynamic>{
      'q_housing_cost_period_chf': housing,
      'q_pay_frequency': 'monthly',
      'q_lamal_premium_monthly_chf': lamal,
    };
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
    // swaps from the empty "Définis ton budget" state to the computed
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
                style: MintTextStyles.bodyMedium(
                    color: MintColors.textSecondary),
              ),
              const SizedBox(height: MintSpacing.lg),
              _field(s.budgetSetupHousing, _housing,
                  required: true, placeholder: _placeholderHousing),
              _field(s.budgetSetupLamal, _lamal,
                  required: true, placeholder: _placeholderLamal),
              if (_showOptional) ...[
                _field(s.budgetSetupTransport, _transport,
                    placeholder: _placeholderTransport),
                _field(s.budgetSetupTelecom, _telecom,
                    placeholder: _placeholderTelecom),
                _field(s.budgetSetupElectricity, _electricity,
                    placeholder: _placeholderElectricity),
                _field(s.budgetSetupMedical, _medical,
                    placeholder: _placeholderMedical),
                _field(s.budgetSetupOther, _other,
                    placeholder: _placeholderOther),
              ] else
                TextButton.icon(
                  onPressed: () => setState(() => _showOptional = true),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(s.budgetSetupAddOthers),
                ),
              if (_liveTotal > 0) ...[
                const SizedBox(height: MintSpacing.md),
                Container(
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
              ],
              const SizedBox(height: MintSpacing.lg),
              FilledButton(
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
              const SizedBox(height: MintSpacing.md),
              Center(
                child: TextButton(
                  onPressed: () =>
                      context.push('/coach/chat?topic=budget'),
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
                  style: MintTextStyles.labelLarge(
                      color: MintColors.textPrimary)),
              if (required) ...[
                const SizedBox(width: 6),
                Text('*',
                    style: MintTextStyles.labelLarge(color: MintColors.error)),
              ],
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r"[0-9' ]")),
            ],
            decoration: InputDecoration(
              hintText: placeholder ?? s.budgetSetupFieldPlaceholder,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
