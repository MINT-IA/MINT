import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';

/// A tappable tile that opens a bottom-sheet text field for entering
/// monetary amounts (CHF). Replaces imprecise sliders for money inputs.
///
/// Shows label + formatted value. Tap opens a sheet with a number keyboard.
class MintAmountField extends StatelessWidget {
  final String label;
  final double value;
  final String Function(double) formatValue;
  final ValueChanged<double> onChanged;
  final String? hint;
  final double? min;
  final double? max;
  final String suffix;

  const MintAmountField({
    super.key,
    required this.label,
    required this.value,
    required this.formatValue,
    required this.onChanged,
    this.hint,
    this.min,
    this.max,
    this.suffix = 'CHF',
  });

  void _openEditor(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      backgroundColor: MintColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AmountEditorSheet(
        label: label,
        initialValue: value,
        hint: hint,
        suffix: suffix,
        onSubmit: (text) => _applyValue(text, ctx),
      ),
    );
  }

  void _applyValue(String text, BuildContext ctx) {
    // Strip Swiss formatting: "1'234.50" → "1234.50", "1 234" → "1234"
    final cleaned = text.replaceAll("'", '').replaceAll('\u00a0', '').replaceAll(' ', '').replaceAll(',', '.');
    final parsed = double.tryParse(cleaned) ?? value;
    double clamped = parsed;
    if (min != null && clamped < min!) clamped = min!;
    if (max != null && clamped > max!) clamped = max!;
    // Fermer la feuille AVANT de notifier.
    //
    // Ce qui est DÉMONTRÉ (test/widgets/premium/mint_amount_field_test.dart) :
    // dans l'ordre inverse — `onChanged` d'abord, `pop` ensuite — Flutter lève
    // `assert(_dependents.isEmpty)` dans `InheritedElement.debugDeactivated()`
    // dès que le parent reconstruit ; dans cet ordre-ci, non. L'ordre est donc
    // le déclencheur.
    //
    // Ce qui n'est PAS démontré : le mécanisme interne exact. Un `setState`
    // parent pendant qu'une route modale est montée est normalement licite. Ne
    // pas transformer cette inversion en explication de la cause racine.
    //
    // Contrat pour les appelants : `onChanged` est invoqué APRÈS l'initiation
    // de la fermeture. Un `onChanged` qui appelle lui-même `pop` viserait donc
    // la route du dessous.
    Navigator.of(ctx).pop();
    onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label\u00a0: ${formatValue(value)}',
      button: true,
      child: GestureDetector(
        onTap: () => _openEditor(context),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MintSpacing.md,
            vertical: MintSpacing.sm + 4,
          ),
          decoration: BoxDecoration(
            color: MintColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MintColors.lightBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: MintSpacing.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatValue(value),
                    style: MintTextStyles.bodyMedium(color: MintColors.primary)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: MintColors.textMuted.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Contenu de la feuille de saisie.
///
/// Ce widget existe pour une seule raison : le `TextEditingController` doit
/// appartenir à quelque chose qui a un cycle de vie. Il était auparavant créé
/// dans `_openEditor` et libéré dans `.then((_) => controller.dispose())`, qui
/// se déclenche dès le `pop` — alors que l'animation de sortie reconstruit
/// encore le `TextField`, d'où « A TextEditingController was used after being
/// disposed ». Porté par un `State`, il est libéré au démontage réel.
class _AmountEditorSheet extends StatefulWidget {
  const _AmountEditorSheet({
    required this.label,
    required this.initialValue,
    required this.hint,
    required this.suffix,
    required this.onSubmit,
  });

  final String label;
  final double initialValue;
  final String? hint;
  final String suffix;
  final ValueChanged<String> onSubmit;

  @override
  State<_AmountEditorSheet> createState() => _AmountEditorSheetState();
}

class _AmountEditorSheetState extends State<_AmountEditorSheet> {
  late final TextEditingController _controller;

  /// Une route reste montée pendant son animation inverse : le bouton et le
  /// champ existent encore après le premier `pop`. Cette garde rend explicite
  /// l'invariant « une feuille ne se valide qu'une fois ».
  ///
  /// Honnêteté sur son statut : je n'ai PAS réussi à provoquer une double
  /// soumission en test — le second tap n'atteint plus la cible, qui glisse
  /// hors de sa position. C'est donc une prévention, pas la correction d'un
  /// défaut constaté.
  bool _submitted = false;

  void _submit(String text) {
    if (_submitted) return;
    _submitted = true;
    widget.onSubmit(text);
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue.round().toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: MintSpacing.lg,
        right: MintSpacing.lg,
        top: MintSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + MintSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: MintColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.md),
          Text(
            widget.label,
            style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
          ),
          const SizedBox(height: MintSpacing.md),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofocus: true,
            style: MintTextStyles.headlineMedium(color: MintColors.textPrimary),
            decoration: InputDecoration(
              suffixText: widget.suffix,
              suffixStyle: MintTextStyles.bodyMedium(color: MintColors.textMuted),
              hintText: widget.hint ?? '0',
              hintStyle: MintTextStyles.headlineMedium(color: MintColors.textMuted),
              filled: true,
              fillColor: MintColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: MintColors.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: MintSpacing.md,
                vertical: MintSpacing.md,
              ),
            ),
            onSubmitted: _submit,
          ),
          const SizedBox(height: MintSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _submit(_controller.text),
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.primary,
                foregroundColor: MintColors.background,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'OK',
                style: MintTextStyles.titleMedium(color: MintColors.background),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
