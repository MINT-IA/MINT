// Synthetic fixture for prefer_mint_color_token (LINT-01) — VIOLATION.
// Contains one raw Color(0xFF...) literal outside lib/theme/.

import 'package:flutter/material.dart';

class FooWidget extends StatelessWidget {
  const FooWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFAB12CD),
      child: Container(color: Colors.white),
    );
  }
}
