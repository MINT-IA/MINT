import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// MINT Design System — Dialog.
///
/// Consistent styling for all confirmation/info dialogs.
/// Uses MintSurface for the card and MINT typography.
class MintDialog extends StatelessWidget {
  final String title;
  final String? body;
  final Widget? content;
  final String confirmLabel;
  final String? cancelLabel;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;

  const MintDialog({
    super.key,
    required this.title,
    this.body,
    this.content,
    this.confirmLabel = 'Confirmer',
    this.cancelLabel,
    this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
  });

  /// Show as a modal dialog.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    String? body,
    Widget? content,
    String confirmLabel = 'Confirmer',
    String? cancelLabel = 'Annuler',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => MintDialog(
        title: title,
        body: body,
        content: content,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
        isDestructive: isDestructive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: MintSurface(
        tone: MintSurfaceTone.porcelaine,
        padding: const EdgeInsets.all(24),
        radius: 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: MintTextStyles.headlineSmall()),
            if (body != null) ...[
              const SizedBox(height: 12),
              Text(body!, style: MintTextStyles.bodyMedium()),
            ],
            if (content != null) ...[
              const SizedBox(height: 12),
              content!,
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (cancelLabel != null)
                  TextButton(
                    onPressed: onCancel,
                    child: Text(
                      cancelLabel!,
                      style: MintTextStyles.bodyMedium(color: MintColors.textMuted),
                    ),
                  ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDestructive ? MintColors.error : MintColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(confirmLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
