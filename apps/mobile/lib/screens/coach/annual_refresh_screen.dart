import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

// ────────────────────────────────────────────────────────────
//  ANNUAL REFRESH SCREEN — T6 / MINT Coach
// ────────────────────────────────────────────────────────────
//
// Check-up annuel leger (7 questions) pour mettre a jour
// les donnees financieres perimees du profil.
//
// Pas un wizard complet — on pre-remplit avec les valeurs
// actuelles et on ne met a jour que ce qui a change.
// Duree cible : 2-3 minutes max.
//
// Tous les textes en francais (informel "tu").
// Aucun terme banni (pas de "garanti", "certain", "optimal", etc.).
// ────────────────────────────────────────────────────────────

class AnnualRefreshScreen extends StatefulWidget {
  const AnnualRefreshScreen({super.key});

  @override
  State<AnnualRefreshScreen> createState() => _AnnualRefreshScreenState();
}

class _AnnualRefreshScreenState extends State<AnnualRefreshScreen> {
  final _formKey = GlobalKey<FormState>();

  // Q1 - Salaire
  late double _salaireBrutMensuel;

  // Q2 - Emploi
  late String _employmentStatus;

  // Q3 - LPP
  late TextEditingController _lppController;

  // Q4 - 3a
  late TextEditingController _threeAController;

  // Q5 - Projet immobilier
  late String _realEstateProject;

  // Q6 - Changement familial
  String _familyChange = 'aucun';

  // Q7 - Tolerance au risque
  late String _riskTolerance;

  // Result state
  bool _isSubmitting = false;
  bool _showResult = false;
  int? _oldScore;
  int? _newScore;

  @override
  void initState() {
    super.initState();
    final profile = context.read<CoachProfileProvider>().profile;
    if (profile != null) {
      _salaireBrutMensuel = profile.salaireBrutMensuel;
      _employmentStatus = profile.employmentStatus;
      _lppController = TextEditingController(
        text: _formatChf(profile.prevoyance.avoirLppTotal ?? 0),
      );
      _threeAController = TextEditingController(
        text: _formatChf(profile.prevoyance.totalEpargne3a),
      );
      _realEstateProject = profile.realEstateProject ?? 'aucun';
      _riskTolerance = profile.riskTolerance ?? 'modere';
    } else {
      _salaireBrutMensuel = 5000;
      _employmentStatus = 'salarie';
      _lppController = TextEditingController(text: '0');
      _threeAController = TextEditingController(text: '0');
      _realEstateProject = 'aucun';
      _riskTolerance = 'modere';
    }
  }

  @override
  void dispose() {
    _lppController.dispose();
    _threeAController.dispose();
    super.dispose();
  }

  String _formatChf(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(0);
  }

  double _parseChf(String text) {
    final cleaned = text.replaceAll(RegExp(r"[^0-9.]"), '');
    return double.tryParse(cleaned) ?? 0;
  }

  String _employmentLabel(BuildContext context, String status) {
    final s = S.of(context)!;
    switch (status) {
      case 'salarie':
        return s.annualRefreshMemeEmploi;
      case 'nouvel_emploi':
        return s.annualRefreshNouvelEmploi;
      case 'independant':
        return s.annualRefreshIndependant;
      case 'chomage':
      case 'sans_emploi':
        return s.annualRefreshSansEmploi;
      default:
        return s.annualRefreshMemeEmploi;
    }
  }

  String _realEstateLabel(BuildContext context, String project) {
    final s = S.of(context)!;
    switch (project) {
      case 'aucun':
        return s.annualRefreshAucun;
      case 'achat':
        return s.annualRefreshAchat;
      case 'vente':
        return s.annualRefreshVente;
      case 'refinancement':
        return s.annualRefreshRefinancement;
      default:
        return s.annualRefreshAucun;
    }
  }

  String _familyLabel(BuildContext context, String change) {
    final s = S.of(context)!;
    switch (change) {
      case 'aucun':
        return s.annualRefreshAucun;
      case 'mariage':
        return s.annualRefreshMariage;
      case 'naissance':
        return s.annualRefreshNaissance;
      case 'divorce':
        return s.annualRefreshDivorce;
      case 'deces':
        return s.annualRefreshDeces;
      default:
        return s.annualRefreshAucun;
    }
  }

  String _riskLabel(BuildContext context, String risk) {
    final s = S.of(context)!;
    switch (risk) {
      case 'conservateur':
        return s.annualRefreshConservateur;
      case 'modere':
        return s.annualRefreshModere;
      case 'agressif':
        return s.annualRefreshAgressif;
      default:
        return s.annualRefreshModere;
    }
  }

