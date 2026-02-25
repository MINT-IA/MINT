import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/consent_manager.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Consent Dashboard Screen — Sprint S40.
///
/// Shows 3 independent consent toggles with:
///   - Clear label and detail text
///   - What is NEVER sent (privacy reassurance)
///   - BYOK: expandable section showing exact fields
///   - Legal disclaimer at bottom
///
/// Colors per consent type:
///   - BYOK (Personnalisation IA): MintColors.purple
///   - Snapshots (Historique): MintColors.teal
///   - Notifications (Rappels): MintColors.info (blue)
///
/// All consents OFF by default (privacy by design, nLPD art. 6).
class ConsentDashboardSettingsScreen extends StatefulWidget {
  const ConsentDashboardSettingsScreen({super.key});

  @override
  State<ConsentDashboardSettingsScreen> createState() =>
      _ConsentDashboardSettingsScreenState();
}

class _ConsentDashboardSettingsScreenState
    extends State<ConsentDashboardSettingsScreen> {
  late ConsentDashboard _dashboard;
  bool _byokExpanded = false;

  @override
  void initState() {
    super.initState();
    _dashboard = ConsentManager.getDefaultDashboard();
    _loadPersistedConsents();
  }

  Future<void> _loadPersistedConsents() async {
    final dashboard = await ConsentManager.loadDashboard();
    if (mounted) setState(() => _dashboard = dashboard);
  }

  Future<void> _toggleConsent(ConsentType type, bool enabled) async {
    setState(() {
      _dashboard = _dashboard.copyWithToggled(type, enabled);
    });
    await ConsentManager.updateConsent(type, enabled);
  }

  Future<void> _revokeAll() async {
    setState(() {
      _dashboard = _dashboard.copyWithAllRevoked();
      _byokExpanded = false;
    });
    await ConsentManager.revokeAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tous les consentements ont ete revoques.'),
        ),
      );
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  'Controle tes donnees. Chaque parametre est '
                  'independant et revocable a tout moment.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: MintColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                // ── Consent cards ─────────────────────────────
                for (final consent in _dashboard.consents) ...[
                  _buildConsentCard(consent),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 8),
                // ── Revoke all button ─────────────────────────
                _buildRevokeAllButton(),
                const SizedBox(height: 24),
                // ── Disclaimer ────────────────────────────────
                _buildDisclaimer(),
                const SizedBox(height: 16),
                // ── Sources ───────────────────────────────────
                _buildSources(),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  APP BAR
  // ════════════════════════════════════════════════════════════════

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: MintColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [MintColors.primary, Color(0xFF2D2D30)],
            ),
          ),
        ),
        title: Text(
          'Consentements',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  CONSENT CARD
  // ════════════════════════════════════════════════════════════════

  Widget _buildConsentCard(ConsentState consent) {
    final color = _consentColor(consent.type);
    final icon = _consentIcon(consent.type);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.circular(20),
        border: Border.all(
          color: consent.enabled
              ? color.withValues(alpha: 0.4)
              : MintColors.lightBorder,
        ),
        boxShadow: consent.enabled
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row: icon + label + switch ───────────
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  consent.label,
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              Switch.adaptive(
                value: consent.enabled,
                onChanged: (v) => _toggleConsent(consent.type, v),
                activeThumbColor: color,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── Detail text ────────────────────────────────
          Text(
            consent.detail,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          // ── Never sent section ─────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: const BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: MintColors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jamais envoye :',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: MintColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        consent.neverSent,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: MintColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── BYOK expandable detail ─────────────────────
          if (consent.type == ConsentType.byokDataSharing) ...[
            const SizedBox(height: 12),
            _buildByokExpandable(),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  BYOK EXPANDABLE DETAIL
  // ════════════════════════════════════════════════════════════════

  Widget _buildByokExpandable() {
    final detail = ConsentManager.getByokDetail();
    final sent = detail['sent'] ?? [];
    final neverSent = detail['neverSent'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _byokExpanded = !_byokExpanded),
          borderRadius: const BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  _byokExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: 18,
                  color: MintColors.purple,
                ),
                const SizedBox(width: 4),
                Text(
                  'Voir les details',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: MintColors.purple,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_byokExpanded) ...[
          const SizedBox(height: 12),
          // Sent fields
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.purple.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.circular(12),
              border: Border.all(
                color: MintColors.purple.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Donnees transmises',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: MintColors.purple,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: sent.map((field) => _buildFieldChip(
                    field,
                    MintColors.purple,
                  )).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Never sent fields
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.success.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.circular(12),
              border: Border.all(
                color: MintColors.success.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.lock_outlined,
                      size: 14,
                      color: MintColors.success,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Jamais transmis',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: MintColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: neverSent.map((field) => _buildFieldChip(
                    field,
                    MintColors.success,
                  )).toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFieldChip(String field, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.circular(8),
      ),
      child: Text(
        field,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  REVOKE ALL BUTTON
  // ════════════════════════════════════════════════════════════════

  Widget _buildRevokeAllButton() {
    final anyEnabled = _dashboard.consents.any((c) => c.enabled);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: anyEnabled ? _revokeAll : null,
        icon: const Icon(Icons.remove_circle_outline, size: 18),
        label: const Text('Revoquer tout'),
        style: OutlinedButton.styleFrom(
          foregroundColor: MintColors.error,
          side: BorderSide(
            color: anyEnabled
                ? MintColors.error
                : MintColors.lightBorder,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  DISCLAIMER + SOURCES
  // ════════════════════════════════════════════════════════════════

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.circular(12),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 16,
            color: MintColors.info,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _dashboard.disclaimer,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: MintColors.textMuted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSources() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sources legales',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: MintColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        ..._dashboard.sources.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '\u2022 $s',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: MintColors.textMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════════

  Color _consentColor(ConsentType type) {
    switch (type) {
      case ConsentType.byokDataSharing:
        return MintColors.purple;
      case ConsentType.snapshotStorage:
        return MintColors.teal;
      case ConsentType.notifications:
        return MintColors.info;
    }
  }

  IconData _consentIcon(ConsentType type) {
    switch (type) {
      case ConsentType.byokDataSharing:
        return Icons.smart_toy_outlined;
      case ConsentType.snapshotStorage:
        return Icons.history;
      case ConsentType.notifications:
        return Icons.notifications_outlined;
    }
  }
}
