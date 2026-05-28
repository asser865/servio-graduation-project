// mobile-app/lib/src/features/booking/widgets/address_selector_section.dart

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/customer_address.dart';
import '../../../design_system/servio_theme_extension.dart';
import '../../../design_system/servio_tokens.dart';
import '../../../design_system/widgets/servio_skeleton.dart';
import '../../../shared/widgets/servio_map_widget.dart';
import '../booking_strings.dart';

class AddressSelectorSection extends StatelessWidget {
  const AddressSelectorSection({
    super.key,
    required this.addresses,
    required this.selectedAddress,
    required this.loading,
    required this.geocoding,
    required this.addressLatLng,
    required this.error,
    required this.addressError,
    required this.onRetry,
    required this.onAdd,
    required this.onSelect,
  });

  final List<CustomerAddress> addresses;
  final CustomerAddress? selectedAddress;
  final bool loading;
  final bool geocoding;
  final LatLng? addressLatLng;
  final String? error;
  final String? addressError;
  final VoidCallback onRetry;
  final VoidCallback onAdd;
  final ValueChanged<CustomerAddress> onSelect;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navyAnchor =
        isDark ? ServioColors.textPrimaryDark : ServioColors.backgroundDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          BookingStrings.serviceAddress,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: navyAnchor,
          ),
        ),
        const SizedBox(height: 16),
        _buildContent(context, isDark, navyAnchor),
        if (geocoding)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: LinearProgressIndicator(
              backgroundColor: Color(0xFFF3EDE7),
              color: Color(0xFF9A8C73),
            ),
          ),
        if (addressLatLng != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SizedBox(
              height: 180,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(ServioRadius.md),
                child: ServioMapWidget(
                  center: addressLatLng!,
                  zoom: 15,
                  interactive: false,
                  markers: [buildPinMarker(addressLatLng!)],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildContent(
      BuildContext context, bool isDark, Color navyAnchor) {
    final servio = context.servio;

    // Loading shimmer
    if (loading && addresses.isEmpty) {
      return Column(
        children: const <Widget>[
          ServioSkeleton(height: 84, radius: ServioRadius.lg),
          SizedBox(height: 12),
          ServioSkeleton(height: 84, radius: ServioRadius.lg),
          SizedBox(height: 12),
          ServioSkeleton(height: 44, radius: ServioRadius.md),
        ],
      );
    }

    // Error state
    if (error != null && addresses.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: servio.danger,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(BookingStrings.retry),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey<String>('booking-add-address-button'),
            onPressed: onAdd,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: Text(BookingStrings.addNewAddress),
          ),
        ],
      );
    }

    // Empty state
    if (addresses.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            BookingStrings.noAddresses,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: navyAnchor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            BookingStrings.addAddressPrompt,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: servio.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const ValueKey<String>('booking-add-address-button'),
            onPressed: onAdd,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: Text(BookingStrings.addNewAddress),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(
                  double.infinity, ServioSpacing.tapTarget),
              side: const BorderSide(
                color: Color.fromRGBO(154, 140, 115, 0.4),
              ),
              foregroundColor: const Color(0xFF9A8C73),
            ),
          ),
          if (addressError != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              addressError!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: servio.danger,
              ),
            ),
          ],
        ],
      );
    }

    // Address list
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final CustomerAddress address in addresses) ...<Widget>[
          _AddressCard(
            address: address,
            selected: selectedAddress?.id == address.id,
            onTap: () => onSelect(address),
            isDark: isDark,
            navyAnchor: navyAnchor,
            servio: servio,
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          key: const ValueKey<String>('booking-add-address-button'),
          onPressed: onAdd,
          icon: const Icon(Icons.add_location_alt_outlined),
          label: Text(BookingStrings.addNewAddress),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(
                double.infinity, ServioSpacing.tapTarget),
            side: const BorderSide(
              color: Color.fromRGBO(154, 140, 115, 0.4),
            ),
            foregroundColor: const Color(0xFF9A8C73),
          ),
        ),
        if (addressError != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            addressError!,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: servio.danger,
            ),
          ),
        ],
      ],
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.selected,
    required this.onTap,
    required this.isDark,
    required this.navyAnchor,
    required this.servio,
  });

  final CustomerAddress address;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;
  final Color navyAnchor;
  final ServioThemeExtension servio;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey<String>('booking-address-${address.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(ServioRadius.lg),
      child: AnimatedContainer(
        duration: ServioMotion.fast,
        curve: ServioMotion.spring,
        padding: const EdgeInsets.all(ServioSpacing.cardPadding),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFF3EDE7).withValues(alpha: 0.5)
              : (isDark ? const Color(0xFF1E2229) : Colors.white),
          borderRadius: BorderRadius.circular(ServioRadius.lg),
          border: Border.all(
            color: selected
                ? const Color(0xFF9A8C73).withValues(alpha: 0.4)
                : const Color(0xFFC6C6CB).withValues(alpha: 0.3),
            width: selected ? 1.5 : 1.0,
          ),
          boxShadow: selected
              ? const <BoxShadow>[
                  BoxShadow(
                    color: Color.fromRGBO(26, 29, 37, 0.04),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: selected
                        ? (isDark
                            ? const Color(0xFF262B34)
                            : Colors.white)
                        : servio.backgroundSoft,
                    borderRadius: BorderRadius.circular(ServioRadius.md),
                    boxShadow: selected
                        ? const <BoxShadow>[
                            BoxShadow(
                              color: Color.fromRGBO(26, 29, 37, 0.06),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    _iconForLabel(address.displayLabel),
                    color: selected ? navyAnchor : servio.textSecondary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: ServioSpacing.cardPadding),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        address.displayLabel,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: navyAnchor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        address.formattedSingleLine,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: servio.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (selected)
              const Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF9A8C73),
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconForLabel(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('home')) return Icons.home_rounded;
    if (lower.contains('office') || lower.contains('work')) {
      return Icons.business_rounded;
    }
    return Icons.location_on_rounded;
  }
}
