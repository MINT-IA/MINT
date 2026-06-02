// Third-party opposable declaration — v2.7 Phase 29 / PRIV-02.
//
// Shown when the backend returns HTTP 428 from /extract-vision with a list
// of detected subject_names. The user must actively confirm they have the
// consent of the named person(s) before the upload can finalise.
//
// Declaration is nominative and bound to (subject_name, doc_hash). A
// secondary CTA "Inviter sur MINT" logs intent only — the async invite
// flow is deferred post-v2.7 (constraint from 29-05-PLAN).
//
// Copy voice per docs/VOICE_SYSTEM.md. No banned terms (CLAUDE.md §6).

import 'package:flutter/material.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

enum ThirdPartyDeclarationChoice { confirmed, cancelled }

class ThirdPartyDeclarationSheet extends StatelessWidget {
  final List<String> subjectNames;
  final VoidCallback? onInviteIntent;

  const ThirdPartyDeclarationSheet({
    super.key,
    required this.subjectNames,
    this.onInviteIntent,
  });

  static Future<ThirdPartyDeclarationChoice?> show(
    BuildContext context, {
    required List<String> subjectNames,
    VoidCallback? onInviteIntent,
  }) {
    return showModalBottomSheet<ThirdPartyDeclarationChoice>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: MintColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ThirdPartyDeclarationSheet(
        subjectNames: subjectNames,
        onInviteIntent: onInviteIntent,
      ),
    );
  }

  String _joinedNames() => subjectNames.join(', ');

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final multiple = subjectNames.length > 1;
    final names = _joinedNames();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.thirdPartyDeclarationTitle,
              style:
                  MintTextStyles.headlineSmall(color: MintColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              multiple
                  ? l.thirdPartyDeclarationMultipleBody(names)
                  : l.thirdPartyDeclarationBody(names),
              style: const TextStyle(
                color: MintColors.textSecondary,
                height: 1.45,
              ).merge(MintTextStyles.labelLarge()),
            ),
            const SizedBox(height: 8),
            Text(
              l.thirdPartyDeclarationNoticeLink,
              style: const TextStyle(
                color: MintColors.textSecondary,
                fontStyle: FontStyle.italic,
              ).merge(MintTextStyles.bodySmall()),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              // lint-ignore: prefer_mint_cta
              key: const Key('thirdPartyDeclarationConfirm'),
              style: ElevatedButton.styleFrom(
                backgroundColor: MintColors.primary,
                foregroundColor: MintColors.background,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(context)
                  .pop(ThirdPartyDeclarationChoice.confirmed),
              child: Text(
                l.thirdPartyDeclarationConfirm,
                style: MintTextStyles.labelLarge()
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              // lint-ignore: prefer_mint_cta
              key: const Key('thirdPartyDeclarationCancel'),
              onPressed: () => Navigator.of(context)
                  .pop(ThirdPartyDeclarationChoice.cancelled),
              child: Text(
                l.thirdPartyDeclarationCancel,
                style: MintTextStyles.bodyMedium(
                  color: MintColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              key: const Key('thirdPartyInviteCta'),
              icon: const Icon(Icons.send_outlined, size: 18),
              onPressed: () {
                onInviteIntent?.call();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l.thirdPartyInviteComingSoon),
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              label: Text(
                l.thirdPartyInviteCta(
                  subjectNames.isNotEmpty ? subjectNames.first : '',
                ),
                style: MintTextStyles.bodySmall(),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: MintColors.primary,
                side: BorderSide(
                    color: MintColors.primary.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
