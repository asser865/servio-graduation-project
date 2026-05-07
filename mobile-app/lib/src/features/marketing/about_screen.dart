import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Scaffold(
      appBar: AppBar(
        title: const Text('About SERVIO'),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Your Home, Handled.',
              style:
                  theme.textTheme.headlineLarge?.copyWith(color: servio.accent),
            ),
            const SizedBox(height: 16),
            Text(
              'SERVIO is an on-demand service platform designed to connect homeowners with verified, high-quality service professionals in just a few taps.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: servio.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Finding a reliable technician used to be a guessing game of asking for recommendations, waiting for callbacks, and hoping for fair pricing. We solve that by bringing transparency, speed, and trust into the home maintenance process. Customers simply book a service, and matched technicians accept and complete the jobs.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: servio.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            Text('Our Mission', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ServioColors.tint(servio.accent),
                borderRadius: BorderRadius.circular(ServioRadius.lg),
              ),
              child: Text(
                'To bring convenience, trust, and quality service to every household, while empowering independent professionals to grow their business.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: servio.accent,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text('Key Features', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            const _FeatureRow(
                icon: Icons.flash_on_rounded, title: 'Easy booking in seconds'),
            const _FeatureRow(
                icon: Icons.verified_user_outlined,
                title: 'Thoroughly verified technicians'),
            const _FeatureRow(
                icon: Icons.notifications_active_outlined,
                title: 'Real-time status updates'),
            const _FeatureRow(
                icon: Icons.star_rate_rounded,
                title: 'Authentic reviews & ratings'),
            const SizedBox(height: 32),
            Text('Trust & Safety', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            const _FeatureRow(
                icon: Icons.lock_outline_rounded,
                title: 'Secure, cashless payments'),
            const _FeatureRow(
                icon: Icons.shield_outlined, title: 'Background-checked users'),
            const _FeatureRow(
                icon: Icons.support_agent_rounded,
                title: 'Dedicated support system'),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: servio.backgroundSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: servio.accent, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
