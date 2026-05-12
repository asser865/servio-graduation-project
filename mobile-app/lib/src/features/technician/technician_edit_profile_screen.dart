import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_primary_button.dart';

class TechnicianEditProfileScreen extends StatefulWidget {
  const TechnicianEditProfileScreen({super.key});

  @override
  State<TechnicianEditProfileScreen> createState() =>
      _TechnicianEditProfileScreenState();
}

class _TechnicianEditProfileScreenState
    extends State<TechnicianEditProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _hourlyRateCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _skillsCtrl;
  String _availabilityType = '';
  bool _saving = false;

  static const List<String> _availabilityOptions = [
    '',
    'weekdays',
    'weekends',
    'both'
  ];
  static const Map<String, String> _availabilityLabels = {
    '': 'Not set',
    'weekdays': 'Weekdays',
    'weekends': 'Weekends',
    'both': 'Weekdays & Weekends',
  };

  @override
  void initState() {
    super.initState();
    final account = context.read<SessionProvider>().account;
    _nameCtrl = TextEditingController(text: account?.name ?? '');
    _emailCtrl = TextEditingController(text: account?.email ?? '');
    _phoneCtrl = TextEditingController(text: account?.phone ?? '');
    _bioCtrl = TextEditingController(text: account?.bio ?? '');
    _hourlyRateCtrl = TextEditingController(
      text: account != null && account.hourlyRate > 0
          ? account.hourlyRate.toStringAsFixed(0)
          : '',
    );
    _locationCtrl = TextEditingController(text: account?.locationLabel ?? '');
    _skillsCtrl = TextEditingController(text: account?.skills.join(', ') ?? '');
    _availabilityType = account?.availabilityType ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    _hourlyRateCtrl.dispose();
    _locationCtrl.dispose();
    _skillsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final session = context.read<SessionProvider>();
    final account = session.account;

    final newEmail = _emailCtrl.text.trim().toLowerCase();
    final emailChanged = newEmail != (account?.email ?? '');

    if (emailChanged) {
      setState(() => _saving = false);
      await _handleEmailChange(newEmail);
      return;
    }

    final fields = <String, dynamic>{};

    if (_nameCtrl.text.trim() != (account?.name ?? '')) {
      fields['name'] = _nameCtrl.text.trim();
    }
    if (_phoneCtrl.text.trim() != (account?.phone ?? '')) {
      fields['phone'] = _phoneCtrl.text.trim();
    }
    if (_bioCtrl.text.trim() != (account?.bio ?? '')) {
      fields['bio'] = _bioCtrl.text.trim();
    }
    if (_locationCtrl.text.trim() != (account?.locationLabel ?? '')) {
      fields['locationLabel'] = _locationCtrl.text.trim();
    }
    if (_availabilityType != (account?.availabilityType ?? '')) {
      fields['availabilityType'] = _availabilityType;
    }
    final rateText = _hourlyRateCtrl.text.trim();
    if (rateText.isNotEmpty) {
      final rate = double.tryParse(rateText);
      if (rate != null && rate != account?.hourlyRate) {
        fields['hourlyRate'] = rate;
      }
    }
    final rawSkills = _skillsCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (rawSkills.join(',') != (account?.skills.join(',') ?? '')) {
      fields['skills'] = rawSkills;
    }

    if (fields.isEmpty) {
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.pop(context);
      return;
    }

    final error = await session.updateProfile(fields);
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _handleEmailChange(String newEmail) async {
    final passwordCtrl = TextEditingController();
    bool obscure = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Confirm Email Change'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('New email: $newEmail'),
              const SizedBox(height: 16),
              const Text('Enter your current password to confirm:'),
              const SizedBox(height: 8),
              TextField(
                controller: passwordCtrl,
                obscureText: obscure,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  suffixIcon: IconButton(
                    icon: Icon(obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || confirmed != true) return;
    if (passwordCtrl.text.isEmpty) return;

    setState(() => _saving = true);
    final error = await context.read<SessionProvider>().updateEmail(
          newEmail: newEmail,
          currentPassword: passwordCtrl.text,
        );
    passwordCtrl.dispose();
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Email updated. Please log in again with your new email.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final account = context.watch<SessionProvider>().account;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 16),
            Center(
              child: Stack(
                children: <Widget>[
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: ServioGradients.warm,
                      shape: BoxShape.circle,
                      border: Border.all(color: servio.accent, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        account?.initials ?? 'T',
                        style: theme.textTheme.headlineLarge
                            ?.copyWith(color: ServioColors.deepBrown),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: servio.accent,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: theme.scaffoldBackgroundColor, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_outlined,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bioCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Bio / Professional Summary',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _hourlyRateCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Hourly Rate (EGP)',
                prefixIcon: Icon(Icons.attach_money_rounded),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Service Area (e.g. Nasr City)',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _skillsCtrl,
              decoration: const InputDecoration(
                labelText: 'Skills (comma-separated)',
                prefixIcon: Icon(Icons.build_outlined),
                hintText: 'e.g. pipe repair, drain cleaning',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _availabilityType,
              decoration: const InputDecoration(
                labelText: 'Availability',
                prefixIcon: Icon(Icons.schedule_outlined),
              ),
              items: _availabilityOptions
                  .map((v) => DropdownMenuItem(
                        value: v,
                        child: Text(_availabilityLabels[v] ?? v),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _availabilityType = v ?? ''),
            ),
            const SizedBox(height: 32),
            ServioPrimaryButton(
              label: _saving ? 'Saving…' : 'Save Changes',
              onPressed: _saving ? null : _save,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
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
