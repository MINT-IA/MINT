import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/services/document_service.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Bank statement import screen with a 3-step flow:
/// 1. Upload CSV/PDF
/// 2. Transaction preview with category breakdown
/// 3. Budget import preview and confirmation
class BankImportScreen extends StatefulWidget {
  const BankImportScreen({super.key});

  @override
  State<BankImportScreen> createState() => _BankImportScreenState();
}

class _BankImportScreenState extends State<BankImportScreen> {
  final DocumentService _documentService = DocumentService();

  bool _isUploading = false;
  String? _error;
  BankStatementResult? _statementResult;
  BudgetImportPreview? _budgetPreview;
  bool _budgetImported = false;

  // Category color mapping
  static const Map<String, Color> _categoryColors = {
    'Logement': MintColors.info,
    'Alimentation': MintColors.greenApple,
    'Transport': MintColors.purpleIos,
    'Assurance': MintColors.orangeGold,
    'Telecom': MintColors.redApple,
    'Impots': MintColors.greyApple,
    'Sante': MintColors.purpleApple,
    'Loisirs': MintColors.blueApple,
    'Epargne': MintColors.greenIos,
    'Salaire': MintColors.greenMint,
    'Restaurant': MintColors.pinkHot,
    'Divers': MintColors.categoryMisc,
  };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(s),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    s?.bankImportTitle ?? 'Importer mes releves',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s?.bankImportSubtitle ??
                        'Analyse automatique de tes transactions',
                    style: const TextStyle(
                      fontSize: 15,
                      color: MintColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Step 1: Upload
                  _buildUploadCard(s),
                  const SizedBox(height: 24),

                  // Uploading indicator
                  if (_isUploading) ...[
                    _buildUploadingIndicator(s),
                    const SizedBox(height: 24),
                  ],

                  // Error display
                  if (_error != null) ...[
                    _buildErrorCard(),
                    const SizedBox(height: 24),
                  ],

                  // Bank detected badge
                  if (_statementResult != null && !_isUploading) ...[
                    _buildBankDetectedBadge(_statementResult!),
                    const SizedBox(height: 24),

                    // Step 2: Transaction Preview
                    _buildSummaryCard(s, _statementResult!),
                    const SizedBox(height: 20),
                    _buildCategoryBreakdown(s, _statementResult!),
                    const SizedBox(height: 20),

                    // Recurring charges
                    if (_statementResult!.recurringMonthly.isNotEmpty) ...[
                      _buildRecurringCharges(s, _statementResult!),
                      const SizedBox(height: 20),
                    ],

                    // Transaction list
                    _buildTransactionList(s, _statementResult!),
                    const SizedBox(height: 24),

                    // Step 3: Budget import
                    if (_budgetPreview != null) ...[
                      _buildBudgetPreviewCard(s, _budgetPreview!),
                      const SizedBox(height: 24),
                    ],
                  ],

                  // Budget imported success
                  if (_budgetImported) ...[
                    _buildSuccessCard(s),
                    const SizedBox(height: 24),
                  ],

                  // Privacy footer
                  _buildPrivacyFooter(s),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // App Bar
  // ──────────────────────────────────────────────────────────

  Widget _buildAppBar(S? s) {
    return SliverAppBar(
      backgroundColor: MintColors.background,
      title: Text(
        s?.bankImportTitle ?? 'Importer mes releves',
        style: GoogleFonts.montserrat(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Step 1: Upload Card
  // ──────────────────────────────────────────────────────────

  Widget _buildUploadCard(S? s) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            MintColors.info,
            MintColors.info.withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MintColors.info.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance_outlined,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  s?.bankImportUploadTitle ??
                      'Importe ton releve bancaire',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            s?.bankImportUploadBody ??
                'CSV ou PDF \u2014 UBS, PostFinance, Raiffeisen, ZKB et autres banques suisses',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isUploading ? null : () => _pickAndUpload(),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: MintColors.info,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.attach_file_rounded, size: 20),
              label: Text(
                s?.bankImportUploadButton ?? 'Choisir un fichier',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Uploading Indicator
  // ──────────────────────────────────────────────────────────

  Widget _buildUploadingIndicator(S? s) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(MintColors.info),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            s?.bankImportAnalyzing ?? 'Analyse des transactions...',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: MintColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Error Card
  // ──────────────────────────────────────────────────────────

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: MintColors.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                fontSize: 14,
                color: MintColors.error,
                height: 1.4,
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _error = null),
            icon: const Icon(Icons.close, size: 18, color: MintColors.error),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Bank Detected Badge
  // ──────────────────────────────────────────────────────────

  Widget _buildBankDetectedBadge(BankStatementResult result) {
    final s = S.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: MintColors.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.success.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: MintColors.success, size: 18),
          const SizedBox(width: 8),
          Text(
            s?.bankImportBankDetected(result.bankName) ??
                '${result.bankName} detecte',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MintColors.success,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Step 2: Summary Card
  // ──────────────────────────────────────────────────────────

  Widget _buildSummaryCard(S? s, BankStatementResult result) {
    final periodStr = s?.bankImportPeriod(
            _formatDate(result.periodStart), _formatDate(result.periodEnd)) ??
        'Periode : ${_formatDate(result.periodStart)} - ${_formatDate(result.periodEnd)}';
    final txCountStr =
        s?.bankImportTransactionCount(result.transactions.length.toString()) ??
            '${result.transactions.length} transactions';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RESUME',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow(
            Icons.calendar_today_outlined,
            periodStr,
            null,
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            Icons.receipt_long_outlined,
            txCountStr,
            null,
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            Icons.arrow_downward_rounded,
            s?.bankImportIncome ?? 'Revenus',
            '+${_formatChf(result.totalCredits)}',
            valueColor: MintColors.success,
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            Icons.arrow_upward_rounded,
            s?.bankImportExpenses ?? 'Depenses',
            '-${_formatChf(result.totalDebits.abs())}',
            valueColor: MintColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String? value,
      {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: MintColors.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: MintColors.textSecondary,
            ),
          ),
        ),
        if (value != null)
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: valueColor ?? MintColors.textPrimary,
            ),
          ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────
  // Category Breakdown
  // ──────────────────────────────────────────────────────────

  Widget _buildCategoryBreakdown(S? s, BankStatementResult result) {
    if (result.categorySummary.isEmpty) return const SizedBox.shrink();

    final totalExpenses = result.totalDebits.abs();
    final sortedCategories = result.categorySummary.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s?.bankImportCategories ?? 'Repartition par categorie',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          for (final entry in sortedCategories) ...[
            _buildCategoryBar(
              _localizeCategory(s, entry.key),
              entry.value,
              totalExpenses,
              _categoryColors[entry.key] ?? const MintColors.categoryMisc,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryBar(
      String label, double amount, double total, Color color) {
    final pct = total > 0 ? (amount / total) : 0.0;
    final pctStr = '${(pct * 100).round()}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: MintColors.textPrimary,
                ),
              ),
            ),
            Text(
              '${_formatChf(amount)}  $pctStr',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MintColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────
  // Recurring Charges
  // ──────────────────────────────────────────────────────────

  Widget _buildRecurringCharges(S? s, BankStatementResult result) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s?.bankImportRecurring ?? 'Charges recurrentes detectees',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          for (final tx in result.recurringMonthly) ...[
            _buildRecurringRow(s, tx),
            if (tx != result.recurringMonthly.last)
              const Divider(color: MintColors.lightBorder, height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildRecurringRow(S? s, BankTransaction tx) {
    final amountStr = s?.bankImportPerMonth(_formatChf(tx.amount.abs())) ??
        '${_formatChf(tx.amount.abs())}/mois';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: MintColors.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.autorenew_rounded,
              color: MintColors.textMuted, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            tx.description,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: MintColors.textPrimary,
            ),
          ),
        ),
        Text(
          amountStr,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: MintColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────
  // Transaction List
  // ──────────────────────────────────────────────────────────

  Widget _buildTransactionList(S? s, BankStatementResult result) {
    // Group transactions by date
    final grouped = <String, List<BankTransaction>>{};
    for (final tx in result.transactions) {
      final dateKey = _formatDate(tx.date);
      grouped.putIfAbsent(dateKey, () => []).add(tx);
    }

    final sortedDates = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Most recent first

    // Show max 20 transactions initially
    const maxItems = 20;
    int itemCount = 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TRANSACTIONS',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          for (final dateKey in sortedDates) ...[
            if (itemCount < maxItems) ...[
              Text(
                dateKey,
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              for (final tx in grouped[dateKey]!)
                if (itemCount++ < maxItems) ...[
                  _buildTransactionRow(tx),
                  const SizedBox(height: 6),
                ],
              const SizedBox(height: 12),
            ],
          ],
          if (result.transactions.length > maxItems)
            Center(
              child: Text(
                '... et ${result.transactions.length - maxItems} autres transactions',
                style: const TextStyle(
                  fontSize: 13,
                  color: MintColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(BankTransaction tx) {
    final isCredit = tx.amount >= 0;
    final amountStr =
        '${isCredit ? '+' : '-'}${_formatChf(tx.amount.abs())}';
    final color =
        _categoryColors[tx.category] ?? const MintColors.categoryMisc;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tx.description,
              style: const TextStyle(
                fontSize: 13,
                color: MintColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amountStr,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isCredit ? MintColors.success : MintColors.error,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              tx.category,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Step 3: Budget Preview Card
  // ──────────────────────────────────────────────────────────

  Widget _buildBudgetPreviewCard(S? s, BudgetImportPreview preview) {
    final recurringTotal = preview.recurringCharges.fold<double>(
      0.0,
      (sum, tx) => sum + tx.amount.abs(),
    );
    final variableExpenses = preview.estimatedMonthlyExpenses - recurringTotal;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: MintColors.primary.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s?.bankImportBudgetPreview ?? 'Ton budget estime',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          _buildBudgetRow(
            s?.bankImportMonthlyIncome ?? 'Revenu mensuel',
            _formatChf(preview.estimatedMonthlyIncome),
            MintColors.textPrimary,
          ),
          const SizedBox(height: 12),
          _buildBudgetRow(
            s?.bankImportFixedCharges ?? 'Charges fixes',
            _formatChf(recurringTotal),
            MintColors.textSecondary,
          ),
          const SizedBox(height: 12),
          _buildBudgetRow(
            s?.bankImportVariable ?? 'Depenses variables',
            _formatChf(variableExpenses > 0 ? variableExpenses : 0),
            MintColors.textSecondary,
          ),
          const SizedBox(height: 12),
          _buildBudgetRow(
            s?.bankImportSavingsRate ?? "Taux d'epargne",
            '${preview.savingsRate.toStringAsFixed(1)}%',
            preview.savingsRate >= 20
                ? MintColors.success
                : preview.savingsRate >= 10
                    ? MintColors.warning
                    : MintColors.error,
            bold: true,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _budgetImported ? null : () => _importIntoBudget(),
              child: Text(
                s?.bankImportButton ?? 'Importer dans mon budget',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetRow(String label, String value, Color valueColor,
      {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: MintColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────
  // Success Card
  // ──────────────────────────────────────────────────────────

  Widget _buildSuccessCard(S? s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.success.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: MintColors.success, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              s?.bankImportSuccess ?? 'Budget mis a jour avec succes',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: MintColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Privacy Footer
  // ──────────────────────────────────────────────────────────

  Widget _buildPrivacyFooter(S? s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.accentPastel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.accent.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: MintColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lock_outline,
                color: MintColors.accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              s?.bankImportPrivacy ??
                  'Tes releves sont analyses localement. Les transactions ne sont jamais stockees sur nos serveurs.',
              style: const TextStyle(
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

  // ──────────────────────────────────────────────────────────
  // Actions
  // ──────────────────────────────────────────────────────────

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'csv'],
    );

    if (result != null && result.files.single.path != null) {
      if (!mounted) return;
      setState(() {
        _isUploading = true;
        _error = null;
        _statementResult = null;
        _budgetPreview = null;
        _budgetImported = false;
      });

      try {
        final file = File(result.files.single.path!);
        final statementResult =
            await _documentService.uploadBankStatement(file);
        if (!mounted) return;
        setState(() {
          _statementResult = statementResult;
          _budgetPreview =
              BudgetImportPreview.fromStatementResult(statementResult);
          _isUploading = false;
        });
      } on DocumentServiceException catch (e) {
        if (!mounted) return;
        setState(() {
          _error = e.message;
          _isUploading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = 'Une erreur est survenue lors de l\'analyse du releve.';
          _isUploading = false;
        });
      }
    }
  }

  void _importIntoBudget() {
    if (_budgetPreview == null) return;

    final preview = _budgetPreview!;
    final recurringTotal = preview.recurringCharges.fold<double>(
      0.0,
      (sum, tx) => sum + tx.amount.abs(),
    );

    // Create BudgetInputs from bank statement analysis
    final budgetInputs = BudgetInputs(
      payFrequency: PayFrequency.monthly,
      netIncome: preview.estimatedMonthlyIncome,
      housingCost: recurringTotal,
      debtPayments: 0,
      style: BudgetStyle.envelopes3,
    );

    // Update the budget provider
    context.read<BudgetProvider>().setInputs(budgetInputs);

    setState(() {
      _budgetImported = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          S.of(context)?.bankImportSuccess ??
              'Budget mis a jour avec succes',
        ),
        backgroundColor: MintColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────────────────

  /// Format a date as dd.MM.yyyy (Swiss format).
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  /// Format a number as CHF with Swiss apostrophe grouping (1'234.56).
  String _formatChf(double value) {
    final intPart = value.truncate();
    final decPart = ((value - intPart) * 100).round().abs();
    final grouped = _groupDigits(intPart.abs());
    final sign = value < 0 ? '-' : '';
    return '$sign$grouped.${decPart.toString().padLeft(2, '0')} CHF';
  }

  /// Group digits with apostrophe (Swiss format): 245678 -> 245'678
  String _groupDigits(int value) {
    final str = value.toString();
    final buffer = StringBuffer();
    final len = str.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) {
        buffer.write("'");
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  /// Localize a category name using ARB keys.
  String _localizeCategory(S? s, String category) {
    switch (category) {
      case 'Logement':
        return s?.bankImportCategoryLogement ?? 'Logement';
      case 'Alimentation':
        return s?.bankImportCategoryAlimentation ?? 'Alimentation';
      case 'Transport':
        return s?.bankImportCategoryTransport ?? 'Transport';
      case 'Assurance':
        return s?.bankImportCategoryAssurance ?? 'Assurance';
      case 'Telecom':
        return s?.bankImportCategoryTelecom ?? 'Telecom';
      case 'Impots':
        return s?.bankImportCategoryImpots ?? 'Impots';
      case 'Sante':
        return s?.bankImportCategorySante ?? 'Sante';
      case 'Loisirs':
        return s?.bankImportCategoryLoisirs ?? 'Loisirs';
      case 'Epargne':
        return s?.bankImportCategoryEpargne ?? 'Epargne';
      case 'Salaire':
        return s?.bankImportCategorySalaire ?? 'Salaire';
      case 'Restaurant':
        return s?.bankImportCategoryRestaurant ?? 'Restaurant';
      case 'Divers':
        return s?.bankImportCategoryDivers ?? 'Divers';
      default:
        return category;
    }
  }
}
