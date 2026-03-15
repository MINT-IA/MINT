import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'dart:math' as math;

// ────────────────────────────────────────────────────────────
//  P10-B  Avalanche vs Boule de neige
//  Charte : L2 (Avant/Apres) + L6 (Chiffre-choc)
//  Source : CO art. 82, bonnes pratiques desendettement
// ────────────────────────────────────────────────────────────

class DebtEntry {
  const DebtEntry({
    required this.label,
    required this.emoji,
    required this.balance,
    required this.monthlyRate,
    required this.minimumPayment,
  });

  final String label;
  final String emoji;
  final double balance;
  final double monthlyRate; // e.g. 0.015 = 1.5%/month
  final double minimumPayment;
}

enum RepaymentStrategy { avalanche, snowball }

class DebtRepaymentWidget extends StatefulWidget {
  const DebtRepaymentWidget({
    super.key,
    required this.debts,
    required this.extraMonthly,
  });

  final List<DebtEntry> debts;
  final double extraMonthly;

  @override
  State<DebtRepaymentWidget> createState() => _DebtRepaymentWidgetState();
}

class _DebtRepaymentWidgetState extends State<DebtRepaymentWidget> {
  RepaymentStrategy _strategy = RepaymentStrategy.avalanche;

  double get _totalDebt =>
      widget.debts.fold<double>(0, (s, d) => s + d.balance);

  double get _minPaymentTotal =>
      widget.debts.fold<double>(0, (s, d) => s + d.minimumPayment);

