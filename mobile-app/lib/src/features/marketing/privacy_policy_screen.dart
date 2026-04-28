import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key, required this.isTechnician});

  final bool isTechnician;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Privacy Policy', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 24),
            const _Section(
              title: '1. Data We Collect',
              content: '• Personal details (Name, email, phone number).\n• Location data (to facilitate service matching).\n• Payment and billing information.',
            ),
            const _Section(
              title: '2. How We Use Your Data',
              content: '• To deliver and manage requested services.\n• To communicate with you regarding bookings and account updates.\n• To improve platform performance and user experience.',
            ),
            const _Section(
              title: '3. Data Sharing',
              content: '• We share necessary information between customers and technicians to facilitate the service.\n• Payment details are shared securely with third-party payment providers.\n• We do not sell your personal data to advertisers.',
            ),
            if (!isTechnician) ...[
              const _Section(
                title: '4. Customer Privacy Notes',
                content: '• Your exact address is only shared with the technician once a booking is confirmed.\n• Your booking history is securely stored for your reference.',
              ),
            ] else ...[
              const _Section(
                title: '4. Technician Privacy Notes',
                content: '• Your public profile (name, photo, ratings) is visible to customers browsing the platform.\n• Your work history and customer reviews will be publicly accessible on your profile.',
              ),
            ],
            const _Section(
              title: '5. Security',
              content: 'We use industry-standard encryption and security measures to protect your personal data from unauthorized access or disclosure.',
            ),
            const _Section(
              title: '6. Your Rights',
              content: 'You have the right to request access to the data we hold about you, request corrections, or request deletion of your account and associated data.',
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
