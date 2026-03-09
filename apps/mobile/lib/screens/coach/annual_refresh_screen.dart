import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';

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

  String _employmentLabel(String status) {
    switch (status) {
      case 'salarie':
        return 'Même emploi';
      case 'nouvel_emploi':
        return 'Nouvel emploi';
      case 'independant':
        return 'Indépendant\u00b7e';
      case 'chomage':
      case 'sans_emploi':
        return 'Sans emploi';
      default:
        return 'Même emploi';
    }
  }

  String _realEstateLabel(String project) {
    switch (project) {
      case 'aucun':
        return 'Aucun';
      case 'achat':
        return 'Achat';
      case 'vente':
        return 'Vente';
      case 'refinancement':
        return 'Refinancement';
      default:
        return 'Aucun';
    }
  }

  String _familyLabel(String change) {
    switch (change) {
      case 'aucun':
        return 'Aucun';
      case 'mariage':
        return 'Mariage';
      case 'naissance':
        return 'Naissance';
      case 'divorce':
        return 'Divorce';
      case 'deces':
        return 'Décès';
      default:
        return 'Aucun';
    }
  }

  String _riskLabel(String risk) {
    switch (risk) {
      case 'conservateur':
        return 'Conservateur';
      case 'modere':
        return 'Modéré';
      case 'agressif':
        return 'Agressif';
      default:
        return 'Modéré';
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
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  'Quelques questions rapides pour mettre ton profil à jour.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: MintColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildSalaireCard(),
                      const SizedBox(height: 16),
                      _buildEmploiCard(),
                      const SizedBox(height: 16),
                      _buildLppCard(),
                      const SizedBox(height: 16),
                      _buildThreeACard(),
                      const SizedBox(height: 16),
                      _buildRealEstateCard(),
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
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  APP BAR
  // ════════════════════════════════════════════════════════════════

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: MintColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [MintColors.primary, Color(0xFF2D2D30)],
            ),
          ),
        ),
        title: Text(
          'Check-up annuel',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  Q1 — SALAIRE
  // ════════════════════════════════════════════════════════════════

  Widget _buildSalaireCard() {
    return _questionCard(
      number: 1,
      title: 'Ton salaire brut mensuel a-t-il changé ?',
      child: Column(
        children: [
          Text(
            '${_salaireBrutMensuel.toInt()} CHF / mois',
            style: GoogleFonts.montserrat(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: MintColors.coachAccent,
            ),
          ),
          const SizedBox(height: 12),
          Slider(
            value: _salaireBrutMensuel.clamp(0, 30000),
            min: 0,
            max: 30000,
            divisions: 300,
            activeColor: MintColors.coachAccent,
            inactiveColor: MintColors.coachAccent.withAlpha(40),
            label: '${_salaireBrutMensuel.toInt()} CHF',
            onChanged: (v) => setState(() => _salaireBrutMensuel = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0 CHF',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: MintColors.textMuted)),
              Text('30\'000 CHF',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: MintColors.textMuted)),
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
      title: 'Ta situation professionnelle',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((opt) {
          final isSelected = _employmentStatus == opt;
          return ChoiceChip(
            label: Text(_employmentLabel(opt)),
            selected: isSelected,
            onSelected: (_) => setState(() => _employmentStatus = opt),
            selectedColor: MintColors.coachAccent.withAlpha(30),
            checkmarkColor: MintColors.coachAccent,
            labelStyle: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? MintColors.coachAccent
                  : MintColors.textSecondary,
            ),
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
      title: 'Ton avoir LPP actuel',
      helpText:
          'Regarde ton certificat de prévoyance (tu le reçois chaque janvier)',
      child: TextFormField(
        controller: _lppController,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InputDecoration(
          suffixText: 'CHF',
          suffixStyle: GoogleFonts.inter(
              fontSize: 14, color: MintColors.textSecondary),
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
        style: GoogleFonts.inter(fontSize: 16, color: MintColors.textPrimary),
        validator: (v) {
          final val = _parseChf(v ?? '');
          if (val < 0) return 'Le montant doit être positif';
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
      title: 'Ton solde 3a approximatif',
      helpText: 'Connecte-toi sur ton app 3a pour voir le solde exact',
      child: TextFormField(
        controller: _threeAController,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InputDecoration(
          suffixText: 'CHF',
          suffixStyle: GoogleFonts.inter(
              fontSize: 14, color: MintColors.textSecondary),
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
        style: GoogleFonts.inter(fontSize: 16, color: MintColors.textPrimary),
        validator: (v) {
          final val = _parseChf(v ?? '');
          if (val < 0) return 'Le montant doit être positif';
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
      title: 'Un projet immobilier en vue ?',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((opt) {
          final isSelected = _realEstateProject == opt;
          return ChoiceChip(
            label: Text(_realEstateLabel(opt)),
            selected: isSelected,
            onSelected: (_) => setState(() => _realEstateProject = opt),
            selectedColor: MintColors.coachAccent.withAlpha(30),
            checkmarkColor: MintColors.coachAccent,
            labelStyle: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? MintColors.coachAccent
                  : MintColors.textSecondary,
            ),
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
      title: 'Un changement familial cette année ?',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((opt) {
          final isSelected = _familyChange == opt;
          return ChoiceChip(
            label: Text(_familyLabel(opt)),
            selected: isSelected,
            onSelected: (_) => setState(() => _familyChange = opt),
            selectedColor: MintColors.coachAccent.withAlpha(30),
            checkmarkColor: MintColors.coachAccent,
            labelStyle: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? MintColors.coachAccent
                  : MintColors.textSecondary,
            ),
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
      title: 'Ta tolérance au risque',
      child: Row(
        children: options.map((opt) {
          final isSelected = _riskTolerance == opt;
          return Expanded(
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
                      _riskLabel(opt),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? MintColors.coachAccent
                            : MintColors.textSecondary,
                      ),
                    ),
                  ],
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
        onPressed: _isSubmitting ? null : _onSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: MintColors.coachAccent,
          foregroundColor: Colors.white,
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
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                'Mettre à jour mon profil',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
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
        'Cet outil est à but éducatif et ne constitue pas un conseil financier '
        'au sens de la LSFin. Consulte un\u00b7e spécialiste pour des conseils '
        'personnalisés.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 11,
          color: MintColors.textMuted,
          height: 1.5,
        ),
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
      body: CustomScrollView(
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
                  'Profil mis à jour !',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                // Score comparison card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: MintColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MintColors.lightBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _scoreColumn(
                            'Avant',
                            _oldScore ?? 0,
                            MintColors.textMuted,
                          ),
                          Icon(
                            Icons.arrow_forward,
                            color: MintColors.textMuted,
                            size: 24,
                          ),
                          _scoreColumn(
                            'Après',
                            _newScore ?? 0,
                            MintColors.coachAccent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Delta text
                      if (improved)
                        Text(
                          'Ton score a augmenté de $delta points !',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: MintColors.success,
                          ),
                        )
                      else if (dropped)
                        Text(
                          'Ton score a baissé de ${delta.abs()} points — vérifions ensemble',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: MintColors.warning,
                          ),
                        )
                      else
                        Text(
                          'Ton score est stable — continue comme ça !',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: MintColors.coachAccent,
                          ),
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
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Retour au dashboard',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildDisclaimer(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreColumn(String label, int score, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: MintColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$score',
          style: GoogleFonts.montserrat(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          '/ 100',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: MintColors.textMuted,
          ),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: MintColors.coachAccent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
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
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
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
