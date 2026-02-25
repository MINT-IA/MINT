import 'package:flutter/material.dart';
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

  static const List<Map<String, String>> _categories = [
    {'id': 'all', 'label': 'Toutes'},
    {'id': 'alimentation', 'label': 'Alimentation'},
    {'id': 'transport', 'label': 'Transport'},
    {'id': 'logement', 'label': 'Logement'},
    {'id': 'telecom', 'label': 'Telecom'},
    {'id': 'assurances', 'label': 'Assurances'},
    {'id': 'sante', 'label': 'Sante'},
    {'id': 'loisirs', 'label': 'Loisirs'},
    {'id': 'impots', 'label': 'Impots'},
    {'id': 'energie', 'label': 'Energie'},
    {'id': 'epargne', 'label': 'Epargne'},
    {'id': 'revenu', 'label': 'Revenu'},
    {'id': 'divers', 'label': 'Divers'},
  ];

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
        'TRANSACTIONS',
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
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: Colors.amber.shade800, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fonctionnalite en preparation',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Consultation reglementaire FINMA en cours. '
                  'Les donnees affichees sont des exemples de demonstration.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.amber.shade800,
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
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Text(
          'MODE DEMO',
          style: GoogleFonts.montserrat(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.blue.shade700,
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
        _buildPeriodChip('this_month', 'Ce mois'),
        const SizedBox(width: 8),
        _buildPeriodChip('last_month', 'Mois precedent'),
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
            color: isSelected ? Colors.white : MintColors.textSecondary,
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
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat['id'];
          return GestureDetector(
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
        color: Colors.white,
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
                  style: GoogleFonts.outfit(
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
      'alimentation' => (Icons.shopping_cart, Colors.orange),
      'transport' => (Icons.directions_bus, Colors.blue),
      'logement' => (Icons.home, Colors.brown),
      'telecom' => (Icons.phone_android, Colors.indigo),
      'assurances' => (Icons.health_and_safety, Colors.teal),
      'energie' => (Icons.bolt, Colors.amber),
      'sante' => (Icons.local_pharmacy, Colors.red),
      'loisirs' => (Icons.movie, Colors.purple),
      'impots' => (Icons.receipt_long, Colors.grey),
      'epargne' => (Icons.savings, Colors.green),
      'revenu' => (Icons.account_balance_wallet, Colors.green),
      _ => (Icons.receipt, Colors.grey),
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
            'Aucune transaction',
            style: GoogleFonts.outfit(
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D1D1F).withValues(alpha: 0.06),
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
            'Synthese du mois',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow(
            'Revenus',
            OpenBankingService.formatChf(summary['income'] ?? 0),
            MintColors.success,
          ),
          const SizedBox(height: 10),
          _buildSummaryRow(
            'Depenses',
            OpenBankingService.formatChf(summary['expenses'] ?? 0),
            MintColors.error,
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          _buildSummaryRow(
            'Epargne nette',
            OpenBankingService.formatChf(summary['net'] ?? 0),
            (summary['net'] ?? 0) >= 0
                ? MintColors.success
                : MintColors.error,
          ),
          const SizedBox(height: 10),
          _buildSummaryRow(
            'Taux d\'epargne',
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
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Cette fonctionnalite est en cours de developpement. '
              'Les donnees affichees sont des exemples. '
              'L\'activation du service Open Banking est soumise '
              'a une consultation reglementaire prealable.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.orange.shade800,
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
    const months = [
      'janvier', 'fevrier', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'aout', 'septembre', 'octobre', 'novembre', 'decembre',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTransactionDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'alimentation':
        return 'Alimentation';
      case 'transport':
        return 'Transport';
      case 'logement':
        return 'Logement';
      case 'telecom':
        return 'Telecom';
      case 'assurances':
        return 'Assurances';
      case 'energie':
        return 'Energie';
      case 'sante':
        return 'Sante';
      case 'loisirs':
        return 'Loisirs';
      case 'impots':
        return 'Impots';
      case 'epargne':
        return 'Epargne';
      case 'revenu':
        return 'Revenu';
      default:
        return 'Divers';
    }
  }
}
