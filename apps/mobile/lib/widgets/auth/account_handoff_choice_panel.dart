import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/account_handoff_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

class AccountHandoffChoicePanel extends StatefulWidget {
  const AccountHandoffChoicePanel({super.key});

  @override
  State<AccountHandoffChoicePanel> createState() =>
      _AccountHandoffChoicePanelState();
}

class _AccountHandoffChoicePanelState extends State<AccountHandoffChoicePanel> {
  AccountHandoffChoice _choice = AccountHandoffChoice.keepLocal;
  bool _hasLocalData = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final choice = await AccountHandoffService.loadChoice();
    final hasLocalData = await AccountHandoffService.hasLocalData();
    if (!mounted) return;
    setState(() {
      _choice = choice;
      _hasLocalData = hasLocalData;
    });
  }

  Future<void> _setChoice(AccountHandoffChoice choice) async {
    setState(() => _choice = choice);
    await AccountHandoffService.saveChoice(choice);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final hint = _choice == AccountHandoffChoice.keepLocal
        ? l10n.authHandoffKeepHint
        : l10n.authHandoffRestartHint;

    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      padding: const EdgeInsets.all(MintSpacing.md),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.storage_outlined,
                color: MintColors.primary,
                size: 20,
              ),
              const SizedBox(width: MintSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.authHandoffTitle,
                      style: MintTextStyles.bodyMedium().copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _hasLocalData
                          ? l10n.authHandoffLocalDetected
                          : l10n.authHandoffNoLocalData,
                      style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),
          SegmentedButton<AccountHandoffChoice>(
            showSelectedIcon: false,
            selected: {_choice},
            onSelectionChanged: (values) => _setChoice(values.first),
            segments: [
              ButtonSegment(
                value: AccountHandoffChoice.keepLocal,
                icon: const Icon(Icons.folder_copy_outlined),
                label: Text(l10n.authHandoffKeep),
              ),
              ButtonSegment(
                value: AccountHandoffChoice.restartClean,
                icon: const Icon(Icons.restart_alt_outlined),
                label: Text(l10n.authHandoffRestart),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            hint,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
        ],
      ),
    );
  }
}
