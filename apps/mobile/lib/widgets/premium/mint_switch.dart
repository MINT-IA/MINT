import 'package:flutter/cupertino.dart';
import 'package:mint_mobile/theme/colors.dart';

/// MINT Design System — Toggle switch.
///
/// Consistent styling across all toggles. Uses CupertinoSwitch
/// for iOS-native feel with MINT brand colors.
class MintSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? label;
  final bool enabled;

  const MintSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoSwitch(
      value: value,
      onChanged: enabled ? onChanged : null,
      activeTrackColor: MintColors.primary,
      inactiveTrackColor: MintColors.border,
    );
  }
}
