import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Shell-aware navigation helper replacing safePop.
///
/// MintNav.back() pops if the stack has depth, otherwise navigates
/// to the shell root (/home). This prevents the infinite loop where
/// safePop sent users to /coach/chat which was the same screen.
class MintNav {
  MintNav._();

  /// Navigate back. If stack is empty, go to shell root /home.
  /// NEVER goes to /coach/chat as fallback (that was the old bug).
  static void back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      // Shell root — user sees the Aujourd'hui tab
      context.go('/home');
    }
  }
}
