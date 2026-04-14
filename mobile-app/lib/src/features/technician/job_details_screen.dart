import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../messages/chat_screen.dart';

class JobDetailsScreen extends StatelessWidget {
  const JobDetailsScreen({
    required this.statusIndex,
    super.key,
  });

  final int statusIndex;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final actionLabel = statusIndex <= 1
        ? 'Start Job - Mark In Progress'
        : statusIndex == 2
            ? 'Complete Job - Mark as Done'
            : 'Job Completed';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ServioCard(
              radius: ServioRadius.lg,
              child: Row(
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: ServioGradients.warm,
                      shape: BoxShape.circle,
                      border: Border.all(color: servio.accent, width: 2),
                    ),
                    child: const Center(child: Text('M')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Mostafa Abdelaal', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Previous rating: 5.0',
                          style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ChatScreen(contactName: 'Mostafa Abdelaal'),
                        ),
                      );
                    },
                    child: const Text('Message'),
                  ),
                  TextButton(onPressed: () {}, child: const Text('Call')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ServioCard(
              radius: ServioRadius.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Kitchen faucet leak repair', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Customer reports constant dripping under the sink and reduced pressure at the faucet head.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: servio.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: 3,
                      separatorBuilder: (BuildContext context, int index) => const SizedBox(width: 12),
                      itemBuilder: (BuildContext context, int index) {
                        return Container(
                          width: 120,
                          decoration: BoxDecoration(
                            gradient: index.isEven ? ServioGradients.brand : ServioGradients.warm,
                            borderRadius: BorderRadius.circular(ServioRadius.md),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'New Cairo, Cairo, Egypt',
                    style: theme.textTheme.bodyMedium?.copyWith(color: servio.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 160,
                    decoration: BoxDecoration(
                      gradient: ServioGradients.warm,
                      borderRadius: BorderRadius.circular(ServioRadius.lg),
                    ),
                    child: Center(
                      child: Text(
                        'Map Preview',
                        style: theme.textTheme.titleMedium?.copyWith(color: servio.accent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Scheduled: 26/03/2026 • 10:00 AM',
                    style: theme.textTheme.bodyMedium?.copyWith(color: servio.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Offered: 850 EGP',
                    style: theme.textTheme.headlineMedium?.copyWith(color: servio.accent),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ServioPrimaryButton(
              label: actionLabel,
              onPressed: statusIndex == 3 ? null : () {},
            ),
          ],
        ),
      ),
    );
  }
}
