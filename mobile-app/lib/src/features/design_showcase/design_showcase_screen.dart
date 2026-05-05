import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_bottom_sheet.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../../design_system/widgets/servio_section_heading.dart';
import '../../design_system/widgets/servio_skeleton.dart';
import '../../design_system/widgets/servio_status_chip.dart';
import '../../design_system/widgets/servio_toast.dart';

class DesignShowcaseScreen extends StatelessWidget {
  const DesignShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: ServioSpacing.screenPadding),
          children: <Widget>[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: ServioGradients.brand,
                borderRadius: BorderRadius.circular(ServioRadius.xl),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: ServioColors.tint(ServioColors.accentLight),
                      borderRadius: BorderRadius.circular(ServioRadius.full),
                    ),
                    child: Text(
                      'NEW FEATURE',
                      style: theme.textTheme.labelLarge?.copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'SERVIO Design System',
                    style: theme.textTheme.headlineLarge?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Warm, trustworthy Flutter foundation for the Egypt marketplace.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: ServioColors.neutralWarm),
                  ),
                  const SizedBox(height: 20),
                  const ServioPrimaryButton(
                    label: 'Explore Components',
                  ),
                ],
              ),
            ),
            const SizedBox(height: ServioSpacing.sectionGap),
            const ServioSectionHeading(
              title: 'Semantic Chips',
              actionLabel: 'See All',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: const <Widget>[
                ServioStatusChip(label: 'Verified', type: ServioStatusChipType.success),
                ServioStatusChip(label: 'Pending', type: ServioStatusChipType.warning),
                ServioStatusChip(label: 'In Progress', type: ServioStatusChipType.info),
                ServioStatusChip(label: 'Cancelled', type: ServioStatusChipType.danger),
              ],
            ),
            const SizedBox(height: ServioSpacing.sectionGap),
            const ServioSectionHeading(title: 'Cards'),
            const SizedBox(height: 12),
            ServioCard(
              radius: ServioRadius.lg,
              elevated: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: servio.backgroundSoft,
                        child: Text(
                          'MA',
                          style: theme.textTheme.labelLarge?.copyWith(color: servio.accent),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Ahmed Nabil', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              'Plumbing Specialist',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: servio.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const ServioStatusChip(
                        label: '4.9 Rating',
                        type: ServioStatusChipType.neutral,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Fast response, verified documents, and clear upfront pricing aligned with the SERVIO brand pillars.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: servio.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ServioSpacing.sectionGap),
            const ServioSectionHeading(title: 'Inputs'),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'What service do you need?',
                hintText: 'Describe the issue',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Job description',
                hintText: 'My kitchen faucet is dripping constantly.',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: ServioSpacing.sectionGap),
            const ServioSectionHeading(title: 'Actions'),
            const SizedBox(height: 12),
            const ServioPrimaryButton(label: 'Book Service'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {},
              child: const Text('View Profile'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {},
              child: const Text('Skip for now'),
            ),
            const SizedBox(height: ServioSpacing.sectionGap),
            const ServioSectionHeading(title: 'Skeleton'),
            const SizedBox(height: 12),
            const ServioCard(
              radius: ServioRadius.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ServioSkeleton(height: 18, width: 140),
                  SizedBox(height: 12),
                  ServioSkeleton(height: 14),
                  SizedBox(height: 8),
                  ServioSkeleton(height: 14, width: 220),
                  SizedBox(height: 16),
                  ServioSkeleton(height: 52),
                ],
              ),
            ),
            const SizedBox(height: ServioSpacing.sectionGap),
            const ServioSectionHeading(title: 'Bottom Sheet & Toast'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                showServioBottomSheet<void>(
                  context: context,
                  builder: (BuildContext context) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Choose an action',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This sheet uses the shared SERVIO shell with the required top radius and handle.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: context.servio.textSecondary,
                              ),
                        ),
                        const SizedBox(height: 20),
                        const ServioPrimaryButton(label: 'Confirm'),
                      ],
                    );
                  },
                );
              },
              child: const Text('Open Bottom Sheet'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                showServioToast(
                  context,
                  message: 'Estimate saved successfully.',
                  type: ServioToastType.success,
                );
              },
              child: const Text('Show Toast'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
