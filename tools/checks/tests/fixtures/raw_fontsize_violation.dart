// Synthetic fixture for prefer_mint_text_style (LINT-02) — VIOLATION.

import 'package:flutter/material.dart';

class FooWidget extends StatelessWidget {
  const FooWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text('hello', style: TextStyle(fontSize: 14));
  }
}
