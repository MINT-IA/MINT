import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
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
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                S.of(context)!.householdTitle,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: MintColors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [MintColors.primary, MintColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          if (!auth.isLoggedIn)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildLoginPrompt(context),
            )
          else if (!sub.isPaid)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildUpsellCard(context),
            )
          else if (household.isLoading && !household.hasHousehold)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SliverToBoxAdapter(
              child: _buildContent(context, household),
            ),
        ],
      ),
    );
  }

  Widget _buildUpsellCard(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: MintColors.greyBorderLight),
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
              S.of(context)!.householdUpsellDescription,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: MintColors.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                final sub = context.read<SubscriptionProvider>();
                sub.upgrade(SubscriptionTier.couplePlus);
              },
              child: Text(S.of(context)!.householdDiscoverCouplePlus),
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
            const Icon(Icons.people_outline, size: 64, color: MintColors.greyBorderLight),
            const SizedBox(height: 16),
            Text(
              S.of(context)!.householdLoginPrompt,
              style: GoogleFonts.inter(fontSize: 16, color: MintColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.push('/auth/login'),
              child: Text(S.of(context)!.householdLogin),
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
            const Icon(Icons.error_outline, size: 48, color: MintColors.coralLight),
            const SizedBox(height: 16),
            Text(
              household.error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: MintColors.redDeep),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                household.clearError();
                household.loadHousehold();
              },
              child: Text(S.of(context)!.householdRetry),
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
            const Icon(Icons.favorite_border, size: 48, color: MintColors.primary),
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
              S.of(context)!.householdEmptyDescription,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: MintColors.textSecondary),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => setState(() => _showInviteForm = true),
              icon: const Icon(Icons.person_add),
              label: Text(S.of(context)!.householdInvitePartner),
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
            const CircleAvatar(
              backgroundColor: MintColors.primary,
              child: Icon(Icons.home, color: MintColors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context)!.householdHeaderTitle,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    S.of(context)!.householdMemberCount(household.activeMemberCount),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MintColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (household.isOwner)
              Chip(
                label: Text(
                  S.of(context)!.householdOwnerBadge,
                  style: GoogleFonts.inter(fontSize: 11, color: MintColors.white),
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
              S.of(context)!.householdMembersTitle,
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
        member['displayName'] ?? member['email'] ?? S.of(context)!.householdPartnerDefault;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: isPending
            ? MintColors.warningBg
            : MintColors.primary.withValues(alpha: 0.15),
        child: Icon(
          isPending ? Icons.hourglass_top : Icons.person,
          color: isPending ? MintColors.warning : MintColors.primary,
        ),
      ),
      title: Text(
        displayName as String,
        style: GoogleFonts.inter(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        isPending ? S.of(context)!.householdPendingStatus : S.of(context)!.householdActiveStatus,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: isPending ? MintColors.warning : MintColors.categoryGreen,
        ),
      ),
      trailing: household.isOwner && isPartner
          ? IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: MintColors.error),
              tooltip: S.of(context)!.householdRemoveTooltip,
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
        title: Text(S.of(context)!.householdRemoveMemberTitle),
        content: Text(
          S.of(context)!.householdRemoveMemberContent,
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.of(context)!.householdCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: MintColors.error),
            child: Text(S.of(context)!.householdRemove),
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
              S.of(context)!.householdInviteSectionTitle,
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              S.of(context)!.householdInviteInfo,
              style: GoogleFonts.inter(fontSize: 13, color: MintColors.textSecondary),
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
            labelText: S.of(context)!.householdEmailLabel,
            hintText: S.of(context)!.householdEmailHint,
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
                      color: MintColors.white,
                    ),
                  )
                : Text(S.of(context)!.householdSendInvitation),
          ),
        ),
      ],
    );
  }

  Widget _buildInviteCodeCard(
      BuildContext context, HouseholdProvider household) {
    return Card(
      color: MintColors.successBg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.check_circle, size: 40, color: MintColors.categoryGreen),
            const SizedBox(height: 8),
            Text(
              S.of(context)!.householdInviteSentTitle,
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: MintColors.greenDark,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: MintColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MintColors.greenLight),
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
                      SnackBar(content: Text(S.of(context)!.householdCodeCopied)),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(S.of(context)!.householdCopy),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(
                      text: S.of(context)!.householdShareMessage(household.pendingInviteCode!),
                    ));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(S.of(context)!.householdMessageCopied)),
                    );
                  },
                  icon: const Icon(Icons.share, size: 18),
                  label: Text(S.of(context)!.householdShare),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              S.of(context)!.householdValidFor,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.greyMedium,
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
      label: Text(S.of(context)!.householdHaveCode),
    );
  }
}
