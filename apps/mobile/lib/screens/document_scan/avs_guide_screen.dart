import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/avs_extract_parser.dart';
import 'package:mint_mobile/screens/document_scan/extraction_review_screen.dart';

// ────────────────────────────────────────────────────────────
//  AVS GUIDE SCREEN — Sprint S45
// ────────────────────────────────────────────────────────────
//
//  Guides the user through obtaining their AVS individual
//  account extract (Extrait de compte individuel CI).
//
//  Steps:
//    1. Go to www.ahv-iv.ch
//    2. Log in with eID or create account
//    3. Request the individual account extract (CI)
//    4. Receive it by mail or PDF
//
//  Actions:
//    - "Ouvrir ahv-iv.ch" (url_launcher)
//    - "J'ai deja mon extrait -> Scanner"
//    - "Utiliser un exemple AVS" (debug / QA)
//
//  Reference:
//    - DATA_ACQUISITION_STRATEGY.md — Channel 1, Document C
//    - LAVS art. 29ter-30 (RAMD, annees de cotisation)
// ────────────────────────────────────────────────────────────

class AvsGuideScreen extends StatefulWidget {
  const AvsGuideScreen({super.key});

  @override
  State<AvsGuideScreen> createState() => _AvsGuideScreenState();
}

class _AvsGuideScreenState extends State<AvsGuideScreen> {
  bool _isProcessing = false;

  static const String _ahvUrl = 'https://www.ahv-iv.ch';

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
                const SizedBox(height: 24),
                _buildConfidenceImpact(),
                const SizedBox(height: 28),
                _buildSteps(),
                const SizedBox(height: 28),
                _buildOpenAhvButton(),
                const SizedBox(height: 16),
                _buildScanButton(),
                if (kDebugMode) ...[
                  const SizedBox(height: 16),
                  _buildSimulateButton(),
                ],
                const SizedBox(height: 24),
                _buildFreeNote(),
                const SizedBox(height: 16),
                _buildPrivacyNote(),
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
        onPressed: () => context.pop(),
      ),
      title: Text(
        'EXTRAIT AVS',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comment obtenir ton extrait AVS',
          style: GoogleFonts.montserrat(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "L'extrait de compte individuel (CI) contient tes années de "
          "cotisation, ton revenu moyen (RAMD) et tes éventuelles lacunes. "
          "C'est la clé pour une projection AVS fiable.",
          style: GoogleFonts.inter(
            fontSize: 15,
            color: MintColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ── Confidence impact card ─────────────────────────────────

  Widget _buildConfidenceImpact() {
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
                  '+${DocumentType.avsExtract.confidenceImpact} points de confiance',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: MintColors.info,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Annees de cotisation, RAMD, lacunes',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Steps ────────────────────────────────────────────────

  Widget _buildSteps() {
    const steps = [
      _StepData(
        number: 1,
        title: 'Va sur www.ahv-iv.ch',
        subtitle: "C'est le site officiel de l'AVS/AI. Tu peux aussi demander "
            'ton extrait directement a ta caisse de compensation.',
      ),
      _StepData(
        number: 2,
        title: 'Connecte-toi avec ton eID ou cree un compte',
        subtitle: 'Tu auras besoin de ton numero AVS '
            '(756.XXXX.XXXX.XX, sur ta carte d\'assurance-maladie).',
      ),
      _StepData(
        number: 3,
        title: 'Demande ton extrait de compte individuel (CI)',
        subtitle:
            "Cherche la section \"Extrait de compte\" ou \"Kontoauszug\". "
            "C'est un document officiel qui recapitule toutes tes cotisations.",
      ),
      _StepData(
        number: 4,
        title: 'Tu le recevras par courrier ou PDF',
        subtitle:
            "Selon ta caisse, l'extrait arrive en 5 a 10 jours ouvrables. "
            "Certaines caisses proposent un telechargement PDF immediat.",
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'En 4 etapes',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
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
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: MintColors.white,
                ),
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
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Open ahv-iv.ch button ──────────────────────────────────

  Widget _buildOpenAhvButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: _onOpenAhv,
        icon: const Icon(Icons.open_in_new, size: 20),
        label: Text(
          'Ouvrir ahv-iv.ch',
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

  // ── Scan button ────────────────────────────────────────────

  Widget _buildScanButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: _isProcessing ? null : _onScanExtract,
        icon: const Icon(Icons.document_scanner_outlined, size: 22),
        label: Text(
          "J'ai deja mon extrait \u2192 Scanner",
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: MintColors.textPrimary,
          side: const BorderSide(color: MintColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ── Simulate button (debug/QA) ───────────────────────────

  Widget _buildSimulateButton() {
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
            'MODE TEST',
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: MintColors.purple,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Pas d'extrait AVS sous la main ? "
            "Teste le flux avec un exemple d'extrait.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
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
                      'Utiliser un exemple',
                      style: GoogleFonts.inter(
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

  Widget _buildFreeNote() {
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
              "L'extrait AVS est gratuit et disponible en 5 a 10 jours ouvrables. "
              "Tu peux aussi te rendre a ta caisse de compensation cantonale.",
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Privacy note ──────────────────────────────────────────

  Widget _buildPrivacyNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, size: 18, color: MintColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "L'image de ton extrait n'est jamais stockee ni envoyee. "
              "L'extraction se fait sur ton appareil. "
              "Seules les valeurs que tu confirmes sont conservees dans ton profil.",
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textMuted,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────

  Future<void> _onOpenAhv() async {
    final uri = Uri.parse(_ahvUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible d\'ouvrir $_ahvUrl. '
            'Copie l\'adresse et ouvre-la dans ton navigateur.',
            style: GoogleFonts.inter(fontSize: 14),
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

    // Navigate to extraction review
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExtractionReviewScreen(result: result),
      ),
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
