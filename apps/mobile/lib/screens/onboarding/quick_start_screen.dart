import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

/// Quick Start — single-screen onboarding that gets the user to the dashboard
/// in under 20 seconds.
///
/// Collects 4 fields: firstName, age, salary, canton.
/// Shows a live retirement preview as the user adjusts sliders.
/// Saves via [CoachProfileProvider.updateFromSmartFlow] and navigates to /home.
class QuickStartScreen extends StatefulWidget {
  const QuickStartScreen({super.key});

  @override
  State<QuickStartScreen> createState() => _QuickStartScreenState();
}

class _QuickStartScreenState extends State<QuickStartScreen> {
  final _analytics = AnalyticsService();
  final _nameController = TextEditingController();
  double _age = 45;
  double _salary = 85000;
  String _canton = 'VD';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _analytics.trackScreenView('/onboarding/quick');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ── Live estimation (same formulas as landing page, via financial_core) ──

  double _estimateLppBalance(int age, double gross) {
    if (gross < lppSeuilEntree) return 0.0;
    final coord = (gross - lppDeductionCoordination)
        .clamp(lppSalaireCoordMin, lppSalaireCoordMax);
    double balance = 0;
    for (int a = 25; a < age && a < 65; a++) {
      balance *= 1.01;
      balance += coord * getLppBonificationRate(a);
    }
    return balance;
  }

  Map<String, double> _estimate() {
    final age = _age.round();
    final avs = AvsCalculator.renteFromRAMD(_salary);
    final lppBalance = _estimateLppBalance(age, _salary);
    final lppAnnual = LppCalculator.projectToRetirement(
      currentBalance: lppBalance,
      currentAge: age,
      retirementAge: 65,
      grossAnnualSalary: _salary,
      caisseReturn: 0.01,
      conversionRate: lppTauxConversionMinDecimal,
    );
    final lppMonthly = lppAnnual / 12;
    final total = avs + lppMonthly;
    final current = _salary / 12;
    final ratio = current > 0 ? total / current : 0.0;
    return {'total': total, 'current': current, 'ratio': ratio};
  }

  Future<void> _onContinue() async {
    if (_saving) return;
    setState(() => _saving = true);

    final provider = context.read<CoachProfileProvider>();
    provider.updateFromSmartFlow(
      age: _age.round(),
      grossSalary: _salary,
      canton: _canton,
      firstName: _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : null,
    );

    _analytics.trackCTAClick('quick_start_completed', screenName: '/onboarding/quick');

    if (mounted) context.go('/home');
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final est = _estimate();
    final total = est['total']!;
    final current = est['current']!;
    final ratio = est['ratio']!;
    final gap = (current - total).clamp(0.0, double.infinity);
    final dropPct = current > 0 ? ((current - total) / current * 100).round() : 0;

    return Scaffold(
      backgroundColor: MintColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Scrollable form ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      'Ton plan retraite\nen 30 secondes',
                      style: GoogleFonts.montserrat(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: MintColors.textPrimary,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '4 infos suffisent. Tu pourras affiner plus tard.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: MintColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Prenom ──
                    Text(
                      'Ton prenom',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'Facultatif',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 14,
                          color: MintColors.textMuted,
                        ),
                        filled: true,
                        fillColor: MintColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: MintColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: MintColors.border),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                      style: GoogleFonts.inter(fontSize: 15),
                    ),
                    const SizedBox(height: 22),

                    // ── Age slider ──
                    _buildSliderLabel('Ton age', '${_age.round()} ans'),
                    SliderTheme(
                      data: _sliderTheme(),
                      child: Slider(
                        value: _age,
                        min: 22,
                        max: 67,
                        divisions: 45,
                        onChanged: (v) => setState(() => _age = v),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Salary slider ──
                    _buildSliderLabel(
                        'Salaire brut annuel', '${formatChf(_salary)} CHF'),
                    SliderTheme(
                      data: _sliderTheme(),
                      child: Slider(
                        value: _salary,
                        min: 30000,
                        max: 250000,
                        divisions: 44,
                        onChanged: (v) => setState(() => _salary = v),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Canton dropdown ──
                    _buildSliderLabel('Canton', ''),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
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
                              fontSize: 15, color: MintColors.textPrimary),
                          items: sortedCantonCodes.map((code) {
                            final name = cantonFullNames[code] ?? code;
                            return DropdownMenuItem(
                              value: code,
                              child: Text('$code — $name'),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _canton = v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Live preview card ──
                    _buildPreviewCard(total, current, ratio, gap, dropPct),

                    const SizedBox(height: 12),
                    Text(
                      'Estimation indicative (1er + 2e pilier). '
                      'Ne constitue pas un conseil financier (LSFin).',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: MintColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── CTA button ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _onContinue,
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: MintColors.white,
                          ),
                        )
                      : Text(
                          'Voir mon tableau de bord',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Preview card with live numbers ──

  Widget _buildPreviewCard(
      double total, double current, double ratio, double gap, int dropPct) {
    final Color accentColor;
    final String verdict;
    if (ratio >= 0.7) {
      accentColor = MintColors.success;
      verdict = 'Bonne posture';
    } else if (ratio >= 0.5) {
      accentColor = MintColors.warning;
      verdict = 'A surveiller';
    } else {
      accentColor = MintColors.scoreAttention;
      verdict = 'Ecart significatif';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          // Title
          Row(
            children: [
              Icon(Icons.show_chart, size: 18, color: accentColor),
              const SizedBox(width: 8),
              Text(
                'Apercu retraite',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  verdict,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Avant / Apres
          Row(
            children: [
              Expanded(
                child: _buildAmountColumn(
                  "Aujourd'hui",
                  current,
                  MintColors.textPrimary,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: MintColors.border,
              ),
              Expanded(
                child: _buildAmountColumn(
                  'A la retraite',
                  total,
                  accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Gap bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              backgroundColor: MintColors.border,
              valueColor: AlwaysStoppedAnimation(accentColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),

          // Drop percentage
          TweenAnimationBuilder<double>(
            tween: Tween(end: dropPct.toDouble()),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (_, value, __) => Text(
              '-${value.round()}% de pouvoir d\'achat '
              '(${formatChfWithPrefix(gap)}/mois)',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountColumn(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: MintColors.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween(end: amount),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          builder: (_, value, __) => Text(
            '${formatChf(value)} CHF',
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        Text(
          '/mois',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: MintColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildSliderLabel(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: MintColors.textPrimary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: MintColors.primary,
          ),
        ),
      ],
    );
  }

  SliderThemeData _sliderTheme() {
    return SliderThemeData(
      activeTrackColor: MintColors.primary,
      inactiveTrackColor: MintColors.border,
      thumbColor: MintColors.primary,
      overlayColor: MintColors.primary.withValues(alpha: 0.12),
      trackHeight: 4,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
    );
  }
}
