import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/housing_sale_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/simulators/simulator_card.dart';
import 'package:mint_mobile/widgets/coach/remploi_countdown_widget.dart';
import 'package:mint_mobile/widgets/coach/sale_surprises_widget.dart';
import 'package:mint_mobile/widgets/coach/net_proceeds_widget.dart';

/// Swiss CHF formatter with apostrophe grouping.
String _formatChfSwiss(double value) {
  final intVal = value.round();
  final isNeg = intVal < 0;
  final str = intVal.abs().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) {
      buffer.write("'");
    }
    buffer.write(str[i]);
  }
  return '${isNeg ? '-' : ''}${buffer.toString()}';
}

/// Swiss CHF formatter with prefix.
String _chfFmt(double value) {
  return 'CHF\u00A0${_formatChfSwiss(value)}';
}

/// Screen for simulating the financial impact of a property sale in Switzerland.
///
/// Covers capital gains tax, EPL repayment, remploi, and net proceeds.
/// Sprint S24 — Life Event: housingSale.
class HousingSaleScreen extends StatefulWidget {
  const HousingSaleScreen({super.key});

  @override
  State<HousingSaleScreen> createState() => _HousingSaleScreenState();
}

class _HousingSaleScreenState extends State<HousingSaleScreen> {
  final _scrollController = ScrollController();
  final _resultsKey = GlobalKey();

  // ── Input state ──
  double _prixAchat = 800000;
  double _prixVente = 1000000;
  int _anneeAchat = 2015;
  double _investissementsValorisants = 50000;
  double _fraisAcquisition = 30000;
  double _hypothequeRestante = 600000;
  String _canton = 'VD';
  bool _residencePrincipale = true;
  bool _projetRemploi = false;
  double _prixRemploi = 900000;
  double _eplLppUtilise = 0;
  double _epl3aUtilise = 0;

  // Result
  HousingSaleResult? _result;

  // Checklist state
  List<bool> _checklistState = [];

