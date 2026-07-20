import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/routes/route_metadata.dart';
import 'package:mint_mobile/services/navigation/safe_pop.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/services/cross_validation_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/services/financial_core/swiss_civil_time.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/l10n/confidence_prompt_localizations.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Data block enrichment screen — deep-edit a specific confidence bloc.
///
/// P8 Phase 3: Routes /data-block/<type> land here.
/// Shows the current block score, prompts, and relevant input fields.
///
/// Supported block types: revenu, lpp, avs, 3a, patrimoine,
/// objectifRetraite, compositionMenage.
class DataBlockEnrichmentScreen extends StatefulWidget {
  final String blockType;
  final String? initialInputKey;

  /// Always supplied by the production route builder. Null only preserves
  /// legacy direct-widget harness behavior outside GoRouter.
  final DataBlockReturnTarget? returnTarget;
  static const Set<String> _supportedBlockTypes = {
    'revenu',
    'lpp',
    'avs',
    '3a',
    'patrimoine',
    'fiscalite',
    'objectifRetraite',
    'compositionMenage',
  };

  const DataBlockEnrichmentScreen({
    super.key,
    required this.blockType,
    this.initialInputKey,
    this.returnTarget,
  });

  @override
  State<DataBlockEnrichmentScreen> createState() =>
      _DataBlockEnrichmentScreenState();
}

class _DataBlockEnrichmentScreenState extends State<DataBlockEnrichmentScreen> {
  static const _swissCantonCodes =
      ' AG AI AR BE BL BS FR GE GL GR JU LU NE NW OW SG SH SO SZ TG TI UR VD VS ZG ZH ';

  bool _showCoachMode = false;
  final TextEditingController _cantonController = TextEditingController();
  final TextEditingController _salaryController = TextEditingController();
  final TextEditingController _selfEmployedIncomeController =
      TextEditingController();
  final TextEditingController _companyProfitController =
      TextEditingController();
  final TextEditingController _unemploymentContributionMonthsController =
      TextEditingController();
  final TextEditingController _birthYearController = TextEditingController();
  final TextEditingController _dateOfBirthController = TextEditingController();
  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _wealthEstimateController =
      TextEditingController();
  final TextEditingController _propertyMarketValueController =
      TextEditingController();
  final TextEditingController _mortgageBalanceController =
      TextEditingController();
  final TextEditingController _debtPaymentsController = TextEditingController();
  final TextEditingController _childrenController = TextEditingController();
  bool _revenueInputsSeeded = false;
  bool _patrimoineInputsSeeded = false;
  bool _householdInputsSeeded = false;
  bool _hasPensionFund = false;
  bool _hasPensionFundTouched = false;
  String? _gender;
  String _civilStatus = 'celibataire';
  String _housingStatus = 'renter';
  bool _childrenConfirmed = false;
  bool _civilStatusConfirmed = false;
  bool _housingStatusConfirmed = false;
  bool _isSavingRevenue = false;
  bool _isSavingPatrimoine = false;
  bool _isSavingHousehold = false;
  bool _revenueSaved = false;
  bool _patrimoineSaved = false;
  bool _householdSaved = false;
  bool _revenuePersistenceFailed = false;
  bool _patrimoinePersistenceFailed = false;
  bool _householdPersistenceFailed = false;
  String? _revenueError;
  String? _patrimoineError;
  String? _householdError;

  /// Cached cross-validation alerts to avoid recomputing on every build.
  List<ValidationAlert>? _cachedAlerts;
  CoachProfile? _cachedAlertsProfile;

  @override
  void dispose() {
    _cantonController.dispose();
    _salaryController.dispose();
    _selfEmployedIncomeController.dispose();
    _companyProfitController.dispose();
    _unemploymentContributionMonthsController.dispose();
    _birthYearController.dispose();
    _dateOfBirthController.dispose();
    _cashController.dispose();
    _wealthEstimateController.dispose();
    _propertyMarketValueController.dispose();
    _mortgageBalanceController.dispose();
    _debtPaymentsController.dispose();
    _childrenController.dispose();
    super.dispose();
  }

  List<ValidationAlert> _getAlertsForBlock(
      CoachProfile profile, String blockType) {
    // Recompute only when the profile object changes (Provider identity).
    if (!identical(profile, _cachedAlertsProfile)) {
      _cachedAlerts = CrossValidationService.validate(profile);
      _cachedAlertsProfile = profile;
    }
    return _cachedAlerts!.where((a) => a.block == blockType).toList();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<CoachProfileProvider>().profile;
    final canonicalBlockType = _canonicalBlockType(widget.blockType);
    if (canonicalBlockType == 'revenu') {
      _seedRevenueInputs(profile);
    } else if (canonicalBlockType == 'patrimoine') {
      _seedPatrimoineInputs(profile);
    } else if (canonicalBlockType == 'compositionMenage') {
      _seedHouseholdInputs(profile);
    }
    final isKnownBlock = DataBlockEnrichmentScreen._supportedBlockTypes
        .contains(canonicalBlockType);
    final blocs = profile != null
        ? ConfidenceScorer.scoreAsBlocs(profile)
        : <String, BlockScore>{};
    final bloc = isKnownBlock ? blocs[canonicalBlockType] : null;

    final l = S.of(context)!;
    final meta = _blockMeta(isKnownBlock ? canonicalBlockType : 'unknown', l);

    // Check if SLM or BYOK is available for coach mode
    final slmProvider = context.watch<SlmProvider>();
    final coachAvailable = slmProvider.isEngineAvailable;

    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        elevation: 0,
        leading: MergeSemantics(
          child: Semantics(
            identifier: 'data_block_cancel_return_cta',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
              onPressed: _cancelToReturnTarget,
            ),
          ),
        ),
        title: Text(
          meta.title,
          style: MintTextStyles.titleLarge(color: MintColors.textPrimary)
              .copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),

                      // ── Block score indicator ────────────────────────────
                      if (bloc != null)
                        MintEntrance(child: _BlockScoreBar(bloc: bloc)),
                      const SizedBox(height: 24),

                      // ── Coach mode toggle ───────────────────────────────
                      MintEntrance(
                          delay: const Duration(milliseconds: 100),
                          child: _CoachModeToggle(
                            isCoachMode: _showCoachMode,
                            coachAvailable: coachAvailable,
                            onToggle: (value) {
                              if (value) {
                                // Navigate to coach chat with structured topic
                                context.go(
                                    '/coach/chat?topic=${Uri.encodeComponent(canonicalBlockType)}');
                              } else {
                                setState(() => _showCoachMode = false);
                              }
                            },
                          )),
                      const SizedBox(height: 16),

                      // ── Description ─────────────────────────────────────
                      ...[
                        MintEntrance(
                            delay: const Duration(milliseconds: 150),
                            child: Text(
                              meta.description,
                              style: MintTextStyles.bodyMedium(
                                      color: MintColors.textSecondary)
                                  .copyWith(height: 1.5),
                            )),
                        const SizedBox(height: 24),
                      ],

