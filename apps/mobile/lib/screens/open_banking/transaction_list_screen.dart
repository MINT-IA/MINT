import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/services/open_banking_service.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

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

  List<Map<String, String>> _categories(BuildContext context) {
    final l = S.of(context)!;
    return [
      {'id': 'all', 'label': l.openBankingCategoryAll},
      {'id': 'alimentation', 'label': l.openBankingCategoryAlimentation},
      {'id': 'transport', 'label': l.openBankingCategoryTransport},
      {'id': 'logement', 'label': l.openBankingCategoryLogement},
      {'id': 'telecom', 'label': l.openBankingCategoryTelecom},
      {'id': 'assurances', 'label': l.openBankingCategoryAssurances},
      {'id': 'sante', 'label': l.openBankingCategorySante},
      {'id': 'loisirs', 'label': l.openBankingCategoryLoisirs},
      {'id': 'impots', 'label': l.openBankingCategoryImpots},
      {'id': 'energie', 'label': l.openBankingCategoryEnergie},
      {'id': 'epargne', 'label': l.openBankingCategoryEpargne},
      {'id': 'revenu', 'label': l.openBankingCategoryRevenu},
      {'id': 'divers', 'label': l.openBankingCategoryDivers},
    ];
  }

  List<BankTransaction> get _filteredTransactions {
    var transactions = OpenBankingService.getMockTransactions();

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

  Map<String, List<BankTransaction>> get _groupedTransactions {
    final grouped = <String, List<BankTransaction>>{};
    for (final tx in _filteredTransactions) {
      final key = _formatDateGroup(tx.date);
      grouped.putIfAbsent(key, () => []).add(tx);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final summary = OpenBankingService.getMonthlySummary();
    final grouped = _groupedTransactions;

    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                MintEntrance(child: _buildFinmaGateBanner()),
                const SizedBox(height: 12),
                MintEntrance(delay: Duration(milliseconds: 100), child: _buildDemoModeBadge()),
                const SizedBox(height: 16),

                // Period selector
                MintEntrance(delay: Duration(milliseconds: 200), child: _buildPeriodSelector()),
                const SizedBox(height: 16),

                // Category filters
                MintEntrance(delay: Duration(milliseconds: 300), child: _buildCategoryFilters()),
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
                MintEntrance(delay: Duration(milliseconds: 400), child: _buildMonthlySummary(summary)),
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
        S.of(context)!.openBankingTransactions,
        style: MintTextStyles.headlineMedium(),
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
                  S.of(context)!.transactionListFinmaTitle,
                  style: MintTextStyles.bodyMedium(color: MintColors.amberDark).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  S.of(context)!.transactionListFinmaDesc,
                  style: MintTextStyles.bodySmall(color: MintColors.amberDark),
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
          S.of(context)!.transactionListModeDemo,
          style: MintTextStyles.labelSmall(color: MintColors.blueDark).copyWith(
            fontWeight: FontWeight.w700,
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
        _buildPeriodChip('this_month', S.of(context)!.transactionListThisMonth),
        const SizedBox(width: 8),
        _buildPeriodChip('last_month', S.of(context)!.transactionListLastMonth),
      ],
    );
  }

  Widget _buildPeriodChip(String value, String label) {
    final isSelected = _selectedPeriod == value;
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
      onTap: () => setState(() => _selectedPeriod = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? MintColors.primary : MintColors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? MintColors.primary : MintColors.border,
          ),
        ),
        child: Text(
          label,
          style: MintTextStyles.bodySmall(
            color: isSelected ? MintColors.white : MintColors.textSecondary,
          ).copyWith(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
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
        itemCount: _categories(context).length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _categories(context)[index];
          final isSelected = _selectedCategory == cat['id'];
          return Semantics(
            label: cat['label']!,
            button: true,
            child: GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat['id']!),
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
                cat['label']!,
                style: MintTextStyles.bodySmall(
                  color: isSelected ? MintColors.primary : MintColors.textSecondary,
                ).copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
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
      style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(
        fontWeight: FontWeight.w700,
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
                  style: MintTextStyles.titleMedium().copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _formatTransactionDate(tx.date),
                      style: MintTextStyles.labelSmall(color: MintColors.textMuted),
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
            style: MintTextStyles.bodyMedium(color: amountColor).copyWith(
              fontWeight: FontWeight.w700,
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
        _categoryLabel(context, category),
        style: MintTextStyles.micro(color: MintColors.textMuted).copyWith(
          fontWeight: FontWeight.w500,
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
            S.of(context)!.transactionListNoTransaction,
            style: MintTextStyles.titleMedium(color: MintColors.textMuted),
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
            S.of(context)!.openBankingMonthlySummary,
            style: MintTextStyles.titleMedium(),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow(
            S.of(context)!.transactionListRevenus,
            OpenBankingService.formatChf(summary['income'] ?? 0),
            MintColors.success,
          ),
          const SizedBox(height: 10),
          _buildSummaryRow(
            S.of(context)!.transactionListDepenses,
            OpenBankingService.formatChf(summary['expenses'] ?? 0),
            MintColors.error,
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          _buildSummaryRow(
            S.of(context)!.transactionListEpargneNette,
            OpenBankingService.formatChf(summary['net'] ?? 0),
            (summary['net'] ?? 0) >= 0
                ? MintColors.success
                : MintColors.error,
          ),
          const SizedBox(height: 10),
          _buildSummaryRow(
            S.of(context)!.transactionListTauxEpargne,
            '${(summary['savingsRate'] ?? 0).toStringAsFixed(1)}\u00a0%',
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
          style: MintTextStyles.bodySmall(),
        ),
        Text(
          value,
          style: MintTextStyles.bodyMedium(color: valueColor).copyWith(
            fontWeight: FontWeight.w600,
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
              S.of(context)!.openBankingDisclaimer,
              style: MintTextStyles.bodySmall(color: MintColors.deepOrange),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────

  String _formatDateGroup(DateTime date) {
    const months = [
      'janvier', 'fevrier', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'aout', 'septembre', 'octobre', 'novembre', 'decembre',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTransactionDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _categoryLabel(BuildContext context, String category) {
    final l = S.of(context)!;
    switch (category) {
      case 'alimentation':
        return l.openBankingCategoryAlimentation;
      case 'transport':
        return l.openBankingCategoryTransport;
      case 'logement':
        return l.openBankingCategoryLogement;
      case 'telecom':
        return l.openBankingCategoryTelecom;
      case 'assurances':
        return l.openBankingCategoryAssurances;
      case 'energie':
        return l.openBankingCategoryEnergie;
      case 'sante':
        return l.openBankingCategorySante;
      case 'loisirs':
        return l.openBankingCategoryLoisirs;
      case 'impots':
        return l.openBankingCategoryImpots;
      case 'epargne':
        return l.openBankingCategoryEpargne;
      case 'revenu':
        return l.openBankingCategoryRevenu;
      default:
        return l.openBankingCategoryDivers;
    }
  }
}
