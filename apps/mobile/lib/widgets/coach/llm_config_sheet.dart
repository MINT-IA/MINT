import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';

// ────────────────────────────────────────────────────────────
//  LLM CONFIG SHEET — Sprint C8 / MINT Coach
// ────────────────────────────────────────────────────────────
//
// Bottom sheet pour configurer la connexion BYOK (Bring Your Own Key).
// L'utilisateur fournit sa propre cle API (OpenAI ou Anthropic).
//
// Elements :
//  - Selecteur de provider (OpenAI / Anthropic)
//  - Champ cle API (masque)
//  - Selecteur de modele (dropdown)
//  - Bouton "Tester la connexion"
//  - Bouton "Sauvegarder"
//  - Note de confidentialite
//
// La cle API ne quitte JAMAIS l'appareil.
// Tous les textes en francais (informel "tu").
// ────────────────────────────────────────────────────────────

class LlmConfigSheet extends StatefulWidget {
  final LlmConfig config;
  final ValueChanged<LlmConfig> onSave;

  const LlmConfigSheet({
    super.key,
    required this.config,
    required this.onSave,
  });

  @override
  State<LlmConfigSheet> createState() => _LlmConfigSheetState();
}

class _LlmConfigSheetState extends State<LlmConfigSheet> {
  late LlmProvider _provider;
  late TextEditingController _apiKeyController;
  late String _selectedModel;
  bool _isTesting = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _provider = widget.config.provider;
    _apiKeyController = TextEditingController(text: widget.config.apiKey);
    _selectedModel = widget.config.model;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  List<String> get _availableModels =>
      LlmConfig.modelsForProvider(_provider);

  void _onProviderChanged(LlmProvider provider) {
    setState(() {
      _provider = provider;
      _selectedModel = _availableModels.first;
      _testResult = null;
    });
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    // Simuler un test de connexion
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    setState(() {
      _isTesting = false;
      if (_apiKeyController.text.isEmpty) {
        _testResult = 'Saisis ta clé API pour tester la connexion.';
      } else if (_apiKeyController.text.length < 10) {
        _testResult = 'La clé API semble invalide. Vérifie le format.';
      } else {
        _testResult = 'Connexion configurée. Le mode mock est actif pour le moment.';
      }
    });
  }

  void _save() {
    final newConfig = LlmConfig(
      apiKey: _apiKeyController.text,
      provider: _provider,
      model: _selectedModel,
    );
    widget.onSave(newConfig);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: MintColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MintColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'Configuration API',
                  style: MintTextStyles.headlineMedium(color: MintColors.textPrimary).copyWith(fontSize: 20, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Bring Your Own Key (BYOK)',
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Provider selector
                _buildSectionLabel('Fournisseur'),
                const SizedBox(height: 8),
                _buildProviderSelector(),
                const SizedBox(height: 20),

                // API Key field
                _buildSectionLabel('Clé API'),
                const SizedBox(height: 8),
                _buildApiKeyField(),
                const SizedBox(height: 20),

                // Model selector
                _buildSectionLabel('Modèle'),
                const SizedBox(height: 8),
                _buildModelSelector(),
                const SizedBox(height: 20),

                // Test connection button
                _buildTestButton(),
                if (_testResult != null) ...[
                  const SizedBox(height: 8),
                  _buildTestResult(),
                ],
                const SizedBox(height: 16),

                // Save button
                _buildSaveButton(),
                const SizedBox(height: 16),

                // Privacy notice
                _buildPrivacyNotice(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _buildProviderSelector() {
    return Container(
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        children: [
          _buildProviderOption(
            label: 'OpenAI',
            provider: LlmProvider.openai,
          ),
          _buildProviderOption(
            label: 'Anthropic',
            provider: LlmProvider.anthropic,
          ),
        ],
      ),
    );
  }

  Widget _buildProviderOption({
    required String label,
    required LlmProvider provider,
  }) {
    final isSelected = _provider == provider;
    return Expanded(
      child: Semantics(
        label: 'Sélectionner $label',
        button: true,
        child: GestureDetector(
          onTap: () => _onProviderChanged(provider),
          child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? MintColors.coachAccent : MintColors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            label,
            style: MintTextStyles.bodyMedium(color: isSelected ? MintColors.white : MintColors.textSecondary).copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildApiKeyField() {
    return TextField(
      controller: _apiKeyController,
      obscureText: true,
      style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
      decoration: InputDecoration(
        hintText: _provider == LlmProvider.openai
            ? 'sk-...'
            : 'sk-ant-...',
        hintStyle: MintTextStyles.bodyMedium(color: MintColors.textMuted),
        filled: true,
        fillColor: MintColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MintColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MintColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: MintColors.coachAccent,
            width: 1.5,
          ),
        ),
        prefixIcon: const Icon(
          Icons.key,
          color: MintColors.textMuted,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildModelSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedModel,
          isExpanded: true,
          style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
          dropdownColor: MintColors.background,
          items: _availableModels.map((model) {
            return DropdownMenuItem(
              value: model,
              child: Text(model),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedModel = value;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildTestButton() {
    return OutlinedButton.icon(
      onPressed: _isTesting ? null : _testConnection,
      icon: _isTesting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: MintColors.coachAccent,
              ),
            )
          : const Icon(
              Icons.wifi_tethering,
              size: 18,
              color: MintColors.coachAccent,
            ),
      label: Text(
        _isTesting ? 'Test en cours...' : 'Tester la connexion',
        style: MintTextStyles.bodyMedium(color: MintColors.coachAccent).copyWith(fontWeight: FontWeight.w500),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: MintColors.coachAccent.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _buildTestResult() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.coachBubble,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _testResult!,
        style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontSize: 12),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _save,
      style: ElevatedButton.styleFrom(
        backgroundColor: MintColors.coachAccent,
        foregroundColor: MintColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        elevation: 0,
      ),
      child: Text(
        'Sauvegarder',
        style: MintTextStyles.titleMedium(color: MintColors.white).copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildPrivacyNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: MintColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline,
            size: 16,
            color: MintColors.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ta cl\u00e9 API est chiffr\u00e9e localement. Elle transite via HTTPS pour communiquer avec le fournisseur IA, jamais stock\u00e9e c\u00f4t\u00e9 serveur.',
              style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
