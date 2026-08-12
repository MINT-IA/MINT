// PrivacyCenterScreen — lists active + historical consent receipts, allows
// revocation from a single hub. Reachable at `/profile/privacy`.
//
// v2.7 Phase 29 / PRIV-01.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/local_preview_reset_service.dart';
import 'package:mint_mobile/services/preview_shell_policy.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/consent/consent_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/future_builder_safe.dart';

class PrivacyCenterScreen extends StatefulWidget {
  const PrivacyCenterScreen({super.key});

  @override
  State<PrivacyCenterScreen> createState() => _PrivacyCenterScreenState();
}

class _PrivacyCenterScreenState extends State<PrivacyCenterScreen> {
  final ConsentService _service = ConsentService();
  late Future<List<ConsentReceipt>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.list(force: true);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _service.list(force: true);
    });
  }

  Future<void> _confirmRevoke(ConsentReceipt receipt) async {
    final l = S.of(context)!;
    final isCascade = receipt.purpose == ConsentPurpose.persistence365d;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.consentRevokeConfirmTitle),
        content: Text(
          isCascade
              ? l.consentRevokeCascadeWarning
              : l.consentRevokeConfirmBody,
        ),
        actions: [
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.consentCancel),
          ),
          FilledButton(
            // lint-ignore: prefer_mint_cta
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.consentRevoke),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.revoke(receipt.receiptId);
      if (!mounted) return;
      await _refresh();
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final l = S.of(context)!;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.profileDeleteAccountTitle),
        content: Text(l.profileDeleteAccountContent),
        actions: [
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.profileDeleteCancel),
          ),
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l.profileDeleteConfirm,
              style: const TextStyle(color: MintColors.error),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    final deleted = await context.read<AuthProvider>().deleteAccount();
    if (!mounted) return;

    if (deleted) {
      context.go('/');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.profileDeleteAccountError)),
      );
    }
  }

  String _labelForPurpose(S l, ConsentPurpose p) {
    switch (p) {
      case ConsentPurpose.visionExtraction:
        return l.consentPurposeVisionExtraction;
      case ConsentPurpose.persistence365d:
        return l.consentPurposePersistence365d;
      case ConsentPurpose.transferUsAnthropic:
        return l.consentPurposeTransferUsAnthropic;
      case ConsentPurpose.coupleProjection:
        return l.consentPurposeCoupleProjection;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final isLoggedIn = context.watch<AuthProvider>().isLoggedIn;
    return Scaffold(
      backgroundColor: MintColors.white,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        elevation: 0,
        title: Text(
          l.privacyCenterTitle,
          style: MintTextStyles.titleLarge(color: MintColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: MintColors.textPrimary),
      ),
      body: FutureBuilderSafe<List<ConsentReceipt>>(
        future: _future,
        onRetry: _refresh,
        builder: (ctx, consents) {
          final active = consents.where((c) => c.isActive).toList();
          final history = consents.where((c) => !c.isActive).toList();
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionHeader(title: l.privacyCenterSectionActive),
                if (active.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      l.privacyCenterEmpty,
                      style: MintTextStyles.bodyMedium(
                        color: MintColors.textSecondary,
                      ),
                    ),
                  )
                else
                  for (final r in active)
                    _ConsentRow(
                      label: _labelForPurpose(l, r.purpose),
                      grantedAt: r.consentTimestamp,
                      onRevoke: () => _confirmRevoke(r),
                    ),
                const SizedBox(height: 24),
                _SectionHeader(title: l.privacyCenterSectionHistory),
                for (final r in history)
                  _ConsentRow(
                    label: _labelForPurpose(l, r.purpose),
                    grantedAt: r.consentTimestamp,
                    revokedAt: r.revokedAt,
                  ),
                if (isLoggedIn) ...[
                  const SizedBox(height: 24),
                  const Divider(color: MintColors.lightBorder),
                  _DeleteAccountRow(onTap: _confirmDeleteAccount),
                ],
                // Bascule 2 — « repartir à zéro » local, préversion uniquement.
                if (PreviewShellPolicy.instance.isPreviewShell) ...[
                  const SizedBox(height: 24),
                  const Divider(color: MintColors.lightBorder),
                  _SectionHeader(title: l.previewResetSection),
                  Semantics(
                    identifier: 'action:preview_reset.open',
                    button: true,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.previewResetTitle,
                          style: MintTextStyles.bodyLarge(
                              color: MintColors.textPrimary)),
                      subtitle: Text(l.previewResetBody,
                          style: MintTextStyles.bodySmall(
                              color: MintColors.textSecondary)),
                      trailing:
                          const Icon(Icons.restart_alt, color: MintColors.error),
                      onTap: _confirmPreviewReset,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

extension _PreviewResetFlow on _PrivacyCenterScreenState {
  Future<void> _confirmPreviewReset() async {
    final l = S.of(context)!;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.previewResetTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.previewResetBody),
            const SizedBox(height: 12),
            TextField(
              key: const Key('preview_reset_confirm_field'),
              controller: controller,
              decoration:
                  InputDecoration(hintText: l.previewResetConfirmHint),
            ),
          ],
        ),
        actions: [
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: () => Navigator.of(dialogContext)
                .pop(controller.text.trim() == l.previewResetConfirmWord),
            child: Text(
              l.previewResetCta,
              style: const TextStyle(color: MintColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final userId = await AuthService.getUserId();
      await LocalPreviewResetService.reset(signedInUserId: userId);
      if (!mounted) return;
      // Rechargement honnête : storage purgé ⇒ profil mémoire remis à null,
      // rien ne survit en RAM jusqu'à la prochaine relance.
      await context.read<CoachProfileProvider>().loadFromWizard();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.previewResetDone)));
      context.go('/home');
    } on StateError {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.previewResetFailed)));
    }
  }
}

class _DeleteAccountRow extends StatelessWidget {
  final VoidCallback onTap;

  const _DeleteAccountRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(
        Icons.delete_outline,
        color: MintColors.error,
        size: 22,
      ),
      title: Text(
        l.profileDeleteCloudAccount,
        style: MintTextStyles.bodyMedium(color: MintColors.error),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: MintColors.error,
        size: 20,
      ),
      onTap: onTap,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style:
            MintTextStyles.bodyMedium(color: MintColors.textSecondary).copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  final String label;
  final DateTime grantedAt;
  final DateTime? revokedAt;
  final VoidCallback? onRevoke;

  const _ConsentRow({
    required this.label,
    required this.grantedAt,
    this.revokedAt,
    this.onRevoke,
  });

  String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: MintTextStyles.labelLarge(
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  revokedAt == null
                      ? '${l.privacyCenterGrantedOn} ${_fmt(grantedAt)}'
                      : '${l.privacyCenterRevokedOn} ${_fmt(revokedAt!)}',
                  style: const TextStyle(
                    color: MintColors.textSecondary,
                  ).merge(MintTextStyles.labelMedium()),
                ),
              ],
            ),
          ),
          if (onRevoke != null)
            TextButton(
              // lint-ignore: prefer_mint_cta
              onPressed: onRevoke,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(l.consentRevoke),
            ),
        ],
      ),
    );
  }
}
