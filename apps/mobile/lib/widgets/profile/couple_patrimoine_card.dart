import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

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

  String _fmt(double value) => formatChf(value);

  bool get _isCouple => conjointFirstName != null;

  String get _userInitial => firstName.isNotEmpty ? firstName[0] : '?';
  String get _conjointInitial =>
      (conjointFirstName?.isNotEmpty ?? false) ? conjointFirstName![0] : '?';

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
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
                        ? l.patrimoineCoupleTitleCouple(firstName, conjointFirstName!)
                        : l.patrimoineCoupleTitleSolo(firstName),
                    style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
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
                  Expanded(child: _buildLiquideColumn(l)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildImmobilierColumn(l)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildPrevoyanceColumn(l)),
                ],
              ),
            ),
          ),

          // Summary box
          _buildSummaryBox(l),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Column 1: LIQUIDE ──

  Widget _buildLiquideColumn(S l) {
    final totalLiquide = epargneLiquide +
        conjointEpargneLiquide +
        investissements +
        conjointInvestissements;

    return _columnContainer(
      children: [
        _columnHeader(l.patrimoineLiquide),
        const SizedBox(height: 8),
        _ownerRow(l.patrimoineEpargne, epargneLiquide, isUser: true),
        if (_isCouple && conjointEpargneLiquide > 0)
          _ownerRow(l.patrimoineEpargne, conjointEpargneLiquide, isUser: false),
        const SizedBox(height: 4),
        _ownerRow(l.patrimoineInvest, investissements, isUser: true),
        if (_isCouple && conjointInvestissements > 0)
          _ownerRow(l.patrimoineInvest, conjointInvestissements, isUser: false),
        const Divider(height: 12),
        _totalRow(l.patrimoineTotal, totalLiquide),
      ],
    );
  }

  // ── Column 2: IMMOBILIER ──

  Widget _buildImmobilierColumn(S l) {
    final netImmobilier = immobilierValeur - mortgageBalance;
    final ltvPercent = (loanToValue * 100).round();
    final hasProperty = immobilierValeur > 0;

    return _columnContainer(
      children: [
        _columnHeader(l.patrimoineImmobilier),
        const SizedBox(height: 8),
        if (!hasProperty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l.patrimoineAucunBien,
              style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(fontStyle: FontStyle.italic),
            ),
          )
        else ...[
          if (propertyDescription != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                propertyDescription!,
                style: MintTextStyles.micro(color: MintColors.textMuted).copyWith(fontStyle: FontStyle.italic),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          _labelValueRow(l.patrimoineValeur, _fmt(immobilierValeur)),
          _labelValueRow(l.patrimoineHypo, _fmt(mortgageBalance),
              valueColor: MintColors.error),
          const Divider(height: 12),
          _totalRow(l.patrimoineNet, netImmobilier),
          const SizedBox(height: 4),
          _ltvIndicator(ltvPercent, l),
        ],
      ],
    );
  }

  // ── Column 3: PRÉVOYANCE ──

  Widget _buildPrevoyanceColumn(S l) {
    final totalPrevoyance = avoirLpp +
        conjointAvoirLpp +
        capital3a +
        conjointCapital3a +
        librePassage;

    return _columnContainer(
      children: [
        _columnHeader(l.patrimoinePrevoyance),
        const SizedBox(height: 8),
        _ownerRow(l.patrimoineLpp, avoirLpp, isUser: true),
        if (_isCouple && conjointAvoirLpp > 0)
          _ownerRow(l.patrimoineLpp, conjointAvoirLpp, isUser: false),
        const SizedBox(height: 4),
        _ownerRow(l.patrimoine3a, capital3a, isUser: true),
        if (_isCouple && conjointCapital3a > 0)
          _ownerRow(l.patrimoine3a, conjointCapital3a, isUser: false),
        if (librePassage > 0) ...[
          const SizedBox(height: 4),
          _labelValueRow(l.patrimoineLibrePassage, _fmt(librePassage)),
        ],
        const Divider(height: 12),
        _totalRow(l.patrimoineTotal, totalPrevoyance),
      ],
    );
  }

  // ── Summary box ──

  Widget _buildSummaryBox(S l) {
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
          _summaryLine(l.patrimoineBrut, patrimoineBrut),
          if (totalDettes > 0)
            _summaryLine(l.patrimoineDettes, totalDettes,
                valueColor: MintColors.error),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  l.patrimoineNetLabel,
                  style: MintTextStyles.bodySmall(color: MintColors.primary).copyWith(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                formatChfWithPrefix(patrimoineNet),
                style: MintTextStyles.headlineMedium(color: MintColors.primary).copyWith(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (_isCouple && partUser != null && partConjoint != null) ...[
            const SizedBox(height: 6),
            Text(
              '${l.patrimoineDont(firstName, _fmt(partUser!))} '
              '| ${l.patrimoineDont(conjointFirstName!, _fmt(partConjoint!))}',
              style: MintTextStyles.micro(color: MintColors.textMuted).copyWith(fontStyle: FontStyle.normal),
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
      style: MintTextStyles.micro(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8, fontStyle: FontStyle.normal),
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
              style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
            ),
          ),
          Text(
            _fmt(value),
            style: MintTextStyles.labelSmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
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
              style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
            ),
          ),
          Text(
            value,
            style: MintTextStyles.labelSmall(color: valueColor ?? MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
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
            style: MintTextStyles.labelSmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          _fmt(value),
          style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _summaryLine(String label, double amount, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: MintTextStyles.bodyMedium(color: MintColors.textSecondary).copyWith(fontSize: 12),
            ),
          ),
          Text(
            formatChfWithPrefix(amount),
            style: MintTextStyles.bodySmall(color: valueColor ?? MintColors.textPrimary).copyWith(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _ltvIndicator(int ltvPercent, S l) {
    final Color ltvColor;
    final String advice;
    if (ltvPercent <= 65) {
      ltvColor = MintColors.success;
      advice = l.patrimoineLtvSaine;
    } else if (ltvPercent <= 80) {
      ltvColor = MintColors.warning;
      advice = l.patrimoineLtvAmortissement;
    } else {
      ltvColor = MintColors.error;
      advice = l.patrimoineLtvElevee;
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
            l.patrimoineLtvDisplay('$ltvPercent'),
            style: MintTextStyles.micro(color: ltvColor).copyWith(fontSize: 9, fontWeight: FontWeight.w700, fontStyle: FontStyle.normal),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            advice,
            style: MintTextStyles.micro(color: ltvColor).copyWith(fontSize: 9, fontStyle: FontStyle.normal),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
