String normalizeProviderLabel(String raw) =>
    raw.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

bool providerLabelIsSafe(String raw) {
  final normalized = normalizeProviderLabel(raw);
  if (normalized.isEmpty || normalized.runes.length > 32) return false;

  final compact = normalized.replaceAll(RegExp(r'[\s.\-]'), '');
  if (RegExp(r'ch[0-9]{19}').hasMatch(compact)) return false;
  if (RegExp(r'756[0-9]{10}').hasMatch(compact)) return false;
  if (RegExp(r'[0-9]{10,}').hasMatch(compact)) return false;

  final identifierKeyword = RegExp(
    r'\b(?:compte|account|konto|conto|cuenta|conta|police|policy|police|polizza|p[oó]liza|ap[oó]lice)\b',
    caseSensitive: false,
  );
  if (identifierKeyword.hasMatch(normalized) &&
      RegExp(r'[0-9]{6,}').hasMatch(compact)) {
    return false;
  }
  return true;
}
