import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

class ConsentDashboardScreen extends StatefulWidget {
  const ConsentDashboardScreen({super.key});

  @override
  State<ConsentDashboardScreen> createState() => _ConsentDashboardScreenState();
}

class _ConsentDashboardScreenState extends State<ConsentDashboardScreen> {
  bool _sixActive = true;
  bool _partnerActive = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        title: Text('CENTRE DE CONTRÔLE DATA', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSecurityHeader(),
            const SizedBox(height: 32),
            const Text('Partages Actifs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildConsentCard(
              partner: 'SIX bLink (Open Banking)',
              purpose: 'Lecture solde & transactions (30 jours)',
              scope: ['Identité', 'Comptes épargne', 'Comptes courants'],
              isActive: _sixActive,
              onChanged: (v) => setState(() => _sixActive = v),
            ),
            const SizedBox(height: 16),
            _buildConsentCard(
              partner: 'Partenaire 3a (Bancaire)',
              purpose: 'Simplification de souscription',
              scope: ['Identité', 'Canton'],
              isActive: _partnerActive,
              onChanged: (v) => setState(() => _partnerActive = v),
            ),
            const SizedBox(height: 40),
            _buildRevokeAllButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.success.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.success.withOpacity(0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_person_outlined, color: MintColors.success),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Vos données restent sur votre appareil. Vous gardez le contrôle total sur les accès tiers.',
              style: TextStyle(fontSize: 13, color: MintColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentCard({
    required String partner,
    required String purpose,
    required List<String> scope,
    required bool isActive,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(partner, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Switch.adaptive(value: isActive, onChanged: onChanged, activeColor: MintColors.success),
            ],
          ),
          const SizedBox(height: 4),
          Text(purpose, style: const TextStyle(fontSize: 13, color: MintColors.textSecondary)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: scope.map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: MintColors.background, borderRadius: BorderRadius.circular(8)),
              child: Text(s, style: const TextStyle(fontSize: 10, color: MintColors.textMuted)),
            )).toList(),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => onChanged(false),
            style: TextButton.styleFrom(foregroundColor: Colors.red, visualDensity: VisualDensity.compact),
            child: const Text('Révoquer cet accès'),
          ),
        ],
      ),
    );
  }

  Widget _buildRevokeAllButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            _sixActive = false;
            _partnerActive = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tous les accès ont été révoqués.')),
          );
        },
        style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
        child: const Text('RÉVOQUER TOUS LES ACCÈS'),
      ),
    );
  }
}
