import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/services/bank_import_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Dedicated bank statement import screen using the new /bank-import/import
/// endpoint with auto-detection for 6 Swiss banks + ISO 20022 XML.
///
/// Flow:
/// 1. User picks a file (.csv or .xml)
/// 2. Backend auto-detects format and parses transactions
/// 3. Shows detected bank, summary, and categorized transactions
class BankImportV2Screen extends StatefulWidget {
  const BankImportV2Screen({super.key});

  @override
  State<BankImportV2Screen> createState() => _BankImportV2ScreenState();
}

class _BankImportV2ScreenState extends State<BankImportV2Screen> {
  final BankImportService _service = BankImportService();

  bool _isLoading = false;
  String? _error;
  BankImportResult? _result;

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
    final s = S.of(context)!;

    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        surfaceTintColor: MintColors.white,
        elevation: 0,
        title: Text(
          s.bankImportTitle,
          style: MintTextStyles.titleMedium(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(MintSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.bankImportTitle, style: MintTextStyles.headlineLarge()),
            const SizedBox(height: MintSpacing.sm),
            Text(s.bankImportSubtitle, style: MintTextStyles.bodyLarge()),
            const SizedBox(height: MintSpacing.lg),

            // Upload button
            _buildUploadButton(s),
            const SizedBox(height: MintSpacing.lg),

            // Loading indicator
            if (_isLoading) _buildLoadingIndicator(s),

            // Error
            if (_error != null) _buildError(),

            // Results
            if (_result != null && !_isLoading) ...[
              _buildBankBadge(_result!),
              const SizedBox(height: MintSpacing.md),
              _buildSummary(s, _result!),
              const SizedBox(height: MintSpacing.md),
              if (_result!.categorySummary.isNotEmpty) ...[
                _buildCategories(s, _result!),
                const SizedBox(height: MintSpacing.md),
              ],
              _buildTransactionList(s, _result!),
            ],

            const SizedBox(height: MintSpacing.xl),
            _buildPrivacyNote(s),
            const SizedBox(height: MintSpacing.xl),
          ],
        ),
      ),
    );
  }

  // ── Upload Button ──

  Widget _buildUploadButton(S s) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _isLoading ? null : _pickAndImport,
        style: FilledButton.styleFrom(
          backgroundColor: MintColors.info,
          foregroundColor: MintColors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.upload_file_rounded, size: 20),
        label: Text(s.bankImportUploadButton),
      ),
    );
  }

  // ── Loading ──

  Widget _buildLoadingIndicator(S s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.lg),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(MintColors.info),
            ),
          ),
          const SizedBox(width: 12),
          Text(s.bankImportAnalyzing, style: MintTextStyles.bodyMedium()),
        ],
      ),
    );
  }

  // ── Error ──

  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.only(bottom: MintSpacing.lg),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: MintColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(fontSize: 14, color: MintColors.error),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _error = null),
            icon: const Icon(Icons.close, size: 16, color: MintColors.error),
          ),
        ],
      ),
    );
  }

  // ── Bank Detected Badge ──

  Widget _buildBankBadge(BankImportResult result) {
    final s = S.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: MintColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MintColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: MintColors.success, size: 18),
          const SizedBox(width: 8),
          Text(
            s.bankImportBankDetected(result.bankName),
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

  // ── Summary ──

  Widget _buildSummary(S s, BankImportResult result) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.bankImportCategories,
              style: MintTextStyles.labelSmall()),
          const SizedBox(height: 14),
          if (result.periodStart != null && result.periodEnd != null)
            _summaryRow(
              Icons.calendar_today_outlined,
              s.bankImportPeriod(
                _fmtDate(result.periodStart!),
                _fmtDate(result.periodEnd!),
              ),
            ),
          const SizedBox(height: 10),
          _summaryRow(
            Icons.receipt_long_outlined,
            s.bankImportTransactionCount(
                result.transactionCount.toString()),
          ),
          const SizedBox(height: 10),
          _summaryRow(
            Icons.arrow_downward_rounded,
            s.bankImportIncome,
            value: '+${_fmtChf(result.totalCredits)}',
            valueColor: MintColors.success,
          ),
          const SizedBox(height: 10),
          _summaryRow(
            Icons.arrow_upward_rounded,
            s.bankImportExpenses,
            value: '-${_fmtChf(result.totalDebits.abs())}',
            valueColor: MintColors.error,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label,
      {String? value, Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: MintColors.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style:
                  const TextStyle(fontSize: 14, color: MintColors.textSecondary)),
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

  // ── Categories ──

  Widget _buildCategories(S s, BankImportResult result) {
    final total = result.totalDebits.abs();
    final sorted = result.categorySummary.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.bankImportCategories,
              style: MintTextStyles.labelSmall()),
          const SizedBox(height: 14),
          for (final entry in sorted) ...[
            _categoryBar(entry.key, entry.value, total,
                _categoryColors[entry.key] ?? MintColors.categoryMisc),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _categoryBar(
      String label, double amount, double total, Color color) {
    final pct = total > 0 ? amount / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textPrimary)),
            Text('${_fmtChf(amount)}  ${(pct * 100).round()}%',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  // ── Transactions ──

  Widget _buildTransactionList(S s, BankImportResult result) {
    const maxShown = 20;
    final txs = result.transactions;

    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TRANSACTIONS', style: MintTextStyles.labelSmall()),
          const SizedBox(height: 14),
          for (int i = 0; i < txs.length && i < maxShown; i++) ...[
            _transactionRow(txs[i]),
            const SizedBox(height: 6),
          ],
          if (txs.length > maxShown)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '... +${txs.length - maxShown}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: MintColors.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _transactionRow(ImportedTransaction tx) {
    final isCredit = tx.amount >= 0;
    final color = _categoryColors[tx.category] ?? MintColors.categoryMisc;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tx.description,
              style: const TextStyle(
                  fontSize: 13, color: MintColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${isCredit ? '+' : '-'}${_fmtChf(tx.amount.abs())}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isCredit ? MintColors.success : MintColors.error,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              tx.category,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }

  // ── Privacy Note ──

  Widget _buildPrivacyNote(S s) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.accentPastel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline,
              color: MintColors.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              s.bankImportPrivacy,
              style: const TextStyle(
                  fontSize: 13,
                  color: MintColors.textSecondary,
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions ──

  Future<void> _pickAndImport() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xml'],
    );

    if (picked == null || picked.files.single.path == null) return;
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
    });

    try {
      final file = File(picked.files.single.path!);
      final result = await _service.importStatement(file);
      if (!mounted) return;
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } on BankImportException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Erreur inattendue lors de l\'import.';
        _isLoading = false;
      });
    }
  }

  // ── Helpers ──

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  String _fmtChf(double v) {
    final intPart = v.truncate().abs();
    final decPart = ((v - v.truncate()) * 100).round().abs();
    final grouped = _groupDigits(intPart);
    return '$grouped.${decPart.toString().padLeft(2, '0')} CHF';
  }

  String _groupDigits(int value) {
    final str = value.toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write("'");
      buf.write(str[i]);
    }
    return buf.toString();
  }
}
