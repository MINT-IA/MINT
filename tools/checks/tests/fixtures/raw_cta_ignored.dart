// Synthetic fixture for prefer_mint_cta (LINT-05) — IGNORED.

import 'package:flutter/material.dart';

class FooWidget extends StatelessWidget {
  const FooWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      // lint-ignore: prefer_mint_cta
      onPressed: () {},
      child: const Text('Press me'),
    );
  }
}
