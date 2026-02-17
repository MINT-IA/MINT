import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/constants/social_insurance.dart';

/// Écran de démo pour tester le rapport financier V2
/// Utilise des données fictives d'un profil type
class FinancialReportDemoScreen extends StatelessWidget {
  const FinancialReportDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Données de test : Profil type pour démonstration
    // Julien, 49 ans, marié, VS, 7800 CHF/mois
    final demoAnswers = <String, dynamic>{
      // Profil
      'q_firstname': 'Julien',
      'q_birth_year': 1977,
      'q_canton': 'VS',
      'q_civil_status': 'married',
      'q_children': 0,
      'q_employment_status': 'employee',

      // Cercle 1 - Protection
      'q_emergency_fund': 'yes_3months', // 3-6 mois
      'q_has_consumer_debt': 'no',
      'q_net_income_period_chf': 7800.0,
      'q_housing_status': 'renter',
      'q_housing_cost_period_chf': 1830.0,

      // Cercle 2 - Prévoyance
      'q_has_pension_fund': 'yes',
      'q_3a_accounts_count': 1, // Sous-optimal
      'q_3a_providers': ['bank'], // Banque classique
      'q_3a_annual_contribution': pilier3aPlafondAvecLpp, // Max
      'q_lpp_buyback_available': 200000.0, // 200k disponibles
      'q_avs_gaps': 'unknown',

      // Cercle 3 - Croissance
      'q_has_investments': 'no',

      // Optionnel
      'q_current_lpp_capital': 350000.0,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Démo Rapport V2'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info de démo
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade200, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.science,
                          color: Colors.blue.shade700, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Mode Démonstration',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Ce rapport utilise des données fictives pour démontrer les capacités de la V2.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Profil de test :',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildDemoRow('👤 Prénom', 'Julien'),
                  _buildDemoRow('📅 Âge', '49 ans (1977)'),
                  _buildDemoRow('📍 Canton', 'Valais (VS)'),
                  _buildDemoRow('💑 Statut', 'Marié, 0 enfant'),
                  _buildDemoRow('💰 Revenu', '7\'800 CHF/mois'),
                  _buildDemoRow('🏠 Logement', 'Locataire (1\'830 CHF)'),
                  _buildDemoRow('💼 3a', '1 compte bancaire, max versé'),
                  _buildDemoRow('🏦 LPP', 'Rachat 200k disponible'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Bouton pour voir le rapport
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  context.push('/report/v2', extra: demoAnswers);
                },
                icon: const Icon(Icons.analytics, size: 24),
                label: const Text(
                  'Voir le Rapport Complet',
                  style: TextStyle(fontSize: 16),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Info supplémentaire
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Le rapport inclut :\n'
                      '• Score de santé financière par cercle\n'
                      '• Top 3 actions prioritaires\n'
                      '• Comparateur 3a (VIAC vs Banque)\n'
                      '• Simulation fiscale\n'
                      '• Projection retraite\n'
                      '• Stratégie rachat LPP échelonné',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Scénarios alternatifs
            const Text(
              'Scénarios de test',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            _buildScenarioCard(
              context,
              title: '🚀 Profil Optimisé',
              description:
                  '35 ans, 2 comptes 3a chez VIAC, investissements diversifiés',
              answers: {
                'q_firstname': 'Sarah',
                'q_birth_year': 1991,
                'q_canton': 'ZH',
                'q_civil_status': 'single',
                'q_children': 0,
                'q_employment_status': 'employee',
                'q_emergency_fund': 'yes_6months',
                'q_has_consumer_debt': 'no',
                'q_net_income_period_chf': 9500.0,
                'q_pay_frequency': 'monthly',
                'q_3a_accounts_count': 3,
                'q_3a_providers': ['fintech'], // Fintech
                'q_3a_annual_contribution': pilier3aPlafondAvecLpp,
                'q_lpp_buyback_available': 0,
                'q_has_investments': 'yes',
                'q_housing_status': 'owner',
              },
            ),

            const SizedBox(height: 12),

            _buildScenarioCard(
              context,
              title: '⚠️ Profil à Risque',
              description: '28 ans, dettes, pas de 3a, pas de fonds d\'urgence',
              answers: {
                'q_firstname': 'Marc',
                'q_birth_year': 1998,
                'q_canton': 'GE',
                'q_civil_status': 'single',
                'q_children': 0,
                'q_employment_status': 'employee',
                'q_emergency_fund': 'no',
                'q_has_consumer_debt': 'yes',
                'q_net_income_period_chf': 4500.0,
                'q_pay_frequency': 'monthly',
                'q_3a_accounts_count': 0,
                'q_lpp_buyback_available': 0,
                'q_has_investments': 'no',
                'q_housing_status': 'renter',
                'q_housing_cost_period_chf': 1200.0,
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label : ', style: const TextStyle(fontSize: 11)),
          Text(value,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildScenarioCard(
    BuildContext context, {
    required String title,
    required String description,
    required Map<String, dynamic> answers,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          context.push('/report/v2', extra: answers);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
