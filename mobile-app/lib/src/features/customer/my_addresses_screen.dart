import 'package:flutter/material.dart';

import '../../core/models/customer_address.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../../design_system/widgets/servio_toast.dart';
import 'create_address_screen.dart';

class MyAddressesScreen extends StatefulWidget {
  const MyAddressesScreen({super.key});

  @override
  State<MyAddressesScreen> createState() => _MyAddressesScreenState();
}

class _MyAddressesScreenState extends State<MyAddressesScreen> {
  final List<CustomerAddress> _addresses = <CustomerAddress>[
    const CustomerAddress(
      id: 'seed_home',
      label: 'Home',
      fullAddress: '123 Main Street, Apt 4B',
      cityArea: 'New York, NY 10001',
      isDefault: true,
    ),
    const CustomerAddress(
      id: 'seed_work',
      label: 'Work',
      fullAddress: '456 Business Blvd, Suite 200',
      cityArea: 'New York, NY 10002',
      isDefault: false,
    ),
  ];

  Future<void> _openCreateAddress() async {
    final created = await Navigator.of(context).push<CustomerAddress>(
      MaterialPageRoute<CustomerAddress>(
        builder: (_) => const CreateAddressScreen(),
      ),
    );

    if (!mounted || created == null) return;

    setState(() {
      if (created.isDefault) {
        for (var index = 0; index < _addresses.length; index++) {
          _addresses[index] = _addresses[index].copyWith(isDefault: false);
        }
      }
      _addresses.add(created);
    });

    showServioToast(
      context,
      message: 'Address added successfully.',
      type: ServioToastType.success,
    );
  }

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
          for (var index = 0; index < _addresses.length; index++) ...<Widget>[
            _AddressCard(address: _addresses[index]),
            if (index != _addresses.length - 1) const SizedBox(height: 16),
          ],
          const SizedBox(height: 32),
          ServioPrimaryButton(
            label: 'Add New Address',
            onPressed: _openCreateAddress,
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
  });

  final CustomerAddress address;

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
              Expanded(
                child: Row(
                  children: <Widget>[
                    Icon(
                      _iconForLabel(address.label),
                      color: servio.accent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        address.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (address.isDefault) ...<Widget>[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
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
                    ],
                  ],
                ),
              ),
              Row(
                children: <Widget>[
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      color: servio.textSecondary,
                      size: 20,
                    ),
                    onPressed: () {},
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: servio.danger,
                      size: 20,
                    ),
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
            address.displayAddress,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: servio.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForLabel(String label) {
    final normalized = label.trim().toLowerCase();
    if (normalized == 'home') return Icons.home_rounded;
    if (normalized == 'work') return Icons.work_rounded;
    return Icons.location_on_rounded;
  }
}
