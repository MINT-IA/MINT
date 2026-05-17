// Synthetic fixture for prefer_mint_color_token (LINT-01) — IGNORED.
// Uses an inline ignore marker — should not be flagged.

import 'package:flutter/material.dart';

class FooWidget extends StatelessWidget {
  const FooWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFAB12CD), // lint-ignore: prefer_mint_color_token
    );
  }
}
