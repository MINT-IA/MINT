import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/routes/mint_next_3a_route_gate.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/mint_next_3a_task_store.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

class MintNext3aHandoffCard extends StatefulWidget {
  const MintNext3aHandoffCard({
    super.key,
    this.store = const MintNext3aTaskStore(),
  });

  final MintNext3aTaskStore store;

  @override
  State<MintNext3aHandoffCard> createState() => _MintNext3aHandoffCardState();
}

class _MintNext3aHandoffCardState extends State<MintNext3aHandoffCard> {
  MintNext3aTask? _task;
  bool _loading = true;
  bool _readFailed = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    FeatureFlags.mintNext3aProductHandoffListenable.addListener(_refresh);
    MintNext3aTaskStore.changes.addListener(_refresh);
    unawaited(_load());
  }

  @override
  void dispose() {
    FeatureFlags.mintNext3aProductHandoffListenable.removeListener(_refresh);
    MintNext3aTaskStore.changes.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => unawaited(_load());

  Future<void> _load() async {
    final generation = ++_generation;
    if (mounted) setState(() => _loading = true);
    MintNext3aTask? task;
    var readFailed = false;
    try {
      task = await widget.store.read();
    } on MintNext3aTaskStorageException {
      readFailed = true;
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _task = task;
      _readFailed = readFailed;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final enabled = FeatureFlags.enableMintNext3aProductHandoff;
    if (_task == null && !_readFailed && !enabled) {
      return const SizedBox.shrink();
    }
    final l10n = S.of(context)!;
    final hasTask = _task != null;
    final actionId = _readFailed
        ? 'action:today.3a_task.recover'
        : hasTask
            ? 'action:today.3a_task.open'
            : 'action:today.open_mint_next_3a';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MintSpacing.md,
        0,
        MintSpacing.md,
        MintSpacing.md,
      ),
      child: Semantics(
        identifier: actionId,
        container: true,
        button: true,
        onTap: () => _open(context),
        label: [
          _readFailed || hasTask
              ? l10n.mintNext3aTaskTitle
              : l10n.mintNext3aTeachBackQuestion,
          if (_readFailed)
            l10n.mintNext3aStorageFailure('read')
          else if (hasTask)
            l10n.mintNext3aTodayStatus(_task!.taxYear)
          else
            l10n.mintNext3aPersonalUnavailable,
          _readFailed
              ? l10n.milestoneContinueBtn
              : hasTask
                  ? l10n.mintNext3aOpenTask
                  : l10n.promiseCta,
        ].join('. '),
        excludeSemantics: true,
        child: Material(
          color: MintColors.craie,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _open(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.all(MintSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.fact_check_outlined,
                        color: MintColors.success),
                    const SizedBox(width: MintSpacing.md),
                    Expanded(
                      child: Semantics(
                        identifier: hasTask
                            ? 'task:today.3a.verify_annual_credited_total'
                            : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _readFailed
                                  ? l10n.mintNext3aTaskTitle
                                  : hasTask
                                      ? l10n.mintNext3aTaskTitle
                                      : l10n.mintNext3aTeachBackQuestion,
                              style: MintTextStyles.titleMedium(
                                  color: MintColors.textPrimary),
                            ),
                            const SizedBox(height: MintSpacing.xs),
                            Text(
                              _readFailed
                                  ? l10n.mintNext3aStorageFailure('read')
                                  : hasTask
                                      ? l10n.mintNext3aTodayStatus(
                                          _task!.taxYear,
                                        )
                                      : l10n.mintNext3aPersonalUnavailable,
                              style: MintTextStyles.bodySmall(
                                  color: MintColors.textSecondary),
                            ),
                            Text(
                              _readFailed
                                  ? l10n.milestoneContinueBtn
                                  : hasTask
                                      ? l10n.mintNext3aOpenTask
                                      : l10n.promiseCta,
                              style: MintTextStyles.labelMedium(
                                  color: MintColors.success),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    await context.push(
      '/mint-next/3a',
      extra: _task != null || _readFailed
          ? MintNext3aRouteIntent.taskManagement
          : null,
    );
    if (mounted) await _load();
  }
}
