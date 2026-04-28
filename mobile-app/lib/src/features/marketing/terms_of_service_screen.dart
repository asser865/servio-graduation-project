import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key, required this.isTechnician});

  final bool isTechnician;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Terms of Service', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 24),
            const _Section(
              title: '1. Acceptance of Terms',
              content: 'By accessing or using the SERVIO platform, you agree to be bound by these Terms of Service. If you do not agree, please do not use the application.',
            ),
            const _Section(
              title: '2. Platform Role',
              content: 'SERVIO acts strictly as a mediator connecting users with service professionals. SERVIO is not a service provider, and technicians are independent service providers, not employees.',
            ),
            const _Section(
              title: '3. Account Responsibility',
              content: 'You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account.',
            ),
            const _Section(
              title: '4. Prohibited Activities',
              content: 'Users may not engage in fraudulent activities, post false information, bypass the platform\'s payment system, or harass other users.',
            ),
            if (!isTechnician) ...[
              const _Section(
                title: '5. Customer Responsibilities',
                content: '• Provide accurate details about the requested service.\n• Be present at the specified location during the service time.\n• Treat technicians with respect and provide a safe working environment.',
              ),
              const _Section(
                title: '6. Payments & Cancellations',
                content: '• Payments must be processed through the platform.\n• Cancellations made within 24 hours of the booking may incur a fee.\n• Refunds are subject to review based on our dispute resolution policy.',
              ),
            ] else ...[
              const _Section(
                title: '5. Technician Responsibilities',
                content: '• Deliver the agreed-upon service to a high standard of quality.\n• Arrive punctually at the scheduled time.\n• Be responsible for providing your own necessary tools and materials.\n• Maintain required compliance, certifications, and licenses.',
              ),
              const _Section(
                title: '6. Earnings & Acceptance',
                content: '• You have the right to accept or reject jobs.\n• Earnings will be paid out according to the platform\'s payout schedule.\n• You are responsible for any taxes related to your earnings.',
              ),
            ],
            const _Section(
              title: '7. Limitation of Liability',
              content: 'SERVIO is not liable for any indirect, incidental, or consequential damages arising from the use of the platform or services rendered by independent technicians.',
            ),
            const _Section(
              title: '8. Termination',
              content: 'We reserve the right to suspend or terminate accounts that violate these Terms of Service or engage in harmful behavior.',
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: servio.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
