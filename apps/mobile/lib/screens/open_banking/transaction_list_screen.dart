import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/open_banking_service.dart';

// ────────────────────────────────────────────────────────────
//  TRANSACTION LIST SCREEN — Sprint S14
// ────────────────────────────────────────────────────────────
//
// Displays mock transactions grouped by date with category
// filters and monthly summary. Behind FINMA gate.
//
// Compliance: FINMA gate banner, disclaimer, read-only,
// no banned terms.
// ────────────────────────────────────────────────────────────

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  String _selectedCategory = 'all';
  String _selectedPeriod = 'this_month';

  static const List<String> _categoryIds = [
    'all', 'alimentation', 'transport', 'logement', 'telecom',
    'assurances', 'sante', 'loisirs', 'impots', 'energie',
    'epargne', 'revenu', 'divers',
  ];

  List<BankTransaction> _getFilteredTransactions(S s) {
    var transactions = OpenBankingService.getMockTransactions(s);

    // Filter by category
    if (_selectedCategory != 'all') {
      transactions = transactions
          .where((tx) => tx.category == _selectedCategory)
          .toList();
    }

    // Sort by date descending
    transactions.sort((a, b) => b.date.compareTo(a.date));
    return transactions;
  }

  Map<String, List<BankTransaction>> _getGroupedTransactions(S s) {
    final grouped = <String, List<BankTransaction>>{};
    for (final tx in _getFilteredTransactions(s)) {
      final key = _formatDateGroup(tx.date);
      grouped.putIfAbsent(key, () => []).add(tx);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final summary = OpenBankingService.getMonthlySummary(s);
    final grouped = _getGroupedTransactions(s);

    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildFinmaGateBanner(),
                const SizedBox(height: 12),
                _buildDemoModeBadge(),
                const SizedBox(height: 16),

                // Period selector
                _buildPeriodSelector(),
                const SizedBox(height: 16),

                // Category filters
                _buildCategoryFilters(),
                const SizedBox(height: 20),

                // Transaction groups
                if (grouped.isEmpty)
                  _buildEmptyState()
                else
                  ...grouped.entries.expand((entry) => [
                        _buildDateHeader(entry.key),
                        const SizedBox(height: 8),
                        ...entry.value.map((tx) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildTransactionCard(tx),
                            )),
                        const SizedBox(height: 12),
                      ]),

                const SizedBox(height: 16),

                // Monthly summary
                _buildMonthlySummary(summary),
                const SizedBox(height: 20),

                // Disclaimer
                _buildDisclaimer(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────

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
        S.of(context)!.txTitle,
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w800,
          fontSize: 13,
          letterSpacing: 1.5,
          color: MintColors.textMuted,
        ),
      ),
    );
  }

  // ── FINMA Gate Banner ──────────────────────────────────────

  Widget _buildFinmaGateBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.disclaimerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.amberWarm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, color: MintColors.amberDark, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.txFinmaGateTitle,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MintColors.amberDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  S.of(context)!.txFinmaGateDesc,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.amberDark,
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

  // ── Demo mode badge ──────────────────────────────────────

  Widget _buildDemoModeBadge() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: MintColors.neutralBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: MintColors.neutralBg),
        ),
        child: Text(
          S.of(context)!.txDemoMode,
          style: GoogleFonts.montserrat(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: MintColors.blueDark,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  // ── Period Selector ────────────────────────────────────────

  Widget _buildPeriodSelector() {
    return Row(
      children: [
        _buildPeriodChip('this_month', S.of(context)!.txThisMonth),
        const SizedBox(width: 8),
        _buildPeriodChip('last_month', S.of(context)!.txLastMonth),
      ],
    );
  }

  Widget _buildPeriodChip(String value, String label) {
    final isSelected = _selectedPeriod == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedPeriod = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? MintColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? MintColors.primary : MintColors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? MintColors.white : MintColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ── Category Filters ───────────────────────────────────────

  Widget _buildCategoryFilters() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categoryIds.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final catId = _categoryIds[index];
          final isSelected = _selectedCategory == catId;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = catId),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? MintColors.primary.withValues(alpha: 0.1)
                    : MintColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? MintColors.primary
                      : MintColors.border.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                _categoryLabel(catId),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? MintColors.primary
                      : MintColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Date Header ────────────────────────────────────────────

  Widget _buildDateHeader(String dateLabel) {
    return Text(
      dateLabel,
      style: GoogleFonts.montserrat(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: MintColors.textMuted,
        letterSpacing: 0.8,
      ),
    );
  }

  // ── Transaction Card ───────────────────────────────────────

  Widget _buildTransactionCard(BankTransaction tx) {
    final isCredit = tx.isCredit;
    final amountColor = isCredit ? MintColors.success : MintColors.error;
    final amountPrefix = isCredit ? '+' : '-';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: MintColors.border.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Row(
        children: [
          // Category icon
          _buildCategoryAvatar(tx.category),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.merchant,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _formatTransactionDate(tx.date),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: MintColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildCategoryBadge(tx.category),
                  ],
                ),
              ],
            ),
          ),
          // Amount
          Text(
            '$amountPrefix${OpenBankingService.formatChf(tx.amount.abs())}',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryAvatar(String category) {
    final (IconData iconData, Color color) = switch (category) {
      'alimentation' => (Icons.shopping_cart, MintColors.warning),
      'transport' => (Icons.directions_bus, MintColors.info),
      'logement' => (Icons.home, MintColors.brownWarm),
      'telecom' => (Icons.phone_android, MintColors.indigo),
      'assurances' => (Icons.health_and_safety, MintColors.teal),
      'energie' => (Icons.bolt, MintColors.amber),
      'sante' => (Icons.local_pharmacy, MintColors.error),
      'loisirs' => (Icons.movie, MintColors.purple),
      'impots' => (Icons.receipt_long, MintColors.greyMedium),
      'epargne' => (Icons.savings, MintColors.success),
      'revenu' => (Icons.account_balance_wallet, MintColors.success),
      _ => (Icons.receipt, MintColors.greyMedium),
    };

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(iconData, color: color.withValues(alpha: 0.8), size: 18),
    );
  }

  Widget _buildCategoryBadge(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _categoryLabel(category),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: MintColors.textMuted,
        ),
      ),
    );
  }

  // ── Empty State ────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 48, color: MintColors.textMuted.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            S.of(context)!.txEmptyState,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MintColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ── Monthly Summary ────────────────────────────────────────

  Widget _buildMonthlySummary(Map<String, double> summary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MintColors.primary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
        border:
            Border.all(color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.txMonthlySummaryTitle,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow(
            S.of(context)!.txIncome,
            OpenBankingService.formatChf(summary['income'] ?? 0),
            MintColors.success,
          ),
          const SizedBox(height: 10),
          _buildSummaryRow(
            S.of(context)!.txExpenses,
            OpenBankingService.formatChf(summary['expenses'] ?? 0),
            MintColors.error,
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          _buildSummaryRow(
            S.of(context)!.txNetSavings,
            OpenBankingService.formatChf(summary['net'] ?? 0),
            (summary['net'] ?? 0) >= 0
                ? MintColors.success
                : MintColors.error,
          ),
          const SizedBox(height: 10),
          _buildSummaryRow(
            S.of(context)!.txSavingsRate,
            '${(summary['savingsRate'] ?? 0).toStringAsFixed(1)}%',
            MintColors.info,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: MintColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  // ── Disclaimer ─────────────────────────────────────────────

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
          const Icon(Icons.info_outline, color: MintColors.warning, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.of(context)!.txDisclaimer,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.deepOrange,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────

  String _formatDateGroup(DateTime date) {
    final s = S.of(context)!;
    final months = [
      s.transactionListMonthJanvier,
      s.transactionListMonthFevrier,
      s.transactionListMonthMars,
      s.transactionListMonthAvril,
      s.transactionListMonthMai,
      s.transactionListMonthJuin,
      s.transactionListMonthJuillet,
      s.transactionListMonthAout,
      s.transactionListMonthSeptembre,
      s.transactionListMonthOctobre,
      s.transactionListMonthNovembre,
      s.transactionListMonthDecembre,
    ];
    return s.transactionListDateGroup(
      date.day.toString(),
      months[date.month - 1],
      date.year.toString(),
    );
  }

  String _formatTransactionDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _categoryLabel(String category) {
    final s = S.of(context)!;
    switch (category) {
      case 'all':
        return s.transactionListCatAll;
      case 'alimentation':
        return s.transactionListCatAlimentation;
      case 'transport':
        return s.transactionListCatTransport;
      case 'logement':
        return s.transactionListCatLogement;
      case 'telecom':
        return s.transactionListCatTelecom;
      case 'assurances':
        return s.transactionListCatAssurances;
      case 'energie':
        return s.transactionListCatEnergie;
      case 'sante':
        return s.transactionListCatSante;
      case 'loisirs':
        return s.transactionListCatLoisirs;
      case 'impots':
        return s.transactionListCatImpots;
      case 'epargne':
        return s.transactionListCatEpargne;
      case 'revenu':
        return s.transactionListCatRevenu;
      default:
        return s.transactionListCatDivers;
    }
  }
}
