// Synthetic fixture for prefer_mint_radius (LINT-04) — CLEAN.
// circular(12) is in the allowlist; circular(999) is the pill shorthand.

import 'package:flutter/material.dart';

class FooWidget extends StatelessWidget {
  const FooWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