  IconData _riskIcon(String risk) {
    switch (risk) {
      case 'conservateur':
        return Icons.shield_outlined;
      case 'modere':
        return Icons.balance_outlined;
      case 'agressif':
        return Icons.trending_up;
      default:
        return Icons.balance_outlined;
    }
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final provider = context.read<CoachProfileProvider>();
    final profile = provider.profile;

    // Calculate old score
    if (profile != null) {
      final oldFfs = FinancialFitnessService.calculate(
        profile: profile,
        previousScore: provider.previousScore,
      );
      _oldScore = oldFfs.global;
    }

    // Update profile via provider
    await provider.updateFromRefresh(
      salaireBrutMensuel: _salaireBrutMensuel,
      employmentStatus: _employmentStatus,
      avoirLppTotal: _parseChf(_lppController.text),
      totalEpargne3a: _parseChf(_threeAController.text),
      realEstateProject: _realEstateProject,
      familyChange: _familyChange,
      riskTolerance: _riskTolerance,
    );

    // Calculate new score
    final updatedProfile = provider.profile;
    if (updatedProfile != null) {
      final newFfs = FinancialFitnessService.calculate(
        profile: updatedProfile,
        previousScore: _oldScore,
      );
      _newScore = newFfs.global;

      // Persist the new score
      await provider.saveCurrentScore(_newScore!);
    }

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _showResult = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showResult) {
      return _buildResultScreen();
    }