  /// Simulate months to payoff and total interest for a given strategy.
  _SimResult _simulate(RepaymentStrategy strategy) {
    // Make mutable copies
    var balances = widget.debts.map((d) => d.balance).toList();
    final rates = widget.debts.map((d) => d.monthlyRate).toList();
    final mins = widget.debts.map((d) => d.minimumPayment).toList();
    final n = widget.debts.length;

    double totalInterest = 0;
    int months = 0;
    final budget = _minPaymentTotal + widget.extraMonthly;
    const maxMonths = 600; // 50 years safety cap

    while (balances.any((b) => b > 0.01) && months < maxMonths) {
      months++;

      // Accrue interest
      for (var i = 0; i < n; i++) {
        if (balances[i] > 0) {
          final interest = balances[i] * rates[i];
          totalInterest += interest;
          balances[i] += interest;
        }
      }

      // Pay minimums
      var remaining = budget;
      for (var i = 0; i < n; i++) {
        if (balances[i] > 0) {
          final pay = math.min(mins[i], balances[i]);
          balances[i] -= pay;
          remaining -= pay;
          if (remaining < 0) remaining = 0;
        }
      }

      // Apply extra to priority debt
      if (remaining > 0) {
        // Find priority index
        int priority = -1;
        if (strategy == RepaymentStrategy.avalanche) {
          // Highest rate first
          double maxRate = 0;
          for (var i = 0; i < n; i++) {
            if (balances[i] > 0.01 && rates[i] > maxRate) {
              maxRate = rates[i];
              priority = i;
            }
          }
        } else {
          // Lowest balance first (snowball)
          double minBal = double.infinity;
          for (var i = 0; i < n; i++) {
            if (balances[i] > 0.01 && balances[i] < minBal) {
              minBal = balances[i];
              priority = i;
            }
          }
        }
        if (priority >= 0) {
          final pay = math.min(remaining, balances[priority]);
          balances[priority] -= pay;
        }
      }
    }

    return _SimResult(months: months, totalInterest: totalInterest);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final avalanche = _simulate(RepaymentStrategy.avalanche);
    final snowball = _simulate(RepaymentStrategy.snowball);
    final current = _strategy == RepaymentStrategy.avalanche ? avalanche : snowball;
    final interestSaved = snowball.totalInterest - avalanche.totalInterest;

    return Semantics(
      label: s.debtRepaymentSemantics,
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(s),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStrategyToggle(s),
                  const SizedBox(height: 16),
                  _buildDebtList(s),
                  const SizedBox(height: 16),
                  _buildResultCard(s, current),
                  const SizedBox(height: 12),
                  _buildComparisonCallout(s, interestSaved, avalanche, snowball),
                  const SizedBox(height: 16),
                  _buildDisclaimer(s),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(S s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: MintColors.urgentBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const Text('\u26f0\ufe0f', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.debtRepaymentTitle,
                  style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.debtRepaymentSubtitle(formatChfWithPrefix(_totalDebt)),
                  style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrategyToggle(S s) {
    return Row(
      children: [
        Expanded(child: _buildToggleBtn(
          label: s.debtRepaymentAvalancheLabel,
          subtitle: s.debtRepaymentAvalancheSubtitle,
          strategy: RepaymentStrategy.avalanche,
        )),
        const SizedBox(width: 10),
        Expanded(child: _buildToggleBtn(
          label: s.debtRepaymentSnowballLabel,
          subtitle: s.debtRepaymentSnowballSubtitle,
          strategy: RepaymentStrategy.snowball,
        )),
      ],
    );
  }

  Widget _buildToggleBtn({
    required String label,
    required String subtitle,
    required RepaymentStrategy strategy,
  }) {
    final isActive = _strategy == strategy;
    return GestureDetector(
      onTap: () => setState(() => _strategy = strategy),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? MintColors.scoreCritique.withValues(alpha: 0.1) : MintColors.appleSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? MintColors.scoreCritique : MintColors.lightBorder,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isActive ? MintColors.scoreCritique : MintColors.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtList(S s) {
    final sorted = List<DebtEntry>.from(widget.debts);
    if (_strategy == RepaymentStrategy.avalanche) {
      sorted.sort((a, b) => b.monthlyRate.compareTo(a.monthlyRate));
    } else {
      sorted.sort((a, b) => a.balance.compareTo(b.balance));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.debtRepaymentOrder,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        ...sorted.asMap().entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: e.key == 0
                      ? MintColors.scoreCritique
                      : MintColors.textSecondary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${e.key + 1}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: e.key == 0 ? MintColors.white : MintColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(e.value.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  e.value.label,
                  style: GoogleFonts.inter(fontSize: 13, color: MintColors.textPrimary),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatChfWithPrefix(e.value.balance),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${(e.value.monthlyRate * 12 * 100).toStringAsFixed(1)}\u00a0%/an',
                    style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildResultCard(S s, _SimResult result) {
    final years = result.months ~/ 12;
    final months = result.months % 12;
    final label = _strategy == RepaymentStrategy.avalanche
        ? s.debtRepaymentAvalancheName
        : s.debtRepaymentSnowballName;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 11, color: MintColors.textSecondary),
                ),
                Text(
                  '${years > 0 ? '${years}a ' : ''}${months > 0 ? '${months}m' : ''}',
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: MintColors.primary,
                  ),
                ),
                Text(
                  s.debtRepaymentPayoffAll,
                  style: GoogleFonts.inter(fontSize: 11, color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                s.debtRepaymentInterestPaid,
                style: GoogleFonts.inter(fontSize: 11, color: MintColors.textSecondary),
              ),
              Text(
                formatChfWithPrefix(result.totalInterest),
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: MintColors.scoreCritique,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonCallout(S s, double saved, _SimResult avalanche, _SimResult snowball) {
    final monthsDiff = snowball.months - avalanche.months;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.scoreExcellent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.scoreExcellent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('\ud83d\udca1', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  saved > 0
                      ? s.debtRepaymentAvalancheSaves(formatChfWithPrefix(saved))
                      : s.debtRepaymentSameCost,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MintColors.scoreExcellent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  saved > 0
                      ? s.debtRepaymentSnowballSlower(monthsDiff)
                      : s.debtRepaymentChooseMotivation,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer(S s) {
    return Text(
      s.debtRepaymentDisclaimer,
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

class _SimResult {
  const _SimResult({required this.months, required this.totalInterest});
  final int months;
  final double totalInterest;
}
