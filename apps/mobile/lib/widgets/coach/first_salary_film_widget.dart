import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  P5-A  Le Film du premier salaire — 5 actes
//  Charte : L1 (CHF/mois) + L2 (Avant/Après) + L4 (Raconte) + L7 (Film)
//  Source : LAVS art. 3 (AVS 5.30%), LPP art. 7, LACI art. 3 (AC 1.10%),
//           OPP3 art. 7 (3a plafond 7'258 CHF)
// ────────────────────────────────────────────────────────────

class FirstSalaryFilmWidget extends StatefulWidget {
  const FirstSalaryFilmWidget({
    super.key,
    required this.grossMonthly,
  });

  final double grossMonthly;

  @override
  State<FirstSalaryFilmWidget> createState() => _FirstSalaryFilmWidgetState();
}

class _FirstSalaryFilmWidgetState extends State<FirstSalaryFilmWidget> {
  int _currentAct = 0;

  static String _fmt(double v) {
    final n = v.round().abs();
    if (n >= 1000) {
      final t = n ~/ 1000;
      final r = n % 1000;
      return r == 0 ? "$t'000" : "$t'${r.toString().padLeft(3, '0')}";
    }
    return '$n';
  }

  // Act 1 — Douche froide: brut → net
  double get _avsEmployee => widget.grossMonthly * avsCotisationSalarie;  // LAVS art. 3
  double get _lppEmployee => widget.grossMonthly * 0.035;       // LPP (avg age 25)
  double get _ac => widget.grossMonthly * acCotisationSalarie;  // LACI art. 3
  double get _aanp => widget.grossMonthly * 0.013;              // LAA
  double get _totalDeductions => _avsEmployee + _lppEmployee + _ac + _aanp;
  double get _netMonthly => widget.grossMonthly - _totalDeductions;

  // Act 2 — Argent invisible: employeur
  double get _avsEmployer => widget.grossMonthly * 0.053;
  double get _lppEmployer => widget.grossMonthly * 0.035;
  double get _ijmEmployer => widget.grossMonthly * 0.006;
  double get _totalEmployerCost => widget.grossMonthly + _avsEmployer + _lppEmployer + _ijmEmployer;

  // Act 3 — Cadeau fiscal 3a
  static const double _monthly3a = pilier3aPlafondAvecLpp / 12;  // OPP3 art. 7
  static const double _return3a = 0.04;            // 4% annuel
  double _project3a(int years) {
    double acc = 0;
    for (int y = 0; y < years; y++) {
      acc = (acc + _monthly3a * 12) * (1 + _return3a);
    }
    return acc;
  }

