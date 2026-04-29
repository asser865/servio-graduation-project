import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';

class MyAddressesScreen extends StatelessWidget {
  const MyAddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Addresses'),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        children: <Widget>[
          const _AddressCard(
            label: 'Home',
            address: '123 Main Street, Apt 4B\nNew York, NY 10001',
            isDefault: true,
          ),
          const SizedBox(height: 16),
          const _AddressCard(
            label: 'Work',
            address: '456 Business Blvd, Suite 200\nNew York, NY 10002',
            isDefault: false,
          ),
          const SizedBox(height: 32),
          ServioPrimaryButton(
            label: '+ Add New Address',
            onPressed: () {
              // Add address logic
            },
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.label,
    required this.address,
    required this.isDefault,
  });

  final String label;
  final String address;
  final bool isDefault;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    return ServioCard(
      radius: ServioRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    label.toLowerCase() == 'home'
                        ? Icons.home_rounded
                        : Icons.work_rounded,
                    color: servio.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: theme.textTheme.titleMedium,
                  ),
                  if (isDefault) ...<Widget>[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: ServioColors.tint(servio.accent),
                        borderRadius: BorderRadius.circular(ServioRadius.sm),
                      ),
                      child: Text(
                        'Default',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: servio.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ]
                ],
              ),
              Row(
                children: <Widget>[
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: servio.textSecondary, size: 20),
                    onPressed: () {},
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: servio.danger, size: 20),
                    onPressed: () {},
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            address,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: servio.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
