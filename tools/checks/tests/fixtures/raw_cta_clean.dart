// Synthetic fixture for prefer_mint_cta (LINT-05) — CLEAN.
// Uses MintCTA (which Phase 4 will create) — no raw button widget.

import 'package:flutter/material.dart';
import 'package:mint/widgets/cta/mint_cta.dart';

class FooWidget extends StatelessWidget {
  const FooWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return MintCTA.primary(
      onPressed: () {},
      label: 'Press me',
    );
  }
}
