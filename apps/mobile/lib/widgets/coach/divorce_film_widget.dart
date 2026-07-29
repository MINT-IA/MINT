import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  P2-B  Le Film du divorce en 3 actes
//  Charte : L2 (Avant/Après) + L4 (Raconte)
//  Source : CC art. 122 (partage LPP), LIFD art. 33/23 (pensions),
//           LIFD art. 33 al. 3 (frais de garde par un tiers)
// ────────────────────────────────────────────────────────────

class DivorceFilmWidget extends StatelessWidget {
  const DivorceFilmWidget({
    super.key,
    required this.myLpp,
    required this.partnerLpp,
    required this.lppTransfer,
    required this.lppTransferDirection,
    required this.annualTaxMarried,
    required this.annualTaxSingle,
    required this.childrenCount,
  });

  final double myLpp;
  final double partnerLpp;

  /// Transfert LPP RÉEL du service (part acquise pendant le mariage, CC art. 122
  /// / LFLP art. 22a) — la valeur affichée sur la carte Partage LPP / le hero.
  /// Le film ne recalcule JAMAIS un partage du solde total.
  final double lppTransfer;

  /// Sens du transfert : '1 → 2' (conjoint 1 = toi verses), '2 → 1' (tu reçois)
  /// ou '-' (aucun transfert).
  final String lppTransferDirection;

  final double annualTaxMarried;
  final double annualTaxSingle;
  final int childrenCount;

  static String _fmt(double v) {
    final n = v.round().abs();
    if (n >= 1000) {
      final t = n ~/ 1000;
      final r = n % 1000;
      return r == 0 ? "$t'000" : "$t'${r.toString().padLeft(3, '0')}";
    }
    return '$n';
  }

  /// Solde LPP de l'utilisateur APRÈS le transfert réel : '1 → 2' = tu verses
  /// (soustrait), sinon tu reçois ou rien (ajoute 0). Jamais un partage du solde
  /// total : on applique le transfert RÉEL du service au solde de départ.
  double get _myLppAfter => (lppTransferDirection == '1 → 2'
          ? myLpp - lppTransfer
          : myLpp + lppTransfer)
      .clamp(0, double.infinity);

  // LPP rente loss using taux de conversion minimum (LPP art. 14), sur le

