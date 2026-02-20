import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/theme/colors.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  String? _debugToken;

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _requestToken() async {
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
    final debugToken = await auth.requestEmailVerification(email);
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
          l10n?.authVerifyRequestAccepted ??
              'Lien de vérification envoyé (si compte existant).',
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    final l10n = S.of(context);
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.authTokenRequired ?? 'Token requis.',
          ),
        ),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    final ok = await auth.confirmEmailVerification(token);
    if (!mounted || !ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n?.authVerifySuccess ?? 'E-mail vérifié. Tu peux te connecter.',
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
          l10n?.authVerifyTitle ?? 'Vérifier mon e-mail',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n?.authVerifyInstructions ??
                    'Demande un nouveau lien puis colle le token de vérification.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: MintColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l10n?.authEmail ?? 'Adresse e-mail',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: auth.isLoading ? null : _requestToken,
                child: Text(
                  l10n?.authVerifySendLink ?? 'Envoyer le lien de vérification',
                ),
              ),
              if (_debugToken != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MintColors.info.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
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
              const SizedBox(height: 16),
              TextField(
                controller: _tokenController,
                decoration: InputDecoration(
                  labelText:
                      l10n?.authVerifyTokenLabel ?? 'Token de vérification',
                  prefixIcon: Icon(Icons.key_outlined),
                ),
              ),
              const SizedBox(height: 16),
              if (auth.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    auth.error!,
                    style: GoogleFonts.inter(color: MintColors.error),
                  ),
                ),
              FilledButton(
                onPressed: auth.isLoading ? null : _confirm,
                child: Text(
                  l10n?.authVerifySubmit ?? 'Valider la vérification',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
