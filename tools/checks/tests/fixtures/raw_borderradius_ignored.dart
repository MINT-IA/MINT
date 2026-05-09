// Synthetic fixture for prefer_mint_radius (LINT-04) — IGNORED.

import 'package:flutter/material.dart';

class FooWidget extends StatelessWidget {
  const FooWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13), // lint-ignore: prefer_mint_radius
      ),
    );
  }
}
