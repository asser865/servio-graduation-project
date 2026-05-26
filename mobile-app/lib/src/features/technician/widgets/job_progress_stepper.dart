import 'package:flutter/material.dart';
import '../../../design_system/servio_theme_extension.dart';

enum JobStep { accepted, enRoute, arrived, working, done }

/// Maps backend status string → current step (null = not in active flow).
JobStep? stepFromStatus(String status) {
  switch (status.trim().toLowerCase().replaceAll('-', '_')) {
    case 'accepted':
      return JobStep.accepted;
    case 'en_route':
      return JobStep.enRoute;
    case 'arrived':
      return JobStep.arrived;
    case 'in_progress':
      return JobStep.working;
    case 'awaiting_customer_confirmation':
    case 'pending_admin_review':
    case 'completed':
      return JobStep.done;
    default:
      return null;
  }
}

const _kLabels = ['Accepted', 'En Route', 'Arrived', 'Working', 'Done'];

class JobProgressStepper extends StatelessWidget {
  const JobProgressStepper({required this.currentStep, super.key});

  final JobStep currentStep;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final currentIndex = JobStep.values.indexOf(currentStep);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: List.generate(JobStep.values.length * 2 - 1, (i) {
          if (i.isOdd) {
            // Connector line
            final stepIndex = i ~/ 2;
            final done = stepIndex < currentIndex;
            return Expanded(
              child: Container(
                height: 2,
                color: done
                    ? servio.accent
                    : servio.textSecondary.withValues(alpha: 0.2),
              ),
            );
          }
          final stepIndex = i ~/ 2;
          final done = stepIndex < currentIndex;
          final active = stepIndex == currentIndex;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done || active
                      ? servio.accent
                      : servio.textSecondary.withValues(alpha: 0.15),
                ),
                child: Center(
                  child: done
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : Text(
                          '${stepIndex + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: active
                                ? Colors.white
                                : servio.textSecondary,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _kLabels[stepIndex],
                style: theme.textTheme.labelSmall?.copyWith(
                  color: done || active
                      ? servio.accent
                      : servio.textSecondary,
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 9,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
