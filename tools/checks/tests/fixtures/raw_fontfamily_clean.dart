// Synthetic fixture for prefer_mint_fonts (LINT-03) — CLEAN.
// Uses MintTextStyles which encapsulates GoogleFonts under lib/theme/.

import 'package:flutter/material.dart';
import 'package:mint/theme/mint_text_styles.dart';

class FooWidget extends StatelessWidget {
  const FooWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Text('hello', style: MintTextStyles.body14());
  }
}
