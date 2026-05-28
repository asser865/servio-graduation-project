// mobile-app/lib/src/features/booking/widgets/booking_progress_indicator.dart

import 'package:flutter/material.dart';

import '../../../design_system/servio_theme_extension.dart';
import '../../../design_system/servio_tokens.dart';

class BookingProgressIndicator extends StatelessWidget {
  const BookingProgressIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.stepLabels,
  });

  final int currentStep;
  final int totalSteps;
  final List<String> stepLabels;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navyAnchor =
        isDark ? ServioColors.textPrimaryDark : ServioColors.backgroundDark;
    final servio = context.servio;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ServioSpacing.screenPadding,
        12,
        ServioSpacing.screenPadding,
        8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Circles + connecting lines
          Row(
            children: <Widget>[
              for (int i = 1; i <= totalSteps; i++) ...<Widget>[
                _StepCircle(
                  stepNumber: i,
                  currentStep: currentStep,
                  navyAnchor: navyAnchor,
                  servio: servio,
                ),
                if (i < totalSteps)
                  Expanded(
                    child: AnimatedContainer(
                      duration: ServioMotion.fast,
                      curve: ServioMotion.spring,
                      height: 2,
                      decoration: BoxDecoration(
                        color: i < currentStep
                            ? navyAnchor
                            : servio.accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // Step labels
          Row(
            children: <Widget>[
              for (int i = 1; i <= totalSteps; i++)
                Expanded(
                  child: Text(
                    i <= stepLabels.length ? stepLabels[i - 1] : '',
                    textAlign: i == 1
                        ? TextAlign.start
                        : i == totalSteps
                            ? TextAlign.end
                            : TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: i == currentStep
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: i == currentStep
                          ? navyAnchor
                          : i < currentStep
                              ? navyAnchor.withValues(alpha: 0.55)
                              : servio.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // "Step X of Y"
          Text(
            'Step $currentStep of $totalSteps',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: servio.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCircle extends StatelessWidget {
  const _StepCircle({
    required this.stepNumber,
    required this.currentStep,
    required this.navyAnchor,
    required this.servio,
  });

  final int stepNumber;
  final int currentStep;
  final Color navyAnchor;
  final ServioThemeExtension servio;

  @override
  Widget build(BuildContext context) {
    final isCompleted = stepNumber < currentStep;
    final isActive = stepNumber == currentStep;

    return AnimatedContainer(
      duration: ServioMotion.fast,
      curve: ServioMotion.spring,
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Gradient transitions hard-cut (Flutter cannot interpolate null↔Gradient).
        gradient: isActive ? ServioGradients.brand : null,
        color: isCompleted ? navyAnchor : isActive ? null : Colors.transparent,
        border: Border.all(
          color: isCompleted || isActive
              ? Colors.transparent
              : servio.accent.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 15)
            : Text(
                '$stepNumber',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? Colors.white
                      : servio.textSecondary.withValues(alpha: 0.5),
                ),
              ),
      ),
    );
  }
}
