import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> semanticIdentifiersInTraversalOrder(WidgetTester tester) {
  final root = tester.binding.renderViews
      .map((view) => view.owner?.semanticsOwner?.rootSemanticsNode)
      .whereType<SemanticsNode>()
      .first;
  final identifiers = <String>[];

  void visit(SemanticsNode node) {
    if (node.identifier.isNotEmpty) {
      identifiers.add(node.identifier);
    }
    for (final child in node
        .debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)) {
      visit(child);
    }
  }

  visit(root);
  return identifiers;
}

void expectIdentifierSubsequence(
  List<String> identifiers,
  List<String> expected,
) {
  var cursor = 0;
  for (final identifier in identifiers) {
    if (identifier == expected[cursor]) {
      cursor += 1;
      if (cursor == expected.length) break;
    }
  }
  expect(
    cursor,
    expected.length,
    reason: 'Expected traversal subsequence $expected in $identifiers',
  );
}
