import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
// Wave A-MINIMAL (2026-04-18) A1: persist a durable scan event so the
// coach can later reference the kind of document that was scanned.
// Events live in a separate non-FIFO namespace from regular insights.
import 'package:mint_mobile/services/memory/coach_memory_service.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:mint_mobile/widgets/mint_custom_paint_mask.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

// ────────────────────────────────────────────────────────────
//  DOCUMENT IMPACT SCREEN — Sprint S42-S43
// ────────────────────────────────────────────────────────────
//
//  Post-confirmation celebration screen.
//  Animated confidence circle from oldConfidence to newConfidence.
//
//  Inspired by ScoreRevealScreen (Apple Watch ring close).
//
//  Reference: DATA_ACQUISITION_STRATEGY.md — Channel 1
//  User flow step 6: impact reveal.
// ────────────────────────────────────────────────────────────

typedef PremierEclairageFetcher = Future<Map<String, dynamic>?> Function({
  required String documentType,
  required List<Map<String, dynamic>> extractedFields,
  required double overallConfidence,
  String? planType,
  String? planTypeWarning,
  String? canton,
});

typedef ScanEventSaver = Future<void> Function(String topic, String summary);

class DocumentImpactScreen extends StatefulWidget {
  final String scanSessionId;
  final ExtractionResult result;
  final int previousConfidence; // 0-100
  final PremierEclairageFetcher? fetchPremierEclairage;
  final ScanEventSaver? saveScanEvent;

  const DocumentImpactScreen({
    super.key,
    required this.scanSessionId,
    required this.result,
    required this.previousConfidence,
    this.fetchPremierEclairage,
    this.saveScanEvent,
  });

  @override
  State<DocumentImpactScreen> createState() => _DocumentImpactScreenState();
}

