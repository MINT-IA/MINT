import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  COUPLE PATRIMOINE CARD — 3-column patrimoine overview
// ────────────────────────────────────────────────────────────
//
// Displays patrimoine split across Liquide / Immobilier / Prévoyance
// columns with owner badges (👤J / 👤L) for couple visibility.
//
// Outil éducatif — ne constitue pas un conseil financier (LSFin).
// ────────────────────────────────────────────────────────────

class CouplePatrimoineCard extends StatelessWidget {
  final String firstName;
  final String? conjointFirstName;
  final double epargneLiquide;
  final double conjointEpargneLiquide;
  final double investissements;
  final double conjointInvestissements;
  final double immobilierValeur;
  final double mortgageBalance;
  final double loanToValue;
  final String? propertyDescription;
  final double avoirLpp;
  final double conjointAvoirLpp;
  final double capital3a;
  final double conjointCapital3a;
  final double librePassage;
  final double totalDettes;
  final double patrimoineBrut;
  final double patrimoineNet;
  final double? partUser;
  final double? partConjoint;
  final bool conjointIsEstimated;

  const CouplePatrimoineCard({
    super.key,
    required this.firstName,
    this.conjointFirstName,
    required this.epargneLiquide,
    this.conjointEpargneLiquide = 0,
    required this.investissements,
    this.conjointInvestissements = 0,
    this.immobilierValeur = 0,
    this.mortgageBalance = 0,
    this.loanToValue = 0,
    this.propertyDescription,
    required this.avoirLpp,
    this.conjointAvoirLpp = 0,
    required this.capital3a,
    this.conjointCapital3a = 0,
    this.librePassage = 0,
    this.totalDettes = 0,
    required this.patrimoineBrut,
    required this.patrimoineNet,
    this.partUser,
    this.partConjoint,
    this.conjointIsEstimated = false,
  });

  static final _chfFormat = NumberFormat('#,##0', 'fr_CH');

  String _fmt(double value) => _chfFormat.format(value.round());

  String _fmtSigned(double value) {
    if (value < 0) return '−${_fmt(value.abs())}';
    return _fmt(value);
  }

  bool get _isCouple => conjointFirstName != null;

