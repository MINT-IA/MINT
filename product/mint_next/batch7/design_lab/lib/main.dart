import 'package:flutter/material.dart';

import 'design_lab_app.dart';

const _evidenceLocale = String.fromEnvironment('MINT_LAB_LOCALE');

void main() => runApp(
  MintNextDesignLabApp(
    locale: _evidenceLocale.isEmpty ? null : Locale(_evidenceLocale),
  ),
);