    return Scaffold(
      backgroundColor: MintColors.background,
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md, vertical: MintSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  S.of(context)!.annualRefreshSubtitle,
                  style: MintTextStyles.bodyMedium(),
                ),
                const SizedBox(height: MintSpacing.lg),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      MintEntrance(child: _buildSalaireCard()),
                      const SizedBox(height: 16),
                      MintEntrance(delay: const Duration(milliseconds: 100), child: _buildEmploiCard()),
                      const SizedBox(height: 16),
                      MintEntrance(delay: const Duration(milliseconds: 200), child: _buildLppCard()),
                      const SizedBox(height: 16),
                      MintEntrance(delay: const Duration(milliseconds: 300), child: _buildThreeACard()),
                      const SizedBox(height: 16),
                      MintEntrance(delay: const Duration(milliseconds: 400), child: _buildRealEstateCard()),
                      const SizedBox(height: 16),
                      _buildFamilyCard(),
                      const SizedBox(height: 16),
                      _buildRiskCard(),
                      const SizedBox(height: 32),
                      _buildSubmitButton(),
                      const SizedBox(height: 16),
                      _buildDisclaimer(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ))),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  APP BAR
  // ════════════════════════════════════════════════════════════════

  SliverAppBar _buildAppBar() {
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
        S.of(context)!.annualRefreshTitle,
        style: MintTextStyles.headlineMedium().copyWith(fontSize: 18),
      ),
      surfaceTintColor: MintColors.white,
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  Q1 — SALAIRE
  // ════════════════════════════════════════════════════════════════

  Widget _buildSalaireCard() {
    return _questionCard(
      number: 1,
      title: S.of(context)!.annualRefreshQ1,
      child: Column(
        children: [
          MintPremiumSlider(
            label: 'Salaire brut mensuel',
            value: _salaireBrutMensuel.clamp(0, 30000),
            min: 0,
            max: 30000,
            divisions: 300,
            activeColor: MintColors.coachAccent,
            formatValue: (v) => '${v.toInt()} CHF / mois',
            onChanged: (v) => setState(() => _salaireBrutMensuel = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0 CHF', style: MintTextStyles.labelSmall()),
              Text('30\'000 CHF', style: MintTextStyles.labelSmall()),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  Q2 — EMPLOI
  // ════════════════════════════════════════════════════════════════

  Widget _buildEmploiCard() {
    final options = ['salarie', 'nouvel_emploi', 'independant', 'sans_emploi'];

    return _questionCard(
      number: 2,
      title: S.of(context)!.annualRefreshQ2,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((opt) {
          final isSelected = _employmentStatus == opt;
          return ChoiceChip(
            label: Text(_employmentLabel(context, opt)),
            selected: isSelected,
            onSelected: (_) => setState(() => _employmentStatus = opt),
            selectedColor: MintColors.coachAccent.withAlpha(30),
            checkmarkColor: MintColors.coachAccent,
            labelStyle: MintTextStyles.bodySmall(
              color: isSelected
                  ? MintColors.coachAccent
                  : MintColors.textSecondary,
            ).copyWith(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected
                    ? MintColors.coachAccent
                    : MintColors.border,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  Q3 — AVOIR LPP
  // ════════════════════════════════════════════════════════════════

  Widget _buildLppCard() {
    return _questionCard(
      number: 3,
      title: S.of(context)!.annualRefreshQ3,
      helpText: S.of(context)!.annualRefreshQ3Help,
      child: TextFormField(
        controller: _lppController,
        keyboardType: TextInputType.number,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InputDecoration(
          suffixText: 'CHF',
          suffixStyle: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: MintColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: MintColors.coachAccent, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        style: MintTextStyles.bodyLarge(color: MintColors.textPrimary),
        validator: (v) {
          final val = _parseChf(v ?? '');
          if (val < 0) return S.of(context)!.annualRefreshMontantPositif;
          return null;
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  Q4 — SOLDE 3A
  // ════════════════════════════════════════════════════════════════

  Widget _buildThreeACard() {
    return _questionCard(
      number: 4,
      title: S.of(context)!.annualRefreshQ4,
      helpText: S.of(context)!.annualRefreshQ4Help,
      child: TextFormField(
        controller: _threeAController,
        keyboardType: TextInputType.number,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InputDecoration(
          suffixText: 'CHF',
          suffixStyle: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: MintColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: MintColors.coachAccent, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        style: MintTextStyles.bodyLarge(color: MintColors.textPrimary),
        validator: (v) {
          final val = _parseChf(v ?? '');
          if (val < 0) return S.of(context)!.annualRefreshMontantPositif;
          return null;
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  Q5 — PROJET IMMOBILIER
  // ════════════════════════════════════════════════════════════════

  Widget _buildRealEstateCard() {
    final options = ['aucun', 'achat', 'vente', 'refinancement'];

    return _questionCard(
      number: 5,
      title: S.of(context)!.annualRefreshQ5,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((opt) {
          final isSelected = _realEstateProject == opt;
          return ChoiceChip(
            label: Text(_realEstateLabel(context, opt)),
            selected: isSelected,
            onSelected: (_) => setState(() => _realEstateProject = opt),
            selectedColor: MintColors.coachAccent.withAlpha(30),
            checkmarkColor: MintColors.coachAccent,
            labelStyle: MintTextStyles.bodySmall(
              color: isSelected
                  ? MintColors.coachAccent
                  : MintColors.textSecondary,
            ).copyWith(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected
                    ? MintColors.coachAccent
                    : MintColors.border,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  Q6 — CHANGEMENT FAMILIAL
  // ════════════════════════════════════════════════════════════════

  Widget _buildFamilyCard() {
    final options = ['aucun', 'mariage', 'naissance', 'divorce', 'deces'];

    return _questionCard(
      number: 6,
      title: S.of(context)!.annualRefreshQ6,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((opt) {
          final isSelected = _familyChange == opt;
          return ChoiceChip(
            label: Text(_familyLabel(context, opt)),
            selected: isSelected,
            onSelected: (_) => setState(() => _familyChange = opt),
            selectedColor: MintColors.coachAccent.withAlpha(30),
            checkmarkColor: MintColors.coachAccent,
            labelStyle: MintTextStyles.bodySmall(
              color: isSelected
                  ? MintColors.coachAccent
                  : MintColors.textSecondary,
            ).copyWith(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected
                    ? MintColors.coachAccent
                    : MintColors.border,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  Q7 — TOLERANCE AU RISQUE
  // ════════════════════════════════════════════════════════════════

  Widget _buildRiskCard() {
    final options = ['conservateur', 'modere', 'agressif'];

    return _questionCard(
      number: 7,
      title: S.of(context)!.annualRefreshQ7,
      child: Row(
        children: options.map((opt) {
          final isSelected = _riskTolerance == opt;
          return Expanded(
            child: Semantics(
              label: _riskLabel(context, opt),
              button: true,
              child: GestureDetector(
              onTap: () => setState(() => _riskTolerance = opt),
              child: Container(
                margin: EdgeInsets.only(
                  right: opt != options.last ? 8 : 0,
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? MintColors.coachAccent.withAlpha(15)
                      : MintColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? MintColors.coachAccent
                        : MintColors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _riskIcon(opt),
                      color: isSelected
                          ? MintColors.coachAccent
                          : MintColors.textMuted,
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _riskLabel(context, opt),
                      textAlign: TextAlign.center,
                      style: MintTextStyles.labelSmall(
                        color: isSelected
                            ? MintColors.coachAccent
                            : MintColors.textSecondary,
                      ).copyWith(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400),
                    ),
                  ],
                ),
              ),
            ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  SUBMIT BUTTON
  // ════════════════════════════════════════════════════════════════

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : () {
          HapticFeedback.lightImpact();
          _onSubmit();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: MintColors.coachAccent,
          foregroundColor: MintColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: MintColors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                S.of(context)!.annualRefreshSubmit,
                style: MintTextStyles.titleMedium(color: MintColors.white),
              ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  DISCLAIMER
  // ════════════════════════════════════════════════════════════════

  Widget _buildDisclaimer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        S.of(context)!.annualRefreshDisclaimer,
        textAlign: TextAlign.center,
        style: MintTextStyles.micro(color: MintColors.textMuted).copyWith(height: 1.5),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  RESULT SCREEN
  // ════════════════════════════════════════════════════════════════

  Widget _buildResultScreen() {
    final delta = (_newScore ?? 0) - (_oldScore ?? 0);
    final improved = delta > 0;
    final dropped = delta < 0;

    return Scaffold(
      backgroundColor: MintColors.background,
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 24),
                // Result icon
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: improved
                          ? MintColors.success.withAlpha(25)
                          : dropped
                              ? MintColors.warning.withAlpha(25)
                              : MintColors.coachAccent.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      improved
                          ? Icons.trending_up
                          : dropped
                              ? Icons.trending_down
                              : Icons.check_circle_outline,
                      size: 40,
                      color: improved
                          ? MintColors.success
                          : dropped
                              ? MintColors.warning
                              : MintColors.coachAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Title
                Text(
                  S.of(context)!.annualRefreshResult,
                  textAlign: TextAlign.center,
                  style: MintTextStyles.headlineMedium(),
                ),
                const SizedBox(height: 24),
                // Score comparison card
                MintSurface(
                  padding: const EdgeInsets.all(24),
                  radius: 16,
                  elevated: true,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _scoreColumn(
                            S.of(context)!.annualRefreshAvant,
                            _oldScore ?? 0,
                            MintColors.textMuted,
                          ),
                          const Icon(
                            Icons.arrow_forward,
                            color: MintColors.textMuted,
                            size: 24,
                          ),
                          _scoreColumn(
                            S.of(context)!.annualRefreshApres,
                            _newScore ?? 0,
                            MintColors.coachAccent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Delta text
                      if (improved)
                        Text(
                          S.of(context)!.annualRefreshScoreUp(delta),
                          textAlign: TextAlign.center,
                          style: MintTextStyles.bodyLarge(color: MintColors.success).copyWith(fontWeight: FontWeight.w600),
                        )
                      else if (dropped)
                        Text(
                          S.of(context)!.annualRefreshScoreDown(delta.abs()),
                          textAlign: TextAlign.center,
                          style: MintTextStyles.bodyLarge(color: MintColors.warning).copyWith(fontWeight: FontWeight.w600),
                        )
                      else
                        Text(
                          S.of(context)!.annualRefreshScoreStable,
                          textAlign: TextAlign.center,
                          style: MintTextStyles.bodyLarge(color: MintColors.coachAccent).copyWith(fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // CTA button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => context.go('/home'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MintColors.coachAccent,
                      foregroundColor: MintColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      S.of(context)!.annualRefreshRetour,
                      style: MintTextStyles.titleMedium(color: MintColors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildDisclaimer(),
              ]),
            ),
          ),
        ],
      ))),
    );
  }

  Widget _scoreColumn(String label, int score, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: MintTextStyles.bodySmall(),
        ),
        const SizedBox(height: MintSpacing.sm),
        Text(
          '$score',
          style: MintTextStyles.displayMedium(color: color).copyWith(fontSize: 36),
        ),
        Text(
          '/ 100',
          style: MintTextStyles.labelSmall(),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  REUSABLE QUESTION CARD
  // ════════════════════════════════════════════════════════════════

  Widget _questionCard({
    required int number,
    required String title,
    String? helpText,
    required Widget child,
  }) {
    return MintSurface(
      padding: const EdgeInsets.all(20),
      radius: 16,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: MintColors.coachAccent.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '$number',
                    style: MintTextStyles.bodyMedium(color: MintColors.coachAccent).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: MintTextStyles.bodyLarge(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (helpText != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 40),
                Expanded(
                  child: Text(
                    helpText,
                    style: MintTextStyles.labelSmall().copyWith(fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
