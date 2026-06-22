// Dev-only admin surface per D-03 + D-10 (CONTEXT v4).
// English-only by executor discretion; no i18n/ARB keys.
library;

import 'package:flutter/material.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/debug/mint_debug_spine_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:provider/provider.dart';

class MintDebugSpineScreen extends StatefulWidget {
  const MintDebugSpineScreen({super.key});

  @override
  State<MintDebugSpineScreen> createState() => _MintDebugSpineScreenState();
}

class _MintDebugSpineScreenState extends State<MintDebugSpineScreen> {
  late Future<MintDebugSpineSnapshot> _snapshot;
  bool _resetting = false;

  @override
  void initState() {
    super.initState();
    _snapshot = MintDebugSpineService.loadSnapshot();
  }

  Future<void> _refresh() async {
    setState(() {
      _snapshot = MintDebugSpineService.loadSnapshot();
    });
  }

  Future<void> _resetProfileStores() async {
    setState(() => _resetting = true);
    final provider = context.read<CoachProfileProvider>();
    final next = await MintDebugSpineService.resetProfileStores(provider);
    if (!mounted) return;
    setState(() {
      _snapshot = Future.value(next);
      _resetting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MintDebugSpineSnapshot>(
      future: _snapshot,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Debug spine',
              style: MintTextStyles.headlineLarge(),
            ),
            const SizedBox(height: 8),
            Text(
              'Redacted local-state inspector. Counts and flags only; no raw profile values.',
              style: MintTextStyles.bodyMedium(),
            ),
            const SizedBox(height: 16),
            if (data == null)
              const Center(child: CircularProgressIndicator())
            else
              Semantics(
                key: const ValueKey('mint_debug_spine_snapshot'),
                identifier: 'mint_debug_spine_snapshot',
                label: data.redactedRows.join('; '),
                child: Column(
                  children: data.redactedRows
                      .map((row) => _DebugRow(label: row))
                      .toList(growable: false),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              // lint-ignore: prefer_mint_cta
              key: const ValueKey('mint_debug_spine_reset'),
              onPressed: _resetting ? null : _resetProfileStores,
              child: Text(_resetting ? 'Resetting...' : 'Reset profile stores'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              // lint-ignore: prefer_mint_cta
              key: const ValueKey('mint_debug_spine_refresh'),
              onPressed: _refresh,
              child: const Text('Refresh snapshot'),
            ),
          ],
        );
      },
    );
  }
}

class _DebugRow extends StatelessWidget {
  final String label;

  const _DebugRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: MintTextStyles.bodyMedium()),
    );
  }
}
