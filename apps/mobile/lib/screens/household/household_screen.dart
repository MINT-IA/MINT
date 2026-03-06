import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/household_provider.dart';
import 'package:mint_mobile/providers/subscription_provider.dart';
import 'package:mint_mobile/services/subscription_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:provider/provider.dart';

/// Household management screen — Couple+ tier.
///
/// Shows household status, members, invitation flow, and partner management.
/// Requires authentication. Backs onto [HouseholdService] backend endpoints.
class HouseholdScreen extends StatefulWidget {
  const HouseholdScreen({super.key});

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  final _emailController = TextEditingController();
  bool _showInviteForm = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HouseholdProvider>().loadHousehold();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final household = context.watch<HouseholdProvider>();
    final auth = context.watch<AuthProvider>();
    final sub = context.watch<SubscriptionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notre Famille',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
        backgroundColor: MintColors.primary,
        foregroundColor: Colors.white,
      ),
      body: !auth.isLoggedIn
          ? _buildLoginPrompt(context)
          : !sub.isPaid
              ? _buildUpsellCard(context)
              : household.isLoading && !household.hasHousehold
                  ? const Center(child: CircularProgressIndicator())
                  : _buildContent(context, household),
    );
  }

  Widget _buildUpsellCard(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Couple+',
              style: GoogleFonts.montserrat(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Optimise ta retraite a deux avec un abonnement Couple+. '
              'Projections partagees, retraits echelonnes, et coaching couple.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                final sub = context.read<SubscriptionProvider>();
                sub.upgrade(SubscriptionTier.couplePlus);
              },
              child: const Text('Decouvrir Couple+'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginPrompt(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Connecte-toi pour gerer ton menage',
              style: GoogleFonts.inter(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.push('/auth/login'),
              child: const Text('Se connecter'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, HouseholdProvider household) {
    if (household.error != null) {
      return _buildError(context, household);
    }

    return RefreshIndicator(
      onRefresh: () => household.loadHousehold(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!household.hasHousehold) ...[
            _buildEmptyState(context, household),
          ] else ...[
            _buildHouseholdHeader(context, household),
            const SizedBox(height: 16),
            _buildMembersList(context, household),
            const SizedBox(height: 16),
            if (household.isOwner && household.activeMemberCount < 2)
              _buildInviteSection(context, household),
          ],
          if (household.pendingInviteCode != null) ...[
            const SizedBox(height: 16),
            _buildInviteCodeCard(context, household),
          ],
          const SizedBox(height: 24),
          _buildAcceptSection(context),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, HouseholdProvider household) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              household.error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.red.shade600),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                household.clearError();
                household.loadHousehold();
              },
              child: const Text('Reessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, HouseholdProvider household) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.favorite_border, size: 48, color: MintColors.primary),
            const SizedBox(height: 16),
            Text(
              'Couple+',
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Optimise ta retraite a deux. Retraits echelonnes, '
              'projections couple, et calendrier fiscal commun.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => setState(() => _showInviteForm = true),
              icon: const Icon(Icons.person_add),
              label: const Text('Inviter mon/ma partenaire'),
            ),
            if (_showInviteForm) ...[
              const SizedBox(height: 16),
              _buildInviteForm(context, household),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHouseholdHeader(
      BuildContext context, HouseholdProvider household) {
    return Card(
      color: MintColors.primary.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: MintColors.primary,
              child: const Icon(Icons.home, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Menage Couple+',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${household.activeMemberCount} membre${household.activeMemberCount > 1 ? 's' : ''} actif${household.activeMemberCount > 1 ? 's' : ''}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (household.isOwner)
              Chip(
                label: Text(
                  'Proprietaire',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white),
                ),
                backgroundColor: MintColors.primary,
                side: BorderSide.none,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersList(
      BuildContext context, HouseholdProvider household) {
    final activeMembers =
        household.members.where((m) => m['status'] != 'revoked').toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Membres',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
            ...activeMembers.map((member) => _buildMemberTile(
                  context, household, member)),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(
    BuildContext context,
    HouseholdProvider household,
    Map<String, dynamic> member,
  ) {
    final isPending = member['status'] == 'pending';
    final isPartner = member['role'] == 'partner';
    final displayName =
        member['displayName'] ?? member['email'] ?? 'Partenaire';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: isPending
            ? Colors.orange.shade100
            : MintColors.primary.withValues(alpha: 0.15),
        child: Icon(
          isPending ? Icons.hourglass_top : Icons.person,
          color: isPending ? Colors.orange.shade700 : MintColors.primary,
        ),
      ),
      title: Text(
        displayName as String,
        style: GoogleFonts.inter(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        isPending ? 'Invitation en attente' : 'Actif',
        style: GoogleFonts.inter(
          fontSize: 12,
          color: isPending ? Colors.orange.shade600 : Colors.green.shade600,
        ),
      ),
      trailing: household.isOwner && isPartner
          ? IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              tooltip: 'Retirer du menage',
              onPressed: () => _confirmRevoke(context, household, member),
            )
          : null,
    );
  }

  Future<void> _confirmRevoke(
    BuildContext context,
    HouseholdProvider household,
    Map<String, dynamic> member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirer ce membre ?'),
        content: Text(
          'Cette action est irreversible. Un delai de 30 jours s\'applique '
          'avant de pouvoir reinviter un nouveau partenaire.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final userId = member['userId'] ?? member['user_id'];
      if (userId != null) {
        await household.revokeMember(userId as String);
      }
    }
  }

  Widget _buildInviteSection(
      BuildContext context, HouseholdProvider household) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inviter un·e partenaire',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ton/ta partenaire recevra un code d\'invitation valable 72 heures.',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            _buildInviteForm(context, household),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteForm(
      BuildContext context, HouseholdProvider household) {
    return Column(
      children: [
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email du/de la partenaire',
            hintText: 'partenaire@email.ch',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: household.isLoading
                ? null
                : () async {
                    final email = _emailController.text.trim();
                    if (email.isEmpty || !email.contains('@')) return;
                    await household.invitePartner(email);
                    if (mounted) _emailController.clear();
                  },
            child: household.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Envoyer l\'invitation'),
          ),
        ),
      ],
    );
  }

  Widget _buildInviteCodeCard(
      BuildContext context, HouseholdProvider household) {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.check_circle, size: 40, color: Colors.green.shade600),
            const SizedBox(height: 8),
            Text(
              'Invitation envoyee',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                household.pendingInviteCode!,
                style: GoogleFonts.montserrat(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: household.pendingInviteCode!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copie')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copier'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(
                      text: 'Rejoins mon menage MINT avec le code : '
                          '${household.pendingInviteCode!}\n\n'
                          'Ouvre l\'app MINT > Famille > J\'ai un code',
                    ));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message copie')),
                    );
                  },
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Partager'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Valable 72 heures',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcceptSection(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => context.push('/household/accept'),
      icon: const Icon(Icons.qr_code),
      label: const Text('J\'ai un code d\'invitation'),
    );
  }
}
