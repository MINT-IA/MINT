import 'package:characters/characters.dart';
import 'package:unorm_dart/unorm_dart.dart' as unicode;

import 'multi_provider_casefold_data.dart';
import 'multi_provider_default_ignorable_data.dart';

final _forbiddenFormatting = RegExp(r'[\p{Cc}\p{Cf}]', unicode: true);

final _unicodeWhitespace = RegExp(
  r'[\s\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]+',
  unicode: true,
);

bool _hasDefaultIgnorable(String value) {
  for (final rune in value.runes) {
    for (final (start, end) in multiProviderDefaultIgnorableRanges) {
      if (rune < start) break;
      if (rune <= end) return true;
    }
  }
  return false;
}

/// Batch 14 identity key. It is intentionally separate from the accepted
/// Batch 12 label contract so strengthening this draft cannot mutate history.
String normalizeMultiProviderLabel(String raw) {
  if (_forbiddenFormatting.hasMatch(raw) || _hasDefaultIgnorable(raw)) {
    return '';
  }
  final compatibilityNormalized = unicode.nfkc(raw);
  if (_forbiddenFormatting.hasMatch(compatibilityNormalized) ||
      _hasDefaultIgnorable(compatibilityNormalized)) {
    return '';
  }
  final folded = StringBuffer();
  for (final rune in compatibilityNormalized.runes) {
    folded.write(multiProviderFullCaseFold[rune] ?? String.fromCharCode(rune));
  }
  final canonicalFolded = unicode.nfkc(folded.toString());
  if (_forbiddenFormatting.hasMatch(canonicalFolded) ||
      _hasDefaultIgnorable(canonicalFolded)) {
    return '';
  }
  return canonicalFolded.trim().replaceAll(_unicodeWhitespace, ' ');
}

bool multiProviderLabelIsSafe(String raw) {
  final normalized = normalizeMultiProviderLabel(raw);
  if (normalized.isEmpty || normalized.characters.length > 80) return false;

  final compact = normalized.replaceAll(RegExp(r'[\s.\-]'), '');
  if (RegExp(r'ch[0-9]{19}').hasMatch(compact)) return false;
  if (RegExp(r'756[0-9]{10}').hasMatch(compact)) return false;
  if (RegExp(r'[0-9]{10,}').hasMatch(compact)) return false;

  final identifierKeyword = RegExp(
    r'\b(?:compte|account|konto|conto|cuenta|conta|police|policy|polizza|p[oó]liza|ap[oó]lice)\b',
    caseSensitive: false,
    unicode: true,
  );
  return !(identifierKeyword.hasMatch(normalized) &&
      RegExp(r'[0-9]{6,}').hasMatch(compact));
}
