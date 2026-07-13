import 'package:flutter/foundation.dart';
import 'package:mint_mobile/services/navigation/safe_pop.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/avs_extract_parser.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

// ────────────────────────────────────────────────────────────
//  AVS GUIDE SCREEN — Sprint S45
// ────────────────────────────────────────────────────────────
//
//  Guides the user to the official future-pension calculation that can
//  certify a monthly AVS amount. The CI scan remains a separate enrichment
//  path for contribution years, income and gaps; it cannot certify a pension.
//
//  Steps:
//    1. Open official form 318.282
//    2. Complete one request per person
//    3. Send it to the compensation office
//    4. Keep the dated calculation returned by the office
//
//  Reference:
//    - Centre d'information AVS/AI — formulaire administratif 318.282
//    - Memento 3.06 — calcul anticipe d'une rente
// ────────────────────────────────────────────────────────────

/// Direct official form 318.282, state 01.01.2026.
///
/// Sources: the AVS/AI administrative-form registries and leaflet 3.06,
/// section 14. The leaflet also recommends a joint request for married
/// couples. Spanish and Portuguese deliberately use the English form because
/// the corresponding `.es` and `.pt` direct endpoints return 404.
Uri avsOfficialFuturePensionFormUri(Locale locale) {
  const suffixByLanguage = <String, String>{
    'fr': 'f',
    'de': 'd',
    'it': 'i',
    'en': 'e',
    'es': 'e',
    'pt': 'e',
  };
  final suffix = suffixByLanguage[locale.languageCode.toLowerCase()] ?? 'e';
  return Uri.parse('https://www.ahv-iv.ch/p/318.282.$suffix');
}

class AvsGuideScreen extends StatefulWidget {
  const AvsGuideScreen({super.key});

  @override
  State<AvsGuideScreen> createState() => _AvsGuideScreenState();
}

