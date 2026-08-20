import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flashcards/features/onboarding/onboarding_progress.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: child))),
  );

  testWidgets('renders totalSteps dots', (tester) async {
    await pump(
      tester,
      const OnboardingProgress(currentStep: 1, totalSteps: 4),
    );

    expect(find.byType(AnimatedContainer), findsNWidgets(4));
  });

  testWidgets('the active step is wider than the inactive ones', (tester) async {
    await pump(
      tester,
      const OnboardingProgress(currentStep: 2, totalSteps: 4),
    );

    final containers = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .toList();

    for (var i = 0; i < containers.length; i++) {
      final width = (containers[i].constraints as BoxConstraints).maxWidth;
      expect(width, i == 1 ? 24 : 8);
    }
  });
}
