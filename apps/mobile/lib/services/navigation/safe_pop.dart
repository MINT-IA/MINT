import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Safe navigation back — pops if possible, otherwise goes to /coach/chat.
///
/// Prevents `GoError: There is nothing to pop` when the navigation stack
/// is empty (deep links, direct coach routing, cold start on sub-screens).
void safePop(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/coach/chat');
  }
}