class _DocumentImpactScreenState extends State<DocumentImpactScreen>
    with TickerProviderStateMixin {
  // ── Animation controllers ──────────────────────────────
  late AnimationController _masterController;
  late Animation<double> _circleProgress;
  late Animation<double> _fadeIn;
  late Animation<double> _badgeFadeIn;
  late Animation<double> _listFadeIn;
  late Animation<double> _ctaFadeIn;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late int _newConfidence;
  late int _deltaPoints;

  // Premier éclairage state
  Map<String, dynamic>? _premierEclairage;
  bool _premierEclairageLoading = true;
  bool _premierEclairageFailed = false;
  ScanSessionProvider? _scanSessions;

  @override
  void initState() {
    super.initState();

    _deltaPoints = widget.result.confidenceDelta.round();
    _newConfidence = (widget.previousConfidence + _deltaPoints).clamp(0, 100);

    _initAnimations();
    final fetchPremierEclairage = _fetchPremierEclairage;
    fetchPremierEclairage();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scanSessions ??= context.read<ScanSessionProvider>();
  }

  Future<void> _fetchPremierEclairage() async {
    if (widget.result.documentType == DocumentType.taxDeclaration) {
      _premierEclairageLoading = false;
      _premierEclairageFailed = true;
      return;
    }
    if (widget.result.documentType == DocumentType.lppCertificate ||
        widget.result.documentType == DocumentType.lppPlan ||
        widget.result.documentType == DocumentType.pillar3aBeneficiaryClause) {
      _premierEclairageLoading = false;
      _premierEclairageFailed = true;
      return;
    }
    try {
      final fields = widget.result.fields
          .map((f) => <String, dynamic>{
                'fieldName': f.fieldName,
                'value': f.value,
                'confidence': f.confidenceLevel.name,
                'sourceText': f.sourceText,
              })
          .toList();

      final fetcher =
          widget.fetchPremierEclairage ?? DocumentService.fetchPremierEclairage;
      final result = await fetcher(
        documentType: widget.result.documentType.backendValue,
        extractedFields: fields,
        overallConfidence: widget.result.overallConfidence,
        planType: widget.result.planType,
        planTypeWarning: widget.result.planTypeWarning,
        canton: null, // Canton from profile context if available
      );

      // A2-fix (2026-04-18) post-exec audit panel façade #1:
      // persist the scan event BEFORE the `mounted` check so that a
      // user who navigates away between network return and setState
      // still has the event recorded. Memory persistence does not
      // touch `setState` and therefore is safe to fire on an unmounted
      // State; the scan DID happen, its memory must not depend on
      // whether the user stayed on this screen.
      final persistScanEvent = _persistScanEvent;
      persistScanEvent();

      if (!mounted) return;
      setState(() {
        _premierEclairage = result;
        _premierEclairageLoading = false;
        _premierEclairageFailed = result == null;
      });
    } catch (_) {
      // Same ordering rule on the error path: persist the event first,
      // regardless of whether the user is still on screen when the
      // exception lands. Panel adversaire 2026-04-18 + panel façade
      // hunter both flagged this as a memory-loss bug.
      final persistScanEvent = _persistScanEvent;
      persistScanEvent();

      if (!mounted) return;
      setState(() {
        _premierEclairageLoading = false;
        _premierEclairageFailed = true;
      });
    }
  }

  /// Persist a scan event in [CoachMemoryService] — Wave A-MINIMAL A1.
  ///
  /// Topic is derived from [DocumentType]. Summary is best-effort:
  /// pulls caisse + avoir from extracted fields when present, falls
  /// back gracefully when fields are missing. The event lives in the
  /// non-pruned events namespace so it survives `fact`-heavy coaching
  /// bursts (panel adversaire 2026-04-18 B5).
  void _persistScanEvent() {
    if (widget.result.documentType == DocumentType.taxDeclaration) {
      return;
    }
    if (widget.result.documentType == DocumentType.lppCertificate ||
        widget.result.documentType == DocumentType.lppPlan) {
      return;
    }
    try {
      final topic = _scanTopicForType(widget.result.documentType);
      // A2-fix (2026-04-18) panel UX #2: pull the localized label from
      // AppLocalizations so the persisted summary respects the user's
      // current language instead of shipping FR literals into all 6
      // locales. The context is still valid here because
      // _persistScanEvent is called synchronously from the fetch
      // handlers (mounted at entry — see ordering rule A2-fix).
      final summary = _scanSummary(_scanTypeLabel(widget.result.documentType));
      final saveScanEvent =
          widget.saveScanEvent ?? CoachMemoryService.saveEvent;
      saveScanEvent(topic, summary).catchError((e) {
        debugPrint('[document_impact] saveEvent failed: $e');
      });
    } catch (e, st) {
      // Never let memory persistence break the scan UX.
      debugPrint('[document_impact] _persistScanEvent threw: $e\n$st');
    }
  }

  String _scanTopicForType(DocumentType type) {
    switch (type) {
      case DocumentType.lppCertificate:
        return 'scan_lpp';
      case DocumentType.lppPlan:
        throw UnsupportedError(type.backendValue);
      case DocumentType.pillar3aBeneficiaryClause:
        throw UnsupportedError(type.backendValue);
      case DocumentType.threeAAttestation:
        return 'scan_3a';
      case DocumentType.taxDeclaration:
        return 'scan_tax';
      case DocumentType.avsExtract:
        return 'scan_avs';
      case DocumentType.mortgageAttestation:
        return 'scan_mortgage';
      case DocumentType.salaryCertificate:
        return 'scan_salary';
    }
  }

  String _scanSummary(String typeLabel) {
    String? caisse;
    String? avoir;

    // Pull common LPP / 3a fields without hardcoding locale strings.
    for (final f in widget.result.fields) {
      final name = f.fieldName.toLowerCase();
      final value = f.value?.toString().trim();
      if (value == null || value.isEmpty) continue;
      if (caisse == null &&
          (name.contains('caisse') ||
              name.contains('institution') ||
              name.contains('pension') ||
              name.contains('fund'))) {
        caisse = value;
      }
      if (avoir == null &&
          (name.contains('avoir') ||
              name.contains('balance') ||
              name.contains('capital') ||
              name.contains('total'))) {
        // A2-fix (2026-04-18) panel UX #3: bucketize raw financial
        // amounts to nearest 10 000 CHF before persistence. A raw
        // "70377.00" violates CLAUDE.md §6.7 (no exact salary / wealth
        // in logs or memory); the rounded "~70'000 CHF" preserves
        // enough signal for the coach to reason about order of
        // magnitude without leaking the identifying precision.
        avoir = _bucketizeAvoir(value);
      }
    }

    if (caisse != null && avoir != null) {
      return '$typeLabel $caisse — $avoir';
    }
    if (caisse != null) {
      return '$typeLabel $caisse';
    }
    if (avoir != null) {
      return '$typeLabel — $avoir';
    }
    return typeLabel;
  }

  /// Round a raw numeric string to the nearest 10 000 CHF and format
  /// it Swiss-style (`~70'000 CHF`). Non-numeric input or parse
  /// failures fall back to localized non-disclosure copy — never return the
  /// raw value because persisted summaries must not leak identifying PII.
  String _bucketizeAvoir(String raw) {
    final cleaned =
        raw.replaceAll("'", '').replaceAll(' ', '').replaceAll(',', '.');
    final parsed = double.tryParse(cleaned);
    if (parsed == null) return S.of(context)!.scanSummaryAmountUnspecified;
    if (parsed <= 0) return S.of(context)!.scanSummaryAmountUnspecified;
    final bucket = (parsed / 10000).round() * 10000;
    // Swiss thousands separator: apostrophe (e.g. 70'000).
    final asInt = bucket.toInt();
    final withSep = asInt.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => "${m[1]}'",
        );
    return "~$withSep CHF";
  }

  String _scanTypeLabel(DocumentType type) {
    // A2-fix (2026-04-18) panel UX #2: pull strings from ARB so
    // persisted summaries respect the active locale. Keys declared in
    // all 6 ARB files (scanSummaryLppCertificate etc.). Uses the
    // current BuildContext — safe because _scanTypeLabel is called
    // synchronously from the fetch handlers before any unmount.
    final l10n = S.of(context)!;
    switch (type) {
      case DocumentType.lppCertificate:
        return l10n.scanSummaryLppCertificate;
      case DocumentType.lppPlan:
        throw UnsupportedError(type.backendValue);
      case DocumentType.pillar3aBeneficiaryClause:
        throw UnsupportedError(type.backendValue);
      case DocumentType.threeAAttestation:
        return l10n.scanSummary3aAttestation;
      case DocumentType.taxDeclaration:
        return l10n.scanSummaryTaxDeclaration;
      case DocumentType.avsExtract:
        return l10n.scanSummaryAvsExtract;
      case DocumentType.mortgageAttestation:
        return l10n.scanSummaryMortgageAttestation;
      case DocumentType.salaryCertificate:
        return l10n.scanSummarySalaryCertificate;
    }
  }

  void _initAnimations() {
    // Master: 3000ms total
    _masterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // Phase 1: Title fade in (0-15%)
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.0, 0.15, curve: Curves.easeOut),
      ),
    );

    // Phase 2: Circle progress (10-60%)
    _circleProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.10, 0.60, curve: Curves.easeOutCubic),
      ),
    );

    // Phase 3: Badge fade in (55-70%)
    _badgeFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.55, 0.70, curve: Curves.easeOut),
      ),
    );

    // Phase 4: Field list fade in (65-85%)
    _listFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.65, 0.85, curve: Curves.easeOut),
      ),
    );

    // Phase 5: CTA button (80-100%)
    _ctaFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.80, 1.0, curve: Curves.easeOut),
      ),
    );

    // Pulse (infinite, starts after circle completes)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _masterController.addListener(() {
      if (widget.result.documentType == DocumentType.taxDeclaration) return;
      if (_masterController.value >= 0.60 && !_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    });

    // Start
    _masterController.forward();
  }

  @override
  void dispose() {
    _scanSessions?.discard(widget.scanSessionId);
    _masterController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.result.documentType == DocumentType.taxDeclaration &&
        !FeatureFlags.taxAssessmentIngestionEnabled) {
      return Scaffold(
        key: const Key('tax_impact_disabled_recovery'),
        backgroundColor: MintColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(MintSpacing.lg),
            child: Text(
              S.of(context)!.docScanGenericError,
              textAlign: TextAlign.center,
              style: MintTextStyles.bodyLarge(color: MintColors.textPrimary),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: MintColors.porcelaine,
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: AnimatedBuilder(
                animation:
                    Listenable.merge([_masterController, _pulseController]),
                builder: (context, _) {
                  return SafeArea(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: MintSpacing.lg),
                        child: Column(
                          children: [
                            const SizedBox(height: MintSpacing.xxl),
                            MintEntrance(child: _buildTitle()),
                            const SizedBox(height: MintSpacing.xl + 4),
                            MintEntrance(
                                delay: const Duration(milliseconds: 100),
                                child: _buildConfidenceCircle()),
                            const SizedBox(height: MintSpacing.lg),
                            if (widget.result.documentType !=
                                DocumentType.taxDeclaration)
                              MintEntrance(
                                  delay: const Duration(milliseconds: 200),
                                  child: _buildDeltaBadge()),
                            if (_deltaPoints > 5) ...[
                              const SizedBox(height: MintSpacing.md),
                              MintEntrance(
                                  delay: const Duration(milliseconds: 250),
                                  child: _buildConfidenceDeltaText()),
                            ],
                            const SizedBox(height: MintSpacing.xl),
                            if (widget.result.documentType !=
                                DocumentType.taxDeclaration)
                              MintEntrance(
                                  delay: const Duration(milliseconds: 300),
                                  child: _buildPremierEclairageSection()),
                            const SizedBox(height: MintSpacing.lg),
                            MintEntrance(
                                delay: const Duration(milliseconds: 400),
                                child: _buildFieldList()),
                            const SizedBox(height: MintSpacing.xl),
                            _buildCtaButton(context),
                            if (_deltaPoints > 5) ...[
                              const SizedBox(height: MintSpacing.sm),
                              _buildCoachCta(context),
                            ],
                            const SizedBox(height: MintSpacing.md),
                            _buildDisclaimer(),
                            const SizedBox(height: MintSpacing.xxl + 12),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ))),
    );
  }

  // ── Title ────────────────────────────────────────────────

  Widget _buildTitle() {
    return Opacity(
      opacity: _fadeIn.value,
      child: Column(
        children: [
          Text(
            widget.result.documentType == DocumentType.taxDeclaration
                ? S.of(context)!.docImpactTaxTitle
                : S.of(context)!.docImpactTitle,
            textAlign: TextAlign.center,
            style: MintTextStyles.headlineMedium(),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            widget.result.documentType == DocumentType.taxDeclaration
                ? S.of(context)!.docImpactTaxSubtitle
                : S
                    .of(context)!
                    .docImpactSubtitle(widget.result.documentType.label),
            textAlign: TextAlign.center,
            style: MintTextStyles.labelLarge(),
          ),
        ],
      ),
    );
  }

  // ── Confidence circle (animated gauge) ───────────────────

  Widget _buildConfidenceCircle() {
    // Interpolate from previous to new confidence
    final displayedConfidence = widget.previousConfidence +
        ((_newConfidence - widget.previousConfidence) * _circleProgress.value)
            .round();

    final pulseGlow = _pulseAnimation.value * 0.15;

    // Phase 31-03 (OBS-06, D-06 default-deny): wrap the confidence
    // CustomPaint in MintCustomPaintMask so that any Session Replay frame
    // captured during an error-only replay (onErrorSampleRate=1.0) blanks
    // the canvas. The inner Text children are already covered by
    // options.privacy.maskAllText=true, but the arc overlays render
    // pixels outside the text engine and must be masked explicitly.
    return SizedBox(
      width: 200,
      height: 200,
      child: MintCustomPaintMask(
        child: CustomPaint(
          painter: _ConfidenceCirclePainter(
            progress: displayedConfidence / 100.0,
            oldProgress: widget.previousConfidence / 100.0,
            animationProgress: _circleProgress.value,
            glowIntensity: pulseGlow,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$displayedConfidence',
                  style: MintTextStyles.displayLarge(),
                ),
                Text(
                  S.of(context)!.docImpactConfidenceLabel,
                  style: MintTextStyles.bodyMedium()
                      .copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Delta badge ──────────────────────────────────────────

  Widget _buildDeltaBadge() {
    return Opacity(
      opacity: _badgeFadeIn.value,
      child: Transform.translate(
        offset: Offset(0, 20 * (1 - _badgeFadeIn.value)),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.md + 4, vertical: MintSpacing.sm + 2),
          decoration: BoxDecoration(
            color: MintColors.success.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(24),
            border:
                Border.all(color: MintColors.success.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_upward,
                  size: 20, color: MintColors.success),
              const SizedBox(width: MintSpacing.sm - 2),
              Text(
                S.of(context)!.docImpactDeltaPoints(_deltaPoints),
                style: MintTextStyles.titleMedium(
                  color: MintColors.success,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Premier Éclairage (4-layer insight from document) ─────

  Widget _buildPremierEclairageSection() {
    return Opacity(
      opacity: _badgeFadeIn.value,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(MintSpacing.md + 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              MintColors.primary.withValues(alpha: 0.04),
              MintColors.info.withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                S.of(context)!.docImpactPremierEclairageTitle,
                style: MintTextStyles.bodySmall().copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: MintSpacing.md),
            _buildPremierEclairageContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildPremierEclairageContent() {
    // Loading state
    if (_premierEclairageLoading) {
      return Center(
        child: Column(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: MintColors.primary,
              ),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              S.of(context)!.docImpactPremierEclairageLoading,
              style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
            ),
          ],
        ),
      );
    }

    // Failed state -- graceful degradation with field summary
    if (_premierEclairageFailed || _premierEclairage == null) {
      return _buildFallbackContent();
    }

    // Success: display 4-layer insight
    final humanTranslation =
        _premierEclairage!['humanTranslation'] as String? ?? '';
    final personalPerspective =
        _premierEclairage!['personalPerspective'] as String? ?? '';
    final questionsToAsk =
        (_premierEclairage!['questionsToAsk'] as List<dynamic>?)
                ?.map((q) => q.toString())
                .toList() ??
            [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Layer 2: Human translation
        if (humanTranslation.isNotEmpty) ...[
          Text(
            humanTranslation,
            style: MintTextStyles.bodyLarge(color: MintColors.textSecondary),
          ),
          const SizedBox(height: MintSpacing.lg),
        ],
        // Layer 3: Personal perspective
        if (personalPerspective.isNotEmpty) ...[
          Text(
            personalPerspective,
            style: MintTextStyles.bodyLarge(color: MintColors.textPrimary),
          ),
          const SizedBox(height: MintSpacing.lg),
        ],
        // Layer 4: Questions to ask
        if (questionsToAsk.isNotEmpty) ...[
          Text(
            S.of(context)!.docImpactQuestionsTitle,
            style: MintTextStyles.bodyMedium().copyWith(
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          ...questionsToAsk.map((q) => Padding(
                padding: const EdgeInsets.only(bottom: MintSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\u2022 ',
                      style: MintTextStyles.bodyMedium(
                          color: MintColors.textSecondary),
                    ),
                    Expanded(
                      child: Text(
                        q,
                        style: MintTextStyles.bodyMedium(
                            color: MintColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildFallbackContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.docImpactFallback,
          style:
              MintTextStyles.bodyLarge(color: MintColors.textPrimary).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: MintSpacing.md),
        // Show extracted field summary cards
        ...widget.result.fields.take(5).map((f) => Padding(
              padding: const EdgeInsets.only(bottom: MintSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _fieldLabel(f),
                      style: MintTextStyles.bodyMedium(
                          color: MintColors.textSecondary),
                    ),
                  ),
                  Text(
                    _formatShortValue(f),
                    style:
                        MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                            .copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  // ── Field list (what was added/updated) ──────────────────

  Widget _buildFieldList() {
    return Opacity(
      opacity: _listFadeIn.value,
      child: Transform.translate(
        offset: Offset(0, 30 * (1 - _listFadeIn.value)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.of(context)!.docImpactFieldsUpdated,
              style: MintTextStyles.bodyMedium().copyWith(
                  fontWeight: FontWeight.w600, color: MintColors.textPrimary),
            ),
            const SizedBox(height: MintSpacing.md - 4),
            ...widget.result.fields.map((f) => _buildFieldRow(f)),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldRow(ExtractedField field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: MintColors.success.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.check, size: 14, color: MintColors.success),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _fieldLabel(field),
              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
            ),
          ),
          Text(
            _formatShortValue(field),
            style: MintTextStyles.bodyMedium(
              color: MintColors.textPrimary,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ── CTA button ───────────────────────────────────────────

  Widget _buildCtaButton(BuildContext context) {
    return Opacity(
      opacity: _ctaFadeIn.value,
      child: Semantics(
        identifier: 'document_impact_return_cta',
        button: true,
        label: S.of(context)!.docImpactReturnDashboard,
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            key: widget.result.documentType == DocumentType.lppCertificate
                ? const Key('lpp_impact_retirement_cta')
                : null,
            onPressed: () {
              _scanSessions?.discard(widget.scanSessionId);
              if (widget.result.documentType == DocumentType.taxDeclaration) {
                context.go('/coach/chat');
                return;
              }
              if (widget.result.documentType == DocumentType.lppCertificate) {
                context.go('/retraite');
                return;
              }
              // Emit ScreenReturn so the coach chat can show a delta message.
              final docLabel = _scanTypeLabel(widget.result.documentType);
              ScreenCompletionTracker.markCompletedWithReturn(
                'document_scan',
                ScreenReturn.completed(
                  route: '/scan/impact',
                  stepOutputs: {
                    'scannedDocument': docLabel,
                    'newConfidence': _newConfidence,
                  },
                  confidenceDelta: _deltaPoints / 100.0,
                ),
              );
              context.go('/coach/chat');
            },
            icon: const Icon(Icons.dashboard_outlined, size: 22),
            label: Text(
              S.of(context)!.docImpactReturnDashboard,
              style: MintTextStyles.titleMedium()
                  .copyWith(fontWeight: FontWeight.w600),
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

  // ── Confidence delta text ─────────────────────────────────

  Widget _buildConfidenceDeltaText() {
    return Opacity(
      opacity: _badgeFadeIn.value,
      child: Text(
        S.of(context)!.scanInsightConfidenceDelta(
              widget.previousConfidence.toString(),
              _newConfidence.toString(),
              _deltaPoints.toString(),
            ),
        textAlign: TextAlign.center,
        style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
      ),
    );
  }

  // ── Coach CTA ───────────────────────────────────────────

  Widget _buildCoachCta(BuildContext context) {
    return Opacity(
      opacity: _ctaFadeIn.value,
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton.icon(
          onPressed: () {
            // Navigate to coach tab to discuss the impact.
            context.go('/coach/chat');
          },
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
          label: Text(
            S.of(context)!.scanInsightCta,
            style: MintTextStyles.bodyMedium(color: MintColors.primary),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: MintColors.primary,
            side: const BorderSide(color: MintColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }

  // ── Disclaimer ───────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Opacity(
      opacity: _ctaFadeIn.value,
      child: Text(
        widget.result.documentType == DocumentType.taxDeclaration
            ? S.of(context)!.docImpactTaxDisclaimer
            : S.of(context)!.docImpactDisclaimer,
        textAlign: TextAlign.center,
        style: MintTextStyles.labelSmall().copyWith(height: 1.5),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────

  String _formatChf(double amount) {
    final intPart = amount.truncate();
    final formatted = intPart.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => "${m[1]}'",
        );
    return formatted;
  }

  String _formatShortValue(ExtractedField field) {
    final value = field.value;
    if (value is double) {
      final lppKey = widget.result.documentType == DocumentType.lppCertificate
          ? LppEvidenceFactKey.fromWireName(field.fieldName)
          : null;
      if (lppKey?.unit == LppEvidenceUnit.ratio) {
        return '${(value * 100).toStringAsFixed(1)}%';
      }
      if (field.fieldName == 'explicitMarginalIncomeTaxRate' ||
          field.fieldName == 'explicitAverageIncomeTaxRate') {
        return '${(value * 100).toStringAsFixed(1)}%';
      }
      final normalizedName = field.fieldName.toLowerCase();
      if (normalizedName.contains('rate') ||
          normalizedName.contains('conversion') ||
          normalizedName.contains('bonification')) {
        return '${value.toStringAsFixed(1)}%';
      }
      return 'CHF ${_formatChf(value)}';
    }
    return value.toString();
  }

  String _fieldLabel(ExtractedField field) {
    if (widget.result.documentType != DocumentType.lppCertificate) {
      return field.label;
    }
    final l10n = S.of(context)!;
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
}

// ────────────────────────────────────────────────────────────
//  CONFIDENCE CIRCLE PAINTER (CustomPainter)
// ────────────────────────────────────────────────────────────

class _ConfidenceCirclePainter extends CustomPainter {
  final double progress; // Current confidence (0.0-1.0)
  final double oldProgress; // Previous confidence (0.0-1.0)
  final double animationProgress; // 0.0-1.0 animation timeline
  final double glowIntensity; // 0.0-0.15 pulse glow

  _ConfidenceCirclePainter({
    required this.progress,
    required this.oldProgress,
    required this.animationProgress,
    required this.glowIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 16;
    const strokeWidth = 12.0;

    // Background track
    final trackPaint = Paint()
      ..color = MintColors.lightBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Old progress arc (faded)
    if (oldProgress > 0) {
      final oldPaint = Paint()
        ..color = MintColors.textMuted.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * oldProgress,
        false,
        oldPaint,
      );
    }

    // Current progress arc (animated)
    final displayProgress =
        oldProgress + (progress - oldProgress) * animationProgress;
    if (displayProgress > 0) {
      // Determine color based on progress level
      final Color arcColor;
      if (displayProgress >= 0.70) {
        arcColor = MintColors.success;
      } else if (displayProgress >= 0.40) {
        arcColor = MintColors.info;
      } else {
        arcColor = MintColors.warning;
      }

      // Glow effect
      if (glowIntensity > 0) {
        final glowPaint = Paint()
          ..color = arcColor.withValues(alpha: glowIntensity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 8
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          -pi / 2,
          2 * pi * displayProgress,
          false,
          glowPaint,
        );
      }

      // Main arc
      final arcPaint = Paint()
        ..color = arcColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * displayProgress,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConfidenceCirclePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.animationProgress != animationProgress ||
        oldDelegate.glowIntensity != glowIntensity;
  }
}
