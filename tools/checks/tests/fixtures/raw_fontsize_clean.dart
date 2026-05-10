// Synthetic fixture for prefer_mint_text_style (LINT-02) — CLEAN.
// Uses MintTextStyles token instead of raw fontSize.

import 'package:flutter/material.dart';
import 'package:mint/theme/mint_text_styles.dart';

class FooWidget extends StatelessWidget {
  const FooWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Text('hello', style: MintTextStyles.body14());
  }
}
