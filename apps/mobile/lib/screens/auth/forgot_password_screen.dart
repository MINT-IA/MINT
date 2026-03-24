import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _debugToken;

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestReset() async {
    final l10n = S.of(context)!;
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.authEmailInvalidPrompt),
        ),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    final debugToken = await auth.requestPasswordReset(email);
    if (!mounted) return;
    setState(() {
      _debugToken = debugToken;
      if (debugToken != null && _tokenController.text.isEmpty) {
        _tokenController.text = debugToken;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.authForgotRequestAccepted),
      ),
    );
  }

  Future<void> _confirmReset() async {
    final l10n = S.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.confirmPasswordReset(
      _tokenController.text.trim(),
      _passwordController.text,
    );
    if (!mounted || !success) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.authForgotResetSuccess),
      ),
    );
    context.go('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final l10n = S.of(context)!;
    return Scaffold(
      backgroundColor: MintColors.white,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        surfaceTintColor: MintColors.white,
        elevation: 0,
        title: Text(
          l10n.authForgotTitle,
          style: MintTextStyles.headlineMedium(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(MintSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.authForgotSteps,
                  style: MintTextStyles.bodyMedium(),
                ),
                const SizedBox(height: MintSpacing.lg - 4),
                Semantics(
                  label: l10n.authEmail,
                  textField: true,
                  child: TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l10n.authEmail,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: MintSpacing.sm + 4),
                FilledButton.tonal(
                  onPressed: auth.isLoading ? null : _requestReset,
                  child: Text(l10n.authForgotSendLink),
                ),
                if (_debugToken != null) ...[
                  const SizedBox(height: MintSpacing.sm + 4),
                  Container(
                    padding: const EdgeInsets.all(MintSpacing.sm + 4),
                    decoration: BoxDecoration(
                      color: MintColors.info.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${l10n.authDebugTokenLabel}: $_debugToken',
                      style: MintTextStyles.labelSmall(
                        color: MintColors.info,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: MintSpacing.lg),
                Semantics(
                  label: l10n.authForgotResetTokenLabel,
                  textField: true,
                  child: TextFormField(
                    controller: _tokenController,
                    decoration: InputDecoration(
                      labelText: l10n.authForgotResetTokenLabel,
                      prefixIcon: const Icon(Icons.key_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.authTokenRequired
                        : null,
                  ),
                ),
                const SizedBox(height: MintSpacing.sm + 4),
                Semantics(
                  label: l10n.authForgotNewPasswordLabel,
                  textField: true,
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: l10n.authForgotNewPasswordLabel,
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
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.length < 8) {
                        return l10n.authPasswordHint;
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: MintSpacing.sm + 4),
                Semantics(
                  label: l10n.authConfirmPassword,
                  textField: true,
                  child: TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: l10n.authConfirmPassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: Semantics(
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
                          onPressed: () => setState(
                            () => _obscureConfirmPassword = !_obscureConfirmPassword,
                          ),
                        ),
                      ),
                    ),
                    validator: (v) => v == _passwordController.text
                        ? null
                        : l10n.authPasswordMismatch,
                  ),
                ),
                const SizedBox(height: MintSpacing.lg - 4),
                if (auth.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: MintSpacing.sm + 4),
                    child: Text(
                      auth.error!,
                      style: MintTextStyles.bodyMedium(color: MintColors.error),
                    ),
                  ),
                Semantics(
                  label: l10n.authForgotSubmitNewPassword,
                  button: true,
                  child: FilledButton(
                    onPressed: auth.isLoading ? null : _confirmReset,
                    child: Text(l10n.authForgotSubmitNewPassword),
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
