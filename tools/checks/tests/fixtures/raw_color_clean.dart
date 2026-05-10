// Synthetic fixture for prefer_mint_color_token (LINT-01) — CLEAN.
// Uses MintColors token, no raw Color() literal.

import 'package:flutter/material.dart';
import 'package:mint/theme/colors.dart';

class FooWidget extends StatelessWidget {
  const FooWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(color: MintColors.primary);
  }
}
