import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/theme/colors.dart';

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
    final l10n = S.of(context);
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.authEmailInvalidPrompt ?? 'Entre une adresse e-mail valide.',
          ),
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
        content: Text(
          l10n?.authForgotRequestAccepted ??
              'Si un compte existe, un lien de réinitialisation a été envoyé.',
        ),
      ),
    );
  }

  Future<void> _confirmReset() async {
    final l10n = S.of(context);
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.confirmPasswordReset(
      _tokenController.text.trim(),
      _passwordController.text,
    );
    if (!mounted || !success) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n?.authForgotResetSuccess ??
              'Mot de passe mis à jour. Connecte-toi.',
        ),
      ),
    );
    context.go('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final l10n = S.of(context);
    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        backgroundColor: MintColors.background,
        elevation: 0,
        title: Text(
          l10n?.authForgotTitle ?? 'Réinitialiser le mot de passe',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n?.authForgotSteps ??
                      '1) Demande un lien  2) Colle le token  3) Choisis un nouveau mot de passe',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: MintColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n?.authEmail ?? 'Adresse e-mail',
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: auth.isLoading ? null : _requestReset,
                  child: Text(
                    l10n?.authForgotSendLink ??
                        'Envoyer le lien de réinitialisation',
                  ),
                ),
                if (_debugToken != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MintColors.info.withValues(alpha: 0.08),
                      borderRadius: const Borderconst Radius.circular(12),
                    ),
                    child: Text(
                      '${l10n?.authDebugTokenLabel ?? 'Token debug (tests)'}: $_debugToken',
                      style: GoogleFonts.inter(
                        color: MintColors.info,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                TextFormField(
                  controller: _tokenController,
                  decoration: InputDecoration(
                    labelText:
                        l10n?.authForgotResetTokenLabel ?? 'Token de réinitialisation',
                    prefixIcon: const Icon(Icons.key_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? (l10n?.authTokenRequired ?? 'Token requis')
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: l10n?.authForgotNewPasswordLabel ?? 'Nouveau mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
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
                  validator: (v) {
                    if (v == null || v.length < 8) {
                      return l10n?.authPasswordHint ?? 'Minimum 8 caractères';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: l10n?.authConfirmPassword ?? 'Confirmer le mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
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
                  validator: (v) => v == _passwordController.text
                      ? null
                      : (l10n?.authPasswordMismatch ??
                          'Les mots de passe ne correspondent pas'),
                ),
                const SizedBox(height: 20),
                if (auth.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      auth.error!,
                      style: GoogleFonts.inter(color: MintColors.error),
                    ),
                  ),
                FilledButton(
                  onPressed: auth.isLoading ? null : _confirmReset,
                  child: Text(
                    l10n?.authForgotSubmitNewPassword ??
                        'Valider le nouveau mot de passe',
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
