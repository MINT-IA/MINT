import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/screens/auth/auth_platform.dart';
import 'package:mint_mobile/screens/auth/auth_redirect.dart';
import 'package:mint_mobile/services/apple_sign_in_service.dart';
import 'package:mint_mobile/services/dob_age_calculator.dart';
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
  bool _showEmailForm = true;
  bool _appleSignInLoading = false;
  String? _appleSignInError;

  /// P2-17: Guard to prevent concurrent SharedPreferences writes.
  bool _isWriting = false;

  @override
  void initState() {
    super.initState();
    _showEmailForm = !canShowAppleSignIn;
    _passwordController.addListener(() => setState(() {}));
    _confirmPasswordController.addListener(() => setState(() {}));
    // Clear any stale auth error that would otherwise surface a red "Action
    // impossible" banner the moment the screen mounts — killing conversion
    // before the user has done anything. Fresh arrival = fresh form.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthProvider>().clearError();
    });
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
    // P2-17: Prevent concurrent writes
    if (_isWriting) return;
    _isWriting = true;

    try {
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
          answers['q_date_of_birth'] =
              _dateOfBirth!.toIso8601String().split('T').first;
        }
        await ReportPersistenceService.saveAnswers(answers);
      }

      await _persistConsentPreferences();

      if (!mounted) return;
      // F2-2: Email verification MUST happen before any redirect.
      // Flow: register -> verify-email -> redirect (not register -> redirect -> 403)
      if (authProvider.requiresEmailVerification) {
        context.go(authRouteWithRedirect(
          '/auth/verify-email',
          GoRouterState.of(context).uri,
        ));
      } else {
        _goAfterAccountCreated();
      }
    }
    } finally {
      _isWriting = false;
    }
  }

  Future<void> _handleAppleSignIn() async {
    if (_isWriting || _appleSignInLoading) return;
    if (!_acceptedCgu || !_confirmed18Plus) {
      setState(() {
        _appleSignInError = S.of(context)!.authRequiredConsents;
      });
      return;
    }

    _isWriting = true;
    setState(() {
      _appleSignInLoading = true;
      _appleSignInError = null;
    });

    final authProvider = context.read<AuthProvider>();
    try {
      final response = await AppleSignInService.signIn();
      if (response == null || !mounted) return;

      final ok = await authProvider.completeAppleSignIn(response);
      if (!ok) {
        if (!mounted) return;
        setState(() {
          _appleSignInError = authProvider.error != null
              ? localizeAuthError(authProvider.error!, S.of(context)!)
              : S.of(context)!.authErrorGeneric;
        });
        return;
      }

      await _persistConsentPreferences();
      if (!mounted) return;
      _goAfterAccountCreated();
    } catch (_) {
      if (mounted) {
        setState(() {
          _appleSignInError = S.of(context)!.authErrorGeneric;
        });
      }
    } finally {
      _isWriting = false;
      if (mounted) {
        setState(() => _appleSignInLoading = false);
      }
    }
  }

  Future<void> _persistConsentPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('consent_notifications', _consentNotifications);
    await prefs.setBool('consent_analytics', _consentAnalytics);
    await prefs.setBool('accepted_cgu_v1', true);
    await prefs.setString('cgu_accepted_at', DateTime.now().toIso8601String());
  }

  void _goAfterAccountCreated() {
    final redirect = resolvePostAuthRedirect(GoRouterState.of(context).uri);
    // KILL-05: all post-auth routing goes to /coach/chat when no explicit
    // safe handoff destination is present.
    context.go(redirect ?? '/coach/chat');
  }

  Widget _buildRequiredConsents(S l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          value: _acceptedCgu,
          onChanged: (v) => setState(() {
            _acceptedCgu = v ?? false;
            _appleSignInError = null;
          }),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: RichText(
            text: TextSpan(
              style: MintTextStyles.bodySmall(
                color: MintColors.textSecondary,
              ),
              children: [
                TextSpan(text: l10n.authCguAccept),
                TextSpan(
                  text: l10n.authCguLink,
                  style: MintTextStyles.bodySmall(
                    color: MintColors.primary,
                  ).copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => context.push('/about'),
                ),
                TextSpan(text: l10n.authCguAndPrivacy),
                TextSpan(
                  text: l10n.authPrivacyPolicyText,
                  style: MintTextStyles.bodySmall(
                    color: MintColors.primary,
                  ).copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => context.push('/about'),
                ),
                const TextSpan(text: ' *'),
              ],
            ),
          ),
        ),
        CheckboxListTile(
          value: _confirmed18Plus,
          onChanged: (v) => setState(() {
            _confirmed18Plus = v ?? false;
            _appleSignInError = null;
          }),
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final l10n = S.of(context)!;
    final accountActionBusy = authProvider.isLoading || _appleSignInLoading;

    return Scaffold(
      backgroundColor: MintColors.white,
      // BUG-W2026-07: persistent top-bar back button. Without this, the user
      // is trapped 5 fields + 4 checkboxes deep before they reach the bottom
      // "Retour" link, and iOS edge-swipe-back is unreliable from a `go` push.
      // We match the sibling auth pattern (`forgot_password_screen` /
      // `verify_email_screen`) — plain `AppBar`, MintColors.white, elevation 0
      // — but skip the title to avoid duplicating the body's `MintEntrance`
      // headline. Leading is an explicit IconButton: `Navigator.pop` if the
      // route is poppable, otherwise `context.go('/auth/login')` because the
      // landing→login→register entry path uses `context.go` (replaces the
      // stack, so `canPop` is false).
      appBar: AppBar(
        backgroundColor: MintColors.white,
        surfaceTintColor: MintColors.white,
        elevation: 0,
        leading: Semantics(
          label: l10n.semanticsBack,
          button: true,
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: l10n.authBack,
            color: MintColors.textPrimary,
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/auth/login');
              }
            },
          ),
        ),
      ),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(MintSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: MintSpacing.xl),
                // Brand mark — typographic, consistent with LandingScreen.
                // Was a generic `Icons.token_rounded` in a soft surface; it
                // read as a misplaced UI chip on an otherwise text-heavy
                // form. The letter-spaced wordmark keeps the identity
                // without adding a second visual language.
                MintEntrance(
                  child: Center(
                    child: Text(
                      'MINT',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            color: MintColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 4,
                          ),
                    ),
                  ),
                ),
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
                if (_showEmailForm || !canShowAppleSignIn) ...[
                const SizedBox(height: MintSpacing.md),
                MintEntrance(delay: const Duration(milliseconds: 300), child: MintSurface(
                  padding: const EdgeInsets.all(14),
                  radius: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.authWhyCreateAccount,
                        style: MintTextStyles.bodyMedium().copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: MintSpacing.sm),
                      _RegisterBenefitRow(text: l10n.authBenefitProjections),
                      _RegisterBenefitRow(text: l10n.authBenefitCoach),
                      _RegisterBenefitRow(text: l10n.authBenefitSync),
                    ],
                  ),
                )),
                const SizedBox(height: MintSpacing.xxl),
                ] else
                  const SizedBox(height: MintSpacing.lg),
                if (canShowAppleSignIn) ...[
                  _buildRequiredConsents(l10n),
                  const SizedBox(height: MintSpacing.lg),
                ],
                if (canShowAppleSignIn) ...[
                  SizedBox(
                    height: 48,
                    child: _appleSignInLoading
                        ? const Center(
                            child: SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : SignInWithAppleButton(
                            onPressed: _handleAppleSignIn,
                            style: SignInWithAppleButtonStyle.black,
                          ),
                  ),
                  if (_appleSignInError != null) ...[
                    const SizedBox(height: MintSpacing.sm),
                    Text(
                      _appleSignInError!,
                      style: MintTextStyles.bodySmall(color: MintColors.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: MintSpacing.sm + 4),
                  if (!_showEmailForm) ...[
                    OutlinedButton(
                      onPressed: accountActionBusy
                          ? null
                          : () {
                              setState(() {
                                _showEmailForm = true;
                                _appleSignInError = null;
                              });
                            },
                      child: Text(l10n.authCreateWithEmail),
                    ),
                    const SizedBox(height: MintSpacing.lg),
                  ],
                ],
                if (_showEmailForm) ...[
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
                        initialDate: _dateOfBirth ?? DateTime(now.year - 35, 1, 1),
                        firstDate: DateTime(now.year - 99),
                        lastDate: DateTime(now.year - 18, now.month, now.day),
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
                          if (yearsBetween(_dateOfBirth!, DateTime.now()) < 18) {
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
                if (!canShowAppleSignIn) ...[
                  _buildRequiredConsents(l10n),
                  const SizedBox(height: MintSpacing.sm + 4),
                ],
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
                    onPressed: (_acceptedCgu &&
                            _confirmed18Plus &&
                            !accountActionBusy)
                        ? () {
                            HapticFeedback.lightImpact();
                            _handleRegister();
                          }
                        : null,
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
                ],
                Semantics(
                  label: l10n.authContinueLocal,
                  button: true,
                  child: OutlinedButton(
                    onPressed: accountActionBusy
                        ? null
                        : () async {
                            await authProvider.enableLocalMode();
                            if (!context.mounted) return;
                            final redirect = resolvePostAuthRedirect(
                              GoRouterState.of(context).uri,
                            );
                            context.go(redirect ?? '/home');
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
