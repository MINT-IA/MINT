// Dev-only admin surface per D-03 + D-10 (CONTEXT v4).
// English-only by executor discretion — no i18n/ARB keys.
// Phase 34 no_hardcoded_fr.py MUST exempt lib/screens/admin/**
// (TODO: add exemption when Phase 34 plan ships lint-config.yaml).

/// Phase 32 D-03 — AdminShell shared scaffold. Phase 33 adds /admin/flags
/// as a second child; NO refactor needed.
library;

import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';

class AdminShell extends StatelessWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.warmWhite,
      appBar: AppBar(
        // Dev-only English per D-03 + D-10 file header.
        title: const Text('MINT Admin'),
        backgroundColor: MintColors.surface,
        foregroundColor: MintColors.primary,
      ),
      body: SafeArea(child: child),
    );
  }
}
