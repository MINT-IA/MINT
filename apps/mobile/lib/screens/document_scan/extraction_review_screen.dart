import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mint_mobile/services/navigation/safe_pop.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/models/partner_accountability.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/lpp_extraction_adapter.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/services/financial_core/swiss_civil_time.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/providers/biography_provider.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/document_service.dart';
import 'package:mint_mobile/services/consent/partner_accountability_binding_store.dart';
import 'package:mint_mobile/services/consent/partner_accountability_service.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

// ────────────────────────────────────────────────────────────
//  EXTRACTION REVIEW SCREEN — Sprint S42-S43
// ────────────────────────────────────────────────────────────
//  Displays extracted fields with confidence badges.
//  User can edit any field before confirming.
//
//  Reference: DATA_ACQUISITION_STRATEGY.md — Channel 1
//  User flow step 4: extraction review.
// ────────────────────────────────────────────────────────────

typedef ScanConfirmationSender = Future<void> Function({
  required String documentType,
  required List<Map<String, dynamic>> confirmedFields,
  required double overallConfidence,
});

typedef LppReviewReferenceRecorder = Future<ConfirmedDocumentReference>
    Function(LppReviewReceipt receipt);

class ExtractionReviewScreen extends StatefulWidget {
  final String scanSessionId;
  final ExtractionResult result;
  final LppExtractionCandidate? lppCandidate;
  final LppAcquisitionAuthorization? lppAuthorization;
  final LppRegulationAcquisitionCandidate? lppRegulationCandidate;
  final ManualPartnerAccountabilityContext? manualPartnerAccountability;
  final TaxExtractionCandidate? taxCandidate;
  final ScanConfirmationSender? sendScanConfirmation;
  final int Function(CoachProfile)? confidenceScorer;
  final DateTime Function()? now;
  final PartnerAccountabilityBindingStore? partnerBindingStore;
  final PartnerAccountabilityService? partnerAccountabilityService;
  final LppReviewReferenceRecorder? recordConfirmedLppReview;

  const ExtractionReviewScreen({
    super.key,
    required this.scanSessionId,
    required this.result,
    this.lppCandidate,
    this.lppAuthorization,
    this.lppRegulationCandidate,
    this.manualPartnerAccountability,
    this.taxCandidate,
    this.sendScanConfirmation,
    this.confidenceScorer,
    this.now,
    this.partnerBindingStore,
    this.partnerAccountabilityService,
    this.recordConfirmedLppReview,
  });

  @override
  State<ExtractionReviewScreen> createState() => _ExtractionReviewScreenState();
}

enum _DocumentOwnerChoice { self, manualPartner }

class _ExtractionReviewScreenState extends State<ExtractionReviewScreen> {
  /// Per-field confidence thresholds (DOC-03).
  /// Salary fields require >= 0.90, LPP capital fields require >= 0.95.
  static const _fieldThresholds = <String, double>{
    'salaireBrutAnnuel': 0.90,
    'salaireBrutMensuel': 0.90,
    'avoirLppTotal': 0.95,
    'avoirLppObligatoire': 0.95,
    'avoirLppSurobligatoire': 0.95,
    'tauxConversion': 0.95,
    'rachatMaximum': 0.90,
    'salaireAssure': 0.90,
    // Default for unlisted fields: 0.80
  };

  /// Get the confidence threshold for a specific field.
  static double _thresholdFor(String fieldName) {
    final lppKey = LppEvidenceFactKey.fromWireName(fieldName);
    if (lppKey != null) return lppKey.reviewConfidenceThreshold;
    return _fieldThresholds[fieldName] ?? 0.80;
  }

  late List<ExtractedField> _fields;
  late double _overallConfidence;
  ScanSessionProvider? _scanSessions;
  bool _transferredToImpact = false;
  bool _partnerReceiptFinalized = false;
  LppReviewReceipt? _acceptedLppReceipt;
  LppReviewConfirmation? _acceptedLppConfirmation;
  int? _acceptedLppPreviousConfidence;
  Future<void>? _partnerCleanup;
  bool _isConfirming = false;
  bool _taxValidationFailed = false;
  bool _lppSourceDateValidationFailed = false;
  bool _lppBalanceValidationFailed = false;
  bool _lppReferenceFailed = false;
  bool _lppRegulationSourceDateValidationFailed = false;
  bool _lppRegulationLegalYearValidationFailed = false;
  bool _lppRegulationFundRelationshipValidationFailed = false;
  bool _lppRegulationAcceptFailed = false;
  bool _lppRegulationRecordFailed = false;
  bool _reviewSessionFinalized = false;
  LppRegulationReviewConfirmation? _acceptedLppRegulationConfirmation;
  LppRegulationReceipt? _acceptedLppRegulationReceipt;
  LppFundRelationship? _lppFundRelationship;
  bool _taxInForceAttested = false;
  bool _federalScopeIncoherent = false;
  late final PartnerAccountabilityBindingStore _partnerBindingStore =
      widget.partnerBindingStore ?? PartnerAccountabilityBindingStore();
  late final PartnerAccountabilityService _partnerAccountabilityService =
      widget.partnerAccountabilityService ?? PartnerAccountabilityService();

  TaxDocumentKind _taxDocumentKind = TaxDocumentKind.unknown;
  TaxAssessmentStatus _taxAssessmentStatus = TaxAssessmentStatus.unknown;
  TaxSubjectScope _taxSubjectScope = TaxSubjectScope.unknown;
  TaxAuthorityScope _cantonalAuthorityScope = TaxAuthorityScope.unknown;
  TaxBaseScope _cantonalBaseScope = TaxBaseScope.unknown;
  TaxAuthorityScope _federalAuthorityScope = TaxAuthorityScope.federalDirect;
  TaxBaseScope _federalBaseScope = TaxBaseScope.unknown;

