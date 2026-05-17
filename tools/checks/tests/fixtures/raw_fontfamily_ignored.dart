// Synthetic fixture for prefer_mint_fonts (LINT-03) — IGNORED.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FooWidget extends StatelessWidget {
  const FooWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'hello',
      style: GoogleFonts.inter(), // lint-ignore: prefer_mint_fonts
    );
  }
}
