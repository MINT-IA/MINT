import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (mounted && success) {
      final redirect = GoRouterState.of(context).uri.queryParameters['redirect'];
      if (redirect != null && redirect.startsWith('/')) {
        context.go(Uri.decodeComponent(redirect));
      } else {
        context.go('/home');
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
                  l10n.authLoginTitle,
                  style: MintTextStyles.headlineLarge(),
                  textAlign: TextAlign.center,
                )),
                const SizedBox(height: MintSpacing.sm),
                MintEntrance(delay: const Duration(milliseconds: 200), child: Text(
                  l10n.authLoginSubtitle,
                  style: MintTextStyles.bodyLarge(),
                  textAlign: TextAlign.center,
                )),
                const SizedBox(height: MintSpacing.xxl),
                // Email field
                MintEntrance(delay: const Duration(milliseconds: 300), child: Semantics(
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
                // Password field
                MintEntrance(delay: const Duration(milliseconds: 400), child: Semantics(
                  label: l10n.authPassword,
                  textField: true,
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: l10n.authPassword,
                      prefixIcon: const Icon(Icons.lock_outline),
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
                      return null;
                    },
                  ),
                )),
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
                // Login button
                Semantics(
                  label: l10n.authLogin,
                  button: true,
                  child: FilledButton(
                    onPressed: authProvider.isLoading
                        ? null
                        : () {
                            HapticFeedback.lightImpact();
                            _handleLogin();
                          },
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
                        : Text(l10n.authLogin),
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
                            context.go('/onboarding/intent');
                          },
                    child: Text(l10n.authContinueLocal),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: authProvider.isLoading
                        ? null
                        : () => context.go('/auth/forgot-password'),
                    child: Text(
                      l10n.authForgotPasswordLink,
                      style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: authProvider.isLoading
                        ? null
                        : () => context.go('/auth/verify-email'),
                    child: Text(
                      l10n.authVerifyEmailLink,
                      style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: MintSpacing.xl),
                // Register link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(child: Text(
                      l10n.authNoAccount,
                      style: MintTextStyles.bodyMedium(),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const SizedBox(width: MintSpacing.sm),
                    TextButton(
                      onPressed: () {
                        context.go('/auth/register');
                      },
                      child: Text(
                        l10n.authRegister,
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
