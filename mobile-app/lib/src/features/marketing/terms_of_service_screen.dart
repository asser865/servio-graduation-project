import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Terms of Service'),
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
                    title: '1. Acceptance of Terms',
                    content: 'By accessing or using the SERVIO platform, you agree to be bound by these Terms of Service. If you do not agree, please do not use the application.',
                  ),
                  _SectionCard(
                    title: '2. Platform Role',
                    content: 'SERVIO acts strictly as a mediator connecting users with service professionals. SERVIO is not a service provider, and technicians are independent service providers, not employees.',
                  ),
                  _SectionCard(
                    title: '3. Customer Responsibilities',
                    content: '• Provide accurate details about the requested service.\n• Be present at the specified location during the service time.\n• Treat technicians with respect and provide a safe working environment.',
                  ),
                  _SectionCard(
                    title: '4. Payments & Cancellations',
                    content: '• Payments must be processed through the platform.\n• Cancellations made within 24 hours of the booking may incur a fee.\n• Refunds are subject to review based on our dispute resolution policy.',
                  ),
                  _SectionCard(
                    title: '5. Prohibited Activities',
                    content: 'Users may not engage in fraudulent activities, post false information, bypass the platform\'s payment system, or harass other users.',
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
                    title: '1. Acceptance of Terms',
                    content: 'By accessing or using the SERVIO platform, you agree to be bound by these Terms of Service. If you do not agree, please do not use the application.',
                  ),
                  _SectionCard(
                    title: '2. Platform Role',
                    content: 'SERVIO acts strictly as a mediator connecting users with service professionals. SERVIO is not a service provider, and technicians are independent service providers, not employees.',
                  ),
                  _SectionCard(
                    title: '3. Technician Responsibilities',
                    content: '• Deliver the agreed-upon service to a high standard of quality.\n• Arrive punctually at the scheduled time.\n• Be responsible for providing your own necessary tools and materials.\n• Maintain required compliance, certifications, and licenses.',
                  ),
                  _SectionCard(
                    title: '4. Earnings & Acceptance',
                    content: '• You have the right to accept or reject jobs.\n• Earnings will be paid out according to the platform\'s payout schedule.\n• You are responsible for any taxes related to your earnings.',
                  ),
                  _SectionCard(
                    title: '5. Limitation of Liability',
                    content: 'SERVIO is not liable for any indirect, incidental, or consequential damages arising from the use of the platform or services rendered by independent technicians.',
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
