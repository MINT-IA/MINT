import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/open_banking_service.dart';

// ────────────────────────────────────────────────────────────
//  OPEN BANKING HUB SCREEN — Sprint S14
// ────────────────────────────────────────────────────────────
//
// Main entry point for the Open Banking feature.
// Fully built but behind a FINMA consultation gate.
// All data is mock/demo — no real API calls.
//
// Compliance: FINMA gate banner, nLPD, read-only,
// no banned terms, disclaimer on every screen.
// ────────────────────────────────────────────────────────────

class OpenBankingHubScreen extends StatelessWidget {
  const OpenBankingHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accounts = OpenBankingService.getMockAccounts();
    final totalBalance = OpenBankingService.getTotalBalance();
    final summary = OpenBankingService.getMonthlySummary();
    final categories = OpenBankingService.computeCategoryBreakdown();

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
                _buildHeader(),
                const SizedBox(height: 24),

                // Connected accounts
                _buildSectionTitle('COMPTES CONNECTES', Icons.account_balance),
                const SizedBox(height: 12),
                ...accounts.map((acc) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildAccountCard(acc),
                    )),
                _buildAddBankButton(),
                const SizedBox(height: 28),

                // Financial overview
                _buildSectionTitle('APERCU FINANCIER', Icons.insights),
                const SizedBox(height: 12),
                _buildTotalBalanceCard(totalBalance),
                const SizedBox(height: 12),
                _buildIncomeExpenseBar(summary),
                const SizedBox(height: 12),
                _buildTopCategories(categories),
                const SizedBox(height: 28),

                // Quick links
                _buildSectionTitle('NAVIGATION', Icons.link),
                const SizedBox(height: 12),
                _buildQuickLinkTile(
                  context,
                  icon: Icons.receipt_long,
                  title: 'Voir les transactions',
                  subtitle: 'Historique detaille par categorie',
                  route: '/open-banking/transactions',
                ),
                const SizedBox(height: 10),
                _buildQuickLinkTile(
                  context,
                  icon: Icons.privacy_tip_outlined,
                  title: 'Gerer les consentements',
                  subtitle: 'Droits nLPD, revocation, scopes',
                  route: '/open-banking/consents',
                ),
                const SizedBox(height: 28),

                // bLink badge
                _buildBlinkBadge(),
                const SizedBox(height: 16),

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
      backgroundColor: MintColors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => context.pop(),
      ),
      title: Text(
        S.of(context)!.openBankingTitle,
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
                  'Fonctionnalite en preparation',
                  style: MintTextStyles.bodyMedium(color: MintColors.amberDark).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Consultation reglementaire FINMA en cours. '
                  'Les donnees affichees sont des exemples de demonstration.',
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
          'MODE DEMO',
          style: MintTextStyles.labelSmall(color: MintColors.blueDark).copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MintColors.accentPastel,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.account_balance,
            color: MintColors.tealLight,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Open Banking',
                style: MintTextStyles.headlineMedium(),
              ),
              const SizedBox(height: 4),
              Text(
                'Connecte tes comptes bancaires',
                style: MintTextStyles.bodyMedium(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Section title ──────────────────────────────────────────

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: MintColors.textMuted),
        const SizedBox(width: 8),
        Text(
          title,
          style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  // ── Account Card ───────────────────────────────────────────

  Widget _buildAccountCard(BankAccount account) {
    final avatarColor = _bankColor(account.bankId);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
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
      child: Row(
        children: [
          // Bank avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: avatarColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                OpenBankingService.getBankInitials(account.bankName),
                style: MintTextStyles.bodySmall(color: avatarColor).copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Account details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${account.bankName} \u2022 ${account.accountName}',
                  style: MintTextStyles.titleMedium().copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  account.maskedIban,
                  style: MintTextStyles.bodySmall(color: MintColors.textMuted),
                ),
              ],
            ),
          ),
          // Balance
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                OpenBankingService.formatChf(account.balance),
                style: MintTextStyles.titleMedium().copyWith(fontSize: 15),
              ),
              const SizedBox(height: 2),
              Text(
                _formatSyncTime(account.lastSync),
                style: MintTextStyles.micro(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatSyncTime(DateTime lastSync) {
    final diff = DateTime.now().difference(lastSync);
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    return 'Il y a ${diff.inDays}j';
  }

  Color _bankColor(String bankId) {
    switch (bankId) {
      case 'ubs':
        return MintColors.redMedium;
      case 'postfinance':
        return MintColors.warningText;
      case 'raiffeisen':
        return MintColors.warning;
      case 'credit_suisse':
        return MintColors.blueMaterial900;
      case 'bcv':
        return MintColors.greenDark;
      case 'bcge':
        return MintColors.tealLight;
      case 'zkb':
        return MintColors.categoryBlue;
      case 'neon':
        return MintColors.cyan;
      case 'yuh':
        return MintColors.categoryPurple;
      default:
        return MintColors.textMuted;
    }
  }

  // ── Add Bank Button (disabled) ─────────────────────────────

  Widget _buildAddBankButton() {
    return Tooltip(
      message: 'Disponible apres consultation FINMA',
      child: Opacity(
        opacity: 0.5,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MintColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: MintColors.border.withValues(alpha: 0.4), width: 0.8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_circle_outline,
                  color: MintColors.textMuted, size: 20),
              const SizedBox(width: 10),
              Text(
                'Ajouter une banque',
                style: MintTextStyles.bodyMedium(color: MintColors.textMuted),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.lock_outline,
                  color: MintColors.warningText, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Total Balance Card ─────────────────────────────────────

  Widget _buildTotalBalanceCard(double total) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            MintColors.primary.withValues(alpha: 0.06),
            MintColors.appleSurface.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: MintColors.border.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Column(
        children: [
          Text(
            'Solde total',
            style: MintTextStyles.bodySmall(),
          ),
          const SizedBox(height: 8),
          Text(
            OpenBankingService.formatChf(total),
            style: MintTextStyles.displayMedium(),
          ),
          const SizedBox(height: 4),
          Text(
            '3 comptes connectes',
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ── Income / Expense Bar ───────────────────────────────────

  Widget _buildIncomeExpenseBar(Map<String, double> summary) {
    final income = summary['income'] ?? 0;
    final expenses = summary['expenses'] ?? 0;
    final maxVal = income > expenses ? income : expenses;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        children: [
          // Income
          _buildBarRow(
            label: 'Revenus',
            value: income,
            maxValue: maxVal,
            color: MintColors.success,
          ),
          const SizedBox(height: 12),
          // Expenses
          _buildBarRow(
            label: 'Depenses',
            value: expenses,
            maxValue: maxVal,
            color: MintColors.error,
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Net
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Epargne nette',
                style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                OpenBankingService.formatChf(summary['net'] ?? 0),
                style: MintTextStyles.bodyMedium(
                  color: (summary['net'] ?? 0) >= 0
                      ? MintColors.success
                      : MintColors.error,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarRow({
    required String label,
    required double value,
    required double maxValue,
    required Color color,
  }) {
    final fraction = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: MintTextStyles.bodySmall(),
            ),
            Text(
              OpenBankingService.formatChf(value),
              style: MintTextStyles.bodySmall(color: color).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: MintColors.surface,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ── Top Categories ─────────────────────────────────────────

  Widget _buildTopCategories(List<CategoryBreakdown> categories) {
    final top3 = categories.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top 3 depenses',
            style: MintTextStyles.titleMedium().copyWith(fontSize: 14),
          ),
          const SizedBox(height: 12),
          for (final cat in top3) ...[
            Row(
              children: [
                _categoryIcon(cat.category),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _categoryLabel(cat.category),
                    style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
                  ),
                ),
                Text(
                  OpenBankingService.formatChf(cat.totalAmount),
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: MintSpacing.sm, vertical: MintSpacing.xs),
                  decoration: BoxDecoration(
                    color: MintColors.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${cat.percentage.toStringAsFixed(0)}%',
                    style: MintTextStyles.micro(color: MintColors.textMuted).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (cat != top3.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  // ── Quick Link Tile ────────────────────────────────────────

  Widget _buildQuickLinkTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return Semantics(
      label: title,
      button: true,
      child: InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: MintColors.border.withValues(alpha: 0.5), width: 0.8),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: MintColors.accentPastel,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: MintColors.tealLight, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: MintTextStyles.titleMedium().copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: MintTextStyles.bodySmall(),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: MintColors.textMuted, size: 20),
          ],
        ),
      ),
    ),
    );
  }

  // ── bLink Badge ────────────────────────────────────────────

  Widget _buildBlinkBadge() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'Propulse par bLink (SIX)',
          style: MintTextStyles.labelSmall(color: MintColors.textMuted),
        ),
      ),
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
              'Cette fonctionnalite est en cours de developpement. '
              'Les donnees affichees sont des exemples. '
              'L\'activation du service Open Banking est soumise '
              'a une consultation reglementaire prealable.',
              style: MintTextStyles.bodySmall(color: MintColors.deepOrange),
            ),
          ),
        ],
      ),
    );
  }

  // ── Category Helpers ───────────────────────────────────────

  Widget _categoryIcon(String category) {
    final (IconData iconData, Color color) = switch (category) {
      'alimentation' => (Icons.shopping_cart, MintColors.warning),
      'transport' => (Icons.directions_bus, MintColors.blueDark),
      'logement' => (Icons.home, MintColors.brownWarm),
      'telecom' => (Icons.phone_android, MintColors.indigoDeep),
      'assurances' => (Icons.health_and_safety, MintColors.tealLight),
      'energie' => (Icons.bolt, MintColors.warningText),
      'sante' => (Icons.local_pharmacy, MintColors.redMedium),
      'loisirs' => (Icons.movie, MintColors.categoryPurple),
      'impots' => (Icons.receipt_long, MintColors.greyDark),
      'epargne' => (Icons.savings, MintColors.success),
      'revenu' => (Icons.account_balance_wallet, MintColors.success),
      _ => (Icons.receipt, MintColors.textMuted),
    };

    return Icon(iconData, size: 18, color: color);
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
