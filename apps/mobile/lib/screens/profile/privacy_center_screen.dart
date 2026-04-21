// PrivacyCenterScreen — lists active + historical consent receipts, allows
// revocation from a single hub. Reachable at `/profile/privacy`.
//
// v2.7 Phase 29 / PRIV-01.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/consent/consent_service.dart';
import 'package:mint_mobile/theme/colors.dart';
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
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.consentCancel),
          ),
          FilledButton(
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          l.privacyCenterTitle,
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: MintColors.textPrimary,
          ),
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
                      style: GoogleFonts.inter(
                        fontSize: 14,
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
              ],
            ),
          );
        },
      ),
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
        style: GoogleFonts.montserrat(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: MintColors.textSecondary,
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
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  revokedAt == null
                      ? '${l.privacyCenterGrantedOn} ${_fmt(grantedAt)}'
                      : '${l.privacyCenterRevokedOn} ${_fmt(revokedAt!)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (onRevoke != null)
            TextButton(
              onPressed: onRevoke,
              child: Text(l.consentRevoke),
            ),
        ],
      ),
    );
  }
}
