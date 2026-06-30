import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/auth/auth_platform.dart';
import 'package:mint_mobile/screens/auth/auth_redirect.dart';
import 'package:mint_mobile/services/account_handoff_service.dart';
import 'package:mint_mobile/services/apple_sign_in_service.dart';
import 'package:mint_mobile/services/dob_age_calculator.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/auth/account_handoff_choice_panel.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _e2eRuntimeEnabled = !kReleaseMode;
  static const _e2eRegisterDob = _e2eRuntimeEnabled
      ? String.fromEnvironment(
          'MINT_E2E_REGISTER_DOB',
        )
      : '';
  static const _e2eRegisterFirstName = _e2eRuntimeEnabled
      ? String.fromEnvironment(
          'MINT_E2E_REGISTER_FIRST_NAME',
        )
      : '';
  static const _e2eRegisterPassword = _e2eRuntimeEnabled
      ? String.fromEnvironment(
          'MINT_E2E_REGISTER_PASSWORD',
        )
      : '';
  static const _e2eAcceptRequiredConsents = bool.fromEnvironment(
        'MINT_E2E_ACCEPT_REQUIRED_CONSENTS',
      ) &&
      _e2eRuntimeEnabled;
  static const _e2eAutoSubmitRegister = bool.fromEnvironment(
        'MINT_E2E_AUTO_SUBMIT_REGISTER',
      ) &&
      _e2eRuntimeEnabled;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _displayNameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  DateTime? _dateOfBirth;
  bool _acceptedCgu = _e2eAcceptRequiredConsents;
  bool _confirmed18Plus = _e2eAcceptRequiredConsents;
  bool _consentNotifications = false;
  bool _consentAnalytics = false;
  bool _showEmailForm = true;
  bool _appleSignInLoading = false;
  String? _appleSignInError;
  bool _handoffChoiceRequired = false;
  bool _e2eRegisterAutoSubmitScheduled = false;
  bool _e2eRegisterEmailApplied = false;

  /// P2-17: Guard to prevent concurrent SharedPreferences writes.
  bool _isWriting = false;

  @override
  void initState() {
    super.initState();
    // Account creation must not depend on Apple Sign-In availability or
    // provisioning state. TestFlight users get the email path immediately.
    _showEmailForm = true;
    _dateOfBirth = _e2eDateOfBirthOverride();
    if (_e2eRegisterFirstName.isNotEmpty) {
      _displayNameController.text = _e2eRegisterFirstName;
    }
    if (_e2eRegisterPassword.isNotEmpty) {
      _passwordController.text = _e2eRegisterPassword;
      _confirmPasswordController.text = _e2eRegisterPassword;
    }
    _emailController.addListener(_maybeScheduleE2eRegisterSubmit);
    _displayNameController.addListener(_maybeScheduleE2eRegisterSubmit);
    _passwordController.addListener(_onPasswordFieldChanged);
    _confirmPasswordController.addListener(_onPasswordFieldChanged);
    // Clear any stale auth error that would otherwise surface a red "Action
    // impossible" banner the moment the screen mounts — killing conversion
    // before the user has done anything. Fresh arrival = fresh form.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthProvider>().clearError();
      _refreshHandoffChoiceRequired();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    _emailFocusNode.dispose();
    _displayNameFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_e2eAutoSubmitRegister || _e2eRegisterEmailApplied) return;

    final email =
        GoRouterState.of(context).uri.queryParameters['e2e_email']?.trim();
    if (email == null || email.isEmpty) return;

    _e2eRegisterEmailApplied = true;
    _emailController.text = email;
    _maybeScheduleE2eRegisterSubmit();
  }

  Widget _runtimeTextFieldAnchor({
    required String identifier,
    required String label,
    required FocusNode focusNode,
    required Widget child,
  }) {
    return Semantics(
      key: ValueKey('${identifier}_semantics'),
      identifier: identifier,
      label: label,
      textField: true,
      container: true,
      onTap: focusNode.requestFocus,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: focusNode.requestFocus,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: child,
        ),
      ),
    );
  }

  void _onPasswordFieldChanged() {
    setState(() {});
    _maybeScheduleE2eRegisterSubmit();
  }

  void _maybeScheduleE2eRegisterSubmit() {
    if (!_e2eAutoSubmitRegister ||
        _e2eRegisterAutoSubmitScheduled ||
        _isWriting) {
      return;
    }

    final email = _emailController.text.trim();
    final firstName = _displayNameController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    // Keep this readiness gate in sync with the real field validators below:
    // if it is looser, E2E auto-submit schedules once and then silently stalls.
    final formReady = email.contains('@') &&
        firstName.isNotEmpty &&
        _dateOfBirth != null &&
        _acceptedCgu &&
        _confirmed18Plus &&
        password.length >= 8 &&
        password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[0-9]')) &&
        password.contains(RegExp(r'[^A-Za-z0-9]')) &&
        confirmPassword == password;

    if (!formReady) return;

    _e2eRegisterAutoSubmitScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_handleRegister());
    });
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!await _canStartAccountAction()) return;
    if (!mounted) return;
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
          await _goAfterAccountCreated();
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
    if (!await _canStartAccountAction()) return;
    if (!mounted) return;

    _isWriting = true;
    setState(() {
      _appleSignInLoading = true;
      _appleSignInError = null;
    });

    final authProvider = context.read<AuthProvider>();
    try {
      final response = await AppleSignInService.signIn();
      if (response == null || !mounted) return;

      final ok = await authProvider.completeAppleSignIn(
        response,
        // Register is a creation path: claim the current guest conversation
        // into the new local account namespace.
        claimAnonymousConversations: true,
      );
      if (!ok) {
        if (!mounted) return;
        setState(() {
          _appleSignInError = authProvider.error == null
              ? S.of(context)!.authErrorService
              : null;
          _showEmailForm = true;
        });
        return;
      }

      await _persistConsentPreferences();
      if (!mounted) return;
      await _goAfterAccountCreated();
    } catch (e) {
      if (AppleSignInService.isCancellation(e)) return;
      if (mounted) {
        setState(() {
          _appleSignInError =
              localizeAuthException(e, S.of(context)!, appleContext: true);
          _showEmailForm = true;
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

  Future<void> _goAfterAccountCreated() async {
    final hasDossierIdentity = await hasPostAuthDossierIdentity(
      localDateOfBirth: _dateOfBirth,
    );
    if (!mounted) return;
    context.go(resolvePostAuthDestination(
      currentUri: GoRouterState.of(context).uri,
      hasDossierIdentity: hasDossierIdentity,
    ));
  }

  String _formattedDateOfBirth() {
    if (_dateOfBirth == null) return '';
    return '${_dateOfBirth!.day.toString().padLeft(2, '0')}.'
        '${_dateOfBirth!.month.toString().padLeft(2, '0')}.'
        '${_dateOfBirth!.year}';
  }

  Future<DateTime?> _pickDateOfBirth() async {
    final e2eDateOfBirth = _e2eDateOfBirthOverride();
    if (e2eDateOfBirth != null) {
      setState(() => _dateOfBirth = e2eDateOfBirth);
      return e2eDateOfBirth;
    }

    final l10n = S.of(context)!;
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
    if (picked != null && mounted) {
      setState(() => _dateOfBirth = picked);
    }
    return picked;
  }

  DateTime? _e2eDateOfBirthOverride() {
    if (_e2eRegisterDob.isEmpty) return null;
    final parsed = DateTime.tryParse(_e2eRegisterDob);
    assert(
      parsed != null,
      'MINT_E2E_REGISTER_DOB must use YYYY-MM-DD format.',
    );
    return parsed;
  }

  Future<bool> _refreshHandoffChoiceRequired() async {
    if (!FeatureFlags.enableMvpWedgeOnboarding) {
      if (mounted && _handoffChoiceRequired) {
        setState(() => _handoffChoiceRequired = false);
      }
      return false;
    }
    final hasSessionProfile = context.read<CoachProfileProvider>().hasProfile;
    final required = await AccountHandoffService.requiresExplicitChoice(
      handoffEnabled: true,
      hasSessionProfile: hasSessionProfile,
    );
    if (!mounted) return required;
    if (_handoffChoiceRequired != required) {
      setState(() => _handoffChoiceRequired = required);
    }
    return required;
  }

  Future<bool> _canStartAccountAction() async {
    final required = await _refreshHandoffChoiceRequired();
    return mounted && !required;
  }

  Widget _buildAppleSignInButton(S l10n, bool handoffBlocksAuth) {
    final button = SignInWithAppleButton(
      onPressed: _handleAppleSignIn,
      text: l10n.authAppleSignIn,
      style: SignInWithAppleButtonStyle.black,
    );
    if (!handoffBlocksAuth) return button;
    return Semantics(
      enabled: false,
      child: IgnorePointer(child: button),
    );
  }

  Widget _buildRequiredConsents(S l10n) {
    final consentTextStyle = MintTextStyles.bodySmall(
      color: MintColors.textSecondary,
    );
    final consentLinkStyle = MintTextStyles.bodySmall(
      color: MintColors.primary,
    ).copyWith(
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );

    void setAcceptedCgu(bool value) {
      setState(() {
        _acceptedCgu = value;
        _appleSignInError = null;
      });
    }

    void setConfirmed18Plus(bool value) {
      setState(() {
        _confirmed18Plus = value;
        _appleSignInError = null;
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              key: const ValueKey('auth_register_accept_cgu'),
              value: _acceptedCgu,
              onChanged: (v) => setAcceptedCgu(v ?? false),
            ),
            const SizedBox(width: MintSpacing.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: MintSpacing.sm),
                child: Wrap(
                  children: [
                    Semantics(
                      key: const ValueKey(
                        'auth_register_accept_cgu_semantics',
                      ),
                      identifier: 'auth_register_accept_cgu',
                      label: l10n.authCguAccept,
                      checked: _acceptedCgu,
                      enabled: true,
                      button: true,
                      excludeSemantics: true,
                      onTap: () => setAcceptedCgu(!_acceptedCgu),
                      child: GestureDetector(
                        key: const ValueKey('auth_register_accept_cgu_label'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setAcceptedCgu(!_acceptedCgu),
                        child: Text(
                          l10n.authCguAccept,
                          style: consentTextStyle,
                        ),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => context.push('/about'),
                      child: Text(
                        l10n.authCguLink,
                        style: consentLinkStyle,
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setAcceptedCgu(!_acceptedCgu),
                      child: Text(
                        l10n.authCguAndPrivacy,
                        style: consentTextStyle,
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => context.push('/about'),
                      child: Text(
                        l10n.authPrivacyPolicyText,
                        style: consentLinkStyle,
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setAcceptedCgu(!_acceptedCgu),
                      child: Text(
                        ' *',
                        style: consentTextStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              key: const ValueKey('auth_register_confirm_18'),
              value: _confirmed18Plus,
              onChanged: (v) => setConfirmed18Plus(v ?? false),
            ),
            const SizedBox(width: MintSpacing.sm),
            Expanded(
              child: Semantics(
                key: const ValueKey('auth_register_confirm_18_semantics'),
                identifier: 'auth_register_confirm_18',
                label: l10n.authConfirm18,
                checked: _confirmed18Plus,
                enabled: true,
                button: true,
                excludeSemantics: true,
                onTap: () => setConfirmed18Plus(!_confirmed18Plus),
                child: InkWell(
                  key: const ValueKey('auth_register_confirm_18_label'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setConfirmed18Plus(!_confirmed18Plus),
                  child: Padding(
                    padding: const EdgeInsets.only(top: MintSpacing.sm),
                    child: Text(
                      l10n.authConfirm18,
                      style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final l10n = S.of(context)!;
    final accountActionBusy = authProvider.isLoading || _appleSignInLoading;
    final handoffBlocksAuth =
        FeatureFlags.enableMvpWedgeOnboarding && _handoffChoiceRequired;
    final canCreateAccount = _acceptedCgu &&
        _confirmed18Plus &&
        !accountActionBusy &&
        !handoffBlocksAuth;
    void submitCreateAccount() {
      HapticFeedback.lightImpact();
      _handleRegister();
    }

    final createAccountAction = canCreateAccount ? submitCreateAccount : null;
    final createAccountActive = canCreateAccount || authProvider.isLoading;
    final createAccountBackground = createAccountActive
        ? MintColors.textPrimary
        : MintColors.textMuted.withValues(alpha: 0.18);
    final createAccountForeground =
        createAccountActive ? MintColors.white : MintColors.textMuted;

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
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(MintSpacing.lg),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: MintSpacing.sm),
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
                        const SizedBox(height: MintSpacing.md),
                        // Title
                        MintEntrance(
                            delay: const Duration(milliseconds: 100),
                            child: Text(
                              l10n.authRegisterTitle,
                              style: MintTextStyles.headlineMedium(),
                              textAlign: TextAlign.center,
                            )),
                        const SizedBox(height: MintSpacing.sm),
                        MintEntrance(
                            delay: const Duration(milliseconds: 200),
                            child: Text(
                              l10n.authRegisterSubtitle,
                              style: MintTextStyles.bodyMedium(),
                              textAlign: TextAlign.center,
                            )),
                        if (FeatureFlags.enableMvpWedgeOnboarding) ...[
                          const SizedBox(height: MintSpacing.lg),
                          AccountHandoffChoicePanel(
                            onChoiceChanged: _refreshHandoffChoiceRequired,
                          ),
                        ],
                        const SizedBox(height: MintSpacing.lg),
                        if (_showEmailForm) ...[
                          // Email field
                          MintEntrance(
                            delay: const Duration(milliseconds: 400),
                            child: _runtimeTextFieldAnchor(
                              identifier: 'auth_register_email_field',
                              label: l10n.authEmail,
                              focusNode: _emailFocusNode,
                              child: TextFormField(
                                key:
                                    const ValueKey('auth_register_email_field'),
                                focusNode: _emailFocusNode,
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
                            ),
                          ),
                          const SizedBox(height: MintSpacing.md),
                          // First name field (required for coach personalization)
                          _runtimeTextFieldAnchor(
                            identifier: 'auth_register_first_name_field',
                            label: l10n.authFirstName,
                            focusNode: _displayNameFocusNode,
                            child: TextFormField(
                              key: const ValueKey(
                                  'auth_register_first_name_field'),
                              focusNode: _displayNameFocusNode,
                              controller: _displayNameController,
                              autofillHints: const [AutofillHints.givenName],
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                if (_e2eDateOfBirthOverride() != null) {
                                  _passwordFocusNode.requestFocus();
                                  return;
                                }
                                FocusScope.of(context).unfocus();
                              },
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
                          FormField<DateTime>(
                            initialValue: _dateOfBirth,
                            validator: (_) {
                              if (_dateOfBirth == null) {
                                return l10n.authDateOfBirthRequired;
                              }
                              if (yearsBetween(_dateOfBirth!, DateTime.now()) <
                                  18) {
                                return l10n.authDateOfBirthTooYoung;
                              }
                              return null;
                            },
                            builder: (field) {
                              Future<void> pickAndSync() async {
                                final picked = await _pickDateOfBirth();
                                if (picked != null) field.didChange(picked);
                              }

                              return Semantics(
                                identifier: 'auth_register_dob_field',
                                label: l10n.authDateOfBirth,
                                button: true,
                                onTap: pickAndSync,
                                child: InkWell(
                                  key:
                                      const ValueKey('auth_register_dob_field'),
                                  borderRadius: BorderRadius.circular(4),
                                  onTap: pickAndSync,
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: l10n.authDateOfBirth,
                                      prefixIcon:
                                          const Icon(Icons.cake_outlined),
                                      hintText: l10n.authDateOfBirthHint,
                                      suffixIcon: const Icon(
                                          Icons.calendar_today_outlined),
                                      errorText: field.errorText,
                                    ),
                                    isEmpty: _dateOfBirth == null,
                                    child: Text(
                                      _dateOfBirth == null
                                          ? l10n.authDateOfBirthHint
                                          : _formattedDateOfBirth(),
                                      style: MintTextStyles.bodyMedium(
                                        color: _dateOfBirth == null
                                            ? MintColors.textMuted
                                            : MintColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: MintSpacing.md),
                          // Password field
                          _runtimeTextFieldAnchor(
                            identifier: 'auth_register_password_field',
                            label: l10n.authPassword,
                            focusNode: _passwordFocusNode,
                            child: TextFormField(
                              key: const ValueKey(
                                  'auth_register_password_field'),
                              focusNode: _passwordFocusNode,
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newPassword],
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              onFieldSubmitted: (_) =>
                                  _confirmPasswordFocusNode.requestFocus(),
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
                          _runtimeTextFieldAnchor(
                            identifier: 'auth_register_confirm_password_field',
                            label: l10n.authConfirmPassword,
                            focusNode: _confirmPasswordFocusNode,
                            child: TextFormField(
                              key: const ValueKey(
                                  'auth_register_confirm_password_field'),
                              focusNode: _confirmPasswordFocusNode,
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.newPassword],
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              onFieldSubmitted: (_) =>
                                  FocusScope.of(context).unfocus(),
                              decoration: InputDecoration(
                                labelText: l10n.authConfirmPassword,
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Real-time match indicator
                                    if (_confirmPasswordController
                                        .text.isNotEmpty)
                                      Icon(
                                        _confirmPasswordController.text ==
                                                _passwordController.text
                                            ? Icons.check_circle
                                            : Icons.cancel,
                                        color:
                                            _confirmPasswordController.text ==
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
                          _buildRequiredConsents(l10n),
                          const SizedBox(height: MintSpacing.sm + 4),
                          // "Consentements optionnels" divider
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: MintSpacing.sm + 4),
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
                            onChanged: (v) => setState(
                                () => _consentNotifications = v ?? false),
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
                                  color:
                                      MintColors.error.withValues(alpha: 0.15),
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
                                      localizeAuthError(
                                          authProvider.error!, l10n),
                                      style: MintTextStyles.bodyMedium(
                                        color: MintColors.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (authProvider.error != null)
                            const SizedBox(height: MintSpacing.lg),
                          // Register button
                          Semantics(
                            key: const ValueKey(
                                'auth_register_create_account_semantics'),
                            identifier: 'auth_register_create_account',
                            label: l10n.authCreateAccount,
                            button: true,
                            container: true,
                            enabled: canCreateAccount,
                            excludeSemantics: true,
                            onTap: createAccountAction,
                            child: InkWell(
                              key: const ValueKey(
                                  'auth_register_create_account'),
                              borderRadius: BorderRadius.circular(20),
                              onTap: createAccountAction,
                              child: Ink(
                                height: 56,
                                decoration: BoxDecoration(
                                  color: createAccountBackground,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Center(
                                  child: authProvider.isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    MintColors.white),
                                          ),
                                        )
                                      : Text(
                                          l10n.authCreateAccount,
                                          style: MintTextStyles.labelLarge(
                                            color: createAccountForeground,
                                          ).copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: MintSpacing.sm + 4),
                        ],
                        if (canShowAppleSignIn) ...[
                          const SizedBox(height: MintSpacing.sm),
                          Text(
                            l10n.authAppleDobNotice,
                            style: MintTextStyles.bodySmall(
                              color: MintColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: MintSpacing.sm),
                          SizedBox(
                            height: 48,
                            child: _appleSignInLoading
                                ? const Center(
                                    child: SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  )
                                : _buildAppleSignInButton(
                                    l10n,
                                    handoffBlocksAuth,
                                  ),
                          ),
                          if (_appleSignInError != null) ...[
                            const SizedBox(height: MintSpacing.sm),
                            Text(
                              _appleSignInError!,
                              style: MintTextStyles.bodySmall(
                                  color: MintColors.error),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: MintSpacing.lg),
                          if (!_showEmailForm) ...[
                            OutlinedButton(
                              // lint-ignore: prefer_mint_cta
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
                        if (_showEmailForm || !canShowAppleSignIn) ...[
                          MintEntrance(
                              delay: const Duration(milliseconds: 300),
                              child: MintSurface(
                                padding: const EdgeInsets.all(14),
                                radius: 14,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.authWhyCreateAccount,
                                      style: MintTextStyles.bodyMedium()
                                          .copyWith(
                                              fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: MintSpacing.sm),
                                    _RegisterBenefitRow(
                                        text: l10n.authBenefitProjections),
                                    _RegisterBenefitRow(
                                        text: l10n.authBenefitCoach),
                                    _RegisterBenefitRow(
                                        text: l10n.authBenefitSync),
                                  ],
                                ),
                              )),
                          const SizedBox(height: MintSpacing.lg),
                        ],
                        Semantics(
                          label: l10n.authContinueLocal,
                          button: true,
                          child: OutlinedButton(
                            // lint-ignore: prefer_mint_cta
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
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              l10n.authAlreadyAccount,
                              style: MintTextStyles.bodyMedium(),
                            ),
                            const SizedBox(width: MintSpacing.sm),
                            TextButton(
                              // lint-ignore: prefer_mint_cta
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
                          // lint-ignore: prefer_mint_cta
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
              color: isActive ? colors[strength - 1] : MintColors.border,
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
