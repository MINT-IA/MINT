import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  P3-E  Parcours fléché immobilier — 7 étapes narratives
//  Charte : L3 (3 niveaux) + L5 (1 action par étape)
//  Source : FINMA/ASB (5% tragbarkeit), LPP art. 30c (EPL)
//          CC art. 652 (propriété), LIFD art. 21 (valeur locative)
// ────────────────────────────────────────────────────────────

/// Represents one step of the mortgage journey.
class MortgageStep {
  const MortgageStep({
    required this.number,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.legalRef,
  });

  final int number;
  final String emoji;
  final String title;
  final String subtitle;
  final String action;
  final String legalRef;
}

const _kSteps = [
  MortgageStep(
    number: 1,
    emoji: '🧮',
    title: 'Est-ce que je peux acheter ?',
    subtitle: 'Règle des 3 tiers : les charges (intérêts théoriques à 5% + amortissement 1% + entretien 1%) ne doivent pas dépasser 1/3 de ton revenu brut.',
    action: 'Calcule ta capacité avec le simulateur MINT',
    legalRef: 'FINMA/ASB — taux théorique 5%',
  ),
  MortgageStep(
    number: 2,
    emoji: '💰',
    title: 'D\'où viennent mes fonds propres ?',
    subtitle: 'Il te faut 20% du prix en fonds propres. Sources possibles : épargne, 3a, EPL (2e pilier, max 10% du prix). Attention : l\'EPL bloque le rachat LPP 3 ans.',
    action: 'Vérifie ton solde 3a et LPP dans MINT',
    legalRef: 'LPP art. 30c (EPL) — OPP2 art. 5 (min CHF 20\'000)',
  ),
  MortgageStep(
    number: 3,
    emoji: '📊',
    title: 'Quel type d\'hypothèque ?',
    subtitle: 'Hypothèque fixe : sécurité, taux fixe pour 2-15 ans. SARON (variable) : taux plus bas mais risque de hausse. Mix possible. Taux actuel ≠ taux théorique 5%.',
    action: 'Compare les offres de 3 banques minimum',
    legalRef: 'FINMA — Circular 2008/10 (standards hypothécaires)',
  ),
  MortgageStep(
    number: 4,
    emoji: '📉',
    title: 'Amortissement direct ou indirect ?',
    subtitle: 'Direct : tu rembourses la banque chaque année (dette baisse, déduction fiscale baisse). Indirect : tu verses dans ton 3a, puis tu rembourses en bloc. Avantage fiscal de l\'indirect.',
    action: 'Consulte un·e spécialiste fiscal pour ton canton',
    legalRef: 'LIFD art. 33 al. 1 let. a (déduction intérêts)',
  ),
  MortgageStep(
    number: 5,
    emoji: '🏠',
    title: 'Et la valeur locative ?',
    subtitle: 'Si tu occupes ton bien, tu paies l\'impôt sur la valeur locative (loyer fictif). Contre-partie : tu peux déduire les intérêts hypothécaires et les frais d\'entretien.',
    action: 'Estime ton impôt valeur locative dans MINT',
    legalRef: 'LIFD art. 21 al. 1 let. b (valeur locative)',
  ),
  MortgageStep(
    number: 6,
    emoji: '⚖️',
    title: 'Au final : louer ou acheter ?',
    subtitle: 'Décision personnelle autant que financière. Facteurs : durée de résidence prévue, stabilité professionnelle, flexibilité souhaitée. Break-even typique : 7-12 ans.',
    action: 'Lance le Bilan de match dans MINT',
    legalRef: 'CO art. 261ss (bail à loyer)',
  ),
  MortgageStep(
    number: 7,
    emoji: '📋',
    title: 'Mon plan d\'action',
    subtitle: 'Avant de signer : vérifier le règlement de co-propriété, la cote de l\'immeuble, les travaux planifiés, l\'état du fonds de rénovation. Faire relire l\'acte de vente.',
    action: 'Télécharge la checklist achat MINT',
    legalRef: 'CC art. 652 (propriété par étages)',
  ),
];

class MortgageJourneyWidget extends StatefulWidget {
  const MortgageJourneyWidget({
    super.key,
    this.currentStep = 0,
  });

  /// 0-indexed step the user is currently at (0-6).
  final int currentStep;

  @override
  State<MortgageJourneyWidget> createState() => _MortgageJourneyWidgetState();
}

class _MortgageJourneyWidgetState extends State<MortgageJourneyWidget> {
  late int _activeStep;

  @override
  void initState() {
    super.initState();
    _activeStep = widget.currentStep.clamp(0, _kSteps.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Parcours fléché achat immobilier 7 étapes hypothèque fonds propres FINMA LPP',
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStepper(),
                  const SizedBox(height: 20),
                  _buildActiveStepDetail(),
                  const SizedBox(height: 16),
                  _buildNavigation(),
                  const SizedBox(height: 16),
                  _buildDisclaimer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.primary.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🗺️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Parcours achat immobilier',
                  style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MintColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_activeStep + 1} / ${_kSteps.length}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: MintColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '7 étapes pour passer de "est-ce que je peux ?" à "j\'ai signé !".',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    return Row(
      children: List.generate(_kSteps.length, (i) {
        final isDone = i < _activeStep;
        final isActive = i == _activeStep;

        return Expanded(
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _activeStep = i),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? MintColors.primary
                        : isActive
                            ? MintColors.white
                            : MintColors.lightBorder.withValues(alpha: 0.4),
                    border: isActive
                        ? Border.all(color: MintColors.primary, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check, size: 14, color: MintColors.white)
                        : Text(
                            '${i + 1}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isActive
                                  ? MintColors.primary
                                  : MintColors.textSecondary,
                            ),
                          ),
                  ),
                ),
              ),
              if (i < _kSteps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: i < _activeStep
                        ? MintColors.primary
                        : MintColors.lightBorder.withValues(alpha: 0.4),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildActiveStepDetail() {
    final step = _kSteps[_activeStep];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Container(
        key: ValueKey(_activeStep),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintColors.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: MintColors.primary.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(step.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Étape ${step.number} · ${step.title}',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: MintColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              step.subtitle,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textPrimary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: MintColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.arrow_forward_rounded,
                      size: 14, color: MintColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      step.action,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: MintColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '📖 ${step.legalRef}',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: MintColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigation() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_activeStep > 0)
          TextButton.icon(
            onPressed: () => setState(() => _activeStep--),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Précédent'),
            style: TextButton.styleFrom(
              foregroundColor: MintColors.textSecondary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          )
        else
          const SizedBox.shrink(),
        if (_activeStep < _kSteps.length - 1)
          ElevatedButton.icon(
            onPressed: () => setState(() => _activeStep++),
            icon: const Text('Étape suivante'),
            label: const Icon(Icons.arrow_forward_rounded, size: 16),
            style: ElevatedButton.styleFrom(
              backgroundColor: MintColors.primary,
              foregroundColor: MintColors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: MintColors.scoreExcellent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '✅ Parcours complet !',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: MintColors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil financier au sens de la LSFin. '
      'Consulte un·e spécialiste hypothécaire avant toute décision. '
      'Sources : FINMA Circular 2008/10, LPP art. 30c, LIFD art. 21, CC art. 652.',
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
