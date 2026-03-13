import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/document_scan/document_impact_screen.dart';

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
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 12),
                _buildHeader(),
                const SizedBox(height: 8),
                _buildOverallConfidenceBadge(),
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
                _buildConfirmButton(),
                const SizedBox(height: 16),
                _buildDisclaimer(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
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
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'VERIFICATION',
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w800,
          fontSize: 13,
          letterSpacing: 1.5,
          color: MintColors.textMuted,
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
          'Verifie les valeurs extraites',
          style: GoogleFonts.montserrat(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_fields.length} champs detectes'
          '${reviewCount > 0 ? ' dont $reviewCount a verifier' : ''}. '
          'Tu peux modifier chaque valeur avant de confirmer.',
          style: GoogleFonts.inter(
            fontSize: 15,
            color: MintColors.textSecondary,
            height: 1.5,
          ),
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
            'Confiance extraction : $pct%',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
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
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textPrimary,
                    height: 1.4,
                  ),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: field.needsReview
              ? badgeColor.withValues(alpha: 0.4)
              : MintColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: MintColors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textSecondary,
                  ),
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
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
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
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              // Edit button
              IconButton(
                onPressed: () => _editField(field),
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: MintColors.textMuted,
                tooltip: 'Modifier',
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
              'Lu : "${_truncateSource(field.sourceText)}"',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: MintColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
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
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: _onConfirmAll,
        icon: const Icon(Icons.check_circle_outline, size: 22),
        label: Text(
          'Confirmer tout',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: MintColors.primary,
          foregroundColor: MintColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ── Disclaimer ───────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.result.disclaimer,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          ...widget.result.sources.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  s,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: MintColors.textMuted,
                  ),
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
          'Modifier : ${field.label}',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Valeur actuelle : ${_formatValue(field)}',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                labelText: 'Nouvelle valeur',
                labelStyle: GoogleFonts.inter(fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: MintColors.primary),
                ),
              ),
              style: GoogleFonts.inter(fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Annuler',
              style: GoogleFonts.inter(color: MintColors.textSecondary),
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
              Navigator.of(ctx).pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: MintColors.primary,
            ),
            child: Text(
              'Valider',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
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

    // Inject extracted data and AWAIT persistence before navigating
    switch (widget.result.documentType) {
      case DocumentType.lppCertificate:
        await coachProvider.updateFromLppExtraction(_fields);
      case DocumentType.avsExtract:
        await coachProvider.updateFromAvsExtraction(_fields);
      case DocumentType.taxDeclaration:
        await coachProvider.updateFromTaxExtraction(_fields);
      default:
        break;
    }

    if (!mounted) return;

    // Navigate to impact screen with real confidence values
    context.push('/document-scan/impact', extra: {
      'result': confirmedResult,
      'previousConfidence': previousConfidence,
    });
  }
}
