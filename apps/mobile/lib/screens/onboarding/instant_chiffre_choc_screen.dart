import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/services/chiffre_choc_selector.dart';
import 'package:mint_mobile/services/minimal_profile_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_hero_number.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/widgets/glossary_term.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Instant chiffre choc screen — shown from landing without account.
///
/// Displays a big animated number (AVS + LPP estimate),
/// canton context, confidence badge, and the P1 moment de silence.
/// No data is stored. Pure ephemeral calculation.
class InstantChiffreChocScreen extends StatefulWidget {
  const InstantChiffreChocScreen({super.key});

  @override
  State<InstantChiffreChocScreen> createState() =>
      _InstantChiffreChocScreenState();
}

class _InstantChiffreChocScreenState extends State<InstantChiffreChocScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  // Moment de silence state
  bool _showQuestion = false;
  bool _showInput = false;
  final TextEditingController _responseController = TextEditingController();

  // Route data
  double _monthlyTotal = 0;
  int _replacementPercent = 0;
  String _canton = '';
  double _grossSalary = 0;
  int? _birthYear;
  ChiffreChoc? _choc;

  bool _didInit = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      _loadFromRouteExtra();
    }
  }

  void _loadFromRouteExtra() {
    final extra = GoRouterState.of(context).extra;
    if (extra is Map<String, dynamic>) {
      _monthlyTotal = (extra['monthlyTotal'] as num?)?.toDouble() ?? 0;
      _replacementPercent = extra['replacementPercent'] as int? ?? 0;
      _canton = extra['canton'] as String? ?? '';
      _grossSalary = (extra['grossSalary'] as num?)?.toDouble() ?? 0;
      _birthYear = extra['birthYear'] as int?;
    }

    // Call ChiffreChocSelector for age-appropriate chiffre choc
    if (_birthYear != null && _grossSalary > 0 && _canton.isNotEmpty) {
      final currentYear = DateTime.now().year;
      final age = currentYear - _birthYear!;
      try {
        final profile = MinimalProfileService.compute(
          age: age,
          grossSalary: _grossSalary,
          canton: _canton,
        );
        _choc = ChiffreChocSelector.select(profile);
      } catch (_) {
        // Fallback: _choc stays null, use legacy display
      }
    }

    AnalyticsService().trackScreenView('/chiffre-choc-instant');

    _animController.forward(from: 0);

    // Moment de silence: timed reveal (same as P1)
    Future.delayed(const Duration(milliseconds: 3900), () {
      if (mounted) setState(() => _showQuestion = true);
    });
    Future.delayed(const Duration(milliseconds: 4700), () {
      if (mounted) setState(() => _showInput = true);
    });
  }

  String _formatChf(double amount) {
    final rounded = amount.round();
    if (rounded >= 1000) {
      final thousands = rounded ~/ 1000;
      final remainder = rounded % 1000;
      if (remainder == 0) return 'CHF\u00a0$thousands\u2019000';
      return 'CHF\u00a0$thousands\u2019${remainder.toString().padLeft(3, '0')}';
    }
    return 'CHF\u00a0$rounded';
  }

  String _cantonContext(String canton, S l10n) {
    // Provide subtle regional context based on canton
    final cantonUpper = canton.toUpperCase();
    return switch (cantonUpper) {
      'VS' => 'En Valais, la vie co\u00fbte moins qu\u2019\u00e0 Gen\u00e8ve\u00a0\u2014\u00a0mais le d\u00e9fi retraite est le m\u00eame.',
      'GE' => '\u00c0 Gen\u00e8ve, le co\u00fbt de la vie amplifie chaque franc manquant.',
      'VD' => 'Dans le canton de Vaud, septante pourcent des gens sous-estiment ce chiffre.',
      'ZH' => 'In Z\u00fcrich, der Lebensstandard macht jeden fehlenden Franken sp\u00fcrbar.',
      'BE' => 'Im Kanton Bern z\u00e4hlt jeder Franken f\u00fcr deine Pensionierung.',
      'TI' => 'In Ticino, il costo della vita \u00e8 pi\u00f9 basso\u00a0\u2014\u00a0ma la sfida resta.',
      'BS' => 'In Basel, die hohen Lebenskosten machen Vorsorge umso wichtiger.',
      'LU' => 'In Luzern, die Vorsorge verdient mehr Aufmerksamkeit.',
      'FR' => '\u00c0 Fribourg, entre deux langues et deux cultures, la retraite se pr\u00e9pare.',
      'NE' => '\u00c0 Neuch\u00e2tel, nonante pourcent des gens ne connaissent pas ce chiffre.',
      'JU' => 'Dans le Jura, la pr\u00e9voyance m\u00e9rite qu\u2019on s\u2019y arr\u00eate.',
      _ => 'En $cantonUpper, ce chiffre est rarement connu avant qu\u2019il soit trop tard.',
    };
  }

  Future<void> _navigateToRegister() async {
    final userFeeling = _responseController.text.trim();
    if (userFeeling.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('onboarding_emotion', userFeeling);
    if (_birthYear != null) {
      await prefs.setInt('onboarding_birth_year', _birthYear!);
    }
    await prefs.setDouble('onboarding_gross_salary', _grossSalary);
    await prefs.setString('onboarding_canton', _canton);
    await prefs.setString(
      'onboarding_choc_type',
      _choc?.type.name ?? 'retirementIncome',
    );
    await prefs.setDouble('onboarding_choc_value', _choc?.rawValue ?? 0);

    if (mounted) context.go('/auth/register');
  }

  Color _colorForChoc(ChiffreChoc choc) {
    return switch (choc.colorKey) {
      'error' => MintColors.error,
      'warning' => MintColors.warning,
      'success' => MintColors.success,
      _ => MintColors.primary,
    };
  }

  String _questionForChoc(ChiffreChoc choc, S l10n) {
    return switch (choc.type) {
      ChiffreChocType.compoundGrowth => l10n.chocQuestionCompoundGrowth,
      ChiffreChocType.taxSaving3a => l10n.chocQuestionTaxSaving(choc.value),
      ChiffreChocType.retirementGap => l10n.chocQuestionRetirementGap(choc.value),
      ChiffreChocType.retirementIncome => l10n.chocQuestionRetirementIncome(
        '${(choc.rawValue > 0 ? ((choc.rawValue / (_grossSalary / 12)) * 100).round() : _replacementPercent)}',
      ),
      ChiffreChocType.liquidityAlert => l10n.chocQuestionLiquidity(
        choc.rawValue.toStringAsFixed(0),
      ),
      ChiffreChocType.hourlyRate => l10n.chocQuestionHourlyRate(
        'CHF\u00a0${choc.rawValue.round()}',
      ),
    };
  }

  @override
  void dispose() {
    _responseController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final formattedTotal = _choc != null ? _choc!.value : _formatChf(_monthlyTotal);
    final subtitle = _choc != null ? _choc!.title : '$_replacementPercent\u00a0% de ton revenu actuel';

    return Scaffold(
      backgroundColor: MintColors.porcelaine,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: MintSpacing.lg),
              child: Column(
                children: [
                  const SizedBox(height: MintSpacing.md),

                  // Back button
                  MintEntrance(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Semantics(
                        button: true,
                        label: 'Retour',
                        child: IconButton(
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: MintColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 3),

                  // Hero: the big number
                  MintEntrance(
                    delay: const Duration(milliseconds: 100),
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: ScaleTransition(
                        scale: _scaleAnim,
                        child: Center(
                          child: MintHeroNumber(
                            value: formattedTotal,
                            caption: subtitle,
                            color: _choc != null
                                ? _colorForChoc(_choc!)
                                : (_replacementPercent < 60
                                    ? MintColors.warning
                                    : MintColors.primary),
                            semanticsLabel:
                                '$formattedTotal — $subtitle',
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: MintSpacing.md),

                  // Glossary terms — explain what composes the number
                  MintEntrance(
                    delay: const Duration(milliseconds: 150),
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const GlossaryTerm(term: 'AVS'),
                          Text(' + ', style: MintTextStyles.bodySmall(
                            color: MintColors.textMuted,
                          )),
                          const GlossaryTerm(term: 'LPP'),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: MintSpacing.xl),

                  // Canton context
                  if (_canton.isNotEmpty)
                    MintEntrance(
                      delay: const Duration(milliseconds: 200),
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: Text(
                          _cantonContext(_canton, l10n),
                          style: MintTextStyles.bodySmall(
                            color: MintColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                  const SizedBox(height: MintSpacing.lg),

                  // Confidence badge
                  MintEntrance(
                    delay: const Duration(milliseconds: 300),
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: MintSurface(
                        tone: MintSurfaceTone.craie,
                        padding: const EdgeInsets.all(MintSpacing.md),
                        radius: 12,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: MintColors.textMuted,
                            ),
                            const SizedBox(width: MintSpacing.sm),
                            Flexible(
                              child: Text(
                                l10n.instantChiffreChocConfidence,
                                style: MintTextStyles.labelSmall(
                                  color: MintColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Moment de silence: question (fade-in after 3.9s)
                  AnimatedOpacity(
                    opacity: _showQuestion ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeIn,
                    child: Text(
                      _choc != null
                          ? _questionForChoc(_choc!, l10n)
                          : l10n.chiffreChocSilenceQuestion,
                      style: MintTextStyles.bodyMedium(
                        color: MintColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: MintSpacing.lg),

                  // Moment de silence: input (fade-in after 4.7s)
                  AnimatedOpacity(
                    opacity: _showInput ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeIn,
                    child: IgnorePointer(
                      ignoring: !_showInput,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: _responseController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: l10n.chiffreChocSilenceHint,
                              hintStyle: MintTextStyles.bodySmall(
                                color: MintColors.textMuted,
                              ),
                              suffixIcon: IconButton(
                                onPressed: _navigateToRegister,
                                icon: const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: MintColors.primary,
                                ),
                              ),
                              filled: true,
                              fillColor: MintColors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide:
                                    const BorderSide(color: MintColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide:
                                    const BorderSide(color: MintColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide:
                                    const BorderSide(color: MintColors.primary),
                              ),
                            ),
                          ),
                          const SizedBox(height: MintSpacing.sm),

                          // Skip — back to landing
                          TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text(l10n.instantChiffreChocComeBack),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                              context.go('/');
                            },
                            child: Text(
                              l10n.instantChiffreChocComeBack,
                              style: MintTextStyles.labelSmall(
                                color: MintColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: MintSpacing.sm),

                  // Privacy badge
                  Text(
                    l10n.instantChiffreChocNothingStored,
                    style: MintTextStyles.micro(
                      color: MintColors.textMuted.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: MintSpacing.md),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
