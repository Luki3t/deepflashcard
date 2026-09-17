import 'package:flutter_test/flutter_test.dart';

import 'package:flashcards/core/utils/string_utils.dart';

void main() {
  test('countLabel uses the singular only for exactly one', () {
    expect(countLabel(0, 'card'), '0 cards');
    expect(countLabel(1, 'card'), '1 card');
    expect(countLabel(2, 'card'), '2 cards');
    expect(countLabel(1, 'valid card'), '1 valid card');
  });

  test('countLabel accepts an irregular plural', () {
    expect(countLabel(1, 'entry', 'entries'), '1 entry');
    expect(countLabel(3, 'entry', 'entries'), '3 entries');
  });
}