  static List<String> get _cantons => sortedCantonCodes;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _simulate() {
    setState(() {
      _result = HousingSaleService.calculate(
        prixAchat: _prixAchat,
        prixVente: _prixVente,
        anneeAchat: _anneeAchat,
        anneeVente: 2025,
        investissementsValorisants: _investissementsValorisants,
        fraisAcquisition: _fraisAcquisition,
        canton: _canton,
        residencePrincipale: _residencePrincipale,
        eplLppUtilise: _eplLppUtilise,
        epl3aUtilise: _epl3aUtilise,
        hypothequeRestante: _hypothequeRestante,
        projetRemploi: _projetRemploi,
        prixRemploi: _prixRemploi,
      );
      _checklistState = List.filled(_result!.checklist.length, false);
    });

    // Smooth scroll to results
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_resultsKey.currentContext != null) {
        Scrollable.ensureVisible(
          _resultsKey.currentContext!,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        title: Text(S.of(context)!.housingSaleAppBarTitle),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildIntroCard(),
            const SizedBox(height: 24),
            _buildBienSection(),
            const SizedBox(height: 12),
            _buildFinancementSection(),
            const SizedBox(height: 12),
            _buildEplSection(),
            const SizedBox(height: 12),
            _buildRemploiSection(),
            const SizedBox(height: 24),
            _buildSimulateButton(),
            const SizedBox(height: 24),
            if (_result != null) ...[
              Container(key: _resultsKey),
              _buildPlusValueCard(),
              const SizedBox(height: 24),
              _buildTaxCard(),
              const SizedBox(height: 24),
              if (_result!.remploiReport > 0) ...[
                _buildRemploiResultCard(),
                const SizedBox(height: 24),
              ],
              if (_result!.remboursementEplLpp > 0 ||
                  _result!.remboursementEpl3a > 0) ...[
                _buildEplRepaymentCard(),
                const SizedBox(height: 24),
              ],
              _buildProduitNetCard(),
              const SizedBox(height: 24),
              if (_result!.alerts.isNotEmpty) ...[
                _buildAlertsSection(),
                const SizedBox(height: 24),
              ],
              _buildChecklistSection(),
              const SizedBox(height: 24),
            ],
            _buildEducationalFooter(),
            const SizedBox(height: 24),
            // ── P15-A : Les 3 surprises de la vente ──────────
            SaleSurprisesWidget(
              salePrice: _prixVente,
              purchasePrice: _prixAchat,
              eplWithdrawn: _eplLppUtilise + _epl3aUtilise,
              holdingYears: 2025 - _anneeAchat,
              canton: _canton,
            ),
            const SizedBox(height: 24),
            // ── P15-B : Net réel calculateur ─────────────────────
            if (_result != null) ...[
              NetProceedsWidget(
                salePrice: _prixVente,
                mortgageBalance: _hypothequeRestante,
                capitalGainTax: _result!.impotEffectif,
                eplReimbursement:
                    _result!.remboursementEplLpp + _result!.remboursementEpl3a,
              ),
              const SizedBox(height: 24),
            ],

            // ── P15-C : Chrono du remploi ─────────────────────
            if (_residencePrincipale) ...[
              RemploiCountdownWidget(
                saleDate: DateTime(2025, 1, 1),
                deferredTax: (_prixVente - _prixAchat - _investissementsValorisants)
                        .clamp(0, double.infinity) *
                    0.20,
              ),
              const SizedBox(height: 24),
            ],
            _buildDisclaimer(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Header ──
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: MintColors.warningText.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.house_outlined,
                color: MintColors.warningText, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.housingSaleHeaderTitle,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  S.of(context)!.housingSaleHeaderSubtitle,
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

  // ── Intro Card ──
  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.warningText.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MintColors.warningText.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline,
              size: 20, color: MintColors.warningText.withValues(alpha: 0.8)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.of(context)!.housingSaleIntroText,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section: Bien immobilier ──
  Widget _buildBienSection() {
    return SimulatorCard(
      title: S.of(context)!.housingSaleBienTitle,
      subtitle: S.of(context)!.housingSaleBienSubtitle,
      icon: Icons.home_work_outlined,
      accentColor: MintColors.warningText,
      child: Column(
        children: [
          _buildSlider(
            label: S.of(context)!.housingSalePrixAchat,
            value: _prixAchat,
            min: 100000,
            max: 3000000,
            divisions: 58,
            format: (v) => _chfFmt(v),
            onChanged: (v) => setState(() => _prixAchat = v),
          ),
          const SizedBox(height: 16),
          _buildSlider(
            label: S.of(context)!.housingSalePrixVente,
            value: _prixVente,
            min: 100000,
            max: 3000000,
            divisions: 58,
            format: (v) => _chfFmt(v),
            onChanged: (v) => setState(() => _prixVente = v),
          ),
          const SizedBox(height: 16),
          _buildSlider(
            label: S.of(context)!.housingSaleAnneeAchat,
            value: _anneeAchat.toDouble(),
            min: 1980,
            max: 2025,
            divisions: 45,
            format: (v) => '${v.toInt()}',
            onChanged: (v) => setState(() => _anneeAchat = v.toInt()),
          ),
          const SizedBox(height: 16),
          _buildSlider(
            label: S.of(context)!.housingSaleInvestissements,
            value: _investissementsValorisants,
            min: 0,
            max: 500000,
            divisions: 100,
            format: (v) => _chfFmt(v),
            onChanged: (v) =>
                setState(() => _investissementsValorisants = v),
          ),
          const SizedBox(height: 16),
          _buildSlider(
            label: S.of(context)!.housingSaleFraisAcquisition,
            value: _fraisAcquisition,
            min: 0,
            max: 100000,
            divisions: 100,
            format: (v) => _chfFmt(v),
            onChanged: (v) => setState(() => _fraisAcquisition = v),
          ),
          const SizedBox(height: 16),
          _buildCantonDropdown(),
          const SizedBox(height: 16),
          _buildSwitch(
            label: S.of(context)!.housingSaleResidencePrincipale,
            value: _residencePrincipale,
            onChanged: (v) => setState(() => _residencePrincipale = v),
          ),
        ],
      ),
    );
  }

  // ── Section: Financement ──
  Widget _buildFinancementSection() {
    return SimulatorCard(
      title: S.of(context)!.housingSaleFinancementTitle,
      subtitle: S.of(context)!.housingSaleFinancementSubtitle,
      icon: Icons.account_balance_outlined,
      accentColor: MintColors.warningText,
      child: Column(
        children: [
          _buildSlider(
            label: S.of(context)!.housingSaleHypotheque,
            value: _hypothequeRestante,
            min: 0,
            max: 2000000,
            divisions: 200,
            format: (v) => _chfFmt(v),
            onChanged: (v) => setState(() => _hypothequeRestante = v),
          ),
        ],
      ),
    );
  }

  // ── Section: EPL ──
  Widget _buildEplSection() {
    return SimulatorCard(
      title: S.of(context)!.housingSaleEplTitle,
      subtitle: S.of(context)!.housingSaleEplSubtitle,
      icon: Icons.savings_outlined,
      accentColor: MintColors.warningText,
      child: Column(
        children: [
          _buildSlider(
            label: S.of(context)!.housingSaleEplLpp,
            value: _eplLppUtilise,
            min: 0,
            max: 500000,
            divisions: 100,
            format: (v) => _chfFmt(v),
            onChanged: (v) => setState(() => _eplLppUtilise = v),
          ),
          const SizedBox(height: 16),
          _buildSlider(
            label: S.of(context)!.housingSaleEpl3a,
            value: _epl3aUtilise,
            min: 0,
            max: 200000,
            divisions: 40,
            format: (v) => _chfFmt(v),
            onChanged: (v) => setState(() => _epl3aUtilise = v),
          ),
        ],
      ),
    );
  }

  // ── Section: Remploi ──
  Widget _buildRemploiSection() {
    return SimulatorCard(
      title: S.of(context)!.housingSaleRemploiTitle,
      subtitle: S.of(context)!.housingSaleRemploiSubtitle,
      icon: Icons.swap_horiz,
      accentColor: MintColors.warningText,
      child: Column(
        children: [
          _buildSwitch(
            label: S.of(context)!.housingSaleProjetRemploi,
            value: _projetRemploi,
            onChanged: (v) => setState(() => _projetRemploi = v),
          ),
          if (_projetRemploi) ...[
            const SizedBox(height: 16),
            _buildSlider(
              label: S.of(context)!.housingSalePrixNouveauBien,
              value: _prixRemploi,
              min: 100000,
              max: 3000000,
              divisions: 58,
              format: (v) => _chfFmt(v),
              onChanged: (v) => setState(() => _prixRemploi = v),
            ),
          ],
        ],
      ),
    );
  }

  // ── Simulate Button ──
  Widget _buildSimulateButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _simulate,
        icon: const Icon(Icons.calculate_outlined, size: 20),
        label: Text(
          S.of(context)!.housingSaleCalculer,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: MintColors.primary,
          foregroundColor: MintColors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  // ── Plus-Value Card ──
  Widget _buildPlusValueCard() {
    final r = _result!;
    final isGain = r.plusValueBrute >= 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (isGain ? MintColors.success : MintColors.error)
            .withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isGain ? MintColors.success : MintColors.error)
              .withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isGain ? Icons.trending_up : Icons.trending_down,
                color: isGain ? MintColors.success : MintColors.error,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.housingSalePlusValueTitle,
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isGain ? MintColors.success : MintColors.error,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildResultRow(S.of(context)!.housingSalePlusValueBrute, _chfFmt(r.plusValueBrute)),
          const SizedBox(height: 8),
          _buildResultRow(
              S.of(context)!.housingSalePlusValueImposable, _chfFmt(r.plusValueImposable)),
          _buildResultRow(
              S.of(context)!.housingSaleDureeDetention, S.of(context)!.housingSaleYearsCount(r.dureeDetention)),
        ],
      ),
    );
  }

