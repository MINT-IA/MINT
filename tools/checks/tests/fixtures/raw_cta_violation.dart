// Synthetic fixture for prefer_mint_cta (LINT-05) — VIOLATION.
// Raw button widget outside lib/widgets/cta/ and outside lib/theme/.

import 'package:flutter/material.dart';

class FooWidget extends StatelessWidget {
  const FooWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {},
      child: const Text('Press me'),
    );
  }
}
