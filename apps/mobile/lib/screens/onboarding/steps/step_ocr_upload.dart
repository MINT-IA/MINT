import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/screens/onboarding/smart_onboarding_viewmodel.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Step OCR — Enrichissement du profil par scan de documents.
///
/// Position dans le flux : apres StepChiffreChoc (hook emotionnel intact).
///
/// Affiche 4 types de documents que l'utilisateur peut scanner :
/// - Lettre de retraite LPP
/// - Extrait AVS
/// - Declaration fiscale
/// - Compte 3a
///
/// Contraintes LPD / FINMA :
/// - Banniere LPD visible avant toute possibilite de scan.
/// - "Traite sur ton appareil, supprime apres extraction" (LPD art. 6).
/// - Skip sans friction depuis l'entree dans le step.
/// - Aucun stockage de document : seules les donnees extraites vont
///   dans CoachProfile via le ViewModel.
///
/// Le pipeline OCR utilise ML Kit on-device + parsers Dart regex
/// (ExtractionResult de document_models.dart).
/// Aucune cle API, aucun envoi reseau.
class StepOcrUpload extends StatefulWidget {
  final SmartOnboardingViewModel viewModel;

  /// Appelé quand l'utilisateur termine le step (avec ou sans document).
  final VoidCallback onNext;

  const StepOcrUpload({
    super.key,
    required this.viewModel,
    required this.onNext,
  });

  @override
  State<StepOcrUpload> createState() => _StepOcrUploadState();
}

class _StepOcrUploadState extends State<StepOcrUpload> {
  // Documents disponibles dans ce step
  static const _documents = [
    (
      type: DocumentType.lppCertificate,
      title: 'Ta lettre de retraite LPP',
      subtitle: 'Avoir, taux de conversion, lacune de rachat',
      icon: Icons.account_balance_outlined,
      confidenceBoost: '+27 pts de precision',
    ),
    (
      type: DocumentType.avsExtract,
      title: 'Ton extrait AVS',
      subtitle: 'Annees de cotisation, lacunes, RAMD',
      icon: Icons.security_outlined,
      confidenceBoost: '+22 pts de precision',
    ),
    (
      type: DocumentType.taxDeclaration,
      title: 'Ta declaration fiscale',
      subtitle: 'Revenu imposable, fortune, taux marginal',
      icon: Icons.receipt_long_outlined,
      confidenceBoost: '+17 pts de precision',
    ),
    (
      type: DocumentType.threeAAttestation,
      title: 'Ton compte 3a',
      subtitle: 'Solde, versements cumules, rendement',
      icon: Icons.savings_outlined,
      confidenceBoost: '+7 pts de precision',
    ),
  ];

  DocumentType? _scanning;
  final Set<DocumentType> _scanned = {};

  Future<void> _scanDocument(DocumentType type) async {
    // LPD : demander confirmation avant de lancer le scan
    final confirmed = await _showLpdConfirmation(type);
    if (!confirmed || !mounted) return;

    setState(() => _scanning = type);

    // TODO(S45): Appeler le scanner ML Kit on-device ici.
    // Pour l'instant, on simule un scan vide (pas de donnees a injecter).
    // Le vrai pipeline : image_picker → google_mlkit_text_recognition → parser.
    //
    // Exemple d'integration future :
    //   final picker = ImagePicker();
    //   final image = await picker.pickImage(source: ImageSource.gallery);
    //   if (image == null) { setState(() => _scanning = null); return; }
    //   final inputImage = InputImage.fromFilePath(image.path);
    //   final recognizer = TextRecognizer();
    //   final recognised = await recognizer.processImage(inputImage);
    //   final result = LppCertificateParser.parse(recognised.text);
    //   widget.viewModel.applyOcrResult(result);

    // Simulation d'un resultat vide (aucun champ extrait)
    final fakeResult = ExtractionResult(
      documentType: type,
      fields: const [],
      overallConfidence: 0,
      confidenceDelta: 0,
      warnings: const ['Scan simule — integration ML Kit prevue S45'],
      disclaimer:
          'Outil educatif. Ne constitue pas un conseil financier (LSFin). '
          'Donnees traitees sur ton appareil, supprimees apres extraction (LPD art. 6).',
      sources: const [],
    );
    widget.viewModel.applyOcrResult(fakeResult);

    if (mounted) {
      setState(() {
        _scanning = null;
        _scanned.add(type);
      });
    }
  }

