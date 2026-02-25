import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/domain/calculators.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mint_mobile/theme/colors.dart';

class DebtRiskCheckScreen extends StatefulWidget {
  const DebtRiskCheckScreen({super.key});

  @override
  State<DebtRiskCheckScreen> createState() => _DebtRiskCheckScreenState();
}

class _DebtRiskCheckScreenState extends State<DebtRiskCheckScreen> {
  // Questionnaire answers
  bool? _hasRegularOverdrafts;
  bool? _hasMultipleCredits;
  bool? _hasLatePayments;
  bool? _hasDebtCollection;
  bool? _hasImpulsiveBuying;
  bool? _hasGamblingHabit;

  Map<String, dynamic>? _result;
  bool _showResults = false;

  void _calculateScore() {
    final result = calculateDebtRiskScore(
      hasRegularOverdrafts: _hasRegularOverdrafts!,
      hasMultipleCredits: _hasMultipleCredits!,
      hasLatePayments: _hasLatePayments!,
      hasDebtCollection: _hasDebtCollection!,
      hasImpulsiveBuying: _hasImpulsiveBuying!,
      hasGamblingHabit: _hasGamblingHabit!,
    );
    setState(() {
      _result = result;
      _showResults = true;
    });
  }

  Future<void> _exportPdf() async {
    if (_result == null) return;
    
    // TODO: Implement PDF export for debt risk check
    // await PdfService.generateBilanPdf(
    //   title: 'Bilan Risque d\'Endettement',
    //   results: results,
    //   recommendations: recommendations,
    // );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        title: const Text('Check-up Santé Financière'),
        actions: [
          if (_showResults)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: _exportPdf,
              tooltip: 'Exporter mon bilan',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: _showResults ? _buildResults() : _buildQuestionnaire(),
      ),
    );
  }

  Widget _buildQuestionnaire() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMentorIntro(),
        const SizedBox(height: 32),
        _buildQuestionSection(
          'Gestion quotidienne',
          [
            _buildQuestionCard(
              'Es-tu régulièrement à découvert ?',
              'Ton compte passe en négatif avant la fin du mois.',
              _hasRegularOverdrafts,
              (v) => setState(() => _hasRegularOverdrafts = v),
            ),
            _buildQuestionCard(
              'As-tu plusieurs crédits en cours ?',
              'Leasing, prêt, petits crédits, cartes de crédit...',
              _hasMultipleCredits,
              (v) => setState(() => _hasMultipleCredits = v),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildQuestionSection(
          'Obligations',
          [
            _buildQuestionCard(
              'As-tu des retards de paiement ?',
              'Factures, impôts ou loyers payés en retard.',
              _hasLatePayments,
              (v) => setState(() => _hasLatePayments = v),
            ),
            _buildQuestionCard(
              'As-tu reçu des poursuites ?',
              'Commandements de payer ou saisies.',
              _hasDebtCollection,
              (v) => setState(() => _hasDebtCollection = v),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildQuestionSection(
          'Comportements',
          [
            _buildQuestionCard(
              'Des achats impulsifs fréquents ?',
              'Des dépenses non planifiées que tu regrettes.',
              _hasImpulsiveBuying,
              (v) => setState(() => _hasImpulsiveBuying = v),
            ),
            _buildQuestionCard(
              'Joues-tu de l\'argent régulièrement ?',
              'Casinos, paris sportifs ou loteries fréquentes.',
              _hasGamblingHabit,
              (v) => setState(() => _hasGamblingHabit = v),
            ),
          ],
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _canSubmit ? _calculateScore : null,
            child: const Text('Analyser ma situation'),
          ),
        ),
        const SizedBox(height: 32),
        _buildPrivacyNote(),
        const SizedBox(height: 40),
      ],
    );
  }

  bool get _canSubmit =>
      _hasRegularOverdrafts != null &&
      _hasMultipleCredits != null &&
      _hasLatePayments != null &&
      _hasDebtCollection != null &&
      _hasImpulsiveBuying != null &&
      _hasGamblingHabit != null;

  Widget _buildMentorIntro() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: const Borderconst Radius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_outlined, color: MintColors.primary, size: 24),
              const SizedBox(width: 12),
              Text('Le mot du Mentor', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Ce check-up de 60 secondes nous permet de détecter les signaux d\'alerte avant qu\'ils ne deviennent critiques.',
            style: TextStyle(fontSize: 14, color: MintColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MintColors.textMuted, letterSpacing: 1.2),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildQuestionCard(String question, String sub, bool? value, Function(bool?) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: const Borderconst Radius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 4),
          Text(sub, style: const TextStyle(fontSize: 13, color: MintColors.textSecondary)),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildChoiceButton('OUI', true, value == true, () => onChanged(true)),
              const SizedBox(width: 12),
              _buildChoiceButton('NON', false, value == false, () => onChanged(false)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceButton(String label, bool choice, bool isSelected, VoidCallback onSelected) {
    return Expanded(
      child: InkWell(
        onTap: onSelected,
        borderRadius: const Borderconst Radius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? MintColors.primary : MintColors.surface,
            borderRadius: const Borderconst Radius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: isSelected ? Colors.white : MintColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    final riskLevel = _result!['riskLevel'] as String;
    final riskScore = _result!['riskScore'] as int;
    final recommendations = _result!['recommendations'] as List<String>;
    final hasGamblingRisk = _result!['hasGamblingRisk'] as bool;

    final (Color color, String label, IconData icon) = switch (riskLevel) {
      'low' => (MintColors.success, 'Risque Maîtrisé', Icons.check_circle_outline),
      'medium' => (MintColors.warning, 'Points d\'Attention', Icons.warning_amber_rounded),
      'high' => (MintColors.error, 'Alerte Critique', Icons.error_outline),
      _ => (Colors.grey, 'Indéterminé', Icons.help_outline),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: const Borderconst Radius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 48),
              const SizedBox(height: 16),
              Text(label, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(height: 8),
              Text('$riskScore facteur(s) détecté(s)', style: const TextStyle(color: MintColors.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'RECOMMANDATIONS DU MENTOR',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MintColors.textMuted, letterSpacing: 1.2),
        ),
        const SizedBox(height: 16),
        ...recommendations.map((r) => _buildGuidanceItem(Icons.lightbulb_outline, r)),
        if (hasGamblingRisk) ...[
          const SizedBox(height: 12),
          _buildSpecialAidCard(),
        ],
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Valider mon check-up'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => setState(() => _showResults = false),
            child: const Text('Refaire le check-up'),
          ),
        ),
        const SizedBox(height: 32),
        const Center(
          child: Text(
            'L\'honnêteté envers soi-même est le premier pas vers la sérénité.',
            style: TextStyle(fontStyle: FontStyle.italic, color: MintColors.textMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildGuidanceItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.arrow_forward, color: MintColors.primary, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.5))),
        ],
      ),
    );
  }

  Widget _buildSpecialAidCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.05),
        borderRadius: const Borderconst Radius.circular(16),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.support_agent_outlined, color: Colors.purple),
              const SizedBox(width: 12),
              Text('Soutien Jeux & Paris', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.purple)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Un soutien professionnel et anonyme est disponible gratuitement.', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _launchUrl('https://www.sos-jeu.ch/'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.purple, side: const BorderSide(color: Colors.purple)),
              child: const Text('SOS Jeu - Aide en ligne'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyNote() {
    return const Center(
      child: Text(
        'Mint respecte ta vie privée. Aucune donnée n\'est stockée ou transmise.',
        style: TextStyle(color: MintColors.textMuted, fontSize: 11),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}
