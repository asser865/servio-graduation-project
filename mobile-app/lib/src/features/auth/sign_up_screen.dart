import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import 'auth_role.dart';
import '../customer/customer_home_screen.dart';
import '../technician/technician_dashboard_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({
    required this.role,
    super.key,
  });

  final AuthRole role;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  int _step = 0;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreed = true;
  bool _readyImmediately = true;
  bool _submitting = false;
  String _availability = 'Both';
  final String _strength = 'strong';
  final Set<String> _specialties = <String>{'Plumbing', 'Electrical'};

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _city = 'Cairo';

  int get _totalSteps => widget.role == AuthRole.technician ? 3 : 2;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_step < _totalSteps - 1) {
      setState(() => _step += 1);
      return;
    }

    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final session = context.read<SessionProvider>();
    if (widget.role == AuthRole.customer) {
      await session.registerCustomer(
        name: _nameCtrl.text.trim().isEmpty ? 'New User' : _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? 'user@example.com' : _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        city: _city,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const CustomerHomeScreen()),
        (Route<dynamic> route) => false,
      );
    } else {
      await session.registerTechnician(
        name: _nameCtrl.text.trim().isEmpty ? 'New Technician' : _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? 'tech@example.com' : _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const TechnicianDashboardScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: ServioSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 20),
              Text(
                'Step ${_step + 1}/$_totalSteps',
                style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
              ),
              const SizedBox(height: 12),
              // Gradient progress bar — matches web linear-gradient(90deg, #9A8C73, #BFB09A)
              LayoutBuilder(
                builder: (BuildContext ctx, BoxConstraints constraints) {
                  return Stack(
                    children: <Widget>[
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: servio.backgroundSoft,
                          borderRadius: BorderRadius.circular(ServioRadius.full),
                        ),
                      ),
                      AnimatedContainer(
                        duration: ServioMotion.normal,
                        curve: ServioMotion.spring,
                        height: 8,
                        width: constraints.maxWidth * (_step + 1) / _totalSteps,
                        decoration: BoxDecoration(
                          gradient: ServioGradients.accent,
                          borderRadius: BorderRadius.circular(ServioRadius.full),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                widget.role == AuthRole.customer ? 'Create your account' : 'Join SERVIO as a technician',
                style: theme.textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _stepTitle(),
                style: theme.textTheme.bodyMedium?.copyWith(color: servio.textSecondary),
              ),
              const SizedBox(height: 24),
              _buildStepContent(context),
              const SizedBox(height: 24),
              ServioPrimaryButton(
                label: _submitting
                    ? 'Creating account…'
                    : _step == _totalSteps - 1
                        ? 'Create Account'
                        : 'Continue',
                onPressed: _submitting ? null : _continue,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _stepTitle() {
    if (_step == 0) {
      return 'Enter your basic account details.';
    }
    if (widget.role == AuthRole.customer) {
      return 'Set your city and accept the agreement.';
    }
    if (_step == 1) {
      return 'Tell customers what kind of work you do.';
    }
    return 'Set your price and availability.';
  }

  Widget _buildStepContent(BuildContext context) {
    return switch ((_step, widget.role)) {
      (0, _) => _buildSharedFields(context),
      (1, AuthRole.customer) => _buildCustomerStep(context),
      (1, AuthRole.technician) => _buildTechnicianStepTwo(context),
      (2, AuthRole.technician) => _buildTechnicianStepThree(context),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildSharedFields(BuildContext context) {
    final servio = context.servio;

    return Column(
      children: <Widget>[
        TextField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Full Name'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            SizedBox(
              width: 96,
              child: DropdownButtonFormField<String>(
                value: '+20',
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(value: '+20', child: Text('+20')),
                ],
                onChanged: (_) {},
                decoration: const InputDecoration(labelText: 'Code'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Mobile Number'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Password',
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(ServioRadius.full),
          child: LinearProgressIndicator(
            value: 1,
            minHeight: 6,
            backgroundColor: servio.backgroundSoft,
            valueColor: AlwaysStoppedAnimation<Color>(_strengthColor()),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Password strength: ${_strength[0].toUpperCase()}${_strength.substring(1)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _strengthColor()),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerStep(BuildContext context) {
    final servio = context.servio;

    return Column(
      children: <Widget>[
        DropdownButtonFormField<String>(
          value: 'Cairo',
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem<String>(value: 'Cairo', child: Text('Cairo')),
            DropdownMenuItem<String>(value: 'Alexandria', child: Text('Alexandria')),
            DropdownMenuItem<String>(value: 'Giza', child: Text('Giza')),
          ],
          onChanged: (String? v) => setState(() => _city = v ?? _city),
          decoration: const InputDecoration(labelText: 'Address / City'),
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          value: _agreed,
          onChanged: (bool? value) => setState(() => _agreed = value ?? false),
          contentPadding: EdgeInsets.zero,
          activeColor: servio.accent,
          title: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: servio.textSecondary),
              children: <InlineSpan>[
                const TextSpan(text: 'I agree to '),
                TextSpan(
                  text: 'Terms of Service',
                  style: TextStyle(color: servio.accent),
                ),
                const TextSpan(text: ' and '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: TextStyle(color: servio.accent),
                ),
              ],
            ),
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }

  Widget _buildTechnicianStepTwo(BuildContext context) {
    final servio = context.servio;
    final options = <String>['Plumbing', 'Electrical', 'Painting', 'HVAC'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Specialty',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: servio.textSecondary),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options.map((String item) {
            final selected = _specialties.contains(item);

            return FilterChip(
              selected: selected,
              label: Text(item),
              selectedColor: servio.accent,
              checkmarkColor: Colors.white,
              labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? Colors.white : servio.textSecondary,
                  ),
              onSelected: (bool value) {
                setState(() {
                  if (value) {
                    _specialties.add(item);
                  } else {
                    _specialties.remove(item);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: 'Cairo',
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem<String>(value: 'Cairo', child: Text('Cairo')),
            DropdownMenuItem<String>(value: 'Giza', child: Text('Giza')),
            DropdownMenuItem<String>(value: 'Mansoura', child: Text('Mansoura')),
          ],
          onChanged: (_) {},
          decoration: const InputDecoration(labelText: 'City / Service Area'),
        ),
        const SizedBox(height: 16),
        const TextField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Years of Experience'),
        ),
      ],
    );
  }

  Widget _buildTechnicianStepThree(BuildContext context) {
    final servio = context.servio;
    const options = <String>['Weekdays', 'Weekends', 'Both'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const TextField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Hourly Rate',
            prefixText: 'EGP ',
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Availability Quick Set',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: servio.textSecondary),
        ),
        const SizedBox(height: 12),
        ServioCard(
          padding: const EdgeInsets.all(6),
          radius: ServioRadius.full,
          backgroundColor: servio.backgroundSoft,
          borderColor: Colors.transparent,
          child: Row(
            children: options.map((String option) {
              final active = _availability == option;

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _availability = option),
                  child: AnimatedContainer(
                    duration: ServioMotion.micro,
                    curve: ServioMotion.curve,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: active ? servio.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(ServioRadius.full),
                    ),
                    child: Text(
                      option,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: active ? Colors.white : servio.textSecondary,
                          ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          value: _readyImmediately,
          onChanged: (bool value) => setState(() => _readyImmediately = value),
          activeColor: servio.accent,
          contentPadding: EdgeInsets.zero,
          title: const Text('Ready to accept jobs immediately'),
        ),
      ],
    );
  }

  Color _strengthColor() {
    return switch (_strength) {
      'weak' => ServioColors.danger,
      'medium' => ServioColors.warning,
      _ => ServioColors.success,
    };
  }
}