  Future<bool> _showLpdConfirmation(DocumentType type) async {
    if (!mounted) return false;
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MintColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: MintColors.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.lock_outline,
                        color: MintColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Traitement prive sur ton appareil',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: MintColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Ce document est analyse directement sur ton telephone.\n'
                  'Aucune donnee n\'est envoyee sur Internet.\n'
                  'Les informations extraites sont supprimees apres traitement.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: MintColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Base legale : LPD art. 6 — minimisation des donnees.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: MintColors.textMuted,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: MintColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Scanner ce document',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(
                      'Annuler',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final scannedCount = _scanned.length;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── AppBar gradient MINT ────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.only(left: 24, bottom: 16, right: 24),
              title: Text(
                'Enrichis ton profil en 30 secondes',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Colors.white,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [MintColors.primary, MintColors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Lien skip — visible sans friction DES l'entree ──────
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: widget.onNext,
                      child: Text(
                        'Continuer sans document',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: MintColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // ── Banniere LPD — obligatoire avant tout scan ──────────
                  const _LpdBanner(),
                  const SizedBox(height: 24),

                  // ── Texte intro ─────────────────────────────────────────
                  Text(
                    'Scanne un ou plusieurs documents pour que MINT calcule '
                    'ta situation avec plus de precision.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: MintColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Cartes documents ────────────────────────────────────
                  ..._documents.map((doc) {
                    final isScanned = _scanned.contains(doc.type);
                    final isScanning = _scanning == doc.type;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DocumentCard(
                        title: doc.title,
                        subtitle: doc.subtitle,
                        icon: doc.icon,
                        confidenceBoost: doc.confidenceBoost,
                        isScanned: isScanned,
                        isLoading: isScanning,
                        onTap: isScanning
                            ? null
                            : () => _scanDocument(doc.type),
                      ),
                    );
                  }),

                  const SizedBox(height: 28),

                  // ── CTA principal ───────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: widget.onNext,
                      style: FilledButton.styleFrom(
                        backgroundColor: scannedCount > 0
                            ? MintColors.primary
                            : MintColors.primary.withAlpha(180),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        scannedCount > 0
                            ? 'Continuer ($scannedCount document${scannedCount > 1 ? 's' : ''} scanne${scannedCount > 1 ? 's' : ''})'
                            : 'Continuer sans document',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Disclaimer FINMA/LPD
                  Text(
                    'Outil educatif — ne constitue pas un conseil financier (LSFin). '
                    'Documents traites sur ton appareil, aucune donnee envoyee (LPD art. 6).',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: MintColors.textMuted,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  LPD BANNER — affichee avant toute possibilite de scan
// ════════════════════════════════════════════════════════════════════════════

class _LpdBanner extends StatelessWidget {
  const _LpdBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: MintColors.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.primary.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_outline,
            size: 18,
            color: MintColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tes documents sont traites sur ton appareil. '
              'Rien n\'est envoye sur Internet.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.primary,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  DOCUMENT CARD — carte pour un type de document scannable
// ════════════════════════════════════════════════════════════════════════════

class _DocumentCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String confidenceBoost;
  final bool isScanned;
  final bool isLoading;
  final VoidCallback? onTap;

  const _DocumentCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.confidenceBoost,
    required this.isScanned,
    required this.isLoading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isScanned
              ? MintColors.primary.withAlpha(12)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isScanned ? MintColors.primary : MintColors.lightBorder,
            width: isScanned ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isScanned
                    ? MintColors.primary.withAlpha(24)
                    : MintColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: MintColors.primary,
                      ),
                    )
                  : Icon(
                      isScanned ? Icons.check_circle_outline : icon,
                      color: isScanned
                          ? MintColors.primary
                          : MintColors.textSecondary,
                      size: 22,
                    ),
            ),
            const SizedBox(width: 14),

            // Textes
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Badge precision
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isScanned
                    ? MintColors.primary
                    : MintColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isScanned
                      ? MintColors.primary
                      : MintColors.lightBorder,
                ),
              ),
              child: Text(
                isScanned ? 'Scanne' : confidenceBoost,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color:
                      isScanned ? Colors.white : MintColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
