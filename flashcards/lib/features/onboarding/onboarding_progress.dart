import 'package:flutter/material.dart';

class OnboardingProgress extends StatelessWidget {
  const OnboardingProgress({
    super.key,
    required this.currentStep,
    this.totalSteps = 4,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (i) {
        final active = i + 1 == currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: active
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        );
      }),
    );
  }
}
