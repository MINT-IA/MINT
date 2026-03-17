import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
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
  ({double partnerPct, double taxRate, String Function(S) withNote, String Function(S) withoutNote}) _calcData(FamilyStatus s) {
    return switch (s) {
      FamilyStatus.married => (
        partnerPct: 50,
        taxRate: 0,
        withNote: (S l) => l.coachTestamentMarriedWith,
        withoutNote: (S l) => l.coachTestamentMarriedWithout,
      ),
      FamilyStatus.concubin => (
        partnerPct: 0,
        taxRate: 24,
        withNote: (S l) => l.coachTestamentConcubinWith,
        withoutNote: (S l) => l.coachTestamentConcubinWithout,
      ),
      // CC reform 2022 : partenaire enregistré·e = droits équivalents au conjoint
      FamilyStatus.couple => (
        partnerPct: 50,
        taxRate: 0,
        withNote: (S l) => l.coachTestamentRegisteredWith,
        withoutNote: (S l) => l.coachTestamentRegisteredWithout,
      ),
      _ => (
        partnerPct: 0,
        taxRate: 0,
        withNote: (S l) => l.coachTestamentSingleWith,
        withoutNote: (S l) => l.coachTestamentSingleWithout,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final c = _calcData(_status);
    final partnerGets = widget.patrimoine * c.partnerPct / 100;
    final taxAmount = widget.patrimoine * c.taxRate / 100;
    final isConcubin = _status == FamilyStatus.concubin;

    return Semantics(
      label: s.coachTestamentSemantics,
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(s, isConcubin),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusSelector(s),
                  const SizedBox(height: 20),
                  _buildComparison(s, c, partnerGets, taxAmount),
                  const SizedBox(height: 16),
                  if (isConcubin) _buildChiffreChoc(s, taxAmount),
                  if (isConcubin) const SizedBox(height: 16),
                  _buildDisclaimer(s),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(S s, bool isConcubin) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: MintColors.successionBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  s.coachTestamentTitle,
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
            s.coachTestamentSubtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSelector(S s) {
    final labels = {
      FamilyStatus.married: '💍 ${s.coachTestamentMarried}',
      FamilyStatus.concubin: '🏠 ${s.coachTestamentConcubin}',
      FamilyStatus.couple: '💑 ${s.coachTestamentRegistered}',
      FamilyStatus.single: '👤 ${s.coachTestamentSingle}',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.coachTestamentSituation,
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
                  color: isSelected ? MintColors.primary : MintColors.white,
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
                    color: isSelected ? MintColors.white : MintColors.textPrimary,
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
    S s,
    ({double partnerPct, double taxRate, String Function(S) withNote, String Function(S) withoutNote}) c,
    double partnerGets,
    double taxAmount,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.coachTestamentPatrimoine(formatChfWithPrefix(widget.patrimoine)),
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
              label: s.coachTestamentWithout,
              emoji: '❌',
              partnerGets: partnerGets,
              taxAmount: taxAmount,
              note: c.withoutNote(s),
              color: MintColors.scoreCritique,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildScenarioCard(
              label: s.coachTestamentWith,
              emoji: '✅',
              partnerGets: partnerGets > 0 ? partnerGets : widget.patrimoine * 0.5,
              taxAmount: taxAmount,
              note: c.withNote(s),
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
            S.of(context)!.coachTestamentPartnerReceives,
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

  Widget _buildChiffreChoc(S s, double taxAmount) {
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
            '💰 ${s.coachTestamentChiffreChocTitle}',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MintColors.scoreCritique,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            s.coachTestamentChiffreChocBody(formatChfWithPrefix(taxAmount)),
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

  Widget _buildDisclaimer(S s) {
    return Text(
      s.coachTestamentDisclaimer,
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