  double get _annualTaxDelta => annualTaxSingle - annualTaxMarried;
  double get _monthlyTaxDelta => _annualTaxDelta / 12;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Film du divorce LPP partage impôts pensions actes CC LIFD',
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
                  _buildAct(
                    number: 'Acte 1',
                    emoji: '⚖️',
                    title: 'Le partage obligatoire',
                    color: MintColors.scoreCritique,
                    content: _buildAct1Content(),
                    legalRef: 'CC art. 122 — règle par défaut',
                  ),
                  const SizedBox(height: 12),
                  _buildAct(
                    number: 'Acte 2',
                    emoji: '📊',
                    title: 'L\'impôt change',
                    color: MintColors.scoreAttention,
                    content: _buildAct2Content(),
                    legalRef: 'LIFD art. 33 al. 3 (frais de garde)',
                  ),
                  const SizedBox(height: 12),
                  _buildAct(
                    number: 'Acte 3',
                    emoji: '👧',
                    title: 'Les pensions alimentaires',
                    color: MintColors.info,
                    content: _buildAct3Content(context),
                    legalRef: 'LIFD art. 33 (déductible) / art. 23 (imposable bénéficiaire)',
                  ),
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
        color: MintColors.scoreCritique.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎬', style: TextStyle(fontSize: 22)), // lint-ignore: prefer_mint_text_style — emoji décoratif, pas du texte
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Le film du divorce en 3 actes',
                  style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 17, fontWeight: FontWeight.w800), // lint-ignore: prefer_mint_text_style — pré-existant, hors périmètre gate-dur
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Dans l\'ordre chronologique de ce que tu vas vivre — chiffres réels, pas de tabous.',
            style: MintTextStyles.labelMedium(color: MintColors.textSecondary).copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildAct({
    required String number,
    required String emoji,
    required String title,
    required Color color,
    required Widget content,
    required String legalRef,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    number,
                    style: MintTextStyles.micro(color: MintColors.white).copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                Text(emoji, style: const TextStyle(fontSize: 18)), // lint-ignore: prefer_mint_text_style — emoji décoratif, pas du texte
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                content,
                const SizedBox(height: 8),
                Text(
                  legalRef,
                  style: MintTextStyles.micro(color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAct1Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '"Par défaut, la prévoyance accumulée pendant le mariage se partage par moitié — le juge peut s\'en écarter, et une renonciation reste possible si la prévoyance de chacun reste suffisante (CC art. 124b)."',
          style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontStyle: FontStyle.italic, height: 1.4),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildLppCard('Toi', myLpp, MintColors.scoreCritique)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward, size: 20, color: MintColors.textSecondary),
            ),
            Expanded(child: _buildLppCard('Toi (après)', _myLppAfter, MintColors.scoreAttention)),
          ],
        ),
        if (lppTransfer > 0) ...[
          const SizedBox(height: 10),
          Builder(builder: (context) {
            // Le sens du transfert vient du service (CC art. 122). '1 → 2' = TOI
            // (conjoint 1) verses à l'ex → ta rente baisse ; '2 → 1' = tu reçois
            // → ta rente augmente. Le montant est le même dans les deux sens ; la
            // phrase ne doit jamais dire « tu transfères » quand tu reçois.
            final userPays = lppTransferDirection == '1 → 2';
            final tone =
                userPays ? MintColors.scoreCritique : MintColors.scoreExcellent;
            // Pas de CHF/mois : le taux de conversion s'applique au capital À LA
            // RETRAITE, pas au transfert d'aujourd'hui. Chiffrer la rente ici
            // supposerait connus les années restantes, les intérêts et le taux
            // de ta caisse au moment venu. On énonce le MÉCANISME à la place.
            final message = userPays
                ? 'Tu transfères CHF ${_fmt(lppTransfer)}. Ce capital ne travaillera plus pour toi : il sortira de ton avoir, avec les intérêts qu\'il aurait produits jusqu\'à la retraite. C\'est le capital atteint À CE MOMENT-LÀ qui sera converti en rente, au taux de ta caisse.'
                : 'Tu reçois CHF ${_fmt(lppTransfer)}. Ce capital rejoint ton avoir et produira des intérêts jusqu\'à la retraite. C\'est le capital atteint À CE MOMENT-LÀ qui sera converti en rente, au taux de ta caisse.';
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                message,
                style: MintTextStyles.labelMedium(color: tone)
                    .copyWith(fontWeight: FontWeight.w700, height: 1.4),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildLppCard(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(label, style: MintTextStyles.labelSmall(color: MintColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            'CHF ${_fmt(amount)}',
            style: MintTextStyles.bodyMedium(color: color).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildAct2Content() {
    final positive = _annualTaxDelta > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // LSFin : marié vs séparé est une COMPARAISON informative, pas un verdict.
            // À deux revenus, « séparé » est souvent moins cher (Heiratsstrafe) —
            // colorer marié en vert « succès » et séparé en rouge « danger » cadrerait
            // le mariage comme toujours meilleur (steering). Ton neutre des deux côtés ;
            // le sens de l'écart est porté, neutre, par le bandeau ci-dessous.
            Expanded(child: _buildTaxCard('Couple marié', annualTaxMarried, MintColors.info)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward, size: 20, color: MintColors.textSecondary),
            ),
            Expanded(child: _buildTaxCard('2 foyers séparés', annualTaxSingle, MintColors.info)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          // LSFin : ce delta est une info éducative. Une BAISSE d'impôt (delta ≤ 0,
          // fréquente à deux revenus) ne doit pas être cadrée en vert « succès »
          // (« le divorce fait gagner ») → ton informatif neutre (info) ; une
          // hausse garde le ton attention (scoreCritique = surcoût réel).
          decoration: BoxDecoration(
            color: (positive ? MintColors.scoreCritique : MintColors.info)
                .withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            // annualTaxSingle = impôt des DEUX ex-conjoints séparés (C1 + C2) ;
            // le delta est donc le changement au niveau du MÉNAGE, pas l'impôt
            // personnel de l'utilisateur. On ne dit jamais « tu perds » (la
            // répartition individuelle dépend du revenu de chacun).
            positive
                ? '+CHF ${_fmt(_monthlyTaxDelta)}/mois d\'impôts pour le ménage — la fin du splitting marié.'
                : '-CHF ${_fmt(_monthlyTaxDelta.abs())}/mois d\'impôts pour le ménage après la séparation.',
            style: MintTextStyles.labelMedium(color: positive ? MintColors.scoreCritique : MintColors.info).copyWith(fontWeight: FontWeight.w700, height: 1.4),
          ),
        ),
        if (childrenCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            // Seul le NOMBRE d'enfants est confirmé — pas la garde ni des frais
            // de garde réels. On énonce la condition (« si »), jamais un « tu peux
            // déduire » qui présumerait la garde et l'éligibilité (LIFD art. 33 al. 3).
            child: Text(
              '💡 Les frais de garde par un tiers peuvent être déduits (LIFD art. 33 al. 3), sous conditions : des frais justifiés, un enfant en dessous de l\'âge limite, et un lien direct avec ton activité, ta formation ou une incapacité. La garde seule ne suffit pas.',
              style: MintTextStyles.labelSmall(color: MintColors.info).copyWith(height: 1.4),
            ),
          ),
      ],
    );
  }

  Widget _buildTaxCard(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(label, style: MintTextStyles.labelSmall(color: MintColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            'CHF ${_fmt(amount)}/an',
            style: MintTextStyles.bodySmall(color: color).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildAct3Content(BuildContext context) {
    // AUCUN montant d'entretien ici. Ni forfait par enfant, ni écart de revenus :
    // le montant d'une contribution d'entretien ne se déduit pas des revenus et
    // du nombre d'enfants (revenus disponibles nets, minimum vital, logement,
    // assurance maladie, frais de garde et de formation, taux de garde, train de
    // vie, capacité de gain, clean-break, fiscalité et allocations familiales).
    // Le film énonce donc la même chose que la carte de l'écran : pas de chiffre,
    // la règle fiscale générale, et le renvoi au calcul d'un·e spécialiste.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.divorcePensionNoEstimate,
          style: MintTextStyles.bodySmall(color: MintColors.textPrimary)
              .copyWith(height: 1.4),
        ),
        const SizedBox(height: 8),
        Text(
          S.of(context)!.divorcePensionSpecialiste,
          style: MintTextStyles.labelSmall(color: MintColors.textSecondary)
              .copyWith(height: 1.4),
        ),
        const SizedBox(height: 8),
        // Le service ne fournit PAS le sens du versement (montant non signé =
        // écart de revenus + enfants ; la direction du volet enfants dépend de la
        // garde, non captée). On énonce donc la règle fiscale GÉNÉRALE (vraie dans
        // les deux sens), jamais un « déductible de TES impôts » qui serait faux
        // quand c'est toi qui la reçois (LIFD art. 33/23).
        Text(
          '⚠️ La contribution est déductible du revenu de la personne qui la verse et imposable pour celle qui la reçoit — sauf pour un enfant MAJEUR : là, elle n\'est ni déductible ni imposable (LIFD art. 33).',
          style: MintTextStyles.labelSmall(color: MintColors.scoreAttention).copyWith(height: 1.4),
        ),
      ],
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil juridique au sens de la LSFin. '
      'Sources : CC art. 122 et 124b (partage LPP), CC art. 125 et 276/285 (contributions d\'entretien), LIFD art. 33 al. 1 let. c et art. 23 let. f (traitement fiscal des contributions), LIFD art. 33 al. 3 (frais de garde).',
      style: MintTextStyles.micro(color: MintColors.textSecondary),
    );
  }
}
