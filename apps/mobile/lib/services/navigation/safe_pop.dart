import 'package:flutter/widgets.dart';
import 'mint_nav.dart';

/// @Deprecated('Use MintNav.back() directly. safePop is a shim.')
/// Safe navigation back — delegates to MintNav.back().
///
/// This shim exists so the 40 existing call sites continue working.
/// New code should use MintNav.back(context) directly.
void safePop(BuildContext context) {
  MintNav.back(context);
}
