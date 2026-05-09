// Synthetic fixture for prefer_mint_radius (LINT-04) — VIOLATION.
// circular(13) is NOT in the allowlist {2,4,6,8,10,12,14,16,20,24,999}.

import 'package:flutter/material.dart';

class FooWidget extends StatelessWidget {
  const FooWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
      ),
    );
  }
}
