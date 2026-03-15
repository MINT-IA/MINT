import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/theme/colors.dart';

/// BYOK Settings Screen - Configure your own LLM API key.
///
/// Supports Claude (recommended), OpenAI, and Mistral.
/// The key is stored securely on-device via flutter_secure_storage.
class ByokSettingsScreen extends StatefulWidget {
  const ByokSettingsScreen({super.key});

  @override
  State<ByokSettingsScreen> createState() => _ByokSettingsScreenState();
}

class _ByokSettingsScreenState extends State<ByokSettingsScreen> {
  final _apiKeyController = TextEditingController();
  String _selectedProvider = 'claude';
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final byok = context.read<ByokProvider>();
    if (byok.isConfigured) {
      _selectedProvider = byok.provider ?? 'claude';
      _apiKeyController.text = byok.apiKey ?? '';
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final byok = context.watch<ByokProvider>();

    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: MintColors.background,
            title: Text(
              s?.byokTitle ?? 'Intelligence artificielle',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    s?.byokTitle ?? 'Intelligence artificielle',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s?.byokSubtitle ??
                        'Connecte ton propre LLM pour des r\u00e9ponses personnalis\u00e9es',
                    style: const TextStyle(
                      fontSize: 15,
                      color: MintColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Privacy card
                  _buildPrivacyCard(s),
                  const SizedBox(height: 32),

                  // Provider selector
                  _buildSectionLabel(s?.byokProviderLabel ?? 'Fournisseur'),
                  const SizedBox(height: 12),
                  _buildProviderSelector(),
                  const SizedBox(height: 24),

                  // API Key input
                  _buildSectionLabel(s?.byokApiKeyLabel ?? 'Cl\u00e9 API'),
                  const SizedBox(height: 12),
                  _buildApiKeyInput(s),
                  const SizedBox(height: 8),
                  _buildApiKeyHelpLink(),
                  const SizedBox(height: 24),

                  // Test & Save buttons
                  _buildTestButton(byok, s),
                  const SizedBox(height: 12),
                  _buildSaveButton(byok, s),
                  const SizedBox(height: 8),

                  // Feedback
                  if (byok.testSuccess) _buildSuccessFeedback(s),
                  if (byok.testError != null) _buildErrorFeedback(byok.testError!),
                  const SizedBox(height: 16),

                  // Clear key (if configured)
                  if (byok.isConfigured) _buildClearButton(byok, s),
                  const SizedBox(height: 32),

                  // Educational section
                  _buildEducationalSection(s),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.montserrat(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: MintColors.textMuted,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildPrivacyCard(S? s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.accentPastel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MintColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock_outline,
                    color: MintColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                s?.byokPrivacyTitle ?? 'Ta cl\u00e9, tes donn\u00e9es',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            s?.byokPrivacyBody ??
                'Ta cl\u00e9 API est stock\u00e9e de mani\u00e8re chiffr\u00e9e sur ton appareil. '
                    'Elle est transmise de fa\u00e7on s\u00e9curis\u00e9e (HTTPS) \u00e0 notre serveur pour communiquer '
                    'avec le fournisseur IA, puis imm\u00e9diatement supprim\u00e9e \u2014 jamais stock\u00e9e c\u00f4t\u00e9 serveur.',
            style: const TextStyle(
              fontSize: 14,
              color: MintColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderSelector() {
    return Row(
      children: [
        _buildProviderChip('claude', 'Claude', isRecommended: true),
        const SizedBox(width: 10),
        _buildProviderChip('openai', 'OpenAI'),
        const SizedBox(width: 10),
        _buildProviderChip('mistral', 'Mistral'),
      ],
    );
  }

  Widget _buildProviderChip(String value, String label,
      {bool isRecommended = false}) {
    final isSelected = _selectedProvider == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedProvider = value),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? MintColors.primary : MintColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? MintColors.primary : MintColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? MintColors.white : MintColors.textPrimary,
                ),
              ),
              if (isRecommended) ...[
                const SizedBox(height: 4),
                Text(
                  S.of(context)?.byokRecommended ?? 'Recommand\u00e9',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? MintColors.white70
                        : MintColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApiKeyInput(S? s) {
    return TextField(
      controller: _apiKeyController,
      obscureText: _obscureKey,
      style: const TextStyle(
        fontSize: 14,
        fontFamily: 'monospace',
        color: MintColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: _selectedProvider == 'claude'
            ? 'sk-ant-...'
            : _selectedProvider == 'openai'
                ? 'sk-...'
                : 'api-...',
        hintStyle: const TextStyle(
          color: MintColors.textMuted,
          fontFamily: 'monospace',
          fontSize: 14,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: MintColors.textMuted,
            size: 20,
          ),
          onPressed: () => setState(() => _obscureKey = !_obscureKey),
        ),
      ),
    );
  }

  Widget _buildApiKeyHelpLink() {
    final (String label, String url) = switch (_selectedProvider) {
      'claude' => (
          'console.anthropic.com',
          'https://console.anthropic.com/settings/keys'
        ),
      'openai' => (
          'platform.openai.com',
          'https://platform.openai.com/api-keys'
        ),
      'mistral' => (
          'console.mistral.ai',
          'https://console.mistral.ai/api-keys'
        ),
      _ => ('', ''),
    };

    return InkWell(
      onTap: () => _launchUrl(url),
      child: Row(
        children: [
          const Icon(Icons.open_in_new, size: 14, color: MintColors.info),
          const SizedBox(width: 6),
          Text(
            S.of(context)?.byokGetKeyOn(label) ?? 'Obtenir une cl\u00e9 sur $label',
            style: const TextStyle(
              fontSize: 13,
              color: MintColors.info,
              decoration: TextDecoration.underline,
              decorationColor: MintColors.info,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton(ByokProvider byok, S? s) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: byok.isTesting || _apiKeyController.text.isEmpty
            ? null
            : () async {
                // Save first then test
                await byok.saveKey(_selectedProvider, _apiKeyController.text.trim());
                await byok.testKey();
              },
        icon: byok.isTesting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.science_outlined, size: 18),
        label: Text(
          byok.isTesting
              ? (s?.byokTesting ?? 'Test en cours...')
              : (s?.byokTestButton ?? 'Tester la cl\u00e9'),
        ),
      ),
    );
  }

  Widget _buildSaveButton(ByokProvider byok, S? s) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: byok.isLoading || _apiKeyController.text.isEmpty
            ? null
            : () async {
                final messenger = ScaffoldMessenger.of(context);
                await byok.saveKey(
                    _selectedProvider, _apiKeyController.text.trim());
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(s?.byokSaved ?? 'Cl\u00e9 sauvegard\u00e9e avec succ\u00e8s'),
                      backgroundColor: MintColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              },
        child: Text(s?.byokSaveButton ?? 'Sauvegarder'),
      ),
    );
  }

  Widget _buildSuccessFeedback(S? s) {
    return Column(
      children: [
        // Success confirmation
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MintColors.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MintColors.success.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: MintColors.success, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  s?.byokTestSuccess ??
                      'Connexion r\u00e9ussie ! Ton IA est pr\u00eate.',
                  style: const TextStyle(
                      fontSize: 14, color: MintColors.success, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // A-ha CTA — "Try it now"
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                MintColors.primary,
                MintColors.charcoal,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: MintColors.primary.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MintColors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: MintColors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                s?.byokCopilotActivated ?? 'Ton copilote financier est activ\u00e9',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: MintColors.white,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s?.byokCopilotBody ??
                'Pose ta premi\u00e8re question sur la finance suisse '
                '\u2014 3e pilier, imp\u00f4ts, LPP, budget...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: MintColors.white.withValues(alpha: 0.75),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push('/ask-mint'),
                  icon: const Icon(Icons.chat_outlined, size: 18),
                  label: Text(s?.byokTryNow ?? 'Essayer maintenant'),
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.white,
                    foregroundColor: MintColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorFeedback(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: MintColors.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                  fontSize: 14, color: MintColors.error, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClearButton(ByokProvider byok, S? s) {
    return Center(
      child: TextButton.icon(
        onPressed: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text(s?.byokClearTitle ?? 'Supprimer la cl\u00e9 ?'),
              content: Text(
                s?.byokClearMessage ??
                    'Cela supprimera ta cl\u00e9 API stock\u00e9e localement. '
                        'Tu pourras en configurer une nouvelle \u00e0 tout moment.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(s?.byokClearCancel ?? 'Annuler'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style:
                      FilledButton.styleFrom(backgroundColor: MintColors.error),
                  child: Text(s?.byokClearConfirm ?? 'Supprimer'),
                ),
              ],
            ),
          );

          if (confirm == true) {
            await byok.clearKey();
            _apiKeyController.clear();
            setState(() => _selectedProvider = 'claude');
          }
        },
        icon: const Icon(Icons.delete_outline, size: 18),
        label: Text(s?.byokClearButton ?? 'Supprimer la cl\u00e9 sauvegard\u00e9e'),
        style: TextButton.styleFrom(foregroundColor: MintColors.error),
      ),
    );
  }

  Widget _buildEducationalSection(S? s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(s?.byokLearnTitle ?? '\u00c0 propos du BYOK'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: MintColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: MintColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s?.byokLearnHeading ??
                    'Qu\'est-ce que le BYOK (Bring Your Own Key) ?',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                s?.byokLearnBody ??
                    'Le BYOK te permet d\'utiliser ta propre cl\u00e9 API d\'un fournisseur d\'IA '
                        '(Claude, OpenAI, Mistral) pour obtenir des r\u00e9ponses personnalis\u00e9es '
                        'sur la finance suisse.\n\n'
                        'Avantages :\n'
                        '\u2022 Contr\u00f4le total sur tes donn\u00e9es\n'
                        '\u2022 Aucun co\u00fbt cach\u00e9 c\u00f4t\u00e9 MINT\n'
                        '\u2022 Tu paies uniquement ce que tu consommes\n'
                        '\u2022 Cl\u00e9 stock\u00e9e de mani\u00e8re chiffr\u00e9e sur ton appareil',
                style: const TextStyle(
                  fontSize: 14,
                  color: MintColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
