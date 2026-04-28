import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Privacy Policy'),
          backgroundColor: theme.scaffoldBackgroundColor,
          bottom: TabBar(
            labelColor: servio.accent,
            unselectedLabelColor: servio.textSecondary,
            indicatorColor: servio.accent,
            tabs: const [
              Tab(text: 'For Customers'),
              Tab(text: 'For Technicians'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(ServioSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const <Widget>[
                  SizedBox(height: 8),
                  _SectionCard(
                    title: '1. Data We Collect',
                    content: '• Personal details (Name, email, phone number).\n• Location data (to facilitate service matching).\n• Payment and billing information.',
                  ),
                  _SectionCard(
                    title: '2. How We Use Your Data',
                    content: '• To deliver and manage requested services.\n• To communicate with you regarding bookings and account updates.\n• To improve platform performance and user experience.',
                  ),
                  _SectionCard(
                    title: '3. Data Sharing',
                    content: '• We share necessary information between customers and technicians to facilitate the service.\n• Payment details are shared securely with third-party payment providers.\n• We do not sell your personal data to advertisers.',
                  ),
                  _SectionCard(
                    title: '4. Customer Privacy Notes',
                    content: '• Your exact address is only shared with the technician once a booking is confirmed.\n• Your booking history is securely stored for your reference.',
                  ),
                  _SectionCard(
                    title: '5. Security',
                    content: 'We use industry-standard encryption and security measures to protect your personal data from unauthorized access or disclosure.',
                  ),
                  _SectionCard(
                    title: '6. Your Rights',
                    content: 'You have the right to request access to the data we hold about you, request corrections, or request deletion of your account and associated data.',
                  ),
                  SizedBox(height: 32),
                ],
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.all(ServioSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const <Widget>[
                  SizedBox(height: 8),
                  _SectionCard(
                    title: '1. Data We Collect',
                    content: '• Personal details (Name, email, phone number).\n• Location data (to facilitate service matching).\n• Payment and billing information.\n• Professional certifications and documents.',
                  ),
                  _SectionCard(
                    title: '2. How We Use Your Data',
                    content: '• To deliver and manage requested services.\n• To communicate with you regarding bookings and account updates.\n• To improve platform performance and user experience.',
                  ),
                  _SectionCard(
                    title: '3. Data Sharing',
                    content: '• We share necessary information between customers and technicians to facilitate the service.\n• Payment details are shared securely with third-party payment providers.\n• We do not sell your personal data to advertisers.',
                  ),
                  _SectionCard(
                    title: '4. Technician Privacy Notes',
                    content: '• Your public profile (name, photo, ratings) is visible to customers browsing the platform.\n• Your work history and customer reviews will be publicly accessible on your profile.',
                  ),
                  _SectionCard(
                    title: '5. Security',
                    content: 'We use industry-standard encryption and security measures to protect your personal data from unauthorized access or disclosure.',
                  ),
                  _SectionCard(
                    title: '6. Your Rights',
                    content: 'You have the right to request access to the data we hold about you, request corrections, or request deletion of your account and associated data.',
                  ),
                  SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ServioCard(
        radius: ServioRadius.md,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: theme.textTheme.titleMedium?.copyWith(color: servio.accent)),
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
      ),
    );
  }
}