  String get _userInitial => firstName.isNotEmpty ? firstName[0] : '?';
  String get _conjointInitial =>
      (conjointFirstName?.isNotEmpty ?? false) ? conjointFirstName![0] : '?';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    size: 18, color: MintColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isCouple
                        ? 'Patrimoine — $firstName & $conjointFirstName'
                        : 'Patrimoine — $firstName',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),

          // 3 columns
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildLiquideColumn()),
                  const SizedBox(width: 8),
                  Expanded(child: _buildImmobilierColumn()),
                  const SizedBox(width: 8),
                  Expanded(child: _buildPrevoyanceColumn()),
                ],
              ),
            ),
          ),

          // Summary box
          _buildSummaryBox(),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Column 1: LIQUIDE ──

  Widget _buildLiquideColumn() {
    final totalLiquide = epargneLiquide +
        conjointEpargneLiquide +
        investissements +
        conjointInvestissements;

    return _columnContainer(
      children: [
        _columnHeader('LIQUIDE'),
        const SizedBox(height: 8),
        _ownerRow('Épargne', epargneLiquide, isUser: true),
        if (_isCouple && conjointEpargneLiquide > 0)
          _ownerRow('Épargne', conjointEpargneLiquide, isUser: false),
        const SizedBox(height: 4),
        _ownerRow('Invest.', investissements, isUser: true),
        if (_isCouple && conjointInvestissements > 0)
          _ownerRow('Invest.', conjointInvestissements, isUser: false),
        const Divider(height: 12),
        _totalRow('Total', totalLiquide),
      ],
    );
  }

  // ── Column 2: IMMOBILIER ──

  Widget _buildImmobilierColumn() {
    final netImmobilier = immobilierValeur - mortgageBalance;
    final ltvPercent = (loanToValue * 100).round();
    final hasProperty = immobilierValeur > 0;

    return _columnContainer(
      children: [
        _columnHeader('IMMOBILIER'),
        const SizedBox(height: 8),
        if (!hasProperty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Aucun bien',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: MintColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else ...[
          if (propertyDescription != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                propertyDescription!,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: MintColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          _labelValueRow('Valeur', _fmt(immobilierValeur)),
          _labelValueRow('−Hypo.', _fmt(mortgageBalance),
              valueColor: MintColors.error),
          const Divider(height: 12),
          _totalRow('Net', netImmobilier),
          const SizedBox(height: 4),
          _ltvIndicator(ltvPercent),
        ],
      ],
    );
  }

  // ── Column 3: PRÉVOYANCE ──

  Widget _buildPrevoyanceColumn() {
    final totalPrevoyance = avoirLpp +
        conjointAvoirLpp +
        capital3a +
        conjointCapital3a +
        librePassage;

    return _columnContainer(
      children: [
        _columnHeader('PRÉVOYANCE'),
        const SizedBox(height: 8),
        _ownerRow('LPP', avoirLpp, isUser: true),
        if (_isCouple && conjointAvoirLpp > 0)
          _ownerRow('LPP', conjointAvoirLpp, isUser: false),
        const SizedBox(height: 4),
        _ownerRow('3a', capital3a, isUser: true),
        if (_isCouple && conjointCapital3a > 0)
          _ownerRow('3a', conjointCapital3a, isUser: false),
        if (librePassage > 0) ...[
          const SizedBox(height: 4),
          _labelValueRow('Libre pass.', _fmt(librePassage)),
        ],
        const Divider(height: 12),
        _totalRow('Total', totalPrevoyance),
      ],
    );
  }

  // ── Summary box ──

  Widget _buildSummaryBox() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.primary.withAlpha(14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MintColors.primary.withAlpha(40)),
      ),
      child: Column(
        children: [
          _summaryLine('Patrimoine brut', _fmt(patrimoineBrut)),
          if (totalDettes > 0)
            _summaryLine('−Dettes', _fmt(totalDettes),
                valueColor: MintColors.error),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Patrimoine net',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MintColors.primary,
                  ),
                ),
              ),
              Text(
                'CHF\u00a0${_fmtSigned(patrimoineNet)}',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: MintColors.primary,
                ),
              ),
            ],
          ),
          if (_isCouple && partUser != null && partConjoint != null) ...[
            const SizedBox(height: 6),
            Text(
              'dont $firstName ~CHF\u00a0${_fmt(partUser!)} '
              '| dont $conjointFirstName ~CHF\u00a0${_fmt(partConjoint!)}',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: MintColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  // ── Shared building blocks ──

  Widget _columnContainer({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _columnHeader(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: MintColors.textMuted,
      ),
    );
  }

  Widget _ownerRow(String label, double value, {required bool isUser}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          _ownerBadge(isUser: isUser),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: MintColors.textSecondary,
              ),
            ),
          ),
          Text(
            _fmt(value),
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ownerBadge({required bool isUser}) {
    final initial = isUser ? _userInitial : _conjointInitial;
    final showEstimated = !isUser && conjointIsEstimated;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: isUser
            ? MintColors.primary.withAlpha(20)
            : MintColors.info.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '\u{1F464}$initial',
            style: const TextStyle(fontSize: 9),
          ),
          if (showEstimated)
            const Text(
              '\u{1F7E1}',
              style: TextStyle(fontSize: 8),
            ),
        ],
      ),
    );
  }

  Widget _labelValueRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: MintColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: valueColor ?? MintColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
        ),
        Text(
          _fmt(value),
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _summaryLine(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textSecondary,
              ),
            ),
          ),
          Text(
            'CHF\u00a0$value',
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? MintColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ltvIndicator(int ltvPercent) {
    final Color ltvColor;
    final String advice;
    if (ltvPercent <= 65) {
      ltvColor = MintColors.success;
      advice = 'LTV saine';
    } else if (ltvPercent <= 80) {
      ltvColor = MintColors.warning;
      advice = 'Amortissement recommandé';
    } else {
      ltvColor = MintColors.error;
      advice = 'LTV élevée — amortir';
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: ltvColor.withAlpha(25),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'LTV $ltvPercent%',
            style: GoogleFonts.montserrat(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: ltvColor,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            advice,
            style: GoogleFonts.inter(
              fontSize: 9,
              color: ltvColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