                      // ── Enrichment prompts for this block ────────────────
                      if (_shouldShowHouseholdCollector(
                          canonicalBlockType)) ...[
                        MintEntrance(
                          delay: const Duration(milliseconds: 200),
                          child: _buildHouseholdCollector(l),
                        ),
                      ] else if (_shouldShowPatrimoineCollector(
                          canonicalBlockType)) ...[
                        MintEntrance(
                          delay: const Duration(milliseconds: 200),
                          child: _buildPatrimoineCollector(l),
                        ),
                      ] else if (profile != null &&
                          canonicalBlockType != 'revenu') ...[
                        MintEntrance(
                            delay: const Duration(milliseconds: 200),
                            child: _buildPrompts(
                                profile, canonicalBlockType, bloc)),
                      ],
                      if (canonicalBlockType == 'revenu') ...[
                        MintEntrance(
                          delay: const Duration(milliseconds: 200),
                          child: _buildRevenueCollector(l),
                        ),
                      ],

                      // ── Cross-validation alerts ────────────────────────────
                      if (profile != null) ...[
                        _buildValidationAlerts(profile, canonicalBlockType),
                      ],

                      const SizedBox(height: 32),

                      // ── CTA ──────────────────────────────────────────────
                      if (canonicalBlockType != 'revenu' &&
                          !_shouldShowHouseholdCollector(canonicalBlockType) &&
                          !_shouldShowPatrimoineCollector(canonicalBlockType))
                        Semantics(
                            identifier: canonicalBlockType == 'lpp'
                                ? 'data_block_lpp_scan_cta'
                                : null,
                            button: true,
                            label: meta.ctaLabel,
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                key: canonicalBlockType == 'lpp'
                                    ? const Key('data_block_lpp_scan_cta')
                                    : null,
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  // Navigate to the appropriate enrichment flow
                                  final route =
                                      _enrichmentRoute(canonicalBlockType);
                                  if (route != null) {
                                    final returnTarget = widget.returnTarget;
                                    if (canonicalBlockType == 'lpp' &&
                                        returnTarget?.location ==
                                            '/rente-vs-capital' &&
                                        FeatureFlags
                                            .lppEvidenceIngestionEnabled) {
                                      final scanReturnId = context
                                          .read<ScanSessionProvider>()
                                          .retainDataBlockScanReturnIntent(
                                            kind:
                                                DataBlockScanReturnKind.rvcLpp,
                                            target: returnTarget!,
                                          );
                                      context.push(
                                        Uri(
                                          path: route,
                                          queryParameters: <String, String>{
                                            'scanReturnId': scanReturnId,
                                          },
                                        ).toString(),
                                      );
                                    } else {
                                      context.push(route);
                                    }
                                  } else {
                                    _cancelToReturnTarget();
                                  }
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: MintColors.primary,
                                  foregroundColor: MintColors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  meta.ctaLabel,
                                  style: MintTextStyles.titleMedium()
                                      .copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            )),
                      const SizedBox(height: 16),

                      // ── Disclaimer ───────────────────────────────────────
                      MintEntrance(
                          child: Text(
                        S.of(context)!.dataBlockDisclaimer,
                        style: MintTextStyles.micro(color: MintColors.textMuted)
                            .copyWith(height: 1.4),
                        textAlign: TextAlign.center,
                      )),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ))),
    );
  }

  void _seedRevenueInputs(CoachProfile? profile) {
    if (_revenueInputsSeeded || profile == null) return;
    _revenueInputsSeeded = true;
    if (profile.canton.isNotEmpty) _cantonController.text = profile.canton;
    if (profile.userProvidedFields.contains('grossSalaryAnnual') &&
        profile.revenuBrutAnnuel > 0) {
      _salaryController.text = '${profile.revenuBrutAnnuel.round()}';
    }
    final selfEmployedIncome = profile.selfEmployedNetIncome;
    if (selfEmployedIncome != null && selfEmployedIncome > 0) {
      _selfEmployedIncomeController.text = '${selfEmployedIncome.round()}';
    }
    final companyProfit = profile.companyProfitAnnual;
    if (companyProfit != null && companyProfit > 0) {
      _companyProfitController.text = '${companyProfit.round()}';
    }
    final unemploymentContributionMonths =
        profile.unemploymentContributionMonths;
    if (unemploymentContributionMonths != null) {
      _unemploymentContributionMonthsController.text =
          '$unemploymentContributionMonths';
    }
    if (profile.birthYear >= 1900) {
      _birthYearController.text = '${profile.birthYear}';
    }
    final dateOfBirth = profile.dateOfBirth;
    if (dateOfBirth != null) {
      _dateOfBirthController.text = _formatCivilDate(dateOfBirth);
    }
    if (profile.gender == 'F' || profile.gender == 'M') {
      _gender = profile.gender;
    }
    _hasPensionFund = (profile.prevoyance.avoirLppTotal ?? 0) > 0 ||
        profile.prevoyance.isLppFromCertificate;
  }

  void _seedPatrimoineInputs(CoachProfile? profile) {
    if (_patrimoineInputsSeeded || profile == null) return;
    _patrimoineInputsSeeded = true;
    if (profile.patrimoine.epargneLiquide > 0) {
      _cashController.text = '${profile.patrimoine.epargneLiquide.round()}';
    }
    final wealthEstimate = profile.patrimoine.wealthEstimate;
    if (wealthEstimate != null && wealthEstimate > 0) {
      _wealthEstimateController.text = '${wealthEstimate.round()}';
    }
    final propertyMarketValue =
        profile.patrimoine.propertyMarketValue ?? profile.patrimoine.immobilier;
    if (propertyMarketValue != null && propertyMarketValue > 0) {
      _propertyMarketValueController.text = '${propertyMarketValue.round()}';
    }
    final mortgageBalance = profile.dettes.hypotheque;
    if (mortgageBalance != null && mortgageBalance >= 0) {
      _mortgageBalanceController.text = '${mortgageBalance.round()}';
    }
    final consumerDebtPayments = (profile.dettes.mensualiteCreditConso ?? 0) +
        (profile.dettes.mensualiteLeasing ?? 0);
    if (consumerDebtPayments > 0) {
      _debtPaymentsController.text = '${consumerDebtPayments.round()}';
    }
  }

  void _seedHouseholdInputs(CoachProfile? profile) {
    if (_householdInputsSeeded) return;
    _householdInputsSeeded = true;
    if (profile == null) return;
    _childrenController.text = '${profile.nombreEnfants}';
    _civilStatus = profile.etatCivil == CoachCivilStatus.registeredPartnership
        ? 'registered_partner'
        : profile.etatCivil.name;
    _childrenConfirmed = profile.userProvidedFields.contains('children');
    _civilStatusConfirmed = profile.userProvidedFields.contains('civilStatus');
    _housingStatusConfirmed =
        profile.userProvidedFields.contains('housingStatus');
    final status = profile.housingStatus;
    if (status == 'owner' ||
        status == 'proprietaire' ||
        status == 'propri\u00e9taire') {
      _housingStatus = 'owner';
    } else if (status == 'family') {
      _housingStatus = 'family';
    } else if (status == 'renter' || status == 'locataire') {
      _housingStatus = 'renter';
    }
  }

  Widget _buildRevenueCollector(S l) {
    final onlyInputKey = _canonicalRevenueInputKey(widget.initialInputKey);
    final children = <Widget>[];

    void addField(Widget field) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 14));
      children.add(field);
    }

    if (_capturesRevenue('q_gross_salary_annual', onlyInputKey)) {
      addField(_buildRevenueTextField(
        key: const Key('salary_input'),
        semanticsIdentifier: 'salary_input',
        controller: _salaryController,
        label: l.renteVsCapitalSalary,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r"[0-9' ]"))
        ],
        onChanged: (_) => setState(() => _revenueSaved = false),
      ));
    }
    if (onlyInputKey == 'q_self_employed_income') {
      addField(_buildRevenueTextField(
        key: const Key('self_employed_income_input'),
        semanticsIdentifier: 'self_employed_income_input',
        controller: _selfEmployedIncomeController,
        label: l.independantRevenueTitle,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r"[0-9' ]"))
        ],
        onChanged: (_) => setState(() => _revenueSaved = false),
      ));
    }
    if (onlyInputKey == 'q_company_profit_annual_chf') {
      addField(_buildRevenueTextField(
        key: const Key('company_profit_input'),
        semanticsIdentifier: 'company_profit_input',
        controller: _companyProfitController,
        label: l.dividendeBeneficeTotal,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r"[0-9' ]"))
        ],
        onChanged: (_) => setState(() => _revenueSaved = false),
      ));
    }
    if (onlyInputKey == 'q_unemployment_contribution_months') {
      addField(_buildRevenueTextField(
        key: const Key('unemployment_contribution_months_input'),
        semanticsIdentifier: 'unemployment_contribution_months_input',
        controller: _unemploymentContributionMonthsController,
        label: l.unemploymentContribTitle,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        onChanged: (_) => setState(() => _revenueSaved = false),
      ));
    }
    if (_capturesRevenue('q_canton', onlyInputKey)) {
      addField(_buildRevenueTextField(
        key: const Key('canton_picker'),
        semanticsIdentifier: 'canton_picker',
        controller: _cantonController,
        label: l.affordabilityCanton,
        textCapitalization: TextCapitalization.characters,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
          LengthLimitingTextInputFormatter(2)
        ],
        onChanged: (_) => setState(() => _revenueSaved = false),
      ));
    }
    if (_capturesRevenue('q_birth_year', onlyInputKey)) {
      addField(_buildRevenueTextField(
        key: const Key('birth_year_input'),
        semanticsIdentifier: 'birth_year_input',
        controller: _birthYearController,
        label: l.landingBirthYear,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4)
        ],
        onChanged: (_) => setState(() => _revenueSaved = false),
      ));
    }
    if (onlyInputKey == 'q_date_of_birth') {
      addField(_buildRevenueTextField(
        key: const Key('date_of_birth_input'),
        semanticsIdentifier: 'date_of_birth_input',
        controller: _dateOfBirthController,
        label: l.dataBlockBirthDateLabel,
        keyboardType: TextInputType.datetime,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
          LengthLimitingTextInputFormatter(10),
        ],
        onChanged: (_) => setState(() => _revenueSaved = false),
        suffixIcon: IconButton(
          key: const Key('date_of_birth_picker'),
          tooltip: l.dataBlockBirthDatePicker,
          onPressed: _pickDateOfBirth,
          icon: const Icon(Icons.calendar_today_outlined),
        ),
      ));
    }
    if (onlyInputKey == 'q_gender') {
      addField(Semantics(
        identifier: 'gender_input',
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.dataBlockGenderLabel,
              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildGenderChoice(
                  key: const Key('gender_f_choice'),
                  value: 'F',
                  label: l.dataBlockGenderFemale,
                ),
                _buildGenderChoice(
                  key: const Key('gender_m_choice'),
                  value: 'M',
                  label: l.dataBlockGenderMale,
                ),
              ],
            ),
          ],
        ),
      ));
    }
    if (_capturesRevenue('q_has_pension_fund', onlyInputKey)) {
      addField(Semantics(
        identifier: 'has_pension_fund_switch',
        child: SwitchListTile.adaptive(
          key: const Key('has_pension_fund_switch'),
          contentPadding: EdgeInsets.zero,
          activeThumbColor: MintColors.primary,
          title: Text(
            l.eduThemeLppQuestion,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
          ),
          value: _hasPensionFund,
          onChanged: (value) => setState(() {
            _hasPensionFund = value;
            _hasPensionFundTouched = true;
            _revenueSaved = false;
          }),
        ),
      ));
    }

    return MintSurface(
      padding: const EdgeInsets.all(18),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...children,
          if (_revenueError != null) ...[
            const SizedBox(height: 8),
            if (_revenuePersistenceFailed)
              _buildPersistenceError(l, _saveRevenueFacts)
            else
              Text(
                _revenueError!,
                style: MintTextStyles.labelMedium(color: MintColors.error),
              ),
          ],
          if (_revenueSaved) ...[
            const SizedBox(height: 8),
            _buildSaveSuccess(l),
          ],
          const SizedBox(height: 12),
          Semantics(
            identifier: 'salary_save_cta',
            button: true,
            label: l.financialSummaryEnregistrer,
            child: FilledButton(
              key: const Key('salary_save_cta'),
              onPressed: _isSavingRevenue ? null : _saveRevenueFacts,
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.primary,
                foregroundColor: MintColors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSavingRevenue
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: MintColors.white,
                      ),
                    )
                  : Text(
                      l.financialSummaryEnregistrer,
                      style: MintTextStyles.titleMedium()
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueTextField({
    required Key key,
    required TextEditingController controller,
    required String label,
    required String semanticsIdentifier,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
    Widget? suffixIcon,
  }) {
    return Semantics(
      identifier: semanticsIdentifier,
      child: TextField(
        key: key,
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Future<void> _saveRevenueFacts() async {
    final l = S.of(context)!;
    final onlyInputKey = _canonicalRevenueInputKey(widget.initialInputKey);
    final capturesSalary =
        _capturesRevenue('q_gross_salary_annual', onlyInputKey);
    final capturesSelfEmployedIncome = onlyInputKey == 'q_self_employed_income';
    final capturesCompanyProfit = onlyInputKey == 'q_company_profit_annual_chf';
    final capturesUnemploymentContributionMonths =
        onlyInputKey == 'q_unemployment_contribution_months';
    final capturesCanton = _capturesRevenue('q_canton', onlyInputKey);
    final capturesBirthYear = _capturesRevenue('q_birth_year', onlyInputKey);
    final capturesDateOfBirth = onlyInputKey == 'q_date_of_birth';
    final capturesGender = onlyInputKey == 'q_gender';
    final capturesPensionFund =
        _capturesRevenue('q_has_pension_fund', onlyInputKey);
    final canton = _cantonController.text.trim().toUpperCase();
    final salary = int.tryParse(_digitsOnly(_salaryController.text));
    final selfEmployedIncome =
        int.tryParse(_digitsOnly(_selfEmployedIncomeController.text));
    final companyProfit =
        int.tryParse(_digitsOnly(_companyProfitController.text));
    final unemploymentContributionMonths = int.tryParse(
      _digitsOnly(_unemploymentContributionMonthsController.text),
    );
    final birthText = _birthYearController.text.trim();
    final birthYear = birthText.isEmpty ? null : int.tryParse(birthText);
    final dateOfBirthText = _dateOfBirthController.text.trim();
    final dateOfBirth =
        dateOfBirthText.isEmpty ? null : _parseCivilDate(dateOfBirthText);
    final currentYear = DateTime.now().year;
    final youngestSupportedBirthYear = currentYear - 18;

    final birthYearRequired = onlyInputKey == 'q_birth_year';
    final invalidBirthYear = capturesBirthYear &&
        ((birthYearRequired && birthText.isEmpty) ||
            (birthText.isNotEmpty &&
                (birthYear == null ||
                    birthYear < 1900 ||
                    birthYear > youngestSupportedBirthYear)));
    final dateOfBirthRequired = onlyInputKey == 'q_date_of_birth';
    final invalidDateOfBirth = capturesDateOfBirth &&
        ((dateOfBirthRequired && dateOfBirthText.isEmpty) ||
            (dateOfBirthText.isNotEmpty &&
                (dateOfBirth == null || !_isSupportedAdult(dateOfBirth))));
    final invalidGender = capturesGender &&
        onlyInputKey == 'q_gender' &&
        _gender != 'F' &&
        _gender != 'M';

    if ((capturesCanton && !_swissCantonCodes.contains(' $canton ')) ||
        (capturesSalary && (salary == null || salary <= 0)) ||
        (capturesSelfEmployedIncome &&
            (selfEmployedIncome == null || selfEmployedIncome <= 0)) ||
        (capturesCompanyProfit &&
            (companyProfit == null || companyProfit <= 0)) ||
        (capturesUnemploymentContributionMonths &&
            (unemploymentContributionMonths == null ||
                unemploymentContributionMonths < 0 ||
                unemploymentContributionMonths > 24)) ||
        invalidBirthYear ||
        invalidDateOfBirth ||
        invalidGender) {
      setState(() {
        _revenueError = l.authErrorInvalid;
        _revenuePersistenceFailed = false;
      });
      return;
    }

    setState(() {
      _isSavingRevenue = true;
      _revenueError = null;
      _revenueSaved = false;
      _revenuePersistenceFailed = false;
    });

    final answers = <String, dynamic>{
      if (capturesSalary) 'q_gross_salary_annual': salary,
      if (capturesSelfEmployedIncome) ...{
        'q_self_employed_income': selfEmployedIncome,
        'q_net_income_period_chf': selfEmployedIncome,
        'q_pay_frequency': 'yearly',
        'q_employment_status': 'independant',
      },
      if (capturesCompanyProfit) 'q_company_profit_annual_chf': companyProfit,
      if (capturesUnemploymentContributionMonths)
        'q_unemployment_contribution_months': unemploymentContributionMonths,
      if (capturesCanton) 'q_canton': canton,
      if (capturesBirthYear && birthYear != null) 'q_birth_year': birthYear,
      if (capturesDateOfBirth && dateOfBirth != null)
        'q_date_of_birth': _formatCivilDate(dateOfBirth),
      if (capturesGender && (_gender == 'F' || _gender == 'M'))
        'q_gender': _gender,
      if (capturesPensionFund &&
          (_hasPensionFundTouched || onlyInputKey == 'q_has_pension_fund'))
        'q_has_pension_fund': _hasPensionFund ? 'yes' : 'no',
    };

    final persisted = await _persistAnswers(answers);
    if (!mounted) return;
    if (!persisted) {
      setState(() {
        _isSavingRevenue = false;
        _revenueError = l.authErrorGeneric;
        _revenueSaved = false;
        _revenuePersistenceFailed = true;
      });
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _isSavingRevenue = false;
      _revenueSaved = true;
    });
    _exitAfterSuccessfulSave();
  }

  Widget _buildGenderChoice({
    required Key key,
    required String value,
    required String label,
  }) {
    return Semantics(
      identifier: (key as ValueKey<String>).value,
      button: true,
      selected: _gender == value,
      child: ChoiceChip(
        key: key,
        label: Text(label),
        selected: _gender == value,
        onSelected: (_) => setState(() {
          _gender = value;
          _revenueSaved = false;
        }),
      ),
    );
  }

  Future<void> _pickDateOfBirth() async {
    final today = SwissCivilTime.civilDate(DateTime.now());
    final lastDate = _birthdayAtAge(today, -18);
    final parsed = _parseCivilDate(_dateOfBirthController.text.trim());
    final initial = parsed != null &&
            !parsed.isBefore(DateTime.utc(1900, 1, 1)) &&
            !parsed.isAfter(lastDate)
        ? parsed
        : DateTime.utc(lastDate.year - 30, lastDate.month, lastDate.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(1900, 1, 1),
      lastDate: DateTime(lastDate.year, lastDate.month, lastDate.day),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dateOfBirthController.text = _formatCivilDate(picked);
      _revenueSaved = false;
      _revenueError = null;
    });
  }

  bool _isSupportedAdult(DateTime dateOfBirth) {
    if (dateOfBirth.isBefore(DateTime.utc(1900, 1, 1))) return false;
    final today = SwissCivilTime.civilDate(DateTime.now());
    return !dateOfBirth.isAfter(_birthdayAtAge(today, -18));
  }

  DateTime _birthdayAtAge(DateTime date, int years) {
    final year = date.year + years;
    final maxDay = DateTime.utc(year, date.month + 1, 0).day;
    return DateTime.utc(year, date.month, date.day.clamp(1, maxDay));
  }

  DateTime? _parseCivilDate(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final parsed = DateTime.utc(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  String _formatCivilDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  bool _shouldShowPatrimoineCollector(String canonicalBlockType) {
    return canonicalBlockType == 'patrimoine';
  }

  bool _shouldShowHouseholdCollector(String canonicalBlockType) {
    return canonicalBlockType == 'compositionMenage';
  }

  Widget _buildHouseholdCollector(S l) {
    final onlyInputKey = _canonicalHouseholdInputKey(widget.initialInputKey);
    final collectsChildren =
        onlyInputKey == null || onlyInputKey == 'q_children';
    final collectsCivilStatus =
        onlyInputKey == null || onlyInputKey == 'q_civil_status';
    final collectsHousingStatus =
        onlyInputKey == null || onlyInputKey == 'q_housing_status';

    return MintSurface(
      padding: const EdgeInsets.all(18),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (collectsChildren) ...[
            _buildRevenueTextField(
              key: const Key('children_count_input'),
              semanticsIdentifier: 'children_count_input',
              controller: _childrenController,
              label: l.coverageCheckPersonnesCharge,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              onChanged: (_) => setState(() {
                _childrenConfirmed = true;
                _householdSaved = false;
              }),
            ),
            const SizedBox(height: 16),
          ],
          if (collectsCivilStatus) ...[
            Text(
              l.dataBlockMenageCivilStatus,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildCivilStatusChoice(
                  key: const Key('civil_status_single_choice'),
                  value: 'celibataire',
                  label: l.dataBlockMenageCivilSingle,
                ),
                _buildCivilStatusChoice(
                  key: const Key('civil_status_married_choice'),
                  value: 'marie',
                  label: l.dataBlockMenageCivilMarried,
                ),
                _buildCivilStatusChoice(
                  key: const Key('civil_status_registered_partner_choice'),
                  value: 'registered_partner',
                  label: l.dataBlockMenageCivilRegisteredPartner,
                ),
                _buildCivilStatusChoice(
                  key: const Key('civil_status_cohabiting_choice'),
                  value: 'concubinage',
                  label: l.dataBlockMenageCivilCohabiting,
                ),
                _buildCivilStatusChoice(
                  key: const Key('civil_status_divorced_choice'),
                  value: 'divorce',
                  label: l.dataBlockMenageCivilDivorced,
                ),
                _buildCivilStatusChoice(
                  key: const Key('civil_status_widowed_choice'),
                  value: 'veuf',
                  label: l.dataBlockMenageCivilWidowed,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (collectsHousingStatus) ...[
            Text(
              l.dataBlockMenageHousingStatus,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildHousingChoice(
                  key: const Key('housing_status_renter_choice'),
                  value: 'renter',
                  label: l.coverageCheckLocataire,
                ),
                _buildHousingChoice(
                  key: const Key('housing_status_owner_choice'),
                  value: 'owner',
                  label: l.householdOwnerBadge,
                ),
                _buildHousingChoice(
                  key: const Key('housing_status_family_choice'),
                  value: 'family',
                  label: l.dataBlockMenageHousingFamily,
                ),
              ],
            ),
          ],
          if (_householdError != null) ...[
            const SizedBox(height: 8),
            if (_householdPersistenceFailed)
              _buildPersistenceError(l, _saveHouseholdFacts)
            else
              Text(
                _householdError!,
                style: MintTextStyles.labelMedium(color: MintColors.error),
              ),
          ],
          if (_householdSaved) ...[
            const SizedBox(height: 8),
            _buildSaveSuccess(l),
          ],
          const SizedBox(height: 12),
          Semantics(
            identifier: 'household_save_cta',
            button: true,
            label: l.financialSummaryEnregistrer,
            child: FilledButton(
              key: const Key('household_save_cta'),
              onPressed: _isSavingHousehold ? null : _saveHouseholdFacts,
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.primary,
                foregroundColor: MintColors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSavingHousehold
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: MintColors.white,
                      ),
                    )
                  : Text(
                      l.financialSummaryEnregistrer,
                      style: MintTextStyles.titleMedium()
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCivilStatusChoice({
    required Key key,
    required String value,
    required String label,
  }) {
    return Semantics(
      identifier: (key as ValueKey<String>).value,
      button: true,
      selected: _civilStatus == value,
      child: ChoiceChip(
        key: key,
        label: Text(label),
        selected: _civilStatus == value,
        onSelected: (_) => setState(() {
          _civilStatus = value;
          _civilStatusConfirmed = true;
          _householdSaved = false;
        }),
      ),
    );
  }

  Widget _buildHousingChoice({
    required Key key,
    required String value,
    required String label,
  }) {
    return Semantics(
      identifier: (key as ValueKey<String>).value,
      button: true,
      selected: _housingStatus == value,
      child: ChoiceChip(
        key: key,
        label: Text(label),
        selected: _housingStatus == value,
        onSelected: (_) => setState(() {
          _housingStatus = value;
          _housingStatusConfirmed = true;
          _householdSaved = false;
        }),
      ),
    );
  }

  Future<void> _saveHouseholdFacts() async {
    final l = S.of(context)!;
    final onlyInputKey = _canonicalHouseholdInputKey(widget.initialInputKey);
    final collectsChildren =
        onlyInputKey == null || onlyInputKey == 'q_children';
    final writesChildren = onlyInputKey == 'q_children' ||
        (onlyInputKey == null && _childrenConfirmed);
    final writesCivilStatus = onlyInputKey == 'q_civil_status' ||
        (onlyInputKey == null && _civilStatusConfirmed);
    final writesHousingStatus = onlyInputKey == 'q_housing_status' ||
        (onlyInputKey == null && _housingStatusConfirmed);
    final children =
        collectsChildren ? int.tryParse(_childrenController.text.trim()) : null;
    if (writesChildren && (children == null || children < 0)) {
      setState(() {
        _householdError = l.authErrorInvalid;
        _householdPersistenceFailed = false;
      });
      return;
    }

    setState(() {
      _isSavingHousehold = true;
      _householdError = null;
      _householdSaved = false;
      _householdPersistenceFailed = false;
    });

    final persisted = await _persistAnswers({
      if (writesChildren) 'q_children': children,
      if (writesCivilStatus) 'q_civil_status': _civilStatus,
      if (writesHousingStatus) 'q_housing_status': _housingStatus,
    });
    if (!mounted) return;
    if (!persisted) {
      setState(() {
        _isSavingHousehold = false;
        _householdError = l.authErrorGeneric;
        _householdSaved = false;
        _householdPersistenceFailed = true;
      });
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _isSavingHousehold = false;
      _householdSaved = true;
    });
    _exitAfterSuccessfulSave();
  }

  Widget _buildPatrimoineCollector(S l) {
    final onlyInputKey = _canonicalPatrimoineInputKey(widget.initialInputKey);
    final collectsCash = onlyInputKey == null || onlyInputKey == 'q_cash_total';
    final collectsWealthEstimate = onlyInputKey == 'q_wealth_estimate';
    final collectsPropertyValue = onlyInputKey == 'q_property_market_value';
    final collectsMortgageBalance = onlyInputKey == '_coach_dettes_hypotheque';
    final collectsDebtPayments = onlyInputKey == 'q_debt_payments_period_chf';

    return MintSurface(
      padding: const EdgeInsets.all(18),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (collectsCash)
            _buildRevenueTextField(
              key: const Key('savings_input'),
              semanticsIdentifier: 'savings_input',
              controller: _cashController,
              label: l.financialSummaryEditEpargneLiquide,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r"[0-9' ]"))
              ],
              onChanged: (_) => setState(() => _patrimoineSaved = false),
            ),
          if (collectsWealthEstimate)
            _buildRevenueTextField(
              key: const Key('wealth_estimate_input'),
              semanticsIdentifier: 'wealth_estimate_input',
              controller: _wealthEstimateController,
              label: l.donationFortuneTotale,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r"[0-9' ]"))
              ],
              onChanged: (_) => setState(() => _patrimoineSaved = false),
            ),
          if (collectsPropertyValue)
            _buildRevenueTextField(
              key: const Key('property_market_value_input'),
              semanticsIdentifier: 'property_market_value_input',
              controller: _propertyMarketValueController,
              label: l.locationPrixBien,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r"[0-9' ]"))
              ],
              onChanged: (_) => setState(() => _patrimoineSaved = false),
            ),
          if (collectsMortgageBalance)
            _buildRevenueTextField(
              key: const Key('mortgage_balance_input'),
              semanticsIdentifier: 'mortgage_balance_input',
              controller: _mortgageBalanceController,
              label: l.financialSummaryHypothequeRestante,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r"[0-9' ]"))
              ],
              onChanged: (_) => setState(() => _patrimoineSaved = false),
            ),
          if (collectsDebtPayments)
            _buildRevenueTextField(
              key: const Key('debt_payments_input'),
              semanticsIdentifier: 'debt_payments_input',
              controller: _debtPaymentsController,
              label: l.debtRatioChargesDette,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r"[0-9' ]"))
              ],
              onChanged: (_) => setState(() => _patrimoineSaved = false),
            ),
          if (_patrimoineError != null) ...[
            const SizedBox(height: 8),
            if (_patrimoinePersistenceFailed)
              _buildPersistenceError(l, _savePatrimoineFacts)
            else
              Text(
                _patrimoineError!,
                style: MintTextStyles.labelMedium(color: MintColors.error),
              ),
          ],
          if (_patrimoineSaved) ...[
            const SizedBox(height: 8),
            _buildSaveSuccess(l),
          ],
          const SizedBox(height: 12),
          Semantics(
            identifier: 'patrimoine_save_cta',
            button: true,
            label: l.financialSummaryEnregistrer,
            child: FilledButton(
              key: const Key('patrimoine_save_cta'),
              onPressed: _isSavingPatrimoine ? null : _savePatrimoineFacts,
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.primary,
                foregroundColor: MintColors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSavingPatrimoine
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: MintColors.white,
                      ),
                    )
                  : Text(
                      l.financialSummaryEnregistrer,
                      style: MintTextStyles.titleMedium()
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _savePatrimoineFacts() async {
    final l = S.of(context)!;
    final onlyInputKey = _canonicalPatrimoineInputKey(widget.initialInputKey);
    final collectsCash = onlyInputKey == null || onlyInputKey == 'q_cash_total';
    final collectsWealthEstimate = onlyInputKey == 'q_wealth_estimate';
    final collectsPropertyValue = onlyInputKey == 'q_property_market_value';
    final collectsMortgageBalance = onlyInputKey == '_coach_dettes_hypotheque';
    final collectsDebtPayments = onlyInputKey == 'q_debt_payments_period_chf';
    final cash =
        collectsCash ? int.tryParse(_digitsOnly(_cashController.text)) : null;
    final wealthEstimate = collectsWealthEstimate
        ? int.tryParse(_digitsOnly(_wealthEstimateController.text))
        : null;
    final propertyMarketValue = collectsPropertyValue
        ? int.tryParse(_digitsOnly(_propertyMarketValueController.text))
        : null;
    final mortgageBalance = collectsMortgageBalance
        ? int.tryParse(_digitsOnly(_mortgageBalanceController.text))
        : null;
    final debtPayments = collectsDebtPayments
        ? int.tryParse(_digitsOnly(_debtPaymentsController.text))
        : null;

    if ((collectsCash && (cash == null || cash < 0)) ||
        (collectsWealthEstimate &&
            (wealthEstimate == null || wealthEstimate <= 0)) ||
        (collectsPropertyValue &&
            (propertyMarketValue == null || propertyMarketValue <= 0)) ||
        (collectsMortgageBalance &&
            (mortgageBalance == null || mortgageBalance < 0)) ||
        (collectsDebtPayments && (debtPayments == null || debtPayments < 0))) {
      setState(() {
        _patrimoineError = l.authErrorInvalid;
        _patrimoinePersistenceFailed = false;
      });
      return;
    }
    setState(() {
      _isSavingPatrimoine = true;
      _patrimoineError = null;
      _patrimoineSaved = false;
      _patrimoinePersistenceFailed = false;
    });
    final persisted = await _persistAnswers({
      if (collectsCash) 'q_cash_total': cash,
      if (collectsWealthEstimate) 'q_wealth_estimate': wealthEstimate,
      if (collectsPropertyValue) 'q_property_market_value': propertyMarketValue,
      if (collectsMortgageBalance) '_coach_dettes_hypotheque': mortgageBalance,
      if (collectsDebtPayments) ...{
        'q_debt_payments_period_chf': debtPayments,
        'q_has_consumer_debt': debtPayments! > 0 ? 'yes' : 'no',
      },
    });
    if (!mounted) return;
    if (!persisted) {
      setState(() {
        _isSavingPatrimoine = false;
        _patrimoineError = l.authErrorGeneric;
        _patrimoineSaved = false;
        _patrimoinePersistenceFailed = true;
      });
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _isSavingPatrimoine = false;
      _patrimoineSaved = true;
    });
    _exitAfterSuccessfulSave();
  }

  Future<bool> _persistAnswers(Map<String, dynamic> answers) async {
    if (answers.isEmpty) return true;

    final provider = context.read<CoachProfileProvider>();
    try {
      await provider.mergeAnswers(answers);
      return true;
    } on Object {
      // This is the persistence boundary: each caller turns failure into the
      // same visible, retryable state without clearing controller input.
      return false;
    }
  }

  void _exitAfterSuccessfulSave() {
    final target = widget.returnTarget;
    if (target != null) context.go(target.location);
  }

  void _cancelToReturnTarget() {
    final target = widget.returnTarget;
    if (target == null) {
      safePop(context);
      return;
    }
    context.go(target.location);
  }

  Widget _buildPersistenceError(S l, VoidCallback onRetry) {
    return Semantics(
      key: const Key('data_block_save_error'),
      identifier: 'data_block_save_error',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.authErrorGeneric,
            style: MintTextStyles.labelMedium(color: MintColors.error),
          ),
          const SizedBox(height: 8),
          Semantics(
            identifier: 'data_block_save_retry_cta',
            button: true,
            label: l.commonRetry,
            child: FilledButton(
              key: const Key('data_block_save_retry_cta'),
              onPressed: onRetry,
              child: Text(l.commonRetry),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveSuccess(S l) {
    return Semantics(
      key: const Key('data_block_save_success'),
      identifier: 'data_block_save_success',
      container: true,
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              color: MintColors.success, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.documentDetailProfileUpdated,
              style: MintTextStyles.labelMedium(color: MintColors.success)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

  String? _canonicalHouseholdInputKey(String? inputKey) {
    if (inputKey == null || inputKey.trim().isEmpty) return null;
    final token =
        inputKey.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return switch (token) {
      'qchildren' || 'children' || 'enfants' || 'nombreenfants' => 'q_children',
      'qcivilstatus' ||
      'civilstatus' ||
      'etatcivil' ||
      'situationfamiliale' ||
      'householdtype' =>
        'q_civil_status',
      'qhousingstatus' ||
      'housingstatus' ||
      'statutlogement' =>
        'q_housing_status',
      _ => null,
    };
  }

  String? _canonicalPatrimoineInputKey(String? inputKey) {
    if (inputKey == null || inputKey.trim().isEmpty) return null;
    final token =
        inputKey.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return switch (token) {
      'totalsavings' ||
      'cashtotal' ||
      'qcashtotal' ||
      'epargneliquide' ||
      'savings' =>
        'q_cash_total',
      'qwealthestimate' ||
      'wealthestimate' ||
      'fortuneestimate' ||
      'fortuneestimee' ||
      'patrimoinetotal' ||
      'fortune' =>
        'q_wealth_estimate',
      'qmortgagebalance' ||
      'mortgagebalance' ||
      'remainingmortgage' ||
      'soldehypothecaire' ||
      'hypothequerestante' ||
      'coachdetteshypotheque' =>
        '_coach_dettes_hypotheque',
      'qpropertymarketvalue' ||
      'propertymarketvalue' ||
      'propertyvalue' ||
      'realestatevalue' ||
      'valeurimmobiliere' ||
      'valeurbien' ||
      'prixbien' =>
        'q_property_market_value',
      'qdebtpaymentsperiodchf' ||
      'debtpayments' ||
      'monthlydebtpayments' ||
      'chargesdette' ||
      'mensualitedettes' =>
        'q_debt_payments_period_chf',
      _ => null,
    };
  }

  String? _canonicalRevenueInputKey(String? inputKey) {
    if (inputKey == null || inputKey.trim().isEmpty) return null;
    final token =
        inputKey.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return switch (token) {
      'qgrosssalaryannual' ||
      'incomegrossyearly' ||
      'revenubrutannuel' ||
      'grosssalaryannual' ||
      'salary' =>
        'q_gross_salary_annual',
      'qselfemployedincome' ||
      'selfemployedincome' ||
      'revenuindependant' ||
      'revenunetannuelindependant' =>
        'q_self_employed_income',
      'qcompanyprofitannualchf' ||
      'companyprofitannual' ||
      'companyprofit' ||
      'beneficeannuelsociete' ||
      'beneficetotal' =>
        'q_company_profit_annual_chf',
      'qunemploymentcontributionmonths' ||
      'unemploymentcontributionmonths' ||
      'unemploymentmonths' ||
      'moiscotisationchomage' ||
      'moisdecotisationchomage' =>
        'q_unemployment_contribution_months',
      'qcanton' || 'canton' => 'q_canton',
      'qbirthyear' || 'birthyear' => 'q_birth_year',
      'qdateofbirth' || 'dateofbirth' || 'datedenaissance' => 'q_date_of_birth',
      'qgender' || 'gender' || 'genre' || 'sexeavs' => 'q_gender',
      'qhaspensionfund' ||
      'has2ndpillar' ||
      'haspensionfund' =>
        'q_has_pension_fund',
      _ => null,
    };
  }

  bool _capturesRevenue(String inputKey, String? onlyInputKey) {
    return onlyInputKey == null || onlyInputKey == inputKey;
  }

  Widget _buildPrompts(CoachProfile profile, String type, BlockScore? bloc) {
    final confidence = ConfidenceScorer.score(profile);
    final relevant = confidence.prompts
        .where((p) => _categoryMatchesBlock(p.category, type))
        .toList();

    if (relevant.isEmpty) {
      final isComplete = bloc?.status == 'complete';
      if (!isComplete) {
        return MintSurface(
          tone: MintSurfaceTone.peche,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  color: MintColors.warning, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  S.of(context)!.dataBlockIncomplete,
                  style:
                      MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                          .copyWith(height: 1.4),
                ),
              ),
            ],
          ),
        );
      }
      return Semantics(
        key: const Key('data_block_complete_state'),
        identifier: 'data_block_complete_state',
        container: true,
        child: MintSurface(
          tone: MintSurfaceTone.sauge,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  color: MintColors.success, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  S.of(context)!.dataBlockComplete,
                  style: MintTextStyles.bodyMedium(color: MintColors.success),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: relevant.map((prompt) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: MintSurface(
            padding: const EdgeInsets.all(16),
            radius: 12,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: MintColors.primary.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '+${prompt.impact}',
                      style:
                          MintTextStyles.labelSmall(color: MintColors.primary)
                              .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prompt.localizedLabel(S.of(context)!),
                        style: MintTextStyles.bodyMedium(
                                color: MintColors.textPrimary)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: MintSpacing.xs),
                      Text(
                        prompt.localizedAction(S.of(context)!),
                        style: MintTextStyles.labelSmall(
                            color: MintColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildValidationAlerts(CoachProfile profile, String blockType) {
    final relevant = _getAlertsForBlock(profile, blockType);

    if (relevant.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 16),
        ...relevant.map((alert) {
          final color = switch (alert.severity) {
            AlertSeverity.error => MintColors.error,
            AlertSeverity.warning => MintColors.warning,
            AlertSeverity.info => MintColors.primary,
          };
          final icon = switch (alert.severity) {
            AlertSeverity.error => Icons.error_outline,
            AlertSeverity.warning => Icons.warning_amber_rounded,
            AlertSeverity.info => Icons.lightbulb_outline,
          };

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withAlpha(12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withAlpha(48)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: color, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          alert.message,
                          style: MintTextStyles.bodySmall(
                                  color: MintColors.textPrimary)
                              .copyWith(height: 1.4),
                        ),
                      ),
                    ],
                  ),
                  if (alert.suggestion != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: Text(
                        alert.suggestion!,
                        style: MintTextStyles.labelSmall(
                                color: MintColors.textSecondary)
                            .copyWith(height: 1.4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  bool _categoryMatchesBlock(String category, String blockType) {
    const mapping = {
      'revenu': ['income'],
      'lpp': ['lpp'],
      'avs': ['avs'],
      '3a': ['3a'],
      'patrimoine': ['patrimoine'],
      'fiscalite': ['fiscalite', 'tax', 'commune'],
      'objectifRetraite': ['objectif_retraite', 'retirement_urgency'],
      'compositionMenage': ['menage'],
      'foreign_pension': ['foreign_pension'],
    };
    final categories = mapping[blockType] ?? [];
    return categories.contains(category);
  }

  String? _enrichmentRoute(String type) {
    const routes = {
      'revenu': '/coach/chat', // P10-02b: was /onboarding/quick (deleted)
      'lpp': '/scan',
      'avs': '/document-scan/avs-guide',
      '3a': '/pilier-3a',
      'patrimoine': '/profile/bilan',
      'fiscalite': '/fiscal',
      'objectifRetraite': '/coach/cockpit',
      'compositionMenage': '/couple',
    };
    return routes[type] ?? '/profile/bilan';
  }

  String _canonicalBlockType(String rawType) {
    final normalized = _normalizeTypeToken(rawType);
    return switch (normalized) {
      'situation' ||
      'income' ||
      'salary' ||
      'revenu' ||
      'salaire' ||
      'base' ||
      'age_canton' =>
        'revenu',
      'couple' ||
      'menage' ||
      'household' ||
      'composition_menage' ||
      'compositionmenage' =>
        'compositionMenage',
      'pension' ||
      'lpp' ||
      'prevoyance' ||
      'prevoyance_lpp' ||
      'pension_lpp' ||
      'lpp_balance' ||
      'lpp_details' ||
      'taux_conversion' =>
        'lpp',
      'avs' || 'avs_extract' || 'ci' => 'avs',
      'goal' ||
      'objectif' ||
      'objectif_retraite' ||
      'retirement_goal' ||
      'retirement_urgency' =>
        'objectifRetraite',
      'housing' ||
      'property' ||
      'patrimoine' ||
      'wealth' ||
      'asset' ||
      'assets' =>
        'patrimoine',
      '3a' || 'pilier_3a' || 'epargne_3a' => '3a',
      'fiscalite' ||
      'fiscal' ||
      'tax' ||
      'impot' ||
      'impots' ||
      'tax_declaration' =>
        'fiscalite',
      _ => rawType.trim(),
    };
  }

  String _normalizeTypeToken(String value) {
    var normalized = value.trim().toLowerCase();
    const accents = {
      0x00E0: 'a',
      0x00E2: 'a',
      0x00E4: 'a',
      0x00E9: 'e',
      0x00E8: 'e',
      0x00EA: 'e',
      0x00EB: 'e',
      0x00EE: 'i',
      0x00EF: 'i',
      0x00F4: 'o',
      0x00F6: 'o',
      0x00F9: 'u',
      0x00FB: 'u',
      0x00FC: 'u',
      0x00E7: 'c',
    };
    accents.forEach((source, target) {
      normalized = normalized.replaceAll(String.fromCharCode(source), target);
    });
    normalized = normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return normalized;
  }

  _BlockMeta _blockMeta(String type, S l) {
    return switch (type) {
      'revenu' => _BlockMeta(
          title: l.dataBlockRevenuTitle,
          description: l.dataBlockRevenuDesc,
          ctaLabel: l.dataBlockRevenuCta,
        ),
      'lpp' => _BlockMeta(
          title: l.dataBlockLppTitle,
          description: l.dataBlockLppDesc,
          ctaLabel: l.dataBlockLppCta,
        ),
      'avs' => _BlockMeta(
          title: l.dataBlockAvsTitle,
          description: l.dataBlockAvsDesc,
          ctaLabel: l.dataBlockAvsCta,
        ),
      '3a' => _BlockMeta(
          title: l.dataBlock3aTitle,
          description: l.dataBlock3aDesc,
          ctaLabel: l.dataBlock3aCta,
        ),
      'patrimoine' => _BlockMeta(
          title: l.dataBlockPatrimoineTitle,
          description: l.dataBlockPatrimoineDesc,
          ctaLabel: l.dataBlockPatrimoineCta,
        ),
      'fiscalite' => _BlockMeta(
          title: l.dataBlockFiscaliteTitle,
          description: l.dataBlockFiscaliteDesc,
          ctaLabel: l.dataBlockFiscaliteCta,
        ),
      'objectifRetraite' => _BlockMeta(
          title: l.dataBlockObjectifTitle,
          description: l.dataBlockObjectifDesc,
          ctaLabel: l.dataBlockObjectifCta,
        ),
      'compositionMenage' => _BlockMeta(
          title: l.dataBlockMenageTitle,
          description: l.dataBlockMenageDesc,
          ctaLabel: l.dataBlockMenageCta,
        ),
      'unknown' => _BlockMeta(
          title: l.dataBlockUnknownTitle,
          description: l.dataBlockUnknownDesc,
          ctaLabel: l.dataBlockUnknownCta,
        ),
      _ => _BlockMeta(
          title: l.dataBlockDefaultTitle,
          description: l.dataBlockDefaultDesc,
          ctaLabel: l.dataBlockDefaultCta,
        ),
    };
  }
}

class _BlockMeta {
  final String title;
  final String description;
  final String ctaLabel;

  const _BlockMeta({
    required this.title,
    required this.description,
    required this.ctaLabel,
  });
}

class _BlockScoreBar extends StatelessWidget {
  final BlockScore bloc;

  const _BlockScoreBar({required this.bloc});

  @override
  Widget build(BuildContext context) {
    final ratio = bloc.maxScore > 0 ? bloc.score / bloc.maxScore : 0.0;
    final color = switch (bloc.status) {
      'complete' => MintColors.success,
      'partial' => MintColors.warning,
      _ => MintColors.error,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${bloc.score.round()} / ${bloc.maxScore.round()} pts',
              style: MintTextStyles.titleMedium(color: color)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            Semantics(
              key: Key('data_block_status_${bloc.status}'),
              identifier: 'data_block_status_${bloc.status}',
              container: true,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  switch (bloc.status) {
                    'complete' => S.of(context)!.dataBlockStatusComplete,
                    'partial' => S.of(context)!.dataBlockStatusPartial,
                    _ => S.of(context)!.dataBlockStatusMissing,
                  },
                  style: MintTextStyles.labelSmall(color: color)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: MintColors.lightBorder,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Coach Mode Toggle
// ═══════════════════════════════════════════════════════════════

class _CoachModeToggle extends StatelessWidget {
  final bool isCoachMode;
  final bool coachAvailable;
  final ValueChanged<bool> onToggle;

  const _CoachModeToggle({
    required this.isCoachMode,
    required this.coachAvailable,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ModeChip(
            label: S.of(context)!.dataBlockModeForm,
            icon: Icons.edit_note,
            isSelected: !isCoachMode,
            onTap: () => onToggle(false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ModeChip(
            label: S.of(context)!.dataBlockModeCoach,
            icon: Icons.smart_toy_outlined,
            isSelected: isCoachMode,
            isDisabled: !coachAvailable,
            onTap: coachAvailable ? () => onToggle(true) : null,
          ),
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback? onTap;

  const _ModeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    this.isDisabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDisabled
        ? MintColors.textMuted
        : isSelected
            ? MintColors.primary
            : MintColors.textSecondary;

    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color:
                isSelected ? MintColors.primary.withAlpha(15) : MintColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? MintColors.primary.withAlpha(60)
                  : MintColors.lightBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: MintTextStyles.bodySmall(color: color).copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Coach Bubble — conversational enrichment guide
// ═══════════════════════════════════════════════════════════════

// _CoachBubble removed — "Parle au coach" now navigates to /coach/chat
// with a contextual prompt for the block type.
