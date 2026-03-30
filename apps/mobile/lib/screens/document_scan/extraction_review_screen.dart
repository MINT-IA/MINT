import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/document_service.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

// ────────────────────────────────────────────────────────────
//  EXTRACTION REVIEW SCREEN — Sprint S42-S43
// ────────────────────────────────────────────────────────────
//
//  "Voici ce qu'on a lu. Verifie et corrige si necessaire."
//
//  Displays extracted fields with confidence badges.
//  User can edit any field before confirming.
//
//  Reference: DATA_ACQUISITION_STRATEGY.md — Channel 1
//  User flow step 4: extraction review.
// ────────────────────────────────────────────────────────────

class ExtractionReviewScreen extends StatefulWidget {
  final ExtractionResult result;

  const ExtractionReviewScreen({super.key, required this.result});

  @override
  State<ExtractionReviewScreen> createState() => _ExtractionReviewScreenState();
}

class _ExtractionReviewScreenState extends State<ExtractionReviewScreen> {
  late List<ExtractedField> _fields;
  late double _overallConfidence;

  @override
  void initState() {
    super.initState();
    _fields = List.from(widget.result.fields);
    _overallConfidence = widget.result.overallConfidence;
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 12),
                MintEntrance(child: _buildHeader()),
                const SizedBox(height: 8),
                MintEntrance(delay: const Duration(milliseconds: 100), child: _buildOverallConfidenceBadge()),
                const SizedBox(height: 20),
                if (widget.result.warnings.isNotEmpty) ...[
                  _buildWarnings(),
                  const SizedBox(height: 20),
                ],
                ..._fields.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildFieldCard(f),
                    )),
                const SizedBox(height: 24),
                MintEntrance(delay: const Duration(milliseconds: 200), child: _buildConfirmButton()),
                const SizedBox(height: 16),
                MintEntrance(delay: const Duration(milliseconds: 300), child: _buildDisclaimer()),
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
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => context.pop(),
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

  // ── Header ───────────────────────────────────────────────

  Widget _buildHeader() {
    final reviewCount = _fields.where((f) => f.needsReview).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.extractionReviewTitle,
          style: MintTextStyles.headlineMedium(color: MintColors.textPrimary).copyWith(height: 1.3),
        ),
        const SizedBox(height: 8),
        Text(
          S.of(context)!.extractionReviewSubtitle(_fields.length, reviewCount > 0 ? S.of(context)!.extractionReviewNeedsReview(reviewCount) : ''),
          style: MintTextStyles.bodyLarge(color: MintColors.textSecondary).copyWith(fontSize: 15, height: 1.5),
        ),
      ],
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
            style: MintTextStyles.bodySmall(color: color).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ── Warnings ─────────────────────────────────────────────

  Widget _buildWarnings() {
    return Column(
      children: widget.result.warnings.map((w) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
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
                  w,
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(height: 1.4),
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
    final Color badgeColor;
    final IconData statusIcon;

    switch (field.confidenceLevel) {
      case ConfidenceLevel.high:
        badgeColor = MintColors.success;
        statusIcon = Icons.check_circle;
      case ConfidenceLevel.medium:
        badgeColor = MintColors.warning;
        statusIcon = Icons.warning_amber;
      case ConfidenceLevel.low:
        badgeColor = MintColors.error;
        statusIcon = Icons.error_outline;
    }

    return MintSurface(
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
                  field.label,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w500),
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
                  style: MintTextStyles.micro(color: badgeColor).copyWith(fontWeight: FontWeight.w700),
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
                  style: MintTextStyles.headlineMedium(color: MintColors.textPrimary).copyWith(fontSize: 20),
                ),
              ),
              // Edit button
              IconButton(
                onPressed: () => _editField(field),
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

          // Source text (small, muted)
          if (field.sourceText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              S.of(context)!.extractionReviewSourcePrefix(_truncateSource(field.sourceText)),
              style: MintTextStyles.micro(color: MintColors.textMuted).copyWith(fontStyle: FontStyle.italic),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  // ── Confirm button ───────────────────────────────────────

  Widget _buildConfirmButton() {
    return Semantics(
      button: true,
      label: S.of(context)!.extractionReviewConfirmAll,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton.icon(
          onPressed: _onConfirmAll,
        icon: const Icon(Icons.check_circle_outline, size: 22),
        label: Text(
          S.of(context)!.extractionReviewConfirmAll,
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
    );
  }

  // ── Disclaimer ───────────────────────────────────────────

  Widget _buildDisclaimer() {
    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      padding: const EdgeInsets.all(14),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.result.disclaimer,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(height: 1.5),
          ),
          const SizedBox(height: 8),
          ...widget.result.sources.map((s) => Padding(
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

  String _formatValue(ExtractedField field) {
    final value = field.value;
    if (value is double) {
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
    final controller = TextEditingController(
      text: field.value is double
          ? (field.value as double).toStringAsFixed(2)
          : field.value.toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          S.of(context)!.extractionReviewEditTitle(field.label),
          style: MintTextStyles.titleMedium().copyWith(fontWeight: FontWeight.w600),
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
            TextField(
              controller: controller,
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
            onPressed: () {
              final newValue = double.tryParse(
                controller.text.replaceAll("'", '').replaceAll(',', '.'),
              );
              if (newValue != null) {
                setState(() {
                  final idx = _fields.indexOf(field);
                  if (idx >= 0) {
                    _fields[idx] = field.copyWithValue(newValue);
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
              style: MintTextStyles.bodyMedium(color: MintColors.white).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  void _recalculateOverallConfidence() {
    if (_fields.isEmpty) return;
    _overallConfidence =
        _fields.map((f) => f.confidence).reduce((a, b) => a + b) /
            _fields.length;
  }

  /// Ask user whose document this is (for couple profiles).
  /// Returns true if this is the partner's document.
  Future<bool> _askWhoseDocument() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(ctx)!.extractionWhoseDocument),
        content: Text(S.of(ctx)!.extractionWhoseDocumentBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.of(ctx)!.extractionDocMine),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.of(ctx)!.extractionDocPartner),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── Confirm and navigate ─────────────────────────────────

  Future<void> _onConfirmAll() async {
    // Build the confirmed result
    final confirmedResult = ExtractionResult(
      documentType: widget.result.documentType,
      fields: _fields,
      overallConfidence: _overallConfidence,
      confidenceDelta: widget.result.confidenceDelta,
      warnings: widget.result.warnings,
      disclaimer: widget.result.disclaimer,
      sources: widget.result.sources,
    );

    // ── Persist extraction data to CoachProfile ──
    final coachProvider = Provider.of<CoachProfileProvider>(
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
    final isCouple = coachProvider.hasProfile &&
        coachProvider.profile!.conjoint != null;
    final isPartnerDoc = isCouple &&
        (widget.result.documentType == DocumentType.lppCertificate ||
         widget.result.documentType == DocumentType.salaryCertificate) &&
        await _askWhoseDocument();

    // Inject extracted data and AWAIT persistence before navigating
    switch (widget.result.documentType) {
      case DocumentType.lppCertificate:
        if (isPartnerDoc) {
          await coachProvider.updateFromPartnerLppExtraction(_fields);
        } else {
          await coachProvider.updateFromLppExtraction(_fields);
        }
      case DocumentType.avsExtract:
        await coachProvider.updateFromAvsExtraction(_fields);
      case DocumentType.taxDeclaration:
        await coachProvider.updateFromTaxExtraction(_fields);
      case DocumentType.salaryCertificate:
        await coachProvider.updateFromSalaryExtraction(_fields);
      default:
        break;
    }

    // ── Sync to backend (offline-first: failure never blocks UX) ──
    final syncFields = _fields.map((f) {
      final conf = f.confidence >= 0.8 ? 'high' : (f.confidence >= 0.5 ? 'medium' : 'low');
      return <String, dynamic>{
        'fieldName': f.profileField ?? f.label,
        'value': f.value,
        'confidence': conf,
        'sourceText': f.sourceText,
      };
    }).toList();
    DocumentService.sendScanConfirmation(
      documentType: widget.result.documentType.name,
      confirmedFields: syncFields,
      overallConfidence: _overallConfidence,
    ).catchError((_) => null); // Fire-and-forget

    if (!mounted) return;

    context.push('/scan/impact', extra: {
      'result': confirmedResult,
      'previousConfidence': previousConfidence,
    });
  }
}
