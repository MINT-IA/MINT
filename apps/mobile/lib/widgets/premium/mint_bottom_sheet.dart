import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';

/// MINT Design System — Bottom Sheet.
///
/// Consistent styling for all bottom sheets: rounded corners,
/// drag handle, max height 85% viewport, MINT colors.
class MintBottomSheet {
  MintBottomSheet._();

  /// Show a MINT-styled bottom sheet.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      backgroundColor: MintColors.porcelaine,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _DragHandle(),
          Flexible(child: builder(ctx)),
        ],
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: MintColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
