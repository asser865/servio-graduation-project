import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/customer_address.dart';
import '../../core/state/customer_addresses_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
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
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final servio = ctx.servio;
        final isDark = theme.brightness == Brightness.dark;

        return AlertDialog(
          backgroundColor: isDark ? servio.surfaceAlt : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ServioRadius.md),
          ),
          title: Text(
            'Delete address?',
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: ServioColors.tint(servio.danger),
                      borderRadius: BorderRadius.circular(ServioRadius.sm),
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: servio.danger,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      address.displayLabel,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                address.formattedSingleLine,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'Inter',
                  color: servio.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This address will be permanently removed from your account.',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'Inter',
                  color: servio.textSecondary,
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: servio.textSecondary,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            FilledButton(
              key: const ValueKey<String>('confirm-delete-address-button'),
              style: FilledButton.styleFrom(
                backgroundColor: servio.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ServioRadius.sm),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'Delete',
                style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
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
    final servio = context.servio;
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<CustomerAddressesProvider>();

    return Scaffold(
      backgroundColor: isDark ? theme.scaffoldBackgroundColor : const Color(0xFFFBF9F6),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Addresses',
          style: theme.textTheme.titleMedium?.copyWith(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          // Main scrollable content
          RefreshIndicator(
            onRefresh: () => context.read<CustomerAddressesProvider>().load(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                ServioSpacing.screenPadding,
                12,
                ServioSpacing.screenPadding,
                120, // bottom padding for floating CTA
              ),
              children: <Widget>[
                // Saving indicator
                if (provider.saving)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      color: servio.accent,
                      backgroundColor: servio.accent.withValues(alpha: 0.15),
                    ),
                  ),
                if (provider.saving) const SizedBox(height: 12),

                // Info Card
                _InfoBanner(),
                const SizedBox(height: 20),

                // Address list states
                if (provider.loading && provider.addresses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
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
                  for (int i = 0; i < provider.addresses.length; i++) ...<Widget>[
                    _AddressCard(
                      address: provider.addresses[i],
                      isDefault: i == 0,
                      onEdit: () => _openAddressForm(provider.addresses[i]),
                      onDelete: () => _deleteAddress(provider.addresses[i]),
                      onSetDefault: () async {
                        final addressesProvider = context.read<CustomerAddressesProvider>();
                        final success = await addressesProvider
                            .setDefaultAddress(provider.addresses[i].id);
                        if (success && context.mounted) {
                          showServioToast(
                            context,
                            message: 'Default address updated.',
                            type: ServioToastType.success,
                          );
                        }
                      },
                    ),
                    if (i < provider.addresses.length - 1)
                      const SizedBox(height: 16),
                  ],
                  if (provider.error != null) ...<Widget>[
                    const SizedBox(height: 16),
                    _InlineError(message: provider.error!),
                  ],
                ],
              ],
            ),
          ),

          // Fixed bottom "Add New Address" CTA
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: (isDark ? theme.scaffoldBackgroundColor : const Color(0xFFFBF9F6))
                    .withValues(alpha: 0.92),
                border: Border(
                  top: BorderSide(
                    color: servio.border.withValues(alpha: 0.4),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? Colors.black : const Color(0xFF1A1D23))
                        .withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(
                ServioSpacing.screenPadding,
                12,
                ServioSpacing.screenPadding,
                12 + MediaQuery.paddingOf(context).bottom,
              ),
              child: _AddAddressButton(
                saving: provider.saving,
                onTap: provider.saving ? null : () => _openAddressForm(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info Banner ───────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? servio.surfaceAlt : const Color(0xFFF3EDE7),
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        border: Border.all(
          color: const Color(0xFF9A8C73).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? servio.backgroundSoft : Colors.white,
              shape: BoxShape.circle,
              boxShadow: ServioShadows.rest,
            ),
            child: Icon(
              Icons.info_rounded,
              size: 18,
              color: isDark ? Colors.white : ServioColors.navyDark,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manage your locations',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : ServioColors.navyDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Save addresses for faster booking and accurate service area verification.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'Inter',
                    color: servio.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Address Card ──────────────────────────────────────────────────────────────

class _AddressCard extends StatefulWidget {
  const _AddressCard({
    required this.address,
    required this.isDefault,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  final CustomerAddress address;
  final bool isDefault;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  @override
  State<_AddressCard> createState() => _AddressCardState();
}

class _AddressCardState extends State<_AddressCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: widget.onEdit,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: ServioMotion.fast,
        curve: ServioMotion.spring,
        child: Container(
          key: ValueKey<String>('address-card-${widget.address.id}'),
          decoration: BoxDecoration(
            color: isDark ? servio.surfaceAlt : Colors.white,
            borderRadius: BorderRadius.circular(ServioRadius.lg),
            border: Border.all(
              color: const Color(0xFF9A8C73).withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : const Color(0xFF1A1D23))
                    .withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Default address left accent bar
              if (widget.isDefault)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: isDark ? servio.accent : ServioColors.navyDark,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(ServioRadius.lg),
                        bottomLeft: Radius.circular(ServioRadius.lg),
                      ),
                    ),
                  ),
                ),

              // Card content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row: icon + label + default badge + action buttons
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon pill
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark
                                ? servio.backgroundSoft
                                : const Color(0xFFF3EDE7),
                            borderRadius: BorderRadius.circular(ServioRadius.sm),
                          ),
                          child: Icon(
                            _iconForLabel(widget.address.displayLabel),
                            size: 18,
                            color: isDark ? Colors.white : ServioColors.navyDark,
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Label + default badge
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      widget.address.displayLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white
                                            : ServioColors.navyDark,
                                      ),
                                    ),
                                  ),
                                  if (widget.isDefault) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? servio.backgroundSoft
                                            : const Color(0xFFEAE8E5),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Default',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w600,
                                          color: servio.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Action buttons
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ActionButton(
                              key: ValueKey<String>('edit-address-${widget.address.id}'),
                              icon: Icons.edit_outlined,
                              color: servio.textSecondary,
                              hoverColor: isDark
                                  ? servio.backgroundSoft
                                  : const Color(0xFFF3EDE7),
                              onTap: widget.onEdit,
                              tooltip: 'Edit address',
                            ),
                            const SizedBox(width: 4),
                            _ActionButton(
                              key: ValueKey<String>('delete-address-${widget.address.id}'),
                              icon: Icons.delete_outline_rounded,
                              color: servio.danger,
                              hoverColor: ServioColors.tint(servio.danger),
                              onTap: widget.onDelete,
                              tooltip: 'Delete address',
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Address lines
                    Padding(
                      padding: const EdgeInsets.only(left: 46),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.address.street.isNotEmpty)
                            Text(
                              widget.address.street,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? theme.colorScheme.onSurface
                                    : const Color(0xFF262B34),
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              widget.address.city,
                              widget.address.state,
                              widget.address.zipCode,
                            ]
                                .where((p) => p.trim().isNotEmpty)
                                .join(', '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'Inter',
                              color: servio.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          if (!widget.isDefault) ...[
                            const SizedBox(height: 12),
                            // Set as Default button (for non-default addresses)
                            OutlinedButton(
                              key: ValueKey<String>('set-default-address-${widget.address.id}'),
                              onPressed: widget.onSetDefault,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark
                                    ? Colors.white
                                    : ServioColors.navyDark,
                                side: BorderSide(
                                  color: const Color(0xFF9A8C73)
                                      .withValues(alpha: 0.3),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(ServioRadius.sm),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                textStyle: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                              child: const Text('Set as Default'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForLabel(String label) {
    final normalized = label.trim().toLowerCase();
    if (normalized == 'home') return Icons.home_rounded;
    if (normalized == 'work' || normalized == 'office') return Icons.work_rounded;
    if (normalized.contains('parent') || normalized.contains('family')) {
      return Icons.favorite_rounded;
    }
    return Icons.location_on_rounded;
  }
}

// ── Action Button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    super.key,
    required this.icon,
    required this.color,
    required this.hoverColor,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final Color color;
  final Color hoverColor;
  final VoidCallback onTap;
  final String tooltip;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _hovered = true),
        onTapUp: (_) => setState(() => _hovered = false),
        onTapCancel: () => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: ServioMotion.fast,
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _hovered ? widget.hoverColor : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            widget.icon,
            size: 18,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

// ── Add Address Button ────────────────────────────────────────────────────────

class _AddAddressButton extends StatefulWidget {
  const _AddAddressButton({
    required this.saving,
    required this.onTap,
  });

  final bool saving;
  final VoidCallback? onTap;

  @override
  State<_AddAddressButton> createState() => _AddAddressButtonState();
}

class _AddAddressButtonState extends State<_AddAddressButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final isDark = theme.brightness == Brightness.dark;
    final isEnabled = widget.onTap != null && !widget.saving;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: isEnabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: ServioMotion.fast,
        curve: ServioMotion.spring,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: isEnabled
                ? (isDark ? servio.accent : ServioColors.navyDark)
                : (isDark ? servio.backgroundSoft : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(ServioRadius.sm + 2),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: (isDark ? servio.accent : ServioColors.navyDark)
                          .withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.saving)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                )
              else
                Icon(
                  Icons.add_rounded,
                  color: isEnabled ? Colors.white : Colors.grey.shade500,
                  size: 20,
                ),
              const SizedBox(width: 8),
              Text(
                widget.saving ? 'Saving...' : 'Add New Address',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  color: isEnabled ? Colors.white : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? servio.surfaceAlt : Colors.white,
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        border: Border.all(
          color: const Color(0xFF9A8C73).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDark ? servio.backgroundSoft : const Color(0xFFF3EDE7),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_off_outlined,
              color: servio.textSecondary,
              size: 26,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No saved addresses yet.',
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : ServioColors.navyDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add an address to reuse during bookings.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'Inter',
              color: servio.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Add Address'),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white : ServioColors.navyDark,
              side: BorderSide(
                color: const Color(0xFF9A8C73).withValues(alpha: 0.4),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ServioRadius.sm),
              ),
              textStyle: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Full-page Error State ─────────────────────────────────────────────────────

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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? servio.surfaceAlt : Colors.white,
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        border: Border.all(
          color: servio.danger.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: ServioColors.tint(servio.danger),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              color: servio.danger,
              size: 26,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'Inter',
              color: isDark ? Colors.white : ServioColors.navyDark,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: servio.danger,
              side: BorderSide(color: servio.danger.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ServioRadius.sm),
              ),
              textStyle: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Saved addresses load from your Servio account.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'Inter',
              color: servio.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Inline Error Banner ───────────────────────────────────────────────────────

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ServioColors.tint(servio.danger),
        borderRadius: BorderRadius.circular(ServioRadius.sm),
        border: Border.all(color: servio.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: servio.danger, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'Inter',
                color: servio.danger,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
