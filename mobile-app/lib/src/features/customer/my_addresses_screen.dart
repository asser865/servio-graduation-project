import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/customer_address.dart';
import '../../core/state/customer_addresses_state.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CustomerAddressesProvider>().load();
    });
  }

  Future<void> _openAddressForm([CustomerAddress? address]) async {
    final saved = await Navigator.of(context).push<CustomerAddress>(
      MaterialPageRoute<CustomerAddress>(
        builder: (_) => CreateAddressScreen(address: address),
      ),
    );

    if (!mounted || saved == null) return;
    showServioToast(
      context,
      message: address == null ? 'Address added.' : 'Address updated.',
      type: ServioToastType.success,
    );
  }

  Future<void> _deleteAddress(CustomerAddress address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text(address.formattedSingleLine),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey<String>('confirm-delete-address-button'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<CustomerAddressesProvider>();
    final deleted = await provider.deleteAddress(address.id);
    if (!mounted) return;
    if (deleted) {
      showServioToast(
        context,
        message: 'Address deleted.',
        type: ServioToastType.success,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Failed to delete address')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<CustomerAddressesProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Addresses'),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<CustomerAddressesProvider>().load(),
        child: ListView(
          padding: const EdgeInsets.all(ServioSpacing.screenPadding),
          children: <Widget>[
            if (provider.saving) const LinearProgressIndicator(),
            if (provider.saving) const SizedBox(height: 16),
            if (provider.loading && provider.addresses.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.error != null && provider.addresses.isEmpty)
              _ErrorState(
                message: provider.error!,
                onRetry: () => context.read<CustomerAddressesProvider>().load(),
              )
            else if (provider.addresses.isEmpty)
              _EmptyState(onAdd: () => _openAddressForm())
            else ...<Widget>[
              for (var index = 0;
                  index < provider.addresses.length;
                  index++) ...<Widget>[
                _AddressCard(
                  address: provider.addresses[index],
                  onEdit: () => _openAddressForm(provider.addresses[index]),
                  onDelete: () => _deleteAddress(provider.addresses[index]),
                ),
                if (index != provider.addresses.length - 1)
                  const SizedBox(height: 16),
              ],
              if (provider.error != null) ...<Widget>[
                const SizedBox(height: 16),
                _InlineError(message: provider.error!),
              ],
            ],
            const SizedBox(height: 32),
            ServioPrimaryButton(
              label: 'Add New Address',
              onPressed: provider.saving ? null : () => _openAddressForm(),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return ServioCard(
      radius: ServioRadius.lg,
      child: Column(
        children: <Widget>[
          Icon(Icons.location_off_outlined, color: servio.textSecondary),
          const SizedBox(height: 12),
          Text('No saved addresses yet.', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Add an address to reuse during bookings.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: servio.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Add Address'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return ServioCard(
      radius: ServioRadius.lg,
      child: Column(
        children: <Widget>[
          Icon(Icons.error_outline_rounded, color: servio.danger),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
          const SizedBox(height: 4),
          Text(
            'Saved addresses load from your Servio account.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: servio.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ServioColors.tint(servio.danger),
        borderRadius: BorderRadius.circular(ServioRadius.md),
      ),
      child: Text(
        message,
        style: TextStyle(color: servio.danger, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onDelete,
  });

  final CustomerAddress address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    return ServioCard(
      key: ValueKey<String>('address-card-${address.id}'),
      radius: ServioRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                _iconForLabel(address.displayLabel),
                color: servio.accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  address.displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                key: ValueKey<String>('edit-address-${address.id}'),
                icon: Icon(
                  Icons.edit_outlined,
                  color: servio.textSecondary,
                  size: 20,
                ),
                onPressed: onEdit,
                tooltip: 'Edit address',
              ),
              IconButton(
                key: ValueKey<String>('delete-address-${address.id}'),
                icon: Icon(
                  Icons.delete_outline,
                  color: servio.danger,
                  size: 20,
                ),
                onPressed: onDelete,
                tooltip: 'Delete address',
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
