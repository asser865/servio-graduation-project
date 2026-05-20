import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/models/customer_address.dart';
import '../../core/services/location_service.dart';
import '../../core/state/customer_addresses_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../../shared/widgets/servio_map_widget.dart';

class CreateAddressScreen extends StatefulWidget {
  const CreateAddressScreen({
    super.key,
    this.address,
  });

  final CustomerAddress? address;

  @override
  State<CreateAddressScreen> createState() => _CreateAddressScreenState();
}

class _CreateAddressScreenState extends State<CreateAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelCtrl;
  late final TextEditingController _streetCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _zipCtrl;

  String? _submitError;
  LatLng? _pickedLocation;
  bool _loadingLocation = false;

  bool get _isEditing => widget.address != null;

  @override
  void initState() {
    super.initState();
    final address = widget.address;
    _labelCtrl = TextEditingController(text: address?.label ?? '');
    _streetCtrl = TextEditingController(text: address?.street ?? '');
    _cityCtrl = TextEditingController(text: address?.city ?? '');
    _stateCtrl = TextEditingController(text: address?.state ?? '');
    _zipCtrl = TextEditingController(text: address?.zipCode ?? '');
    if (address != null && address.lat != null && address.lng != null) {
      _pickedLocation = LatLng(address.lat!, address.lng!);
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _streetCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _zipCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAddress() async {
    setState(() => _submitError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final provider = context.read<CustomerAddressesProvider>();
    final saved = _isEditing
        ? await provider.updateAddress(
            widget.address!.id,
            label: _labelCtrl.text,
            street: _streetCtrl.text,
            city: _cityCtrl.text,
            state: _stateCtrl.text,
            zipCode: _zipCtrl.text,
            lat: _pickedLocation?.latitude,
            lng: _pickedLocation?.longitude,
          )
        : await provider.addAddress(
            label: _labelCtrl.text,
            street: _streetCtrl.text,
            city: _cityCtrl.text,
            state: _stateCtrl.text,
            zipCode: _zipCtrl.text,
            lat: _pickedLocation?.latitude,
            lng: _pickedLocation?.longitude,
          );

    if (!mounted) return;
    if (saved != null) {
      Navigator.of(context).pop<CustomerAddress>(saved);
      return;
    }

    setState(() {
      _submitError = provider.error ?? 'Failed to save address';
    });
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _loadingLocation = true);
    final loc = await LocationService().getCurrentLocation();
    if (mounted) {
      setState(() {
        _pickedLocation = loc;
        _loadingLocation = false;
      });
    }
  }

  String? _requiredStreet(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Street address is required';
    if (trimmed.length > 200) return 'Street cannot exceed 200 characters';
    return null;
  }

  String? _maxLength(String? value, String fieldName, int max) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length > max) return '$fieldName cannot exceed $max characters';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final saving = context.watch<CustomerAddressesProvider>().saving;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Address' : 'Add Address'),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
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
                        color: ServioColors.tint(servio.accent),
                        borderRadius: BorderRadius.circular(ServioRadius.md),
                      ),
                      child: Icon(
                        Icons.add_location_alt_rounded,
                        color: servio.accent,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Address details',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Saved addresses sync with the website.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: servio.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const ValueKey<String>('address-label-field'),
                controller: _labelCtrl,
                textInputAction: TextInputAction.next,
                validator: (value) => _maxLength(value, 'Label', 100),
                decoration: const InputDecoration(
                  labelText: 'Address label (optional)',
                  hintText: 'Home, Work, Office',
                  prefixIcon: Icon(Icons.label_outline_rounded),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey<String>('address-street-field'),
                controller: _streetCtrl,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.streetAddress,
                validator: _requiredStreet,
                decoration: const InputDecoration(
                  labelText: 'Street address',
                  hintText: 'Street, building, apartment',
                  prefixIcon: Icon(Icons.home_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey<String>('address-city-field'),
                controller: _cityCtrl,
                textInputAction: TextInputAction.next,
                validator: (value) => _maxLength(value, 'City', 100),
                decoration: const InputDecoration(
                  labelText: 'City',
                  hintText: 'Cairo',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey<String>('address-state-field'),
                controller: _stateCtrl,
                textInputAction: TextInputAction.next,
                validator: (value) => _maxLength(value, 'District / Area', 100),
                decoration: const InputDecoration(
                  labelText: 'District / Area',
                  hintText: 'Maadi, Nasr City',
                  prefixIcon: Icon(Icons.map_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey<String>('address-zip-field'),
                controller: _zipCtrl,
                textInputAction: TextInputAction.done,
                validator: (value) => _maxLength(value, 'Zip code', 30),
                decoration: const InputDecoration(
                  labelText: 'ZIP / Postal code (optional)',
                  hintText: '11765',
                  prefixIcon: Icon(Icons.markunread_mailbox_outlined),
                ),
                onFieldSubmitted: (_) {
                  if (!saving) _saveAddress();
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Pin Location (Optional)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _pickedLocation == null
                      ? Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text('Tap the map to pin your location'),
                          ),
                        )
                      : ServioMapWidget(
                          center: _pickedLocation!,
                          interactive: true,
                          markers: [buildPinMarker(_pickedLocation!)],
                          onTap: (latLng) =>
                              setState(() => _pickedLocation = latLng),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _loadingLocation ? null : _fetchCurrentLocation,
                icon: _loadingLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: Text(
                  _loadingLocation ? 'Getting location...' : 'Use my location',
                ),
              ),
              if (_submitError != null) ...<Widget>[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ServioColors.tint(servio.danger),
                    borderRadius: BorderRadius.circular(ServioRadius.md),
                  ),
                  child: Text(
                    _submitError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: servio.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              ServioPrimaryButton(
                key: const ValueKey<String>('address-save-button'),
                label: saving ? 'Saving...' : 'Save Address',
                onPressed: saving ? null : _saveAddress,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: saving ? null : () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: servio.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
