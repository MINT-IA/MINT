import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/theme/colors.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int? _birthYear;
  bool _acceptedCgu = false;
  bool _confirmed18Plus = false;
  bool _consentNotifications = false;
  bool _consentAnalytics = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.register(
      _emailController.text.trim(),
      _passwordController.text,
      displayName: _displayNameController.text.trim().isEmpty
          ? null
          : _displayNameController.text.trim(),
    );

    if (mounted && success) {
      // Persist registration data to profile answers so onboarding
      // can pre-fill and CoachProfile gets the firstName + birthYear.
      final firstName = _displayNameController.text.trim();
      if (firstName.isNotEmpty || _birthYear != null) {
        final answers = await ReportPersistenceService.loadAnswers();
        if (firstName.isNotEmpty) answers['q_firstname'] = firstName;
        if (_birthYear != null) answers['q_birth_year'] = _birthYear;
        await ReportPersistenceService.saveAnswers(answers);
      }

      // Persist consent preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('consent_notifications', _consentNotifications);
      await prefs.setBool('consent_analytics', _consentAnalytics);
      await prefs.setBool('accepted_cgu_v1', true);
      await prefs.setString('cgu_accepted_at', DateTime.now().toIso8601String());

      if (!mounted) return;
      final redirect = GoRouterState.of(context).uri.queryParameters['redirect'];
      if (redirect != null && redirect.startsWith('/')) {
        context.go(Uri.decodeComponent(redirect));
      } else if (authProvider.requiresEmailVerification) {
        context.go('/auth/verify-email');
      } else {
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: MintColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                // Logo
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: MintColors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: MintColors.black.withValues(alpha: 0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.token_rounded,
                      color: MintColors.primary,
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Title
                Text(
                  S.of(context)?.authRegisterTitle ?? 'Créer ton compte',
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                    letterSpacing: -1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Compte optionnel: tes données restent locales par défaut',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: MintColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: MintColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: MintColors.primary.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pourquoi créer un compte ?',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: MintColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const _RegisterBenefitRow(
                        text: 'Projections AVS/LPP alignees a ta situation',
                      ),
                      const _RegisterBenefitRow(
                        text: 'Coach personnalise avec ton prenom',
                      ),
                      const _RegisterBenefitRow(
                        text: 'Sauvegarde cloud + synchronisation multi-appareils',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                // Email field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: S.of(context)?.authEmail ?? 'Adresse e-mail',
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return S.of(context)?.authEmailInvalid ??
                          'Adresse e-mail invalide';
                    }
                    if (!value.contains('@')) {
                      return S.of(context)?.authEmailInvalid ??
                          'Adresse e-mail invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // First name field (required for coach personalization)
                TextFormField(
                  controller: _displayNameController,
                  autofillHints: const [AutofillHints.givenName],
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Prenom',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le prenom est necessaire pour personnaliser ton coach';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Birth year dropdown (LPD minimisation: only year needed for AVS/LPP)
                DropdownButtonFormField<int>(
                  value: _birthYear,
                  decoration: const InputDecoration(
                    labelText: 'Annee de naissance',
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                  items: List.generate(
                    DateTime.now().year - 1940 + 1,
                    (i) {
                      final year = DateTime.now().year - i;
                      return DropdownMenuItem(
                        value: year,
                        child: Text('$year'),
                      );
                    },
                  ),
                  onChanged: (value) => setState(() => _birthYear = value),
                  validator: (value) {
                    if (value == null) {
                      return 'Necessaire pour les projections AVS/LPP';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Password field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: S.of(context)?.authPassword ?? 'Mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline),
                    hintText:
                        S.of(context)?.authPasswordHint ?? 'Minimum 8 caractères',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Mot de passe requis';
                    }
                    if (value.length < 8) {
                      return S.of(context)?.authPasswordTooShort ??
                          'Le mot de passe doit contenir au moins 8 caractères';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Confirm password field
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: S.of(context)?.authConfirmPassword ??
                        'Confirmer le mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return S.of(context)?.authPasswordMismatch ??
                          'Les mots de passe ne correspondent pas';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Password strength indicator
                _PasswordStrengthIndicator(
                  password: _passwordController.text,
                ),
                const SizedBox(height: 24),
                // ── CGU & Consent checkboxes ──
                // CGU checkbox (required, non-pre-checked)
                CheckboxListTile(
                  value: _acceptedCgu,
                  onChanged: (v) => setState(() => _acceptedCgu = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: MintColors.textSecondary,
                      ),
                      children: [
                        TextSpan(
                          text: S.of(context)!.authCguAccept,
                        ),
                        TextSpan(
                          text: S.of(context)!.authCguLink,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: MintColors.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => context.go('/profile/consent'),
                        ),
                        TextSpan(
                          text: S.of(context)!.authCguAndPrivacy,
                        ),
                        TextSpan(
                          text: 'politique de confidentialité',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: MintColors.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => context.go('/profile/consent'),
                        ),
                        const TextSpan(text: ' *'),
                      ],
                    ),
                  ),
                ),
                // 18+ checkbox (required, non-pre-checked)
                CheckboxListTile(
                  value: _confirmed18Plus,
                  onChanged: (v) =>
                      setState(() => _confirmed18Plus = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    S.of(context)!.authConfirm18,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MintColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // "Consentements optionnels" divider
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        S.of(context)!.authConsentSection,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: MintColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                // Notifications checkbox (optional)
                CheckboxListTile(
                  value: _consentNotifications,
                  onChanged: (v) =>
                      setState(() => _consentNotifications = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    S.of(context)!.authConsentNotifications,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MintColors.textSecondary,
                    ),
                  ),
                ),
                // Analytics checkbox (optional)
                CheckboxListTile(
                  value: _consentAnalytics,
                  onChanged: (v) =>
                      setState(() => _consentAnalytics = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    S.of(context)!.authConsentAnalytics,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MintColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Privacy reassurance text
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MintColors.appleSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: MintColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          S.of(context)!.authPrivacyReassurance,
                          style: GoogleFonts.inter(
                            color: MintColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Error message
                if (authProvider.error != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: MintColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: MintColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            authProvider.error!,
                            style: GoogleFonts.inter(
                              color: MintColors.error,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (authProvider.error != null) const SizedBox(height: 24),
                // Register button
                FilledButton(
                  onPressed: (_acceptedCgu && _confirmed18Plus && !authProvider.isLoading) ? _handleRegister : null,
                  child: authProvider.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(MintColors.white),
                          ),
                        )
                      : Text(
                          S.of(context)?.authCreateAccount ??
                              'Créer mon compte',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: authProvider.isLoading
                      ? null
                      : () {
                          context.go('/onboarding/quick');
                        },
                  child: Text(
                    'Continuer en mode local',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Login link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      S.of(context)?.authAlreadyAccount ?? 'Déjà inscrit ?',
                      style: GoogleFonts.inter(
                        color: MintColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        context.go('/auth/login');
                      },
                      child: Text(
                        S.of(context)?.authLogin ?? 'Se connecter',
                        style: GoogleFonts.inter(
                          color: MintColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Back to landing
                TextButton(
                  onPressed: () {
                    context.go('/');
                  },
                  child: Text(
                    'Retour',
                    style: GoogleFonts.inter(
                      color: MintColors.textMuted,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const _PasswordStrengthIndicator({required this.password});

  int _computeStrength() {
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 8) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[^A-Za-z0-9]'))) score++;
    return score;
  }

  @override
  Widget build(BuildContext context) {
    final strength = _computeStrength();
    const colors = [
      MintColors.error,
      MintColors.scoreAttention,
      MintColors.warning,
      MintColors.success,
    ];

    return Row(
      children: List.generate(4, (i) {
        final isActive = i < strength;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
            decoration: BoxDecoration(
              color: isActive
                  ? colors[strength - 1]
                  : MintColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class _RegisterBenefitRow extends StatelessWidget {
  final String text;

  const _RegisterBenefitRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.check_circle_outline,
              size: 16,
              color: MintColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
