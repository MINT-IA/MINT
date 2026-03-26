import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

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
        content: Text(l10n.authVerifyRequestAccepted),
      ),
    );
  }

  Future<void> _confirm() async {
    final l10n = S.of(context)!;
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.authTokenRequired),
        ),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    final ok = await auth.confirmEmailVerification(token);
    if (!mounted || !ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.authVerifySuccess),
      ),
    );
    // F3-2: After verification, redirect to the original destination if provided.
    final redirect = GoRouterState.of(context).uri.queryParameters['redirect'];
    if (redirect != null && redirect.startsWith('/')) {
      context.go(Uri.decodeComponent(redirect));
    } else {
      context.go('/auth/login');
    }
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
          l10n.authVerifyTitle,
          style: MintTextStyles.headlineMedium(),
        ),
      ),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(MintSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MintEntrance(child: Text(
                l10n.authVerifyInstructions,
                style: MintTextStyles.bodyMedium(),
              )),
              const SizedBox(height: MintSpacing.md),
              MintEntrance(delay: const Duration(milliseconds: 100), child: Semantics(
                label: l10n.authEmail,
                textField: true,
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.authEmail,
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                ),
              )),
              const SizedBox(height: MintSpacing.sm + 4),
              FilledButton.tonal(
                onPressed: auth.isLoading ? null : _requestToken,
                child: Text(l10n.authVerifySendLink),
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
              const SizedBox(height: MintSpacing.md),
              MintEntrance(delay: const Duration(milliseconds: 200), child: Semantics(
                label: l10n.authVerifyTokenLabel,
                textField: true,
                child: TextField(
                  controller: _tokenController,
                  decoration: InputDecoration(
                    labelText: l10n.authVerifyTokenLabel,
                    prefixIcon: const Icon(Icons.key_outlined),
                  ),
                ),
              )),
              const SizedBox(height: MintSpacing.md),
              if (auth.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: MintSpacing.sm),
                  child: Text(
                    localizeAuthError(auth.error!, l10n),
                    style: MintTextStyles.bodyMedium(color: MintColors.error),
                  ),
                ),
              MintEntrance(delay: const Duration(milliseconds: 300), child: Semantics(
                label: l10n.authVerifySubmit,
                button: true,
                child: FilledButton(
                  onPressed: auth.isLoading ? null : _confirm,
                  child: Text(l10n.authVerifySubmit),
                ),
              )),
            ],
          ),
        ),
      ))),
    );
  }
}