  @override
  Widget build(BuildContext context) {
    final acts = [
      _buildAct1(),
      _buildAct2(),
      _buildAct3(),
      _buildAct4(),
      _buildAct5(),
    ];

    return Semantics(
      label: 'Film premier salaire 5 actes AVS LPP 3a LAMal douche froide',
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
            _buildActSelector(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  acts[_currentAct],
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
        color: MintColors.scoreExcellent.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎬', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Le film de ton premier salaire',
                  style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'CHF ${_fmt(widget.grossMonthly)} brut — 5 actes pour tout comprendre.',
            style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildActSelector() {
    final actLabels = ['1 · Brut→Net', '2 · Invisible', '3 · 3a', '4 · LAMal', '5 · Action'];

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: const BoxDecoration(
        color: MintColors.appleSurface,
        border: Border(bottom: BorderSide(color: MintColors.lightBorder)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actLabels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final selected = _currentAct == i;
          return GestureDetector(
            onTap: () => setState(() => _currentAct = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? MintColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? MintColors.primary : MintColors.lightBorder,
                ),
              ),
              child: Text(
                actLabels[i],
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? MintColors.white : MintColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAct1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'La douche froide',
          style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w800, color: MintColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          '"${_fmt(_totalDeductions)} CHF disparaissent. Mais ce n\'est pas perdu — c\'est ton futur."',
          style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary, height: 1.4, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 16),
        _buildSalaryBar(),
        const SizedBox(height: 16),
        _buildDeductionRows(),
      ],
    );
  }

  Widget _buildSalaryBar() {
    final netRatio = _netMonthly / widget.grossMonthly;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Brut : CHF ${_fmt(widget.grossMonthly)}', style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary)),
            Text('Net : CHF ${_fmt(_netMonthly)}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: MintColors.scoreExcellent)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Container(height: 28, color: MintColors.scoreCritique.withValues(alpha: 0.2)),
              FractionallySizedBox(
                widthFactor: netRatio,
                child: Container(
                  height: 28,
                  color: MintColors.scoreExcellent,
                  alignment: Alignment.center,
                  child: Text(
                    '${(netRatio * 100).round()}% net',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: MintColors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeductionRows() {
    final rows = [
      ('AVS/AI/APG 5.30%', _avsEmployee, 'LAVS art. 3'),
      ('LPP ~3.5%', _lppEmployee, 'LPP art. 7'),
      ('AC 1.10%', _ac, 'LACI art. 3'),
      ('AANP 1.30%', _aanp, 'LAA art. 6'),
    ];
    return Column(
      children: rows.map((r) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(r.$1, style: GoogleFonts.inter(fontSize: 12, color: MintColors.textPrimary))),
            Text('− CHF ${_fmt(r.$2)}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: MintColors.scoreCritique)),
            const SizedBox(width: 8),
            Text(r.$3, style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildAct2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'L\'argent invisible',
          style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w800, color: MintColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          '"Ton vrai salaire est CHF ${_fmt(_totalEmployerCost)}. Ton employeur paie bien plus que tu ne crois."',
          style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary, height: 1.4, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 16),
        _buildIcebergCards(),
      ],
    );
  }

  Widget _buildIcebergCards() {
    return Column(
      children: [
        _buildCostCard('🌊 Visible : ton salaire net', _netMonthly, MintColors.scoreExcellent, 'Ce que tu touches'),
        const SizedBox(height: 6),
        _buildCostCard('💧 Tes cotisations', _totalDeductions, MintColors.scoreAttention, 'Déduits de ton brut'),
        const SizedBox(height: 6),
        _buildCostCard('🏔️ Cotisations employeur', _avsEmployer + _lppEmployer + _ijmEmployer, MintColors.info, 'Invisibles sur ta fiche'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: MintColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Coût total employeur', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: MintColors.textPrimary)),
              Text(
                'CHF ${_fmt(_totalEmployerCost)}/mois',
                style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w800, color: MintColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCostCard(String label, double amount, Color color, String sub) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: MintColors.textPrimary)),
                Text(sub, style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary)),
              ],
            ),
          ),
          Text(
            'CHF ${_fmt(amount)}',
            style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildAct3() {
    final at30 = _project3a(5);   // 25+5 = 30 ans
    final at40 = _project3a(15);  // 25+15 = 40 ans
    final at65 = _project3a(40);  // 25+40 = 65 ans

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Le cadeau fiscal 3a',
          style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w800, color: MintColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          '"CHF ${_fmt(_monthly3a)}/mois → potentiellement millionnaire. Commence maintenant."',
          style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary, height: 1.4, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 16),
        _buildProjectionBar('À 30 ans', at30, at65),
        const SizedBox(height: 8),
        _buildProjectionBar('À 40 ans', at40, at65),
        const SizedBox(height: 8),
        _buildProjectionBar('À 65 ans', at65, at65),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MintColors.scoreExcellent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '💰 Plafond 2026 : CHF 7\'258/an · Déduction fiscale directe · OPP3 art. 7',
            style: GoogleFonts.inter(fontSize: 11, color: MintColors.scoreExcellent, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectionBar(String label, double value, double max) {
    final ratio = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary)),
            Text('CHF ${_fmt(value)}', style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w800, color: MintColors.primary)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: MintColors.primary.withValues(alpha: 0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(MintColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildAct4() {
    final franchises = [
      (label: 'CHF 300/an', monthly: 25.0, advice: 'Conseillé si maladies chroniques'),
      (label: 'CHF 1\'500/an', monthly: 125.0, advice: 'Bon compromis · Recommandé'),
      (label: 'CHF 2\'500/an', monthly: 208.0, advice: 'Économise la prime · Si tu es en bonne santé'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Le piège LAMal',
          style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w800, color: MintColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          '"La franchise pas chère peut te coûter cher si tu tombes malade."',
          style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary, height: 1.4, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 16),
        ...franchises.map((f) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: f.label.contains('500/an') && !f.label.contains('2')
                  ? MintColors.scoreExcellent.withValues(alpha: 0.07)
                  : MintColors.appleSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: f.label.contains('500/an') && !f.label.contains('2')
                    ? MintColors.scoreExcellent.withValues(alpha: 0.3)
                    : MintColors.lightBorder,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Franchise ${f.label}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: MintColors.textPrimary)),
                      Text(f.advice, style: GoogleFonts.inter(fontSize: 11, color: MintColors.textSecondary)),
                    ],
                  ),
                ),
                Text(
                  '−CHF ${_fmt(f.monthly)}/mois prime',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: MintColors.primary),
                ),
              ],
            ),
          ),
        )),
        const SizedBox(height: 4),
        Text(
          '💡 LAMal art. 64 — Franchise annuelle choisie, renouvelable chaque année.',
          style: GoogleFonts.inter(fontSize: 11, color: MintColors.info, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildAct5() {
    final checklist = [
      (week: 'Semaine 1', emoji: '🏦', task: 'Ouvrir un compte 3a (banque ou fintech)'),
      (week: 'Semaine 1', emoji: '⚙️', task: 'Mettre en place un virement automatique mensuel'),
      (week: 'Semaine 2', emoji: '🏥', task: 'Choisir ta franchise LAMal (recommandé : CHF 1\'500)'),
      (week: 'Semaine 2', emoji: '🛡️', task: 'Vérifier ta RC privée (env. CHF 100/an)'),
      (week: 'Avant 31.12', emoji: '💰', task: 'Verser le maximum 3a avant le 31 décembre'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ta checklist de démarrage',
          style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w800, color: MintColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          '"5 actions. C\'est tout. Commence cette semaine."',
          style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary, height: 1.4, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 16),
        ...checklist.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MintColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.week,
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: MintColors.primary),
                ),
              ),
              const SizedBox(width: 8),
              Text(item.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.task,
                  style: GoogleFonts.inter(fontSize: 12, color: MintColors.textPrimary, height: 1.4),
                ),
              ),
            ],
          ),
        )),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MintColors.scoreExcellent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Premier pas financier', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w800, color: MintColors.scoreExcellent)),
                    Text('Tu sais maintenant ce que 90% des gens ne savent jamais.', style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil financier au sens de la LSFin. '
      'Source : LAVS art. 3, LPP art. 7, LACI art. 3, OPP3 art. 7 (3a 7\'258 CHF/an). '
      'Taux cotisations indicatifs 2026. Projection 3a : rendement hypothétique 4%/an.',
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