class _AvsGuideScreenState extends State<AvsGuideScreen> {
  bool _isProcessing = false;

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return Scaffold(
      backgroundColor: MintColors.background,
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: CustomScrollView(
        slivers: [
          _buildAppBar(context, l),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 12),
                MintEntrance(child: _buildHeader(l)),
                const SizedBox(height: 24),
                MintEntrance(delay: const Duration(milliseconds: 100), child: _buildConfidenceImpact(l)),
                const SizedBox(height: 28),
                MintEntrance(delay: const Duration(milliseconds: 200), child: _buildSteps(l)),
                const SizedBox(height: 28),
                MintEntrance(
                  delay: const Duration(milliseconds: 300),
                  child: _buildOpenOfficialFormButton(l),
                ),
                const SizedBox(height: 16),
                MintEntrance(delay: const Duration(milliseconds: 400), child: _buildScanButton(l)),
                if (kDebugMode) ...[
                  const SizedBox(height: 16),
                  _buildSimulateButton(l),
                ],
                const SizedBox(height: 24),
                _buildFreeNote(l),
                const SizedBox(height: 16),
                _buildPrivacyNote(l),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ))),
    );
  }

  // ── AppBar ───────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context, S l) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: MintColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => safePop(context),
      ),
      title: Text(
        l.avsGuideAppBarTitle,
        style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────

  Widget _buildHeader(S l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.avsGuideHeaderTitle,
          style: MintTextStyles.headlineMedium(color: MintColors.textPrimary).copyWith(height: 1.3),
        ),
        const SizedBox(height: 8),
        Text(
          l.avsGuideHeaderSubtitle,
          style: MintTextStyles.labelLarge(color: MintColors.textSecondary).copyWith(height: 1.5),
        ),
      ],
    );
  }

  // ── Confidence impact card ─────────────────────────────────

  Widget _buildConfidenceImpact(S l) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.coachBubble,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: MintColors.info.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.trending_up, color: MintColors.info, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.avsGuideConfidencePoints(DocumentType.avsExtract.confidenceImpact),
                  style: MintTextStyles.bodyLarge(color: MintColors.info).copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.avsGuideConfidenceSubtitle,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Steps ────────────────────────────────────────────────

  Widget _buildSteps(S l) {
    final steps = [
      _StepData(
        number: 1,
        title: l.avsGuideStep1Title,
        subtitle: l.avsGuideStep1Subtitle,
      ),
      _StepData(
        number: 2,
        title: l.avsGuideStep2Title,
        subtitle: l.avsGuideStep2Subtitle,
      ),
      _StepData(
        number: 3,
        title: l.avsGuideStep3Title,
        subtitle: l.avsGuideStep3Subtitle,
      ),
      _StepData(
        number: 4,
        title: l.avsGuideStep4Title,
        subtitle: l.avsGuideStep4Subtitle,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.avsGuideStepsTitle,
          style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: MintSpacing.md),
        ...steps.map((step) => _buildStepCard(step)),
      ],
    );
  }

  Widget _buildStepCard(_StepData step) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step number circle
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: MintColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '${step.number}',
                style: MintTextStyles.bodyMedium(color: MintColors.white).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Step content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: MintTextStyles.bodyLarge(color: MintColors.textPrimary).copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.subtitle,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Open official future-pension form ──────────────────────

  Widget _buildOpenOfficialFormButton(S l) {
    return Semantics(
      identifier: 'avs_official_form_cta',
      button: true,
      label: l.avsGuideOpenAhvButton,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton.icon(
          key: const Key('avs_official_form_cta'),
          onPressed: _onOpenOfficialForm,
        icon: const Icon(Icons.open_in_new, size: 20),
        label: Text(
          l.avsGuideOpenAhvButton,
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

  // ── Scan button ────────────────────────────────────────────

  Widget _buildScanButton(S l) {
    return Semantics(
      button: true,
      label: l.avsGuideScanButton,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: OutlinedButton.icon(
          onPressed: _isProcessing ? null : _onScanExtract,
        icon: const Icon(Icons.document_scanner_outlined, size: 22),
        label: Text(
          l.avsGuideScanButton,
          style: MintTextStyles.titleMedium(),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: MintColors.textPrimary,
          side: const BorderSide(color: MintColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    ),
    );
  }

  // ── Simulate button (debug/QA) ───────────────────────────

  Widget _buildSimulateButton(S l) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.purple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.purple.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            l.avsGuideTestMode,
            style: MintTextStyles.micro(color: MintColors.purple).copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.avsGuideTestDescription,
            textAlign: TextAlign.center,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: _isProcessing
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: MintColors.purple,
                      ),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: _onSimulateScan,
                    icon: const Icon(Icons.science_outlined, size: 20),
                    label: Text(
                      l.avsGuideTestButton,
                      style: MintTextStyles.bodyLarge(color: MintColors.white).copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: MintColors.purple,
                      foregroundColor: MintColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Free note ──────────────────────────────────────────────

  Widget _buildFreeNote(S l) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.success.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 18, color: MintColors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l.avsGuideFreeNote,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // ── Privacy note ──────────────────────────────────────────

  Widget _buildPrivacyNote(S l) {
    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      padding: const EdgeInsets.all(14),
      radius: 12,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, size: 18, color: MintColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l.avsGuidePrivacyNote,
              style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────

  Future<void> _onOpenOfficialForm() async {
    final uri = avsOfficialFuturePensionFormUri(Localizations.localeOf(context));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      final l = S.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l.avsGuideSnackbarError(uri.toString()),
            style: MintTextStyles.bodyMedium(),
          ),
          backgroundColor: MintColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _onScanExtract() {
    context.push('/scan', extra: DocumentType.avsExtract);
  }

  void _onSimulateScan() async {
    setState(() => _isProcessing = true);

    // Simulate processing delay (OCR would take 2-5 seconds)
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    // Parse the sample OCR text
    final result = AvsExtractParser.parseAvsExtract(
      AvsExtractParser.sampleOcrText,
      userAge: 37, // Demo user born 1988
    );

    setState(() => _isProcessing = false);

    if (!mounted) return;
    final scanSessionId =
        context.read<ScanSessionProvider>().retainExtraction(result);
    context.push(
      '/scan/review?scanSessionId=${Uri.encodeQueryComponent(scanSessionId)}',
    );
  }
}

/// Data class for step display.
class _StepData {
  final int number;
  final String title;
  final String subtitle;

  const _StepData({
    required this.number,
    required this.title,
    required this.subtitle,
  });
}
