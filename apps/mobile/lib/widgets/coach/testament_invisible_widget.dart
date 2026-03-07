import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  P8-A  Le Testament invisible — sans vs avec testament
//  Charte : L6 (Chiffre-choc) + L7 (Métaphore testament)
//  Source : CC art. 457-462, OPP3 art. 2
// ────────────────────────────────────────────────────────────

enum FamilyStatus { single, couple, married, concubin }

class TestamentInvisibleWidget extends StatefulWidget {
  const TestamentInvisibleWidget({
    super.key,
    required this.patrimoine,
    this.initialStatus = FamilyStatus.concubin,
  });

  final double patrimoine;
  final FamilyStatus initialStatus;

  @override
  State<TestamentInvisibleWidget> createState() => _TestamentInvisibleWidgetState();
}

class _TestamentInvisibleWidgetState extends State<TestamentInvisibleWidget> {
  late FamilyStatus _status;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
  }

  // Returns (partnerShare%, inheritanceTaxRate%, withTestamentNote)
  ({double partnerPct, double taxRate, String withNote, String withoutNote}) _calc(FamilyStatus s) {
    return switch (s) {
      FamilyStatus.married => (
        partnerPct: 50,
        taxRate: 0,
        withNote: 'Conjoint hérite de 50%+. Impôt = 0%.',
        withoutNote: 'Conjoint hérite selon CC. Impôt = 0%.',
      ),
      FamilyStatus.concubin => (
        partnerPct: 0,
        taxRate: 24,
        withNote: 'Clause bénéficiaire 3a + testament indispensables.',
        withoutNote: 'Ton partenaire hérite 0%. L\'État ou tes parents touchent tout.',
      ),
      // CC reform 2022 : partenaire enregistré·e = droits équivalents au conjoint
      FamilyStatus.couple => (
        partnerPct: 50,
        taxRate: 0,
        withNote: 'Droits héréditaires équivalents au conjoint depuis 2022 (CC art. 462).',
        withoutNote: 'Partenaire enregistré·e hérite selon CC art. 462 — même droits que conjoint. Impôt = 0%.',
      ),
      _ => (
        partnerPct: 0,
        taxRate: 0,
        withNote: 'Libre de léguer à qui tu veux.',
        withoutNote: 'La loi distribue selon CC art. 457-462.',
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = _calc(_status);
    final partnerGets = widget.patrimoine * c.partnerPct / 100;
    final taxAmount = widget.patrimoine * c.taxRate / 100;
    final isConcubin = _status == FamilyStatus.concubin;

    return Semantics(
      label: 'Testament invisible distribution succession',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isConcubin),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusSelector(),
                  const SizedBox(height: 20),
                  _buildComparison(c, partnerGets, taxAmount),
                  const SizedBox(height: 16),
                  if (isConcubin) _buildChiffreChoc(taxAmount),
                  if (isConcubin) const SizedBox(height: 16),
                  _buildDisclaimer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isConcubin) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📜', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Si tu mourais ce soir…',
                  style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Distribution légale automatique vs avec testament · CC art. 457-462',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSelector() {
    final labels = {
      FamilyStatus.married: '💍 Marié·e',
      FamilyStatus.concubin: '🏠 Concubin·e',
      FamilyStatus.couple: '💑 Partenaire enregistré·e',
      FamilyStatus.single: '👤 Célibataire',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ta situation',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: labels.entries.map((e) {
            final isSelected = _status == e.key;
            return GestureDetector(
              onTap: () => setState(() => _status = e.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? MintColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? MintColors.primary : MintColors.lightBorder,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Text(
                  e.value,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : MintColors.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildComparison(
    ({double partnerPct, double taxRate, String withNote, String withoutNote}) c,
    double partnerGets,
    double taxAmount,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Patrimoine : ${formatChfWithPrefix(widget.patrimoine)}',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildScenarioCard(
              label: 'Sans testament',
              emoji: '❌',
              partnerGets: partnerGets,
              taxAmount: taxAmount,
              note: c.withoutNote,
              color: MintColors.scoreCritique,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildScenarioCard(
              label: 'Avec testament',
              emoji: '✅',
              partnerGets: partnerGets > 0 ? partnerGets : widget.patrimoine * 0.5,
              taxAmount: taxAmount,
              note: c.withNote,
              color: MintColors.scoreExcellent,
              isOptimized: true,
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildScenarioCard({
    required String label,
    required String emoji,
    required double partnerGets,
    required double taxAmount,
    required String note,
    required Color color,
    bool isOptimized = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3), width: isOptimized ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$emoji $label',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Partenaire reçoit',
            style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary),
          ),
          Text(
            isOptimized ? formatChfWithPrefix(partnerGets) : (partnerGets > 0 ? formatChfWithPrefix(partnerGets) : '0 CHF'),
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            note,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChiffreChoc(double taxAmount) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.scoreCritique.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.scoreCritique.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💰 Concubin·e : 0% d\'héritage + impôt jusqu\'à 24%',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MintColors.scoreCritique,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sans testament ni clause 3a, ton partenaire ne reçoit rien. '
            'Un testament coûte ~500 CHF. Le silence peut coûter ${formatChfWithPrefix(taxAmount)} d\'impôts.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil financier au sens de la LSFin. '
      'Source : CC art. 457-462, OPP3 art. 2.',
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
