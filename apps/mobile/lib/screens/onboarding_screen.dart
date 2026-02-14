import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/models/profile.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/analytics_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0;
  HouseholdType? _selectedHousehold;
  Goal? _selectedGoal;
  String? _selectedCanton;
  int? _birthYear;
  late DateTime _startTime;

  final List<String> _cantons = [
    'AG', 'AI', 'AR', 'BE', 'BL', 'BS', 'FR', 'GE', 'GL', 'GR',
    'JU', 'LU', 'NE', 'NW', 'OW', 'SG', 'SH', 'SO', 'SZ', 'TG',
    'TI', 'UR', 'VD', 'VS', 'ZG', 'ZH',
  ];

  final AnalyticsService _analytics = AnalyticsService();

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _analytics.trackOnboardingStarted();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    _buildStepContent(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentStep > 0)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 20, color: MintColors.textSecondary),
                  onPressed: () => setState(() => _currentStep--),
                )
              else
                const SizedBox(width: 48),
              Text(
                'Étape ${_currentStep + 1} sur 4',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: MintColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              // Skip button for optional steps
              if (_currentStep == 2)
                TextButton(
                  onPressed: () {
                    _analytics.trackEvent('onboarding_step_skipped',
                      category: 'engagement',
                      data: {'step': 3, 'step_name': 'location_details'}
                    );
                    setState(() => _currentStep++);
                  },
                  child: Text(
                    s?.onboardingSkip ?? 'Passer',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textSecondary,
                    ),
                  ),
                )
              else
                const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 16),
          // Progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: index == _currentStep ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: index <= _currentStep ? MintColors.primary : MintColors.surface,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep(
          title: S.of(context)?.onboardingStep1Title ?? 'Bonjour, je suis ton mentor.',
          subtitle: S.of(context)?.onboardingStep1Subtitle ?? 'Commençons par faire connaissance. Quelle est ta situation actuelle ?',
          child: Column(
            children: [
              _buildChoiceCard(
                icon: Icons.person_outline,
                title: S.of(context)?.onboardingHouseholdSingle ?? 'Seul(e)',
                description: S.of(context)?.onboardingHouseholdSingleDesc ?? 'Je gère mes finances en solo',
                isSelected: _selectedHousehold == HouseholdType.single,
                onTap: () => _handleChoice(() => _selectedHousehold = HouseholdType.single, 'household_single'),
              ),
              _buildChoiceCard(
                icon: Icons.people_outline,
                title: S.of(context)?.onboardingHouseholdCouple ?? 'En couple',
                description: S.of(context)?.onboardingHouseholdCoupleDesc ?? 'Nous partageons nos objectifs financiers',
                isSelected: _selectedHousehold == HouseholdType.couple,
                onTap: () => _handleChoice(() => _selectedHousehold = HouseholdType.couple, 'household_couple'),
              ),
              _buildChoiceCard(
                icon: Icons.family_restroom_outlined,
                title: S.of(context)?.onboardingHouseholdFamily ?? 'Famille',
                description: S.of(context)?.onboardingHouseholdFamilyDesc ?? 'Avec enfant(s) à charge',
                isSelected: _selectedHousehold == HouseholdType.family,
                onTap: () => _handleChoice(() => _selectedHousehold = HouseholdType.family, 'household_family'),
              ),
            ],
          ),
        );
      case 1:
        return _buildStep(
          title: S.of(context)?.onboardingStep2Title ?? 'Très bien.',
          subtitle: S.of(context)?.onboardingStep2Subtitle ?? 'Quel est le voyage financier que tu souhaites entreprendre en priorité ?',
          child: Column(
            children: [
              _buildChoiceCard(
                icon: Icons.home_outlined,
                title: S.of(context)?.onboardingGoalHouse ?? 'Devenir propriétaire',
                description: S.of(context)?.onboardingGoalHouseDesc ?? 'Préparer mon apport et mon hypothèque',
                isSelected: _selectedGoal == Goal.house,
                onTap: () => _handleChoice(() => _selectedGoal = Goal.house, 'goal_house'),
              ),
              _buildChoiceCard(
                icon: Icons.wb_sunny_outlined,
                title: S.of(context)?.onboardingGoalRetire ?? 'Sérénité Retraite',
                description: S.of(context)?.onboardingGoalRetireDesc ?? 'Maximiser mon avenir à long terme',
                isSelected: _selectedGoal == Goal.retire,
                onTap: () => _handleChoice(() => _selectedGoal = Goal.retire, 'goal_retire'),
              ),
              _buildChoiceCard(
                icon: Icons.trending_up,
                title: S.of(context)?.onboardingGoalInvest ?? 'Investir & Grandir',
                description: S.of(context)?.onboardingGoalInvestDesc ?? 'Fructifier mes économies intelligemment',
                isSelected: _selectedGoal == Goal.invest,
                onTap: () => _handleChoice(() => _selectedGoal = Goal.invest, 'goal_invest'),
              ),
              _buildChoiceCard(
                icon: Icons.account_balance_outlined,
                title: S.of(context)?.onboardingGoalTaxOptim ?? 'Optimisation Fiscale',
                description: S.of(context)?.onboardingGoalTaxOptimDesc ?? 'Réduire mes impôts légalement',
                isSelected: _selectedGoal == Goal.optimizeTaxes,
                onTap: () => _handleChoice(() => _selectedGoal = Goal.optimizeTaxes, 'goal_optimize_taxes'),
              ),
            ],
          ),
        );
      case 2:
        return _buildStep(
          title: S.of(context)?.onboardingStep3Title ?? 'Presque là.',
          subtitle: S.of(context)?.onboardingStep3Subtitle ?? 'Ces détails nous permettent de personnaliser tes calculs selon la loi suisse.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.of(context)?.onboardingCantonLabel ?? 'Canton de résidence',
                style: const TextStyle(fontWeight: FontWeight.w500, color: MintColors.textPrimary),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCanton,
                style: GoogleFonts.montserrat(color: MintColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: S.of(context)?.onboardingCantonHint ?? 'Sélectionne ton canton',
                  hintStyle: const TextStyle(color: MintColors.textMuted, fontSize: 14),
                  fillColor: MintColors.surface,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: _cantons.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (value) {
                  setState(() => _selectedCanton = value);
                },
              ),
              const SizedBox(height: 24),
              Text(
                S.of(context)?.onboardingBirthYearLabel ?? 'Année de naissance (optionnel)',
                style: const TextStyle(fontWeight: FontWeight.w500, color: MintColors.textPrimary),
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: InputDecoration(
                  hintText: S.of(context)?.onboardingBirthYearHint ?? 'Ex: 1990',
                  hintStyle: const TextStyle(color: MintColors.textMuted, fontSize: 14),
                  fillColor: MintColors.surface,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => _birthYear = int.tryParse(value),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selectedCanton != null ? () {
                    _analytics.trackOnboardingStep(
                      3,
                      'location_details',
                      totalSteps: 4,
                    );
                    setState(() => _currentStep++);
                  } : null,
                  child: Text(S.of(context)?.onboardingContinue ?? 'Continuer'),
                ),
              ),
            ],
          ),
        );
      case 3:
        return _buildStep(
          title: S.of(context)?.onboardingStep4Title ?? 'Prêt à commencer ?',
          subtitle: S.of(context)?.onboardingStep4Subtitle ?? 'Mint est un environnement sûr. Voici nos engagements envers toi.',
          child: Column(
            children: [
              _buildTrustTile(Icons.remove_red_eye_outlined, S.of(context)?.onboardingTrustTransparency ?? 'Transparence totale', S.of(context)?.onboardingTrustTransparencyDesc ?? 'Toutes les hypothèses sont visibles.'),
              _buildTrustTile(Icons.lock_outline, S.of(context)?.onboardingTrustPrivacy ?? 'Vie privée', S.of(context)?.onboardingTrustPrivacyDesc ?? 'Calculs locaux, pas de stockage de données sensibles.'),
              _buildTrustTile(Icons.shield_outlined, S.of(context)?.onboardingTrustSecurity ?? 'Sécurité', S.of(context)?.onboardingTrustSecurityDesc ?? 'Aucun accès direct à ton argent.'),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _createProfileAndNavigate,
                  child: Text(S.of(context)?.onboardingEnterSpace ?? 'Entrer dans mon espace'),
                ),
              ),
            ],
          ),
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildStep({required String title, required String subtitle, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: MintColors.textPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 16,
            color: MintColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        child,
      ],
    );
  }

  Widget _buildChoiceCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected ? MintColors.appleSurface : MintColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? MintColors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: MintColors.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: MintColors.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrustTile(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: MintColors.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
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

  Widget _buildBottomNavigation() {
    return const SizedBox(height: 20); // Spacing, as buttons are now in steps or auto-advancing
  }

  void _handleChoice(VoidCallback action, String stepName) {
    setState(action);

    // Track step completion
    _analytics.trackOnboardingStep(
      _currentStep + 1,
      stepName,
      totalSteps: 4,
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _currentStep++);
      }
    });
  }

  void _createProfileAndNavigate() {
    final timeSpent = DateTime.now().difference(_startTime).inSeconds;

    // Track onboarding completion
    _analytics.trackOnboardingCompleted(timeSpentSeconds: timeSpent);

    final profile = Profile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      householdType: _selectedHousehold ?? HouseholdType.single,
      goal: _selectedGoal ?? Goal.invest,
      canton: _selectedCanton,
      birthYear: _birthYear,
      createdAt: DateTime.now(),
    );

    context.read<ProfileProvider>().setProfile(profile);
    context.go('/home');
  }
}