  // ── Tax Card ──
  Widget _buildTaxCard() {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.warningText.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MintColors.warningText.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long,
                  color: MintColors.warningText, size: 18),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.housingSaleImpotGainsCanton(_canton),
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: MintColors.warningText,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildResultRow(
            S.of(context)!.housingSaleTauxImposition,
            '${(r.tauxImpositionPlusValue * 100).toStringAsFixed(0)}%',
          ),
          const SizedBox(height: 8),
          _buildResultRow(
            S.of(context)!.housingSaleImpotGains,
            _chfFmt(r.impotPlusValue),
          ),
          if (r.remploiReport > 0) ...[
            const SizedBox(height: 8),
            _buildResultRow(
              S.of(context)!.housingSaleReportRemploi,
              '- ${_chfFmt(r.remploiReport)}',
            ),
            _buildResultRow(
              S.of(context)!.housingSaleImpotEffectif,
              _chfFmt(r.impotEffectif),
            ),
          ],
        ],
      ),
    );
  }

  // ── Remploi Result Card ──
  Widget _buildRemploiResultCard() {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.success.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.replay, color: MintColors.success, size: 18),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.housingSaleReportTitle,
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: MintColors.success,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _chfFmt(r.remploiReport),
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: MintColors.success,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            S.of(context)!.housingSaleReportDesc,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            S.of(context)!.housingSaleReportNote,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── EPL Repayment Card ──
  Widget _buildEplRepaymentCard() {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.replay_circle_filled,
                  color: MintColors.warning, size: 18),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.housingSaleEplRepaymentTitle,
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: MintColors.warning,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (r.remboursementEplLpp > 0)
            _buildResultRow(
              S.of(context)!.housingSaleRemboursementLpp,
              _chfFmt(r.remboursementEplLpp),
            ),
          if (r.remboursementEpl3a > 0) ...[
            const SizedBox(height: 8),
            _buildResultRow(
              S.of(context)!.housingSaleRemboursement3a,
              _chfFmt(r.remboursementEpl3a),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            S.of(context)!.housingSaleEplNote,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Produit Net Card (chiffre choc) ──
  Widget _buildProduitNetCard() {
    final r = _result!;
    final isPositive = r.produitNet >= 0;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: (isPositive ? MintColors.primary : MintColors.error)
            .withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isPositive ? MintColors.primary : MintColors.error)
              .withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Text(
            S.of(context)!.housingSaleProduitNetTitle,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isPositive ? MintColors.primary : MintColors.error,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _chfFmt(r.produitNet),
            style: GoogleFonts.outfit(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: isPositive ? MintColors.primary : MintColors.error,
            ),
          ),
          const SizedBox(height: 16),
          // Breakdown
          _buildResultRow(S.of(context)!.housingSalePrixVente, _chfFmt(_prixVente)),
          const SizedBox(height: 4),
          _buildResultRow(
              S.of(context)!.housingSaleHypotheque, '- ${_chfFmt(r.soldeHypotheque)}'),
          const SizedBox(height: 4),
          _buildResultRow(
              S.of(context)!.housingSaleImpotPlusValue, '- ${_chfFmt(r.impotEffectif)}'),
          if (r.remboursementEplLpp > 0) ...[
            const SizedBox(height: 4),
            _buildResultRow(
                S.of(context)!.housingSaleRemboursementEplLpp,
                '- ${_chfFmt(r.remboursementEplLpp)}'),
          ],
          if (r.remboursementEpl3a > 0) ...[
            const SizedBox(height: 4),
            _buildResultRow(
                S.of(context)!.housingSaleRemboursementEpl3a,
                '- ${_chfFmt(r.remboursementEpl3a)}'),
          ],
        ],
      ),
    );
  }

  // ── Alerts Section ──
  Widget _buildAlertsSection() {
    final r = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.lifeEventPointsAttention,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MintColors.textMuted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        ...r.alerts.map((alert) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MintColors.warning.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: MintColors.warning.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 16, color: MintColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        alert,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: MintColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  // ── Checklist Section ──
  Widget _buildChecklistSection() {
    final r = _result!;
    return SimulatorCard(
      title: S.of(context)!.lifeEventActionsTitle,
      subtitle: S.of(context)!.lifeEventChecklistSubtitle,
      icon: Icons.checklist,
      accentColor: MintColors.warningText,
      child: Column(
        children: List.generate(r.checklist.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _checklistState[index] = !_checklistState[index];
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _checklistState[index]
                      ? MintColors.success.withValues(alpha: 0.06)
                      : MintColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _checklistState[index]
                        ? MintColors.success.withValues(alpha: 0.3)
                        : MintColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _checklistState[index]
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 20,
                      color: _checklistState[index]
                          ? MintColors.success
                          : MintColors.textMuted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        r.checklist[index],
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _checklistState[index]
                              ? MintColors.textSecondary
                              : MintColors.textPrimary,
                          decoration: _checklistState[index]
                              ? TextDecoration.lineThrough
                              : null,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Educational Footer ──
  Widget _buildEducationalFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.lifeEventComprendre,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MintColors.textMuted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        _buildExpandableTile(
          S.of(context)!.housingSaleEduImpotTitle,
          S.of(context)!.housingSaleEduImpotBody,
        ),
        const SizedBox(height: 8),
        _buildExpandableTile(
          S.of(context)!.housingSaleEduRemploiTitle,
          S.of(context)!.housingSaleEduRemploiBody,
        ),
        const SizedBox(height: 8),
        _buildExpandableTile(
          S.of(context)!.housingSaleEduEplTitle,
          S.of(context)!.housingSaleEduEplBody,
        ),
      ],
    );
  }

  // ── Expandable Tile ──
  Widget _buildExpandableTile(String title, String content) {
    return Container(
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: MintColors.textPrimary,
            ),
          ),
          children: [
            Text(
              content,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Disclaimer ──
  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.warningBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.orangeRetroWarm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: MintColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _result?.disclaimer ??
                  'Cet outil éducatif fournit des estimations indicatives et '
                      'ne constitue pas un conseil fiscal, juridique ou immobilier '
                      'personnalisé au sens de la LSFin. Consulte un·e spécialiste '
                      'pour ta situation personnelle.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: MintColors.deepOrange,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Canton Dropdown ──
  Widget _buildCantonDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.housingSaleCanton,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: MintColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MintColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _canton,
              isExpanded: true,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: MintColors.textPrimary,
              ),
              dropdownColor: MintColors.white,
              items: _cantons.map((c) {
                return DropdownMenuItem(
                  value: c,
                  child: Text('$c \u2014 ${cantonFullNames[c] ?? c}'),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _canton = v);
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── Result Row ──
  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Switch ──
  Widget _buildSwitch({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textPrimary,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: MintColors.primary,
        ),
      ],
    );
  }

  // ── Slider ──
  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String Function(double) format,
    required void Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: MintColors.textPrimary,
                ),
              ),
            ),
            Text(
              format(value),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: MintColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 8),
            activeTrackColor: MintColors.primary,
            inactiveTrackColor: MintColors.border,
            thumbColor: MintColors.primary,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: (v) {
              setState(() {
                onChanged(v);
              });
            },
          ),
        ),
      ],
    );
  }
}
