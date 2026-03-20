import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/auth/auth_gate.dart';

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
    final s = S.of(context)!;
    final byok = context.watch<ByokProvider>();

    return Scaffold(
      backgroundColor: MintColors.white,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        surfaceTintColor: MintColors.white,
        elevation: 0,
        title: Text(
          s.byokTitle,
          style: MintTextStyles.headlineMedium(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(MintSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              s.byokTitle,
              style: MintTextStyles.headlineLarge(),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              s.byokSubtitle,
              style: MintTextStyles.bodyLarge(),
            ),
            const SizedBox(height: MintSpacing.xl),

            // Privacy card
            _buildPrivacyCard(s),
            const SizedBox(height: MintSpacing.xl),

            // Provider selector
            _buildSectionLabel(s.byokProviderLabel),
            const SizedBox(height: MintSpacing.sm + 4),
            _buildProviderSelector(s),
            const SizedBox(height: MintSpacing.lg),

            // API Key input
            _buildSectionLabel(s.byokApiKeyLabel),
            const SizedBox(height: MintSpacing.sm + 4),
            _buildApiKeyInput(),
            const SizedBox(height: MintSpacing.sm),
            _buildApiKeyHelpLink(s),
            const SizedBox(height: MintSpacing.lg),

            // Test & Save buttons
            _buildTestButton(byok, s),
            const SizedBox(height: MintSpacing.sm + 4),
            _buildSaveButton(byok, s),
            const SizedBox(height: MintSpacing.sm),

            // Feedback
            if (byok.testSuccess) _buildSuccessFeedback(s),
            if (byok.testError != null) _buildErrorFeedback(byok.testError!),
            const SizedBox(height: MintSpacing.md),

            // Clear key (if configured)
            if (byok.isConfigured) _buildClearButton(byok, s),
            const SizedBox(height: MintSpacing.xl),

            // Educational section
            _buildEducationalSection(s),
            const SizedBox(height: MintSpacing.xxl - 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: MintTextStyles.bodySmall(color: MintColors.textMuted),
    );
  }

  Widget _buildPrivacyCard(S s) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg - 4),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(MintSpacing.sm),
                decoration: BoxDecoration(
                  color: MintColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock_outline,
                    color: MintColors.primary, size: 20),
              ),
              const SizedBox(width: MintSpacing.sm + 4),
              Text(
                s.byokPrivacyTitle,
                style: MintTextStyles.titleMedium(),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          Text(
            s.byokPrivacyBody,
            style: MintTextStyles.bodyMedium(),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderSelector(S s) {
    return Row(
      children: [
        _buildProviderChip('claude', 'Claude', s, isRecommended: true),
        const SizedBox(width: MintSpacing.sm + 2),
        _buildProviderChip('openai', 'OpenAI', s),
        const SizedBox(width: MintSpacing.sm + 2),
        _buildProviderChip('mistral', 'Mistral', s),
      ],
    );
  }

  Widget _buildProviderChip(String value, String label, S s,
      {bool isRecommended = false}) {
    final isSelected = _selectedProvider == value;
    return Expanded(
      child: Semantics(
        label: '${s.byokProviderLabel} $label',
        button: true,
        selected: isSelected,
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
                style: MintTextStyles.bodySmall(
                  color: isSelected ? MintColors.white : MintColors.textPrimary,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              if (isRecommended) ...[
                const SizedBox(height: MintSpacing.xs),
                Text(
                  s.byokRecommended,
                  style: MintTextStyles.labelSmall(
                    color: isSelected
                        ? MintColors.white.withValues(alpha: 0.7)
                        : MintColors.textMuted,
                  ).copyWith(fontSize: 10),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildApiKeyInput() {
    return Semantics(
      label: S.of(context)!.byokApiKeyLabel,
      textField: true,
      child: TextField(
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
          suffixIcon: Semantics(
            label: _obscureKey
                ? 'Afficher la clé'
                : 'Masquer la clé',
            button: true,
            child: IconButton(
              icon: Icon(
                _obscureKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: MintColors.textMuted,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureKey = !_obscureKey),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApiKeyHelpLink(S s) {
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

    return Semantics(
      label: s.byokGetKeyOn(label),
      button: true,
      child: InkWell(
      onTap: () => _launchUrl(url),
      child: Row(
        children: [
          const Icon(Icons.open_in_new, size: 14, color: MintColors.info),
          const SizedBox(width: 6),
          Text(
            s.byokGetKeyOn(label),
            style: MintTextStyles.bodySmall(
              color: MintColors.info,
            ).copyWith(
              decoration: TextDecoration.underline,
              decorationColor: MintColors.info,
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildTestButton(ByokProvider byok, S s) {
    return SizedBox(
      width: double.infinity,
      child: Semantics(
        label: s.byokTestButton,
        button: true,
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
            byok.isTesting ? s.byokTesting : s.byokTestButton,
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton(ByokProvider byok, S s) {
    return AuthGate(
      triggerContext: AuthTrigger.byokSetup,
      child: SizedBox(
        width: double.infinity,
        child: Semantics(
          label: s.byokSaveButton,
          button: true,
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
                          content: Text(s.byokSaved),
                          backgroundColor: MintColors.success,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }
                  },
            child: Text(s.byokSaveButton),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessFeedback(S s) {
    return Column(
      children: [
        // Success confirmation
        Container(
          padding: const EdgeInsets.all(MintSpacing.md),
          decoration: BoxDecoration(
            color: MintColors.success.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MintColors.success.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: MintColors.success, size: 20),
              const SizedBox(width: MintSpacing.sm + 4),
              Expanded(
                child: Text(
                  s.byokTestSuccess,
                  style: MintTextStyles.bodyMedium(color: MintColors.success),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: MintSpacing.md),

        // A-ha CTA — "Try it now"
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(MintSpacing.lg),
          decoration: BoxDecoration(
            color: MintColors.primary,
            borderRadius: BorderRadius.circular(16),
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
              const SizedBox(height: MintSpacing.md),
              Text(
                s.byokCopilotActivated,
                textAlign: TextAlign.center,
                style: MintTextStyles.headlineMedium(
                  color: MintColors.white,
                ).copyWith(fontSize: 18),
              ),
              const SizedBox(height: MintSpacing.sm),
              Text(
                s.byokCopilotBody,
                textAlign: TextAlign.center,
                style: MintTextStyles.bodyMedium(
                  color: MintColors.white,
                ).copyWith(
                  color: MintColors.white.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: MintSpacing.lg - 4),
              SizedBox(
                width: double.infinity,
                child: Semantics(
                  label: s.byokTryNow,
                  button: true,
                  child: FilledButton.icon(
                    onPressed: () => context.push('/ask-mint'),
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    label: Text(s.byokTryNow),
                    style: FilledButton.styleFrom(
                      backgroundColor: MintColors.white,
                      foregroundColor: MintColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.error.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: MintColors.error, size: 20),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Text(
              error,
              style: MintTextStyles.bodyMedium(color: MintColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClearButton(ByokProvider byok, S s) {
    return Center(
      child: Semantics(
        label: s.byokClearButton,
        button: true,
        child: TextButton.icon(
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: Text(s.byokClearTitle),
                content: Text(s.byokClearMessage),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(s.byokClearCancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style:
                        FilledButton.styleFrom(backgroundColor: MintColors.error),
                    child: Text(s.byokClearConfirm),
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
          label: Text(s.byokClearButton),
          style: TextButton.styleFrom(foregroundColor: MintColors.error),
        ),
      ),
    );
  }

  Widget _buildEducationalSection(S s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(s.byokLearnTitle),
        const SizedBox(height: MintSpacing.md),
        Container(
          padding: const EdgeInsets.all(MintSpacing.lg - 4),
          decoration: BoxDecoration(
            color: MintColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MintColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.byokLearnHeading,
                style: MintTextStyles.titleMedium(),
              ),
              const SizedBox(height: MintSpacing.sm + 4),
              Text(
                s.byokLearnBody,
                style: MintTextStyles.bodyMedium(),
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
