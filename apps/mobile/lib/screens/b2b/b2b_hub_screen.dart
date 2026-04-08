/// B2B Hub Screen — employer/caisse portal.
///
/// Design: Cleo-inspired — calm, warm, narrative-first.
/// Hero zone with org identity → module cards → quiet leave.
///
/// Sprint S71-S72 — Phase 4 "La Référence"
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/b2b/b2b_organization_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_narrative_card.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

class B2bHubScreen extends StatefulWidget {
  const B2bHubScreen({super.key});

  @override
  State<B2bHubScreen> createState() => _B2bHubScreenState();
}

class _B2bHubScreenState extends State<B2bHubScreen> {
  B2bOrganization? _org;
  bool _loading = true;
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadOrganization();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadOrganization() async {
    final org = await B2bOrganizationService.getOrganization();
    if (mounted) setState(() { _org = org; _loading = false; });
  }

  Future<void> _joinOrganization() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() => _loading = true);
    try {
      await B2bOrganizationService.joinOrganization(inviteCode: code);
      await _loadOrganization();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context)!.b2bHubInvalidCode)),
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _leaveOrganization() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(S.of(context)!.b2bHubLeaveTitle,
            style: MintTextStyles.headlineMedium()),
        content: Text(
          S.of(context)!.b2bHubLeaveBody,
          style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.of(context)!.commonCancel, style: MintTextStyles.bodyMedium()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.of(context)!.commonConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await B2bOrganizationService.leaveOrganization();
    await _loadOrganization();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _org == null
              ? _buildJoinView()
              : _buildOrgView(),
    );
  }

  // ── JOIN VIEW (no org yet) ────────────────────────────────────────

  Widget _buildJoinView() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 180,
          pinned: true,
          backgroundColor: MintColors.primary,
          foregroundColor: MintColors.white,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(S.of(context)!.b2bHubTitle,
                style: MintTextStyles.titleMedium(color: MintColors.white)),
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [MintColors.primary, MintColors.primaryLight],
                ),
              ),
              child: Center(
                child: Icon(Icons.business_center_outlined,
                    size: 64, color: MintColors.white.withAlpha(61)),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(MintSpacing.xl),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              MintEntrance(
                child: MintNarrativeCard(
                  headline: S.of(context)!.b2bHubNarrativeHeadline,
                  body: S.of(context)!.b2bHubNarrativeBody,
                  tone: MintSurfaceTone.porcelaine,
                ),
              ),
              const SizedBox(height: MintSpacing.xl),

              // Code input — elevated, centered
              MintEntrance(
                delay: const Duration(milliseconds: 200),
                child: MintSurface(
                  padding: const EdgeInsets.all(MintSpacing.lg + 4),
                  radius: 20,
                  elevated: true,
                  child: Column(
                    children: [
                      Text(S.of(context)!.b2bHubInviteCodeLabel,
                          style: MintTextStyles.bodySmall(
                              color: MintColors.textMuted)),
                      const SizedBox(height: MintSpacing.md),
                      TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        textAlign: TextAlign.center,
                        style: MintTextStyles.displayMedium()
                            .copyWith(letterSpacing: 4, fontSize: 28),
                        decoration: InputDecoration(
                          hintText: '• • • • • •',
                          hintStyle: MintTextStyles.displayMedium().copyWith(
                            letterSpacing: 8,
                            fontSize: 28,
                            color: MintColors.lightBorder,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: MintSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: Semantics(
                          button: true,
                          label: S.of(context)!.b2bHubJoinSemantics,
                          child: FilledButton(
                            onPressed: _joinOrganization,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(S.of(context)!.b2bHubJoinButton,
                                style: MintTextStyles.titleMedium(
                                    color: MintColors.white)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: MintSpacing.xl),
              MintEntrance(
                delay: const Duration(milliseconds: 400),
                child: Text(
                  S.of(context)!.b2bHubNoCodeHint,
                  style: MintTextStyles.bodySmall(color: MintColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  // ── ORG VIEW (connected) ──────────────────────────────────────────

  Widget _buildOrgView() {
    final org = _org!;
    final modules = B2bOrganizationService.availableModules(org);

    return CustomScrollView(
      slivers: [
        // Hero gradient with org name
        SliverAppBar(
          expandedHeight: 160,
          pinned: true,
          backgroundColor: MintColors.primary,
          foregroundColor: MintColors.white,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(org.name,
                style: MintTextStyles.titleMedium(color: MintColors.white)),
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [MintColors.primary, MintColors.primaryLight],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(MintSpacing.xl),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Org info card
              MintEntrance(
                child: MintSurface(
                  padding: const EdgeInsets.all(MintSpacing.lg),
                  radius: 16,
                  elevated: true,
                  child: Row(
                    children: [
                      // Org avatar
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: MintColors.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            org.name.isNotEmpty ? org.name[0].toUpperCase() : '?',
                            style: MintTextStyles.displayMedium(
                                color: MintColors.white)
                                .copyWith(fontSize: 24),
                          ),
                        ),
                      ),
                      const SizedBox(width: MintSpacing.md + 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              S.of(context)!.b2bHubEmployeeCount(org.employeeCount.toString()),
                              style: MintTextStyles.bodyMedium(),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: MintColors.primary.withAlpha(15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Plan ${org.plan.name}',
                                style: MintTextStyles.micro(
                                    color: MintColors.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: MintSpacing.xl),

              // Section title
              MintEntrance(
                delay: const Duration(milliseconds: 100),
                child: Text(S.of(context)!.b2bHubModulesTitle,
                    style: MintTextStyles.headlineMedium()),
              ),
              const SizedBox(height: MintSpacing.md),

              // Module cards — staggered entrance
              ...modules.asMap().entries.map((e) {
                final delay = Duration(milliseconds: 200 + e.key * 120);
                return MintEntrance(
                  delay: delay,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: MintSpacing.sm),
                    child: _buildModuleCard(e.value),
                  ),
                );
              }),

              const SizedBox(height: MintSpacing.xl * 2),

              // Quiet leave
              Center(
                child: TextButton(
                  onPressed: _leaveOrganization,
                  child: Text(
                    S.of(context)!.b2bHubLeaveButton,
                    style: MintTextStyles.bodySmall(color: MintColors.textMuted),
                  ),
                ),
              ),
              const SizedBox(height: MintSpacing.xl),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildModuleCard(String module) {
    final l = S.of(context)!;
    final (icon, label, subtitle, route) = switch (module) {
      'education' => (
        Icons.school_outlined,
        l.b2bModuleEducation,
        l.b2bModuleEducationSubtitle,
        '/explore/retraite',  // Education hub entry (no root /explorer route)
      ),
      'wellness' => (
        Icons.favorite_outline,
        l.b2bModuleWellness,
        l.b2bModuleWellnessSubtitle,
        '/home',
      ),
      '3a' => (
        Icons.savings_outlined,
        l.b2bModule3a,
        l.b2bModule3aSubtitle,
        '/pilier-3a',
      ),
      'lpp' => (
        Icons.account_balance_outlined,
        l.b2bModuleLpp,
        l.b2bModuleLppSubtitle,
        '/rachat-lpp',  // LPP deep entry point (no /lpp-deep root route)
      ),
      _ => (
        Icons.extension_outlined,
        module,
        '',
        '/home',
      ),
    };

    return MintSurface(
      radius: 14,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.lightImpact();
          context.push(route);
        },
        child: Padding(
          padding: const EdgeInsets.all(MintSpacing.md + 4),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: MintColors.primary.withAlpha(10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: MintColors.primary, size: 21),
              ),
              const SizedBox(width: MintSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: MintTextStyles.bodyMedium()
                        .copyWith(fontWeight: FontWeight.w600)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: MintTextStyles.bodySmall(
                              color: MintColors.textMuted)),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: MintColors.textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