  final _taxYearController = TextEditingController();
  final _basedOnTaxYearController = TextEditingController();
  final _sourceDateController = TextEditingController();
  final _lppRegulationLegalYearController = TextEditingController();
  final _cantonCodeController = TextEditingController();
  final _municipalityIdController = TextEditingController();
  final _municipalityLabelController = TextEditingController();
  final _cantonalIncomeController = TextEditingController();
  final _federalIncomeController = TextEditingController();
  final _wealthController = TextEditingController();
  final _cantonalTaxController = TextEditingController();
  final _federalTaxController = TextEditingController();
  final _marginalRateController = TextEditingController();
  final _averageRateController = TextEditingController();
  final _lppRegulationRetryScrollKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fields = List.from(widget.result.fields);
    _overallConfidence = widget.result.overallConfidence;
    _initializeTaxReview(widget.taxCandidate);
    _initializeLppReview(widget.lppCandidate);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scanSessions ??= context.read<ScanSessionProvider>();
  }

  @override
  void dispose() {
    if (!_partnerReceiptFinalized) unawaited(_cleanupPartnerReceipt());
    if (!_transferredToImpact && !_reviewSessionFinalized) {
      final scanSessions = _scanSessions;
      if (scanSessions != null) {
        unawaited(Future<void>.microtask(
          () => scanSessions.discard(widget.scanSessionId),
        ));
      }
    }
    for (final controller in [
      _taxYearController,
      _basedOnTaxYearController,
      _sourceDateController,
      _lppRegulationLegalYearController,
      _cantonCodeController,
      _municipalityIdController,
      _municipalityLabelController,
      _cantonalIncomeController,
      _federalIncomeController,
      _wealthController,
      _cantonalTaxController,
      _federalTaxController,
      _marginalRateController,
      _averageRateController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _requiresPartnerAccountability =>
      widget.lppAuthorization?.subject == LppEvidenceOwnerKind.manualPartner;

  bool get _partnerAccountabilityStillValid {
    if (!_requiresPartnerAccountability) {
      return widget.manualPartnerAccountability == null;
    }
    final authorization = widget.lppAuthorization!;
    final accountability = widget.manualPartnerAccountability;
    final current = (widget.now ?? DateTime.now)().toUtc();
    return FeatureFlags.partnerLppAccountabilityEnabled &&
        accountability != null &&
        authorization.receiptId != null &&
        authorization.manualPartnerOwnerId != null &&
        accountability.isActiveAt(current) &&
        accountability.matchesAuthorization(
          receiptId: authorization.receiptId,
          ownerId: authorization.manualPartnerOwnerId,
        );
  }

  Future<void> _cleanupPartnerReceipt() {
    final existing = _partnerCleanup;
    if (existing != null) return existing;
    final accountability = widget.manualPartnerAccountability;
    if (accountability == null || _partnerReceiptFinalized) {
      return Future.value();
    }
    final cleanup = () async {
      try {
        await _partnerAccountabilityService.erase(accountability.receiptId);
      } catch (_) {
        // Backend DELETE is idempotent; cold reconciliation remains fail closed.
      }
      try {
        await _partnerBindingStore.rollback(
          receiptId: accountability.receiptId,
          manualPartnerOwnerId: accountability.ownerId,
        );
      } catch (_) {
        // A concurrent terminal transition must not restore a different binding.
      }
    }();
    _partnerCleanup = cleanup;
    return cleanup;
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.result.documentType == DocumentType.lppPlan) {
      if (!FeatureFlags.lppRegulationAcquisitionEnabled) {
        return _buildLppRegulationRecovery(
          key: const Key('lpp_regulation_review_disabled_recovery'),
        );
      }
      if (widget.lppRegulationCandidate == null) {
        return _buildLppRegulationRecovery(
          key: const Key(
            'lpp_regulation_review_missing_candidate_recovery',
          ),
        );
      }
      return _buildLppRegulationReview();
    }
    if (widget.result.documentType == DocumentType.lppCertificate &&
        !FeatureFlags.lppEvidenceIngestionEnabled) {
      return _buildLppRecovery(
        key: const Key('lpp_review_disabled_recovery'),
      );
    }
    if (_acceptedLppReceipt == null &&
        widget.result.documentType == DocumentType.lppCertificate &&
        (widget.lppCandidate == null ||
            !_isCanonicalLppReview(widget.lppCandidate!) ||
            widget.lppAuthorization == null ||
            !widget.lppAuthorization!.isValidAt(
              (widget.now ?? DateTime.now)().toUtc(),
            ) ||
            !_partnerAccountabilityStillValid)) {
      unawaited(_cleanupPartnerReceipt());
      return _buildLppRecovery(
        key: const Key('lpp_review_missing_candidate_recovery'),
      );
    }
    if (widget.result.documentType == DocumentType.taxDeclaration &&
        !FeatureFlags.taxAssessmentIngestionEnabled) {
      return _buildTaxRecovery(
        key: const Key('tax_review_disabled_recovery'),
      );
    }
    if (widget.result.documentType == DocumentType.taxDeclaration &&
        widget.taxCandidate == null) {
      return _buildTaxRecovery(
        key: const Key('tax_review_missing_candidate_recovery'),
      );
    }
    return Scaffold(
      backgroundColor: MintColors.background,
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: CustomScrollView(
                slivers: [
                  _buildAppBar(context),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const SizedBox(height: 12),
                        MintEntrance(child: _buildHeader()),
                        const SizedBox(height: 8),
                        _buildDeeplinkBanner(),
                        const SizedBox(height: 8),
                        MintEntrance(
                            delay: const Duration(milliseconds: 100),
                            child: _buildOverallConfidenceBadge()),
                        const SizedBox(height: 20),
                        if (widget.result.planTypeWarning != null) ...[
                          _buildLpp1eWarning(),
                          const SizedBox(height: 8),
                        ],
                        if (widget.result.coherenceWarnings.isNotEmpty) ...[
                          _buildCoherenceWarnings(),
                          const SizedBox(height: 8),
                        ],
                        if (widget.result.warnings.isNotEmpty ||
                            widget.result.diagnostics.isNotEmpty) ...[
                          _buildWarnings(),
                          const SizedBox(height: 20),
                        ],
                        if (widget.result.documentType ==
                            DocumentType.taxDeclaration)
                          _buildTaxReviewForm()
                        else ...[
                          if (widget.result.documentType ==
                              DocumentType.lppCertificate) ...[
                            _buildLppOwnerBadge(),
                            const SizedBox(height: 12),
                            if (widget.lppAuthorization?.subject ==
                                    LppEvidenceOwnerKind.manualPartner &&
                                widget.lppCandidate?.facts.containsKey(
                                      LppEvidenceFactKey.fundReturnRateRatio,
                                    ) ==
                                    true) ...[
                              MintSurface(
                                key: const Key(
                                  'lpp_review_caisse_rate_quarantined',
                                ),
                                tone: MintSurfaceTone.porcelaine,
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  S.of(context)!.lppPartnerCaisseRateExcluded,
                                  style: MintTextStyles.bodySmall(
                                    color: MintColors.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            _buildLppSourceDateField(),
                            const SizedBox(height: 8),
                          ],
                          ..._fields.map((f) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildFieldCard(f),
                              )),
                        ],
                        if (_taxValidationFailed) ...[
                          const SizedBox(height: 12),
                          Text(
                            S.of(context)!.docFieldVerify,
                            style: MintTextStyles.bodyMedium(
                                color: MintColors.error),
                          ),
                        ],
                        if (_lppBalanceValidationFailed) ...[
                          const SizedBox(height: 12),
                          Text(
                            S.of(context)!.lppReviewBalanceIncoherent,
                            key: const Key('lpp_review_balance_error'),
                            style: MintTextStyles.bodyMedium(
                              color: MintColors.error,
                            ),
                          ),
                        ],
                        if (_lppReferenceFailed) ...[
                          const SizedBox(height: 12),
                          MintSurface(
                            key: const Key('lpp_reference_retry_state'),
                            tone: MintSurfaceTone.porcelaine,
                            padding: const EdgeInsets.all(14),
                            child: Text(
                              S.of(context)!.lppReferencePersistFailed,
                              style: MintTextStyles.bodyMedium(
                                color: MintColors.error,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        MintEntrance(
                            delay: const Duration(milliseconds: 200),
                            child: _buildConfirmButton()),
                        const SizedBox(height: 16),
                        MintEntrance(
                            delay: const Duration(milliseconds: 300),
                            child: _buildDisclaimer()),
                        const SizedBox(height: 100),
                      ]),
                    ),
                  ),
                ],
              ))),
    );
  }

  // ── AppBar ───────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: MintColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: Semantics(
        identifier: widget.result.documentType == DocumentType.taxDeclaration
            ? 'tax_review_back_cta'
            : null,
        button: true,
        label: S.of(context)!.documentScanCancel,
        child: IconButton(
          key: widget.result.documentType == DocumentType.taxDeclaration
              ? const Key('tax_review_back_cta')
              : null,
          icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
          onPressed: _onBack,
          tooltip: S.of(context)!.documentScanCancel,
        ),
      ),
      title: Text(
        S.of(context)!.extractionReviewAppBar,
        style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildTaxRecovery({required Key key}) {
    return Scaffold(
      key: key,
      backgroundColor: MintColors.background,
      appBar: AppBar(
        backgroundColor: MintColors.background,
        leading: Semantics(
          identifier: 'tax_review_back_cta',
          button: true,
          label: S.of(context)!.documentScanCancel,
          child: IconButton(
            key: const Key('tax_review_back_cta'),
            onPressed: _onBack,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            S.of(context)!.docScanGenericError,
            style: MintTextStyles.bodyLarge(color: MintColors.textPrimary),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildLppRecovery({required Key key}) {
    return Scaffold(
      key: key,
      backgroundColor: MintColors.background,
      appBar: AppBar(
        backgroundColor: MintColors.background,
        leading: IconButton(
          onPressed: _onBack,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                S.of(context)!.docScanGenericError,
                style: MintTextStyles.bodyLarge(color: MintColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('lpp_review_recovery_cta'),
                onPressed: _onBack,
                child: Text(S.of(context)!.documentScanCancel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLppRegulationRecovery({required Key key}) {
    return Scaffold(
      key: key,
      backgroundColor: MintColors.background,
      appBar: AppBar(
        backgroundColor: MintColors.background,
        leading: IconButton(
          onPressed: _onBack,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                S.of(context)!.lppRegulationReviewRecoveryBody,
                style: MintTextStyles.bodyLarge(color: MintColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Semantics(
                identifier: 'lpp_regulation_review_recovery_cta',
                button: true,
                child: FilledButton(
                  key: const Key('lpp_regulation_review_recovery_cta'),
                  onPressed: _onBack,
                  child: Text(S.of(context)!.documentScanCancel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLppRegulationReview() {
    final l10n = S.of(context)!;
    final fieldsEnabled =
        !_isConfirming && _acceptedLppRegulationReceipt == null;
    return Semantics(
      identifier: 'lpp_regulation_review_screen',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        key: const Key('lpp_regulation_review_screen'),
        backgroundColor: MintColors.background,
        appBar: AppBar(
          backgroundColor: MintColors.background,
          leading: IconButton(
            onPressed: _onBack,
            icon: const Icon(Icons.arrow_back),
            tooltip: l10n.documentScanCancel,
          ),
          title: Text(
            l10n.lppRegulationReviewTitle,
            style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MintSurface(
                    tone: MintSurfaceTone.porcelaine,
                    padding: const EdgeInsets.all(14),
                    radius: 12,
                    child: Text(
                      l10n.lppRegulationReviewBody,
                      style: MintTextStyles.bodyMedium(
                        color: MintColors.textSecondary,
                      ).copyWith(height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Semantics(
                    identifier: 'lpp_regulation_review_source_date',
                    textField: true,
                    child: TextFormField(
                      key: const Key('lpp_regulation_review_source_date'),
                      controller: _sourceDateController,
                      enabled: fieldsEnabled,
                      keyboardType: TextInputType.datetime,
                      decoration: InputDecoration(
                        labelText: l10n.lppRegulationReviewSourceDate,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        if (_lppRegulationSourceDateValidationFailed ||
                            _lppRegulationAcceptFailed) {
                          setState(() {
                            _lppRegulationSourceDateValidationFailed = false;
                            _lppRegulationAcceptFailed = false;
                          });
                        }
                      },
                    ),
                  ),
                  if (_lppRegulationSourceDateValidationFailed) ...[
                    const SizedBox(height: 6),
                    Text(
                      l10n.lppRegulationReviewSourceDateError,
                      key: const Key(
                        'lpp_regulation_review_source_date_error',
                      ),
                      style: MintTextStyles.bodySmall(color: MintColors.error),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Semantics(
                    identifier: 'lpp_regulation_review_legal_year',
                    textField: true,
                    child: TextFormField(
                      key: const Key('lpp_regulation_review_legal_year'),
                      controller: _lppRegulationLegalYearController,
                      enabled: fieldsEnabled,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.lppRegulationReviewLegalYear,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        if (_lppRegulationLegalYearValidationFailed ||
                            _lppRegulationAcceptFailed) {
                          setState(() {
                            _lppRegulationLegalYearValidationFailed = false;
                            _lppRegulationAcceptFailed = false;
                          });
                        }
                      },
                    ),
                  ),
                  if (_lppRegulationLegalYearValidationFailed) ...[
                    const SizedBox(height: 6),
                    Text(
                      l10n.lppRegulationReviewLegalYearError,
                      key: const Key(
                        'lpp_regulation_review_legal_year_error',
                      ),
                      style: MintTextStyles.bodySmall(color: MintColors.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    l10n.lppRegulationReviewFundRelationshipQuestion,
                    style: MintTextStyles.titleMedium(
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildLppFundRelationshipChoice(
                        relationship: LppFundRelationship.currentFund,
                        identifier: 'lpp_regulation_fund_relation_current',
                        label: l10n.lppRegulationReviewFundCurrent,
                        enabled: fieldsEnabled,
                      ),
                      _buildLppFundRelationshipChoice(
                        relationship: LppFundRelationship.uncertain,
                        identifier: 'lpp_regulation_fund_relation_uncertain',
                        label: l10n.lppRegulationReviewFundUncertain,
                        enabled: fieldsEnabled,
                      ),
                      _buildLppFundRelationshipChoice(
                        relationship: LppFundRelationship.formerOrOther,
                        identifier:
                            'lpp_regulation_fund_relation_former_or_other',
                        label: l10n.lppRegulationReviewFundFormerOrOther,
                        enabled: fieldsEnabled,
                      ),
                    ],
                  ),
                  if (_lppRegulationFundRelationshipValidationFailed) ...[
                    const SizedBox(height: 6),
                    Text(
                      l10n.lppRegulationReviewFundRelationshipRequired,
                      key: const Key(
                        'lpp_regulation_fund_relation_required_error',
                      ),
                      style: MintTextStyles.bodySmall(color: MintColors.error),
                    ),
                  ],
                  if (_lppRegulationAcceptFailed) ...[
                    const SizedBox(height: 16),
                    MintSurface(
                      key: const Key('lpp_regulation_review_accept_error'),
                      tone: MintSurfaceTone.porcelaine,
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        l10n.lppRegulationReviewAcceptError,
                        style:
                            MintTextStyles.bodyMedium(color: MintColors.error),
                      ),
                    ),
                  ],
                  if (_lppRegulationRecordFailed) ...[
                    const SizedBox(height: 16),
                    MintSurface(
                      key: const Key(
                        'lpp_regulation_reference_retry_state',
                      ),
                      tone: MintSurfaceTone.porcelaine,
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        key: _lppRegulationRetryScrollKey,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.lppRegulationReviewRecordError,
                            style: MintTextStyles.bodyMedium(
                              color: MintColors.error,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Semantics(
                            identifier: 'lpp_regulation_reference_retry_cta',
                            button: true,
                            enabled: !_isConfirming,
                            child: FilledButton(
                              key: const Key(
                                'lpp_regulation_reference_retry_cta',
                              ),
                              onPressed: _isConfirming
                                  ? null
                                  : _retryLppRegulationRecord,
                              child: Text(l10n.commonRetry),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (_acceptedLppRegulationReceipt == null)
                    Semantics(
                      identifier: 'lpp_regulation_review_confirm_cta',
                      button: true,
                      enabled: !_isConfirming,
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const Key(
                            'lpp_regulation_review_confirm_cta',
                          ),
                          onPressed:
                              _isConfirming ? null : _confirmLppRegulation,
                          child: Text(l10n.lppRegulationReviewConfirm),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLppFundRelationshipChoice({
    required LppFundRelationship relationship,
    required String identifier,
    required String label,
    required bool enabled,
  }) {
    final selected = _lppFundRelationship == relationship;
    void select() {
      setState(() {
        _lppFundRelationship = relationship;
        _lppRegulationFundRelationshipValidationFailed = false;
        _lppRegulationAcceptFailed = false;
      });
    }

    return Semantics(
      identifier: identifier,
      checked: selected,
      button: true,
      enabled: enabled,
      onTap: enabled ? select : null,
      child: ExcludeSemantics(
        child: ChoiceChip(
          key: Key(identifier),
          label: Text(label),
          selected: selected,
          onSelected: enabled ? (_) => select() : null,
        ),
      ),
    );
  }

  Future<void> _confirmLppRegulation() async {
    final candidate = widget.lppRegulationCandidate;
    if (_isConfirming ||
        candidate == null ||
        !FeatureFlags.lppRegulationAcquisitionEnabled ||
        _acceptedLppRegulationReceipt != null) {
      return;
    }
    final rawDate = _sourceDateController.text.trim();
    final rawLegalYear = _lppRegulationLegalYearController.text.trim();
    DateTime? sourceDate;
    try {
      sourceDate = _parseOptionalTaxDate(rawDate);
    } on FormatException {
      sourceDate = null;
    }
    final legalYear = RegExp(r'^\d{4}$').hasMatch(rawLegalYear)
        ? int.tryParse(rawLegalYear)
        : null;
    final current = (widget.now ?? DateTime.now)().toUtc();
    final invalidDate = sourceDate == null ||
        SwissCivilTime.isFutureCivilDate(sourceDate, now: current);
    final invalidLegalYear =
        legalYear == null || legalYear < 1900 || legalYear > 9999;
    final invalidFundRelationship = _lppFundRelationship == null;
    if (invalidDate || invalidLegalYear || invalidFundRelationship) {
      setState(() {
        _lppRegulationSourceDateValidationFailed = invalidDate;
        _lppRegulationLegalYearValidationFailed = invalidLegalYear;
        _lppRegulationFundRelationshipValidationFailed =
            invalidFundRelationship;
        _lppRegulationAcceptFailed = false;
      });
      return;
    }

    final LppRegulationReviewConfirmation confirmation;
    try {
      confirmation = LppRegulationReviewConfirmation(
        ownerKind: LppEvidenceOwnerKind.self,
        sourceDate: sourceDate,
        legalYear: legalYear,
        fundRelationship: _lppFundRelationship!,
        expectedPreviousReferenceId: candidate.expectedPreviousReferenceId,
      );
    } on ArgumentError {
      setState(() => _lppRegulationAcceptFailed = true);
      return;
    }

    final ledger = context.read<CoachProfileProvider>();
    setState(() {
      _isConfirming = true;
      _lppRegulationSourceDateValidationFailed = false;
      _lppRegulationLegalYearValidationFailed = false;
      _lppRegulationFundRelationshipValidationFailed = false;
      _lppRegulationAcceptFailed = false;
      _lppRegulationRecordFailed = false;
    });
    final LppRegulationReceipt receipt;
    try {
      receipt = await ledger.acceptLppRegulationReference(confirmation);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isConfirming = false;
          _lppRegulationAcceptFailed = true;
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _acceptedLppRegulationConfirmation = confirmation;
      _acceptedLppRegulationReceipt = receipt;
    });
    await _recordAcceptedLppRegulation(continuingFromAccept: true);
  }

  Future<void> _retryLppRegulationRecord() async {
    await _recordAcceptedLppRegulation(continuingFromAccept: false);
  }

  Future<void> _recordAcceptedLppRegulation({
    required bool continuingFromAccept,
  }) async {
    final receipt = _acceptedLppRegulationReceipt;
    if (receipt == null ||
        _acceptedLppRegulationConfirmation == null ||
        (!continuingFromAccept && _isConfirming)) {
      return;
    }
    final documents = context.read<DocumentProvider>();
    if (!continuingFromAccept) {
      setState(() {
        _isConfirming = true;
        _lppRegulationRecordFailed = false;
      });
    }
    try {
      await documents.recordLppRegulation(receipt);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isConfirming = false;
          _lppRegulationRecordFailed = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final retryContext = _lppRegulationRetryScrollKey.currentContext;
          if (retryContext != null) {
            unawaited(
              Scrollable.ensureVisible(
                retryContext,
                alignment: 0.8,
              ),
            );
          }
        });
      }
      return;
    }
    _reviewSessionFinalized = true;
    _scanSessions?.discard(widget.scanSessionId);
    if (!mounted) return;
    context.go('/retraite');
  }

  void _onBack() {
    unawaited(_cleanupPartnerReceipt());
    _scanSessions?.discard(widget.scanSessionId);
    safePop(context);
  }

  void _initializeTaxReview(TaxExtractionCandidate? candidate) {
    if (candidate == null) return;
    _taxDocumentKind = candidate.documentKind;
    _taxAssessmentStatus = candidate.assessmentStatus;
    _taxSubjectScope = candidate.subjectScope;
    _cantonalAuthorityScope =
        candidate.cantonalCommunalAssessedTax?.authorityScope ??
            TaxAuthorityScope.unknown;
    _cantonalBaseScope = candidate.cantonalCommunalAssessedTax?.baseScope ??
        TaxBaseScope.unknown;
    _federalAuthorityScope =
        candidate.federalDirectAssessedTax?.authorityScope ??
            TaxAuthorityScope.federalDirect;
    final federalBase = candidate.federalDirectAssessedTax?.baseScope;
    _federalScopeIncoherent = federalBase == TaxBaseScope.wealthOnly ||
        federalBase == TaxBaseScope.incomeAndWealth ||
        federalBase == TaxBaseScope.totalInvoice;
    _federalBaseScope = _federalScopeIncoherent
        ? TaxBaseScope.unknown
        : federalBase ?? TaxBaseScope.unknown;
    _taxYearController.text = candidate.taxYear?.toString() ?? '';
    _basedOnTaxYearController.text = candidate.basedOnTaxYear?.toString() ?? '';
    _sourceDateController.text = _formatTaxDate(candidate.sourceDate);
    _cantonCodeController.text = candidate.cantonCode ?? '';
    _municipalityIdController.text = candidate.municipalityId ?? '';
    _municipalityLabelController.text = candidate.municipalityLabel ?? '';
    _cantonalIncomeController.text =
        _formatTaxNumber(candidate.cantonalCommunalTaxableIncomeChf);
    _federalIncomeController.text =
        _formatTaxNumber(candidate.federalTaxableIncomeChf);
    _wealthController.text =
        _formatTaxNumber(candidate.cantonalCommunalTaxableWealthChf);
    _cantonalTaxController.text =
        _formatTaxNumber(candidate.cantonalCommunalAssessedTax?.amountChf);
    _federalTaxController.text =
        _formatTaxNumber(candidate.federalDirectAssessedTax?.amountChf);
    _marginalRateController.text = _formatTaxNumber(
      candidate.explicitMarginalIncomeTaxRate == null
          ? null
          : candidate.explicitMarginalIncomeTaxRate! * 100,
    );
    _averageRateController.text = _formatTaxNumber(
      candidate.explicitAverageIncomeTaxRate == null
          ? null
          : candidate.explicitAverageIncomeTaxRate! * 100,
    );
  }

  void _initializeLppReview(LppExtractionCandidate? candidate) {
    if (candidate == null) return;
    _sourceDateController.text = _formatTaxDate(candidate.sourceDate);
  }

  String _formatTaxDate(DateTime? value) {
    if (value == null) return '';
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  String _formatTaxNumber(double? value) {
    if (value == null) return '';
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  Widget _buildLppSourceDateField() {
    final l10n = S.of(context)!;
    return Semantics(
      identifier: 'lpp_review_source_date',
      textField: true,
      label: l10n.lppReviewSourceDate,
      child: TextFormField(
        key: const Key('lpp_review_source_date'),
        enabled: _acceptedLppReceipt == null,
        controller: _sourceDateController,
        keyboardType: TextInputType.datetime,
        onChanged: (_) {
          if (_lppSourceDateValidationFailed) {
            setState(() => _lppSourceDateValidationFailed = false);
          }
        },
        decoration: InputDecoration(
          labelText: l10n.lppReviewSourceDate,
          helperText: l10n.lppReviewSourceDateHint,
          error: _lppSourceDateValidationFailed
              ? Text(
                  l10n.lppReviewSourceDateInvalid,
                  key: const Key('lpp_review_source_date_error'),
                )
              : null,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildLppOwnerBadge() {
    final authorization = widget.lppAuthorization!;
    final l10n = S.of(context)!;
    final label = authorization.subject == LppEvidenceOwnerKind.self
        ? l10n.lppReviewOwnerSelf
        : l10n.lppReviewOwnerPartner;
    return MintSurface(
      key: const Key('lpp_review_owner_badge'),
      tone: MintSurfaceTone.porcelaine,
      padding: const EdgeInsets.all(14),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline, color: MintColors.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style:
                      MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                          .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('lpp_review_restart_owner_cta'),
              onPressed: _restartLppAcquisition,
              child: Text(l10n.lppReviewOwnerRestart),
            ),
          ),
        ],
      ),
    );
  }

  void _restartLppAcquisition() {
    _scanSessions?.discard(widget.scanSessionId);
    context.go('/scan?type=lppCertificate');
  }

  Widget _buildTaxReviewForm() {
    final l10n = S.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _taxDropdown<TaxDocumentKind>(
          controlKey: 'tax_review_document_kind',
          label: l10n.taxReviewDocumentKind,
          value: _taxDocumentKind,
          values: TaxDocumentKind.values,
          onChanged: (value) => setState(() => _taxDocumentKind = value),
        ),
        _taxDropdown<TaxAssessmentStatus>(
          controlKey: 'tax_review_assessment_status',
          label: l10n.taxReviewAssessmentStatus,
          value: _taxAssessmentStatus,
          values: TaxAssessmentStatus.values,
          onChanged: (value) => setState(() {
            _taxAssessmentStatus = value;
            if (value != TaxAssessmentStatus.inForce) {
              _taxInForceAttested = false;
            }
          }),
        ),
        if (_taxAssessmentStatus == TaxAssessmentStatus.inForce)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              key: const Key('tax_review_in_force_attested'),
              identifier: 'tax_review_in_force_attested',
              checked: _taxInForceAttested,
              label: l10n.taxReviewInForceAttestation,
              onTap: () => setState(
                () => _taxInForceAttested = !_taxInForceAttested,
              ),
              child: ExcludeSemantics(
                child: CheckboxListTile(
                  value: _taxInForceAttested,
                  title: Text(l10n.taxReviewInForceAttestation),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) => setState(
                    () => _taxInForceAttested = value ?? false,
                  ),
                ),
              ),
            ),
          ),
        _taxTextField(
          controlKey: 'tax_review_tax_year',
          label: l10n.taxReviewTaxYear,
          controller: _taxYearController,
        ),
        _taxTextField(
          controlKey: 'tax_review_based_on_tax_year',
          label: l10n.taxReviewBasedOnTaxYear,
          controller: _basedOnTaxYearController,
        ),
        _taxTextField(
          controlKey: 'tax_review_source_date',
          label: l10n.taxReviewSourceDate,
          controller: _sourceDateController,
        ),
        _taxDropdown<TaxSubjectScope>(
          controlKey: 'tax_review_subject_scope',
          label: l10n.taxReviewSubjectScope,
          value: _taxSubjectScope,
          values: TaxSubjectScope.values,
          onChanged: (value) => setState(() => _taxSubjectScope = value),
        ),
        _taxTextField(
          controlKey: 'tax_review_canton_code',
          label: l10n.taxReviewCantonCode,
          controller: _cantonCodeController,
        ),
        _taxTextField(
          controlKey: 'tax_review_municipality_id',
          label: l10n.taxReviewMunicipalityId,
          controller: _municipalityIdController,
        ),
        _taxTextField(
          controlKey: 'tax_review_municipality_label',
          label: l10n.taxReviewMunicipalityLabel,
          controller: _municipalityLabelController,
        ),
        _taxTextField(
          controlKey: 'tax_review_cantonal_communal_taxable_income_chf',
          label: l10n.taxReviewCantonalIncome,
          controller: _cantonalIncomeController,
        ),
        _taxTextField(
          controlKey: 'tax_review_federal_taxable_income_chf',
          label: l10n.taxReviewFederalIncome,
          controller: _federalIncomeController,
        ),
        _taxTextField(
          controlKey: 'tax_review_cantonal_communal_taxable_wealth_chf',
          label: l10n.taxReviewCantonalWealth,
          controller: _wealthController,
        ),
        _taxTextField(
          controlKey: 'tax_review_cantonal_communal_assessed_tax_chf',
          label: l10n.taxReviewCantonalTax,
          controller: _cantonalTaxController,
        ),
        _taxDropdown<TaxAuthorityScope>(
          controlKey: 'tax_review_cantonal_authority_scope',
          label: l10n.taxReviewCantonalAuthority,
          value: _cantonalAuthorityScope,
          values: TaxAuthorityScope.values,
          onChanged: (value) => setState(() => _cantonalAuthorityScope = value),
        ),
        _taxDropdown<TaxBaseScope>(
          controlKey: 'tax_review_cantonal_base_scope',
          label: l10n.taxReviewCantonalBase,
          value: _cantonalBaseScope,
          values: TaxBaseScope.values,
          onChanged: (value) => setState(() => _cantonalBaseScope = value),
        ),
        _taxTextField(
          controlKey: 'tax_review_federal_direct_assessed_tax_chf',
          label: l10n.taxReviewFederalTax,
          controller: _federalTaxController,
        ),
        _taxDropdown<TaxAuthorityScope>(
          controlKey: 'tax_review_federal_authority_scope',
          label: l10n.taxReviewFederalAuthority,
          value: _federalAuthorityScope,
          values: TaxAuthorityScope.values,
          onChanged: (value) => setState(() => _federalAuthorityScope = value),
        ),
        _taxDropdown<TaxBaseScope>(
          controlKey: 'tax_review_federal_base_scope',
          label: l10n.taxReviewFederalBase,
          value: _federalBaseScope,
          values: const [TaxBaseScope.incomeOnly, TaxBaseScope.unknown],
          onChanged: (value) => setState(() {
            _federalBaseScope = value;
            _federalScopeIncoherent = false;
          }),
        ),
        if (_federalScopeIncoherent)
          Padding(
            key: const Key('tax_review_federal_scope_incoherence'),
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              l10n.taxReviewFederalScopeIncoherence,
              style: MintTextStyles.bodySmall(color: MintColors.warning),
            ),
          ),
        _taxTextField(
          controlKey: 'tax_review_explicit_marginal_rate_percent',
          label: l10n.taxReviewMarginalRate,
          controller: _marginalRateController,
        ),
        _taxTextField(
          controlKey: 'tax_review_explicit_average_rate_percent',
          label: l10n.taxReviewAverageRate,
          controller: _averageRateController,
        ),
      ],
    );
  }

  Widget _taxTextField({
    required String controlKey,
    required String label,
    required TextEditingController controller,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        identifier: controlKey,
        textField: true,
        label: label,
        child: TextFormField(
          key: Key(controlKey),
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );
  }

  Widget _taxDropdown<T extends Enum>({
    required String controlKey,
    required String label,
    required T value,
    required List<T> values,
    required ValueChanged<T> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        identifier: controlKey,
        label: label,
        child: DropdownButtonFormField<T>(
          key: Key(controlKey),
          initialValue: value,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          isExpanded: true,
          items: values.map(
            (option) {
              final optionKey = '${controlKey}_${_enumSnakeCase(option.name)}';
              final optionLabel = _taxOptionLabel(option);
              return DropdownMenuItem<T>(
                key: Key(optionKey),
                value: option,
                child: Semantics(
                  identifier: optionKey,
                  child: Text(optionLabel),
                ),
              );
            },
          ).toList(growable: false),
          selectedItemBuilder: (context) => values
              .map((option) => Text(_taxOptionLabel(option)))
              .toList(growable: false),
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }

  String _enumSnakeCase(String value) => value.replaceAllMapped(
        RegExp(r'[A-Z]'),
        (match) => '_${match[0]!.toLowerCase()}',
      );

  String _taxOptionLabel(Enum value) {
    final l10n = S.of(context)!;
    return switch (value) {
      TaxDocumentKind.taxpayerReturn => l10n.taxReviewOptionTaxpayerReturn,
      TaxDocumentKind.provisionalBill => l10n.taxReviewOptionProvisionalBill,
      TaxDocumentKind.assessmentNotice => l10n.taxReviewOptionAssessmentNotice,
      TaxDocumentKind.finalTaxBill => l10n.taxReviewOptionFinalTaxBill,
      TaxDocumentKind.unknown => l10n.taxReviewOptionUnknown,
      TaxAssessmentStatus.selfDeclared => l10n.taxReviewOptionSelfDeclared,
      TaxAssessmentStatus.provisional => l10n.taxReviewOptionProvisional,
      TaxAssessmentStatus.assessedAppealable =>
        l10n.taxReviewOptionAssessedAppealable,
      TaxAssessmentStatus.contested => l10n.taxReviewOptionContested,
      TaxAssessmentStatus.inForce => l10n.taxReviewOptionInForce,
      TaxAssessmentStatus.unknown => l10n.taxReviewOptionUnknown,
      TaxSubjectScope.individual => l10n.taxReviewOptionIndividual,
      TaxSubjectScope.jointlyAssessedCouple => l10n.taxReviewOptionJointCouple,
      TaxSubjectScope.unknown => l10n.taxReviewOptionUnknown,
      TaxAuthorityScope.cantonalOnly => l10n.taxReviewOptionCantonalOnly,
      TaxAuthorityScope.communalOnly => l10n.taxReviewOptionCommunalOnly,
      TaxAuthorityScope.cantonalCommunalCombined =>
        l10n.taxReviewOptionCantonalCommunal,
      TaxAuthorityScope.federalDirect => l10n.taxReviewOptionFederalDirect,
      TaxAuthorityScope.unknown => l10n.taxReviewOptionUnknown,
      TaxBaseScope.incomeOnly => l10n.taxReviewOptionIncomeOnly,
      TaxBaseScope.wealthOnly => l10n.taxReviewOptionWealthOnly,
      TaxBaseScope.incomeAndWealth => l10n.taxReviewOptionIncomeAndWealth,
      TaxBaseScope.totalInvoice => l10n.taxReviewOptionTotalInvoice,
      TaxBaseScope.unknown => l10n.taxReviewOptionUnknown,
      _ => value.name,
    };
  }

  // ── Header ───────────────────────────────────────────────

  Widget _buildHeader() {
    final reviewCount = _fields.where((f) => f.needsReview).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.extractionReviewTitle,
          style: MintTextStyles.headlineMedium(color: MintColors.textPrimary)
              .copyWith(height: 1.3),
        ),
        const SizedBox(height: 8),
        Text(
          S.of(context)!.extractionReviewSubtitle(
              _fields.length,
              reviewCount > 0
                  ? S.of(context)!.extractionReviewNeedsReview(reviewCount)
                  : ''),
          style: MintTextStyles.labelLarge(color: MintColors.textSecondary)
              .copyWith(height: 1.5),
        ),
      ],
    );
  }

  // ── Direct-link context banner ───────────────────────────
  //
  // Surface the existing context reminder when review is opened directly.

  Widget _buildDeeplinkBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.link_rounded,
              size: 16, color: MintColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              S.of(context)!.documentReviewOpenedFromDeeplink,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Overall confidence badge ─────────────────────────────

  Widget _buildOverallConfidenceBadge() {
    final pct = (_overallConfidence * 100).round();
    final color = pct >= 80
        ? MintColors.success
        : pct >= 50
            ? MintColors.warning
            : MintColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            pct >= 80
                ? Icons.verified
                : pct >= 50
                    ? Icons.info_outline
                    : Icons.warning_amber_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            S.of(context)!.extractionReviewConfidence(pct),
            style: MintTextStyles.bodySmall(color: color)
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ── Warnings ─────────────────────────────────────────────

  Widget _buildWarnings() {
    final messages = <String>[
      ...widget.result.warnings,
      ...widget.result.diagnostics.map(_localizedDiagnostic),
    ];
    return Column(
      children: messages.map((w) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MintColors.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: MintColors.warning.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_outlined,
                  size: 18, color: MintColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  w,
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary)
                      .copyWith(height: 1.4),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── LPP 1e plan type warning (DOC-04) ────────────────────

  Widget _buildLpp1eWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_outlined,
              size: 18, color: MintColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              S.of(context)!.docLpp1eWarning,
              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                  .copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ── Cross-field coherence warnings (DOC-05) ─────────────

  Widget _buildCoherenceWarnings() {
    return Column(
      children: widget.result.coherenceWarnings.map((w) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MintColors.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: MintColors.warning.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_outlined,
                  size: 18, color: MintColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  w,
                  style:
                      MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                          .copyWith(height: 1.4),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Field card ───────────────────────────────────────────

  Widget _buildFieldCard(ExtractedField field) {
    final confidencePct = (field.confidence * 100).round();
    final threshold = _thresholdFor(field.fieldName);
    final bool isAboveThreshold = field.confidence >= threshold;
    final bool isMedium = !isAboveThreshold && field.confidence >= 0.70;
    final bool isLow = !isAboveThreshold && !isMedium;

    final Color badgeColor;
    final IconData statusIcon;

    if (isAboveThreshold) {
      badgeColor = MintColors.success;
      statusIcon = Icons.check_circle;
    } else if (isMedium) {
      badgeColor = MintColors.warning;
      statusIcon = Icons.warning_amber_outlined;
    } else {
      badgeColor = MintColors.error;
      statusIcon = Icons.error_outline;
    }

    // Don't display backend fallback source text
    final hasSourceText = field.sourceText.isNotEmpty &&
        field.sourceText != '[non fourni par l\'extraction]';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: isLow
            ? Border.all(
                color: MintColors.error.withValues(alpha: 0.3), width: 1.5)
            : null,
      ),
      child: MintSurface(
        padding: const EdgeInsets.all(16),
        radius: 14,
        elevated: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: label + confidence badge
            Row(
              children: [
                Icon(statusIcon, size: 18, color: badgeColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _localizedFieldLabel(field),
                    style: MintTextStyles.bodySmall(
                            color: MintColors.textSecondary)
                        .copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$confidencePct%',
                    style: MintTextStyles.micro(color: badgeColor)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Value row
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatValue(field),
                    style: MintTextStyles.headlineSmall(
                        color: MintColors.textPrimary),
                  ),
                ),
                // Edit button
                IconButton(
                  key: widget.result.documentType == DocumentType.lppCertificate
                      ? Key('lpp_review_field_edit_${field.fieldName}')
                      : null,
                  onPressed: _acceptedLppReceipt == null
                      ? () => _editField(field)
                      : null,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  color: MintColors.textMuted,
                  tooltip: S.of(context)!.extractionReviewEditTooltip,
                  style: IconButton.styleFrom(
                    backgroundColor: MintColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),

            // Red field: verification prompt (DOC-03)
            if (isLow) ...[
              const SizedBox(height: 6),
              Text(
                S.of(context)!.docFieldVerify,
                style: MintTextStyles.bodyMedium(color: MintColors.error),
              ),
            ],

            // Source text display (DOC-09)
            if (hasSourceText) ...[
              const SizedBox(height: 6),
              Text(
                '${S.of(context)!.docSourcePrefix}${_truncateSource(field.sourceText)}',
                style: MintTextStyles.micro(color: MintColors.textMuted)
                    .copyWith(fontStyle: FontStyle.italic),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Confirm button ───────────────────────────────────────

  Widget _buildConfirmButton() {
    final isTax = widget.result.documentType == DocumentType.taxDeclaration;
    final isLpp = widget.result.documentType == DocumentType.lppCertificate;
    final retryingReference = isLpp && _acceptedLppReceipt != null;
    final action = _isConfirming ? null : _onConfirmAll;
    return Semantics(
      identifier: isTax
          ? 'tax_review_confirm_cta'
          : isLpp
              ? 'lpp_review_confirm_cta'
              : null,
      button: true,
      enabled: action != null,
      label: S.of(context)!.docReviewConfirm,
      onTap: action,
      child: ExcludeSemantics(
        child: SizedBox(
          key: retryingReference ? const Key('lpp_reference_retry_cta') : null,
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            key: isTax
                ? const Key('tax_review_confirm_cta')
                : isLpp
                    ? const Key('lpp_review_confirm_cta')
                    : null,
            onPressed: action,
            icon: const Icon(Icons.check_circle_outline, size: 22),
            label: Text(
              retryingReference
                  ? S.of(context)!.commonRetry
                  : S.of(context)!.docReviewConfirm,
              style: MintTextStyles.titleMedium(color: MintColors.white),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: MintColors.primary,
              foregroundColor: MintColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Disclaimer ───────────────────────────────────────────

  Widget _buildDisclaimer() {
    final isTax = widget.result.documentType == DocumentType.taxDeclaration;
    final disclaimer = isTax
        ? S.of(context)!.taxReviewLocalDisclaimer
        : widget.result.disclaimer;
    final sources = isTax ? const <String>[] : widget.result.sources;
    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      padding: const EdgeInsets.all(14),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            disclaimer,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted)
                .copyWith(height: 1.5),
          ),
          if (sources.isNotEmpty) const SizedBox(height: 8),
          ...sources.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  s,
                  style: MintTextStyles.micro(color: MintColors.textMuted),
                ),
              )),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────

  String _localizedDiagnostic(ExtractionDiagnostic diagnostic) {
    final l10n = S.of(context)!;
    return switch (diagnostic.code) {
      ExtractionDiagnosticCode.taxPercentUnitOutOfRange =>
        l10n.taxParserDiagnosticPercentUnit(
          diagnostic.ratePercent!.toStringAsFixed(1),
        ),
      ExtractionDiagnosticCode.taxNegativeWealthNeedsLabelReview =>
        l10n.taxParserDiagnosticNegativeWealth(
          diagnostic.amountChf!.toStringAsFixed(0),
        ),
      ExtractionDiagnosticCode.taxComputedAverageRateNotMarginal =>
        l10n.taxParserDiagnosticAverageNotMarginal(
          diagnostic.ratePercent!.toStringAsFixed(1),
        ),
    };
  }

  String _localizedFieldLabel(ExtractedField field) {
    final l10n = S.of(context)!;
    if (widget.result.documentType == DocumentType.lppCertificate) {
      return switch (LppEvidenceFactKey.fromWireName(field.fieldName)) {
        LppEvidenceFactKey.vestedBenefitsCapitalChf =>
          l10n.documentsFieldAvoirTotal,
        LppEvidenceFactKey.mandatoryVestedBenefitsCapitalChf =>
          l10n.documentsFieldAvoirObligatoire,
        LppEvidenceFactKey.extraMandatoryVestedBenefitsCapitalChf =>
          l10n.documentsFieldAvoirSurobligatoire,
        LppEvidenceFactKey.insuredSalaryAnnualChf =>
          l10n.documentsFieldSalaireAssure,
        LppEvidenceFactKey.maximumBuybackCapitalChf =>
          l10n.documentsFieldRachatMax,
        LppEvidenceFactKey.mandatoryConversionRateRatio =>
          l10n.documentsFieldTauxObligatoire,
        LppEvidenceFactKey.extraMandatoryConversionRateRatio =>
          l10n.documentsFieldTauxSurobligatoire,
        LppEvidenceFactKey.fundReturnRateRatio =>
          l10n.docScanLabelTauxRemuneration,
        LppEvidenceFactKey.retirementPensionAnnualChf =>
          l10n.lppEvidenceRetirementPensionAnnualLabel,
        LppEvidenceFactKey.retirementCapitalLumpSumChf =>
          l10n.lppEvidenceRetirementCapitalLumpSumLabel,
        LppEvidenceFactKey.disabilityPensionAnnualChf =>
          l10n.documentsFieldRenteInvalidite,
        LppEvidenceFactKey.disabilityCapitalLumpSumChf =>
          l10n.lppEvidenceDisabilityCapitalLumpSumLabel,
        LppEvidenceFactKey.deathCapitalLumpSumChf =>
          l10n.documentsFieldCapitalDeces,
        null => field.label,
      };
    }
    return switch (field.labelCode) {
      null => field.label,
      ExtractionFieldLabelCode.taxTaxableIncome => l10n.reportTaxIncome,
      ExtractionFieldLabelCode.taxTaxableWealth => l10n.taxReviewCantonalWealth,
      ExtractionFieldLabelCode.taxDeductions => l10n.reportTaxDeductions,
      ExtractionFieldLabelCode.taxCantonalCommunalTax ||
      ExtractionFieldLabelCode.taxCantonalOnlyTax =>
        l10n.taxReviewCantonalTax,
      ExtractionFieldLabelCode.taxFederalDirectTax => l10n.taxReviewFederalTax,
      ExtractionFieldLabelCode.taxMarginalRate => l10n.taxReviewMarginalRate,
      ExtractionFieldLabelCode.taxAverageRate => l10n.taxReviewAverageRate,
    };
  }

  String _formatValue(ExtractedField field) {
    final value = field.value;
    if (value is double) {
      final lppKey = LppEvidenceFactKey.fromWireName(field.fieldName);
      if (lppKey?.unit == LppEvidenceUnit.ratio) {
        return '${value.toStringAsFixed(2)} %';
      }
      // Check if it's a percentage field
      if (field.fieldName.contains('rate') ||
          field.fieldName.contains('conversion') ||
          field.fieldName.contains('bonification')) {
        return '${value.toStringAsFixed(2)} %';
      }
      // Format as CHF with Swiss thousand separators
      return 'CHF ${_formatChf(value)}';
    }
    return value.toString();
  }

  String _formatChf(double amount) {
    final intPart = amount.truncate();
    final decPart = ((amount - intPart) * 100).round();
    final formatted = intPart.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => "${m[1]}'",
        );
    if (decPart == 0) return formatted;
    return '$formatted.${decPart.toString().padLeft(2, '0')}';
  }

  String _truncateSource(String text) {
    if (text.length <= 60) return text.trim();
    return '${text.substring(0, 57).trim()}...';
  }

  // ── Edit field dialog ────────────────────────────────────

  void _editField(ExtractedField field) {
    var editedValue = field.value is double
        ? (field.value as double).toStringAsFixed(2)
        : field.value.toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          S.of(context)!.extractionReviewEditTitle(
                _localizedFieldLabel(field),
              ),
          style: MintTextStyles.titleMedium()
              .copyWith(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.of(context)!.extractionReviewCurrentValue(_formatValue(field)),
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: editedValue,
              onChanged: (value) => editedValue = value,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                labelText: S.of(context)!.extractionReviewNewValue,
                labelStyle: MintTextStyles.bodyMedium(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: MintColors.primary),
                ),
              ),
              style: MintTextStyles.bodyLarge(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: Text(
              S.of(context)!.extractionReviewCancel,
              style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
            ),
          ),
          FilledButton(
            key: widget.result.documentType == DocumentType.lppCertificate
                ? const Key('lpp_review_edit_validate')
                : null,
            onPressed: () {
              final newValue = double.tryParse(
                editedValue.replaceAll("'", '').replaceAll(',', '.'),
              );
              if (newValue != null) {
                setState(() {
                  final idx = _fields.indexOf(field);
                  if (idx >= 0) {
                    _fields[idx] = field.copyWithValue(newValue);
                    _lppBalanceValidationFailed = false;
                    _recalculateOverallConfidence();
                  }
                });
              }
              ctx.pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: MintColors.primary,
            ),
            child: Text(
              S.of(context)!.extractionReviewValidate,
              style: MintTextStyles.bodyMedium(color: MintColors.white)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _recalculateOverallConfidence() {
    if (_fields.isEmpty) return;
    _overallConfidence =
        _fields.map((f) => f.confidence).reduce((a, b) => a + b) /
            _fields.length;
  }

  Future<_DocumentOwnerChoice?> _askWhoseDocument() async {
    return showDialog<_DocumentOwnerChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(ctx)!.extractionWhoseDocument),
        content: Text(S.of(ctx)!.extractionWhoseDocumentBody),
        actions: [
          TextButton(
            key: const Key('lpp_review_subject_cancel'),
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.of(ctx)!.extractionReviewCancel),
          ),
          TextButton(
            key: const Key('lpp_review_subject_self'),
            onPressed: () => Navigator.pop(ctx, _DocumentOwnerChoice.self),
            child: Text(S.of(ctx)!.extractionDocMine),
          ),
          FilledButton(
            key: const Key('lpp_review_subject_manual_partner'),
            onPressed: () =>
                Navigator.pop(ctx, _DocumentOwnerChoice.manualPartner),
            child: Text(S.of(ctx)!.extractionDocPartner),
          ),
        ],
      ),
    );
  }

  // ── Confirm and navigate ─────────────────────────────────

  int _scoreProfile(CoachProfile profile) {
    final injected = widget.confidenceScorer;
    if (injected != null) return injected(profile);
    return ConfidenceScorer.score(profile).score.round();
  }

  bool _isCanonicalLppReview(LppExtractionCandidate candidate) {
    if (widget.result.documentType != DocumentType.lppCertificate ||
        widget.result.fields.length != candidate.facts.length) {
      return false;
    }
    final seen = <LppEvidenceFactKey>{};
    for (final field in widget.result.fields) {
      final key = LppEvidenceFactKey.fromWireName(field.fieldName);
      final fact = key == null ? null : candidate.factFor(key);
      if (key == null ||
          fact == null ||
          !seen.add(key) ||
          field.value is! num) {
        return false;
      }
      var reviewValue = (field.value as num).toDouble();
      if (!reviewValue.isFinite || reviewValue < 0) return false;
      if (key.unit == LppEvidenceUnit.ratio) reviewValue /= 100;
      if ((reviewValue - fact.value).abs() > 1e-12) return false;
    }
    return true;
  }

  Map<LppEvidenceFactKey, LppReviewedFact>? _buildLppReviewedFacts() {
    final candidate = widget.lppCandidate;
    if (candidate == null || !_isCanonicalLppReview(candidate)) {
      return null;
    }
    final facts = <LppEvidenceFactKey, LppReviewedFact>{};
    final seenKeys = <LppEvidenceFactKey>{};
    for (final field in _fields) {
      final key = LppEvidenceFactKey.fromWireName(field.fieldName);
      if (key == null) continue;
      if (!seenKeys.add(key) || field.value is! num) return null;
      var value = (field.value as num).toDouble();
      if (!value.isFinite || value < 0) return null;
      if (key.unit == LppEvidenceUnit.ratio) {
        if (value > 100) return null;
        value /= 100;
      }
      final candidateFact = candidate.factFor(key);
      if (candidateFact == null) return null;
      final corrected = (candidateFact.value - value).abs() > 1e-12;
      if (candidateFact.derived && !corrected) continue;
      facts[key] = LppReviewedFact(
        value: value,
        unit: key.unit,
        corrected: corrected,
      );
    }
    return Map.unmodifiable(facts);
  }

  ({bool isValid, DateTime? value}) _validatedLppSourceDate() {
    final candidate = widget.lppCandidate;
    if (candidate == null || !_isCanonicalLppReview(candidate)) {
      return (isValid: false, value: null);
    }
    var hasUntouchedDocumentFact = false;
    for (final field in _fields) {
      final key = LppEvidenceFactKey.fromWireName(field.fieldName);
      final candidateFact = key == null ? null : candidate.factFor(key);
      if (key == null || candidateFact == null || field.value is! num) {
        return (isValid: false, value: null);
      }
      var value = (field.value as num).toDouble();
      if (!value.isFinite || value < 0) {
        return (isValid: false, value: null);
      }
      if (key.unit == LppEvidenceUnit.ratio) {
        if (value > 100) return (isValid: false, value: null);
        value /= 100;
      }
      final corrected = (candidateFact.value - value).abs() > 1e-12;
      if (!corrected && !candidateFact.derived) {
        hasUntouchedDocumentFact = true;
      }
    }
    try {
      final sourceDate = _parseOptionalTaxDate(_sourceDateController.text);
      final current = (widget.now ?? DateTime.now)();
      if (sourceDate != null &&
          SwissCivilTime.isFutureCivilDate(sourceDate, now: current)) {
        return (isValid: false, value: null);
      }
      if (hasUntouchedDocumentFact && sourceDate == null) {
        return (isValid: false, value: null);
      }
      return (isValid: true, value: sourceDate);
    } on FormatException {
      return (isValid: false, value: null);
    }
  }

  ExtractionResult _lppImpactResult(
    LppReviewConfirmation confirmation,
    double confidenceDelta,
  ) {
    return ExtractionResult(
      documentType: DocumentType.lppCertificate,
      fields: confirmation.facts.entries
          .map(
            (entry) => ExtractedField(
              fieldName: entry.key.wireName,
              label: entry.key.wireName,
              value: entry.value.value,
              confidence: 1,
              sourceText: '',
              needsReview: false,
              profileField: confirmation.subject == LppEvidenceOwnerKind.self
                  ? entry.key.profilePath
                  : entry.key.manualPartnerProfilePath,
            ),
          )
          .toList(growable: false),
      overallConfidence: 1,
      confidenceDelta: confidenceDelta,
      warnings: const [],
      disclaimer: '',
      sources: const [],
    );
  }

  Future<void> _onConfirmAll() async {
    if (widget.result.documentType == DocumentType.lppCertificate) {
      if (_isConfirming ||
          !FeatureFlags.lppEvidenceIngestionEnabled ||
          (_acceptedLppReceipt == null &&
              (widget.lppCandidate == null ||
                  !_isCanonicalLppReview(widget.lppCandidate!)))) {
        return;
      }
      LppReviewConfirmation confirmation;
      var previousConfidence = _acceptedLppPreviousConfidence;
      if (_acceptedLppReceipt == null) {
        final authorization = widget.lppAuthorization;
        if (authorization == null ||
            !authorization.isValidAt(
              (widget.now ?? DateTime.now)().toUtc(),
            ) ||
            !_partnerAccountabilityStillValid) {
          return;
        }
        final reviewedFacts = _buildLppReviewedFacts();
        if (reviewedFacts == null || reviewedFacts.isEmpty) {
          setState(() {
            _taxValidationFailed = true;
            _lppSourceDateValidationFailed = false;
            _lppBalanceValidationFailed = false;
          });
          return;
        }
        if (!LppBalanceCoherence.isCoherent({
          for (final entry in reviewedFacts.entries)
            entry.key: entry.value.value,
        })) {
          setState(() {
            _lppBalanceValidationFailed = true;
            _lppSourceDateValidationFailed = false;
            _taxValidationFailed = false;
          });
          return;
        }
        final sourceDate = _validatedLppSourceDate();
        if (!sourceDate.isValid) {
          setState(() {
            _lppSourceDateValidationFailed = true;
            _lppBalanceValidationFailed = false;
            _taxValidationFailed = false;
          });
          return;
        }
        confirmation = LppReviewConfirmation(
          facts: reviewedFacts,
          sourceDate: sourceDate.value,
          authorization: authorization,
          partnerAccountabilityContext: widget.manualPartnerAccountability,
        );
        final beforeProfile = context.read<CoachProfileProvider>().profile ??
            CoachProfile.defaults();
        previousConfidence = _scoreProfile(beforeProfile);
      } else {
        confirmation = _acceptedLppConfirmation!;
      }
      setState(() {
        _isConfirming = true;
        _taxValidationFailed = false;
        _lppSourceDateValidationFailed = false;
        _lppBalanceValidationFailed = false;
      });
      final coachProvider = context.read<CoachProfileProvider>();
      if (_acceptedLppReceipt == null) {
        try {
          _acceptedLppReceipt =
              await coachProvider.acceptLppReview(confirmation);
        } catch (_) {
          await _cleanupPartnerReceipt();
          if (mounted) setState(() => _isConfirming = false);
          return;
        }
        _acceptedLppConfirmation = confirmation;
        _acceptedLppPreviousConfidence = previousConfidence;
        _partnerReceiptFinalized = true;
        _lppReferenceFailed = false;
      }
      final referenceRecorder = widget.recordConfirmedLppReview;
      if (referenceRecorder != null) {
        try {
          await referenceRecorder(_acceptedLppReceipt!);
          if (mounted && _lppReferenceFailed) {
            setState(() => _lppReferenceFailed = false);
          }
        } catch (_) {
          // The ledger is already authoritative. Keep this screen available
          // for an idempotent metadata-only retry and never revoke the receipt.
          if (mounted) {
            setState(() {
              _isConfirming = false;
              _lppReferenceFailed = true;
            });
          }
          return;
        }
      }
      final afterProfile = coachProvider.profile ?? CoachProfile.defaults();
      final confidenceDelta =
          _scoreProfile(afterProfile).toDouble() - previousConfidence!;
      final retained = _scanSessions?.retainImpact(
            widget.scanSessionId,
            extraction: _lppImpactResult(confirmation, confidenceDelta),
            previousConfidence: previousConfidence,
          ) ??
          false;
      if (!retained || !mounted) {
        if (mounted) setState(() => _isConfirming = false);
        return;
      }
      _transferredToImpact = true;
      context.go(
        '/scan/impact?scanSessionId=${Uri.encodeQueryComponent(widget.scanSessionId)}',
      );
      return;
    }
    if (widget.result.documentType == DocumentType.taxDeclaration) {
      if (_isConfirming ||
          !FeatureFlags.taxAssessmentIngestionEnabled ||
          widget.taxCandidate == null) {
        return;
      }
      final confirmation = _buildTaxConfirmation();
      if (confirmation == null) {
        setState(() => _taxValidationFailed = true);
        return;
      }
      setState(() {
        _isConfirming = true;
        _taxValidationFailed = false;
      });
      final coachProvider = context.read<CoachProfileProvider>();
      final beforeProfile = coachProvider.profile ?? CoachProfile.defaults();
      final previousConfidence = _scoreProfile(beforeProfile);
      try {
        await coachProvider.acceptTaxReview(confirmation);
      } catch (_) {
        if (mounted) setState(() => _isConfirming = false);
        return;
      }
      final afterProfile = coachProvider.profile ?? CoachProfile.defaults();
      final afterConfidence = _scoreProfile(afterProfile).toDouble();
      final canonicalFields = _canonicalTaxImpactFields(confirmation);
      final confirmedResult = ExtractionResult(
        documentType: widget.result.documentType,
        fields: canonicalFields,
        overallConfidence: canonicalFields.isEmpty ? 0 : 1,
        confidenceDelta: afterConfidence - previousConfidence,
        warnings: const [],
        disclaimer: '',
        sources: const [],
      );
      final retained = _scanSessions?.retainImpact(
            widget.scanSessionId,
            extraction: confirmedResult,
            previousConfidence: previousConfidence,
          ) ??
          false;
      if (!retained || !mounted) {
        if (mounted) setState(() => _isConfirming = false);
        return;
      }
      _transferredToImpact = true;
      context.go(
        '/scan/impact?scanSessionId=${Uri.encodeQueryComponent(widget.scanSessionId)}',
      );
      return;
    }

    // Build the confirmed result
    final confirmedResult = ExtractionResult(
      documentType: widget.result.documentType,
      fields: _fields,
      overallConfidence: _overallConfidence,
      confidenceDelta: widget.result.confidenceDelta,
      warnings: widget.result.warnings,
      disclaimer: widget.result.disclaimer,
      sources: widget.result.sources,
      diagnostics: widget.result.diagnostics,
      planType: widget.result.planType,
      planTypeWarning: widget.result.planTypeWarning,
      coherenceWarnings: widget.result.coherenceWarnings,
    );

    // ── Persist extraction data to CoachProfile ──
    final coachProvider = Provider.of<CoachProfileProvider>(
      context,
      listen: false,
    );
    // Capture BiographyProvider BEFORE async gaps (use_build_context_synchronously)
    final biographyProvider = Provider.of<BiographyProvider>(
      context,
      listen: false,
    );

    // Get the CURRENT confidence score BEFORE injection
    int previousConfidence = 42; // fallback if no profile
    if (coachProvider.hasProfile) {
      final currentConfidence = ConfidenceScorer.score(coachProvider.profile!);
      previousConfidence = currentConfidence.score.round();
    }

    // For couple profiles: ask whose document this is before injecting.
    final isCouple =
        coachProvider.hasProfile && coachProvider.profile!.conjoint != null;
    if (isCouple &&
        widget.result.documentType == DocumentType.salaryCertificate) {
      final owner = await _askWhoseDocument();
      if (!mounted || owner == null) return;
    }

    // Inject extracted data and AWAIT persistence before navigating
    switch (widget.result.documentType) {
      case DocumentType.lppCertificate:
        return;
      case DocumentType.lppPlan:
        return;
      case DocumentType.avsExtract:
        await coachProvider.updateFromAvsExtraction(_fields);
      case DocumentType.taxDeclaration:
        return;
      case DocumentType.salaryCertificate:
        await coachProvider.updateFromSalaryExtraction(_fields);
      default:
        break;
    }

    // ── Persist confirmed fields as BiographyFacts (BIO-01) ──
    // Only high-confidence fields (>= 0.80) become biography entries.
    // Maps profileField string to FactType enum.
    final now = DateTime.now();
    for (final field in _fields) {
      if (field.confidence < 0.80) continue;
      final factType = _mapProfileFieldToFactType(field.profileField);
      if (factType == null) continue;
      try {
        await biographyProvider.addFact(BiographyFact(
          id: '${now.millisecondsSinceEpoch}-${field.profileField}',
          factType: factType,
          fieldPath: field.profileField,
          value: field.value,
          source: FactSource.document,
          sourceDate: now,
          createdAt: now,
          updatedAt: now,
          freshnessCategory: _freshnessCategoryFor(factType),
        ));
      } catch (_) {
        // Biography write is best-effort; never block confirmation UX
      }
    }

    if (!mounted) return;

    // ── Sync to backend (offline-first: failure never blocks UX) ──
    final syncFields = _fields.map((f) {
      final conf = f.confidence >= 0.8
          ? 'high'
          : (f.confidence >= 0.5 ? 'medium' : 'low');
      return <String, dynamic>{
        'fieldName': f.profileField ?? f.label,
        'value': f.value,
        'confidence': conf,
        'sourceText': f.sourceText,
      };
    }).toList();
    await _sendWithRetry(
      documentType: widget.result.documentType.backendValue,
      confirmedFields: syncFields,
      overallConfidence: _overallConfidence,
    );

    if (!mounted) return;

    final retained = context.read<ScanSessionProvider>().retainImpact(
          widget.scanSessionId,
          extraction: confirmedResult,
          previousConfidence: previousConfidence,
        );
    if (!retained || !mounted) return;
    _transferredToImpact = true;
    context.push(
      '/scan/impact?scanSessionId=${Uri.encodeQueryComponent(widget.scanSessionId)}',
    );
  }

  TaxReviewConfirmation? _buildTaxConfirmation() {
    final candidate = widget.taxCandidate;
    if (candidate == null) return null;
    try {
      final taxYear = _parseOptionalYear(_taxYearController.text);
      final basedOnTaxYear = _parseOptionalYear(_basedOnTaxYearController.text);
      final sourceDate = _parseOptionalTaxDate(_sourceDateController.text);
      final current = (widget.now ?? DateTime.now)();
      final currentDay = SwissCivilTime.civilDate(current);
      bool isValidCivilTaxYear(int? year) =>
          year == null || year >= 1900 && year <= currentDay.year;
      if (!isValidCivilTaxYear(taxYear) ||
          !isValidCivilTaxYear(basedOnTaxYear) ||
          _taxDocumentKind == TaxDocumentKind.provisionalBill &&
              taxYear != null &&
              basedOnTaxYear != null &&
              basedOnTaxYear > taxYear) {
        return null;
      }
      if (sourceDate != null &&
          SwissCivilTime.isFutureCivilDate(sourceDate, now: current)) {
        return null;
      }
      final cantonCode = _optionalTaxText(_cantonCodeController.text);
      if (cantonCode != null && !sortedCantonCodes.contains(cantonCode)) {
        return null;
      }
      final cantonalIncome =
          _parseOptionalTaxNumber(_cantonalIncomeController.text);
      final federalIncome =
          _parseOptionalTaxNumber(_federalIncomeController.text);
      final wealth = _parseOptionalTaxNumber(_wealthController.text);
      final cantonalAmount =
          _parseOptionalTaxNumber(_cantonalTaxController.text);
      final federalAmount = _parseOptionalTaxNumber(_federalTaxController.text);
      final marginalPercent =
          _parseOptionalTaxNumber(_marginalRateController.text);
      final averagePercent =
          _parseOptionalTaxNumber(_averageRateController.text);
      if (wealth != null && wealth < 0 ||
          cantonalAmount != null && cantonalAmount < 0 ||
          federalAmount != null && federalAmount < 0 ||
          marginalPercent != null &&
              (marginalPercent < 0 || marginalPercent > 100) ||
          averagePercent != null &&
              (averagePercent < 0 || averagePercent > 100)) {
        return null;
      }
      if (_taxAssessmentStatus == TaxAssessmentStatus.inForce &&
          !_taxInForceAttested) {
        return null;
      }

      return TaxReviewConfirmation(
        candidate: candidate,
        taxYear: taxYear,
        basedOnTaxYear: basedOnTaxYear,
        sourceDate: sourceDate,
        documentKind: _taxDocumentKind,
        assessmentStatus: _taxAssessmentStatus,
        inForceAttested: _taxInForceAttested,
        subjectScope: _taxSubjectScope,
        cantonCode: cantonCode,
        municipalityId: _optionalTaxText(_municipalityIdController.text),
        municipalityLabel: _optionalTaxText(_municipalityLabelController.text),
        cantonalCommunalTaxableIncomeChf: cantonalIncome,
        federalTaxableIncomeChf: federalIncome,
        cantonalCommunalTaxableWealthChf: wealth,
        cantonalCommunalAssessedTax: cantonalAmount == null
            ? null
            : AssessedTaxAmount(
                amountChf: cantonalAmount,
                authorityScope: _cantonalAuthorityScope,
                baseScope: _cantonalBaseScope,
              ),
        federalDirectAssessedTax: federalAmount == null
            ? null
            : AssessedTaxAmount(
                amountChf: federalAmount,
                authorityScope: _federalAuthorityScope,
                baseScope: _federalBaseScope,
              ),
        explicitMarginalIncomeTaxRate:
            marginalPercent == null ? null : marginalPercent / 100,
        explicitAverageIncomeTaxRate:
            averagePercent == null ? null : averagePercent / 100,
        now: () => currentDay,
      );
    } on ArgumentError {
      return null;
    } on FormatException {
      return null;
    }
  }

  List<ExtractedField> _canonicalTaxImpactFields(
    TaxReviewConfirmation confirmation,
  ) {
    final fields = <ExtractedField>[];
    void add(String fieldName, String label, Object? value) {
      if (value == null) return;
      fields.add(
        ExtractedField(
          fieldName: fieldName,
          label: label,
          value: value,
          confidence: 1,
          sourceText: '',
          needsReview: false,
        ),
      );
    }

    final l10n = S.of(context)!;
    add(
      'cantonalCommunalTaxableIncomeChf',
      l10n.taxReviewCantonalIncome,
      confirmation.cantonalCommunalTaxableIncomeChf,
    );
    add(
      'federalTaxableIncomeChf',
      l10n.taxReviewFederalIncome,
      confirmation.federalTaxableIncomeChf,
    );
    add(
      'cantonalCommunalTaxableWealthChf',
      l10n.taxReviewCantonalWealth,
      confirmation.cantonalCommunalTaxableWealthChf,
    );
    add(
      'cantonalCommunalAssessedTax.amountChf',
      l10n.taxReviewCantonalTax,
      confirmation.cantonalCommunalAssessedTax?.amountChf,
    );
    add(
      'federalDirectAssessedTax.amountChf',
      l10n.taxReviewFederalTax,
      confirmation.federalDirectAssessedTax?.amountChf,
    );
    add(
      'explicitMarginalIncomeTaxRate',
      l10n.taxReviewMarginalRate,
      confirmation.explicitMarginalIncomeTaxRate,
    );
    add(
      'explicitAverageIncomeTaxRate',
      l10n.taxReviewAverageRate,
      confirmation.explicitAverageIncomeTaxRate,
    );
    return List.unmodifiable(fields);
  }

  int? _parseOptionalYear(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final value = int.tryParse(text);
    if (value == null || value < 1900 || value > 2100) {
      throw const FormatException('Invalid tax year');
    }
    return value;
  }

  DateTime? _parseOptionalTaxDate(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
    if (match == null) throw const FormatException('Invalid source date');
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime.utc(year, month, day);
    if (_formatTaxDate(parsed) != text) {
      throw const FormatException('Invalid source date');
    }
    return parsed;
  }

  double? _parseOptionalTaxNumber(String raw) {
    final text =
        raw.trim().replaceAll("'", '').replaceAll(' ', '').replaceAll(',', '.');
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null || !value.isFinite) {
      throw const FormatException('Invalid tax number');
    }
    return value;
  }

  String? _optionalTaxText(String raw) {
    final value = raw.trim();
    return value.isEmpty ? null : value;
  }

  /// Send scan confirmation with 3 retries + exponential backoff.
  /// Shows snackbar warning on final failure.
  Future<void> _sendWithRetry({
    required String documentType,
    required List<Map<String, dynamic>> confirmedFields,
    required double overallConfidence,
  }) async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final sender =
            widget.sendScanConfirmation ?? DocumentService.sendScanConfirmation;
        await sender(
          documentType: documentType,
          confirmedFields: confirmedFields,
          overallConfidence: overallConfidence,
        );
        return; // Success
      } catch (_) {
        if (attempt < 3) {
          await Future.delayed(
              Duration(seconds: attempt * 2)); // 2s, 4s backoff
        }
      }
    }
    // All 3 attempts failed
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context)!.syncFailedLocalSave),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Maps a CoachProfile field path to its FactType for biography storage.
  /// Returns null if the field doesn't map to a known FactType.
  FactType? _mapProfileFieldToFactType(String? profileField) {
    if (profileField == null) return null;
    if (profileField.contains('salaire') ||
        profileField.contains('Salary') ||
        profileField.contains('salary')) {
      return FactType.salary;
    }
    if (profileField.contains('avoirLpp') ||
        profileField.contains('lppCapital') ||
        profileField.contains('Lpp')) {
      return FactType.lppCapital;
    }
    if (profileField.contains('rachatMax') || profileField.contains('Rachat')) {
      return FactType.lppRachatMax;
    }
    if (profileField.contains('3a') ||
        profileField.contains('threeA') ||
        profileField.contains('pillar3a')) {
      return FactType.threeACapital;
    }
    if (profileField.contains('avs') ||
        profileField.contains('Avs') ||
        profileField.contains('AVS')) {
      return FactType.avsContributionYears;
    }
    if (profileField.contains('tax') ||
        profileField.contains('impot') ||
        profileField.contains('Tax')) {
      return FactType.taxRate;
    }
    if (profileField.contains('mortgage') ||
        profileField.contains('hypotheque')) {
      return FactType.mortgageDebt;
    }
    if (profileField.contains('canton')) {
      return FactType.canton;
    }
    return null;
  }

  /// Returns the freshness category for a given FactType.
  /// Volatile: 3-month decay. Annual: 12-month decay.
  String _freshnessCategoryFor(FactType type) {
    switch (type) {
      case FactType.taxRate:
        return 'volatile';
      case FactType.salary:
      case FactType.lppCapital:
      case FactType.lppRachatMax:
      case FactType.threeACapital:
      case FactType.avsContributionYears:
      case FactType.mortgageDebt:
      case FactType.canton:
      case FactType.civilStatus:
      case FactType.employmentStatus:
      case FactType.lifeEvent:
      case FactType.userDecision:
      case FactType.coachPreference:
      case FactType.alertAcknowledged:
        return 'annual';
    }
  }
}
