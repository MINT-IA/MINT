import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';

/// Mixin for screens that auto-fill inputs from [CoachProfile] on first load.
///
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with ProfileAutoFillMixin {
///   @override
///   void didChangeDependencies() {
///     super.didChangeDependencies();
///     autoFillFromProfile(context, (profile) {
///       setState(() {
///         _age = profile.age;
///         _canton = profile.canton;
///       });
///     });
///   }
/// }
/// ```
mixin ProfileAutoFillMixin<T extends StatefulWidget> on State<T> {
  bool _profileAutoFilled = false;

  /// Whether the profile has already been loaded (prevents re-fill on rebuild).
  bool get profileAutoFilled => _profileAutoFilled;

  /// Call from [didChangeDependencies]. Invokes [onProfile] exactly once
  /// if the user has a [CoachProfile].
  void autoFillFromProfile(
    BuildContext context,
    void Function(CoachProfile profile) onProfile,
  ) {
    if (_profileAutoFilled) return;
    final provider = context.read<CoachProfileProvider>();
    if (provider.hasProfile) {
      onProfile(provider.profile!);
      _profileAutoFilled = true;
    }
  }
}
