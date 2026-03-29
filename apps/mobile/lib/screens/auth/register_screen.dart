import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

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
  DateTime? _dateOfBirth;
  bool _acceptedCgu = false;
  bool _confirmed18Plus = false;
  bool _consentNotifications = false;
  bool _consentAnalytics = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
    _confirmPasswordController.addListener(() => setState(() {}));
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
      if (firstName.isNotEmpty || _dateOfBirth != null) {
        final answers = await ReportPersistenceService.loadAnswers();
        if (firstName.isNotEmpty) answers['q_firstname'] = firstName;
        if (_dateOfBirth != null) {
          // Store both for backward compatibility
          answers['q_birth_year'] = _dateOfBirth!.year;
          answers['q_date_of_birth'] = _dateOfBirth!.toIso8601String();
        }
        await ReportPersistenceService.saveAnswers(answers);
      }

      // Persist consent preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('consent_notifications', _consentNotifications);
      await prefs.setBool('consent_analytics', _consentAnalytics);
      await prefs.setBool('accepted_cgu_v1', true);
      await prefs.setString('cgu_accepted_at', DateTime.now().toIso8601String());

      if (!mounted) return;
      // F2-2: Email verification MUST happen before any redirect.
      // Flow: register -> verify-email -> redirect (not register -> redirect -> 403)
      if (authProvider.requiresEmailVerification) {
        // F3-2: Preserve redirect through the email verification step.
        final redirect = GoRouterState.of(context).uri.queryParameters['redirect'];
        if (redirect != null && redirect.startsWith('/')) {
          context.go('/auth/verify-email?redirect=${Uri.encodeComponent(redirect)}');
        } else {
          context.go('/auth/verify-email');
        }
      } else {
        final redirect = GoRouterState.of(context).uri.queryParameters['redirect'];
        if (redirect != null && redirect.startsWith('/')) {
          context.go(Uri.decodeComponent(redirect));
        } else {
          context.go('/home');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final l10n = S.of(context)!;

    return Scaffold(
      backgroundColor: MintColors.white,
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(MintSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: MintSpacing.xl),
                // Logo
                const MintEntrance(child: Center(
                  child: MintSurface(
                    padding: EdgeInsets.all(MintSpacing.md),
                    radius: 24,
                    elevated: true,
                    child: Icon(
                      Icons.token_rounded,
                      color: MintColors.primary,
                      size: 48,
                    ),
                  ),
                )),
                const SizedBox(height: MintSpacing.xl),
                // Title
                MintEntrance(delay: const Duration(milliseconds: 100), child: Text(
                  l10n.authRegisterTitle,
                  style: MintTextStyles.headlineLarge(),
                  textAlign: TextAlign.center,
                )),
                const SizedBox(height: MintSpacing.sm),
                MintEntrance(delay: const Duration(milliseconds: 200), child: Text(
                  l10n.authRegisterSubtitle,
                  style: MintTextStyles.bodyLarge(),
                  textAlign: TextAlign.center,
                )),
                const SizedBox(height: MintSpacing.md),
                MintEntrance(delay: const Duration(milliseconds: 300), child: MintSurface(
                  padding: const EdgeInsets.all(14),
                  radius: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.authWhyCreateAccount,
                        style: MintTextStyles.titleMedium().copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: MintSpacing.sm),
                      _RegisterBenefitRow(text: l10n.authBenefitProjections),
                      _RegisterBenefitRow(text: l10n.authBenefitCoach),
                      _RegisterBenefitRow(text: l10n.authBenefitSync),
                    ],
                  ),
                )),
                const SizedBox(height: MintSpacing.xxl),
                // Email field
                MintEntrance(delay: const Duration(milliseconds: 400), child: Semantics(
                  label: l10n.authEmail,
                  textField: true,
                  child: TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(
                      labelText: l10n.authEmail,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.authEmailInvalid;
                      }
                      if (!value.contains('@')) {
                        return l10n.authEmailInvalid;
                      }
                      return null;
                    },
                  ),
                )),
                const SizedBox(height: MintSpacing.md),
                // First name field (required for coach personalization)
                Semantics(
                  label: l10n.authFirstName,
                  textField: true,
                  child: TextFormField(
                    controller: _displayNameController,
                    autofillHints: const [AutofillHints.givenName],
                    textCapitalization: TextCapitalization.words,
                    maxLength: 50, // FIX-079
                    decoration: InputDecoration(
                      labelText: l10n.authFirstName,
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.authFirstNameRequired;
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: MintSpacing.md),
                // Date of birth picker (precise age for AVS/LPP calculations)
                Semantics(
                  label: l10n.authDateOfBirth,
                  button: true,
                  child: GestureDetector(
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dateOfBirth ?? DateTime(1980, 1, 1),
                        firstDate: DateTime(1940),
                        lastDate: now,
                        locale: const Locale('fr'),
                        helpText: l10n.authDateOfBirthHelp,
                        cancelText: l10n.authDateOfBirthCancel,
                        confirmText: l10n.authDateOfBirthConfirm,
                      );
                      if (picked != null) {
                        setState(() => _dateOfBirth = picked);
                      }
                    },
                    child: AbsorbPointer(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: l10n.authDateOfBirth,
                          prefixIcon: const Icon(Icons.cake_outlined),
                          hintText: l10n.authDateOfBirthHint,
                          suffixIcon: const Icon(Icons.calendar_today_outlined),
                        ),
                        controller: TextEditingController(
                          text: _dateOfBirth != null
                              ? '${_dateOfBirth!.day.toString().padLeft(2, '0')}.'
                                '${_dateOfBirth!.month.toString().padLeft(2, '0')}.'
                                '${_dateOfBirth!.year}'
                              : '',
                        ),
                        validator: (_) {
                          if (_dateOfBirth == null) {
                            return l10n.authDateOfBirthRequired;
                          }
                          final age = DateTime.now().year - _dateOfBirth!.year;
                          if (age < 18) {
                            return l10n.authDateOfBirthTooYoung;
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: MintSpacing.md),
                // Password field
                Semantics(
                  label: l10n.authPassword,
                  textField: true,
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.newPassword],
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: l10n.authPassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                      hintText: l10n.authPasswordHintFull,
                      suffixIcon: Semantics(
                        label: _obscurePassword
                            ? l10n.authShowPassword
                            : l10n.authHidePassword,
                        button: true,
                        child: IconButton(
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
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.authPasswordRequired;
                      }
                      if (value.length < 8) {
                        return l10n.authPasswordMinChars;
                      }
                      if (!value.contains(RegExp(r'[A-Z]'))) {
                        return l10n.authPasswordNeedUppercase;
                      }
                      if (!value.contains(RegExp(r'[0-9]'))) {
                        return l10n.authPasswordNeedDigit;
                      }
                      if (!value.contains(RegExp(r'[^A-Za-z0-9]'))) {
                        return l10n.authPasswordNeedSpecial;
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: MintSpacing.md),
                // Confirm password field
                Semantics(
                  label: l10n.authConfirmPassword,
                  textField: true,
                  child: TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    autofillHints: const [AutofillHints.newPassword],
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: l10n.authConfirmPassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Real-time match indicator
                          if (_confirmPasswordController.text.isNotEmpty)
                            Icon(
                              _confirmPasswordController.text ==
                                      _passwordController.text
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: _confirmPasswordController.text ==
                                      _passwordController.text
                                  ? MintColors.success
                                  : MintColors.error,
                              size: 20,
                            ),
                          Semantics(
                            label: _obscureConfirmPassword
                                ? l10n.authShowPassword
                                : l10n.authHidePassword,
                            button: true,
                            child: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.authConfirmRequired;
                      }
                      if (value != _passwordController.text) {
                        return l10n.authPasswordMismatch;
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: MintSpacing.md),
                // Password strength indicator
                _PasswordStrengthIndicator(
                  password: _passwordController.text,
                ),
                const SizedBox(height: MintSpacing.lg),
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
                      style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary,
                      ),
                      children: [
                        TextSpan(
                          text: l10n.authCguAccept,
                        ),
                        TextSpan(
                          text: l10n.authCguLink,
                          style: MintTextStyles.bodySmall(
                            color: MintColors.primary,
                          ).copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => context.go('/profile/consent'),
                        ),
                        TextSpan(
                          text: l10n.authCguAndPrivacy,
                        ),
                        TextSpan(
                          text: l10n.authPrivacyPolicyText,
                          style: MintTextStyles.bodySmall(
                            color: MintColors.primary,
                          ).copyWith(
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
                    l10n.authConfirm18,
                    style: MintTextStyles.bodySmall(
                      color: MintColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: MintSpacing.sm + 4),
                // "Consentements optionnels" divider
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: MintSpacing.sm + 4),
                      child: Text(
                        l10n.authConsentSection,
                        style: MintTextStyles.labelSmall(
                          color: MintColors.textMuted,
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
                    l10n.authConsentNotifications,
                    style: MintTextStyles.bodySmall(
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
                    l10n.authConsentAnalytics,
                    style: MintTextStyles.bodySmall(
                      color: MintColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: MintSpacing.sm),
                // Privacy reassurance text
                MintSurface(
                  tone: MintSurfaceTone.porcelaine,
                  padding: const EdgeInsets.all(MintSpacing.md),
                  radius: 12,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: MintColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: MintSpacing.sm + 4),
                      Expanded(
                        child: Text(
                          l10n.authPrivacyReassurance,
                          style: MintTextStyles.bodySmall(
                            color: MintColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MintSpacing.lg),
                // Error message
                if (authProvider.error != null)
                  Container(
                    padding: const EdgeInsets.all(MintSpacing.md),
                    decoration: BoxDecoration(
                      color: MintColors.error.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: MintColors.error.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: MintColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: MintSpacing.sm + 4),
                        Expanded(
                          child: Text(
                            localizeAuthError(authProvider.error!, l10n),
                            style: MintTextStyles.bodyMedium(
                              color: MintColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (authProvider.error != null) const SizedBox(height: MintSpacing.lg),
                // Register button
                Semantics(
                  label: l10n.authCreateAccount,
                  button: true,
                  child: FilledButton(
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
                        : Text(l10n.authCreateAccount),
                  ),
                ),
                const SizedBox(height: MintSpacing.sm + 4),
                Semantics(
                  label: l10n.authContinueLocal,
                  button: true,
                  child: OutlinedButton(
                    onPressed: authProvider.isLoading
                        ? null
                        : () {
                            context.go('/onboarding/quick');
                          },
                    child: Text(l10n.authContinueLocal),
                  ),
                ),
                const SizedBox(height: MintSpacing.xl),
                // Login link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.authAlreadyAccount,
                      style: MintTextStyles.bodyMedium(),
                    ),
                    const SizedBox(width: MintSpacing.sm),
                    TextButton(
                      onPressed: () {
                        context.go('/auth/login');
                      },
                      child: Text(
                        l10n.authLogin,
                        style: MintTextStyles.bodyMedium(
                          color: MintColors.primary,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MintSpacing.md),
                // Back to landing
                TextButton(
                  onPressed: () {
                    context.go('/');
                  },
                  child: Text(
                    l10n.authBack,
                    style: MintTextStyles.bodyMedium(
                      color: MintColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ))),
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
            margin: EdgeInsets.only(right: i < 3 ? MintSpacing.xs : 0),
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
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: MintTextStyles.bodySmall(
                color: MintColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
