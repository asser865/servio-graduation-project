import 'package:flutter/material.dart';

import '../../core/models/customer_address.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';

class CreateAddressScreen extends StatefulWidget {
  const CreateAddressScreen({super.key});

  @override
  State<CreateAddressScreen> createState() => _CreateAddressScreenState();
}

class _CreateAddressScreenState extends State<CreateAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _labelCtrl = TextEditingController();
  final _fullAddressCtrl = TextEditingController();
  final _cityAreaCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();

  bool _isDefault = false;

  @override
  void dispose() {
    _labelCtrl.dispose();
    _fullAddressCtrl.dispose();
    _cityAreaCtrl.dispose();
    _landmarkCtrl.dispose();
    super.dispose();
  }

  void _saveAddress() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final landmark = _landmarkCtrl.text.trim();
    final address = CustomerAddress(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      label: _labelCtrl.text.trim(),
      fullAddress: _fullAddressCtrl.text.trim(),
      cityArea: _cityAreaCtrl.text.trim(),
      landmarkInstructions: landmark.isEmpty ? null : landmark,
      isDefault: _isDefault,
    );

    Navigator.of(context).pop<CustomerAddress>(address);
  }

  String? _required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Address'),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(ServioSpacing.screenPadding),
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
                          'Save a location you can reuse during booking.',
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
              controller: _labelCtrl,
              textInputAction: TextInputAction.next,
              validator: (value) => _required(value, 'Label'),
              decoration: const InputDecoration(
                labelText: 'Address label',
                hintText: 'Home, Work, Studio',
                prefixIcon: Icon(Icons.label_outline_rounded),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fullAddressCtrl,
              textInputAction: TextInputAction.newline,
              keyboardType: TextInputType.streetAddress,
              maxLines: 3,
              validator: (value) => _required(value, 'Full address'),
              decoration: const InputDecoration(
                labelText: 'Full address',
                hintText: 'Building, street, apartment, floor',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.home_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cityAreaCtrl,
              textInputAction: TextInputAction.next,
              validator: (value) => _required(value, 'City / area'),
              decoration: const InputDecoration(
                labelText: 'City / area',
                hintText: 'Cairo, Nasr City',
                prefixIcon: Icon(Icons.location_city_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _landmarkCtrl,
              textInputAction: TextInputAction.done,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Landmark or instructions (optional)',
                hintText: 'Near gate 2, call on arrival',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 20),
            ServioCard(
              radius: ServioRadius.lg,
              child: Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: ServioColors.tint(servio.success),
                      borderRadius: BorderRadius.circular(ServioRadius.md),
                    ),
                    child: Icon(
                      Icons.check_circle_outline_rounded,
                      color: servio.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Set as default',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Use this address first during future bookings.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: servio.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isDefault,
                    activeColor: servio.accent,
                    onChanged: (value) => setState(() => _isDefault = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            ServioPrimaryButton(
              label: 'Save Address',
              onPressed: _saveAddress,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: servio.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
