import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../customer/customer_home_screen.dart';
import '../technician/verification_upload_screen.dart';
import 'auth_role.dart';
import 'role_selection_screen.dart';

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
  bool _agreed = false;
  bool _submitting = false;
  String? _error;
  String _availability = 'Both';
  String _currency = 'EGP';

  final Set<String> _specialties = <String>{};
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _cityCtrl = TextEditingController(text: 'Cairo');
  final _skillSearchCtrl = TextEditingController();
  final _serviceAreaCtrl = TextEditingController(text: 'Cairo');
  final _rateCtrl = TextEditingController(text: '350');
  final VerificationUploadController _verificationController =
      VerificationUploadController();

  int get _totalSteps => widget.role == AuthRole.technician ? 7 : 3;
  bool get _isTechnician => widget.role == AuthRole.technician;
  bool get _isSubmittedStep => _isTechnician && _step == _totalSteps - 1;

  @override
  void initState() {
    super.initState();
    for (final controller in <TextEditingController>[
      _nameCtrl,
      _emailCtrl,
      _phoneCtrl,
      _passwordCtrl,
      _otpCtrl,
      _cityCtrl,
      _skillSearchCtrl,
      _serviceAreaCtrl,
      _rateCtrl,
    ]) {
      controller.addListener(_onFormChanged);
    }
    _verificationController.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _nameCtrl,
      _emailCtrl,
      _phoneCtrl,
      _passwordCtrl,
      _otpCtrl,
      _cityCtrl,
      _skillSearchCtrl,
      _serviceAreaCtrl,
      _rateCtrl,
    ]) {
      controller.removeListener(_onFormChanged);
    }
    _verificationController.removeListener(_onFormChanged);
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _otpCtrl.dispose();
    _cityCtrl.dispose();
    _skillSearchCtrl.dispose();
    _serviceAreaCtrl.dispose();
    _rateCtrl.dispose();
    _verificationController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    setState(() => _error = null);

    if (!_validateStep()) return;

    if (_isTechnician && _step == 5) {
      setState(() => _step = 6);
      return;
    }

    if (_step < _totalSteps - 1) {
      setState(() => _step += 1);
      return;
    }

    await _createCustomerAccount();
  }

  bool _validateStep() {
    if (_step == 0) {
      if (_nameCtrl.text.trim().isEmpty ||
          _phoneCtrl.text.trim().isEmpty ||
          _emailCtrl.text.trim().isEmpty ||
          _passwordCtrl.text.trim().isEmpty) {
        setState(() => _error = 'Complete all basic information fields.');
        return false;
      }
    }
    if (_step == 1 && _otpCtrl.text.trim().length != 6) {
      setState(() => _error = 'Enter the 6-digit verification code.');
      return false;
    }
    if (!_isTechnician && _step == 2 && !_agreed) {
      setState(() => _error = 'Accept Terms and Privacy to create account.');
      return false;
    }
    if (_isTechnician && _step == 2 && _specialties.isEmpty) {
      setState(() => _error = 'Select at least one service.');
      return false;
    }
    if (_isTechnician && _step == 3 && _serviceAreaCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Service area is required.');
      return false;
    }
    if (_isTechnician && _step == 4) {
      final rate = int.tryParse(_rateCtrl.text.trim());
      if (rate == null || rate < 50 || rate > 2000) {
        setState(() => _error = 'Hourly rate must be between 50 and 2000.');
        return false;
      }
    }
    if (_isTechnician && _step == 5) {
      final ok = _verificationController.validate();
      if (!ok) {
        setState(() => _error = 'Upload all required verification documents.');
        return false;
      }
    }
    return true;
  }

  Future<void> _createCustomerAccount() async {
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    await context.read<SessionProvider>().registerCustomer(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          city: _cityCtrl.text.trim().isEmpty ? 'Cairo' : _cityCtrl.text.trim(),
        );

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const CustomerHomeScreen()),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _finishTechnicianSubmitted() async {
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const RoleSelectionScreen()),
      (Route<dynamic> route) => false,
    );
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _error = null;
      _step -= 1;
    });
  }

  void _showLegalNotice(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title will open from the legal center.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ServioSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const _BrandShowcaseStrip(),
              const SizedBox(height: 20),
              if (!_isSubmittedStep) ...<Widget>[
                Row(
                  children: <Widget>[
                    _RoleBadge(role: widget.role),
                    const Spacer(),
                    Text(
                      'Step ${_step + 1}/$_totalSteps',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: servio.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Progress(value: (_step + 1) / _totalSteps),
                const SizedBox(height: 24),
              ],
              Text(_headline(), style: theme.textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(
                _subtitle(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: servio.textSecondary,
                  height: 1.5,
                ),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 14),
                _ErrorBox(message: _error!),
              ],
              const SizedBox(height: 24),
              _buildStepContent(context),
              const SizedBox(height: 24),
              if (!_isSubmittedStep) _actionRow(),
              if (_isSubmittedStep)
                ServioPrimaryButton(
                  label: 'Back to Home',
                  isLoading: _submitting,
                  onPressed: _submitting ? null : _finishTechnicianSubmitted,
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionRow() {
    final lastCustomerStep = !_isTechnician && _step == _totalSteps - 1;
    final verificationStep = _isTechnician && _step == 5;

    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton(
            onPressed: _submitting ? null : _back,
            child: const Text('Back'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ServioPrimaryButton(
            label: verificationStep
                ? 'Submit Application'
                : lastCustomerStep
                    ? 'Create Account'
                    : _step == 1
                        ? 'Verify'
                        : 'Continue',
            isLoading: _submitting,
            onPressed: _submitting ||
                    (verificationStep &&
                        !_verificationController.requiredComplete)
                ? null
                : _continue,
          ),
        ),
      ],
    );
  }

  String _headline() {
    if (_isSubmittedStep) return 'Application Submitted!';
    if (_step == 0) return 'Basic Information';
    if (_step == 1) return 'Verify your phone number';
    if (!_isTechnician) return 'Almost done!';
    return switch (_step) {
      2 => 'What services do you offer?',
      3 => 'Set your availability',
      4 => 'Set your hourly rate',
      5 => 'Verify your identity',
      _ => 'Application Submitted!',
    };
  }

  String _subtitle() {
    if (_isSubmittedStep) {
      return 'Thanks for applying to SERVIO. Our verification team will review your documents and notify you by email.';
    }
    if (_step == 0) {
      return 'Create your ${_isTechnician ? 'technician' : 'customer'} profile with secure account details.';
    }
    if (_step == 1) {
      final phone = _phoneCtrl.text.trim().isEmpty
          ? 'your phone number'
          : _phoneCtrl.text.trim();
      return 'Enter the 6-digit code sent to $phone.';
    }
    if (!_isTechnician) {
      return 'Add your city and confirm the agreement to start booking services.';
    }
    return switch (_step) {
      2 => 'Select the categories customers can book you for.',
      3 => 'Choose where and when you can accept jobs.',
      4 => 'Set transparent pricing customers can understand.',
      5 => 'Required documents must be uploaded before submitting.',
      _ => '',
    };
  }

  Widget _buildStepContent(BuildContext context) {
    if (_isSubmittedStep) return const _ApplicationSubmitted();
    return switch ((_step, widget.role)) {
      (0, _) => _BasicInformationStep(
          nameCtrl: _nameCtrl,
          emailCtrl: _emailCtrl,
          phoneCtrl: _phoneCtrl,
          passwordCtrl: _passwordCtrl,
          obscurePassword: _obscurePassword,
          onTogglePassword: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        ),
      (1, _) => _OtpStep(
          controller: _otpCtrl,
          phone: _phoneCtrl.text,
          onResend: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verification code resent.')),
          ),
        ),
      (2, AuthRole.customer) => _CustomerFinishStep(
          cityCtrl: _cityCtrl,
          agreed: _agreed,
          onAgreedChanged: (value) => setState(() => _agreed = value),
          onLegalTap: _showLegalNotice,
        ),
      (2, AuthRole.technician) => _SkillsStep(
          searchCtrl: _skillSearchCtrl,
          selected: _specialties,
          onToggle: (skill) {
            setState(() {
              if (_specialties.contains(skill)) {
                _specialties.remove(skill);
              } else {
                _specialties.add(skill);
              }
            });
          },
        ),
      (3, AuthRole.technician) => _AvailabilityStep(
          serviceAreaCtrl: _serviceAreaCtrl,
          availability: _availability,
          onAvailabilityChanged: (value) =>
              setState(() => _availability = value),
        ),
      (4, AuthRole.technician) => _PricingStep(
          currency: _currency,
          rateCtrl: _rateCtrl,
          onCurrencyChanged: (value) => setState(() => _currency = value),
        ),
      (5, AuthRole.technician) => VerificationUploadStep(
          controller: _verificationController,
          stepLabel: 'Step 6 of $_totalSteps',
          progress: 6 / _totalSteps,
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _BrandShowcaseStrip extends StatelessWidget {
  const _BrandShowcaseStrip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: ServioGradients.brand,
        borderRadius: BorderRadius.circular(ServioRadius.xl),
        boxShadow: ServioShadows.rest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(ServioRadius.sm),
                ),
                child: const Icon(Icons.home_repair_service_rounded,
                    color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text(
                'SERVIO',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Verified work, secure payments, instant booking.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 10,
            runSpacing: 8,
            children: <Widget>[
              _BrandPill(icon: Icons.verified_outlined, label: '2.5k Experts'),
              _BrandPill(icon: Icons.task_alt_rounded, label: '15k Jobs'),
              _BrandPill(icon: Icons.star_rounded, label: '4.9 Rating'),
            ],
          ),
        ],
      ),
    );
  }
}

class _BrandPill extends StatelessWidget {
  const _BrandPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ServioRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: ServioColors.accentLight),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final AuthRole role;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final isTech = role == AuthRole.technician;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: ServioColors.tint(servio.accent),
        borderRadius: BorderRadius.circular(ServioRadius.full),
        border: Border.all(color: servio.accent.withValues(alpha: 0.24)),
      ),
      child: Text(
        isTech ? 'Technician Signup' : 'Customer Signup',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: servio.accent,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return ClipRRect(
      borderRadius: BorderRadius.circular(ServioRadius.full),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 8,
        backgroundColor: servio.backgroundSoft,
        valueColor: const AlwaysStoppedAnimation<Color>(ServioColors.accent),
      ),
    );
  }
}

class _BasicInformationStep extends StatelessWidget {
  const _BasicInformationStep({
    required this.nameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.passwordCtrl,
    required this.obscurePassword,
    required this.onTogglePassword,
  });

  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController passwordCtrl;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final strength = passwordCtrl.text.length >= 8
        ? 'strong'
        : passwordCtrl.text.length >= 5
            ? 'medium'
            : 'weak';
    final strengthColor = switch (strength) {
      'strong' => servio.success,
      'medium' => servio.warning,
      _ => servio.danger,
    };

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.g_mobiledata_rounded),
                label: const Text('Continue with Google'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.apple_rounded),
                label: const Text('Continue with Apple'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(child: Divider(color: servio.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: servio.textSecondary),
              ),
            ),
            Expanded(child: Divider(color: servio.border)),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: nameCtrl,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Full Name',
            prefixIcon: const Icon(Icons.person_outline_rounded),
            suffixIcon: nameCtrl.text.isEmpty
                ? null
                : IconButton(
                    onPressed: nameCtrl.clear,
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Phone Number',
            prefixIcon: const Icon(Icons.phone_outlined),
            suffixIcon: phoneCtrl.text.isEmpty
                ? null
                : IconButton(
                    onPressed: phoneCtrl.clear,
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            prefixIcon: Icon(Icons.alternate_email_rounded),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: passwordCtrl,
          obscureText: obscurePassword,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              onPressed: onTogglePassword,
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(ServioRadius.full),
          child: LinearProgressIndicator(
            value: strength == 'strong'
                ? 1
                : strength == 'medium'
                    ? 0.62
                    : 0.28,
            minHeight: 6,
            backgroundColor: servio.backgroundSoft,
            valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            'Password strength: ${strength[0].toUpperCase()}${strength.substring(1)}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: strengthColor),
          ),
        ),
        const SizedBox(height: 14),
        const _TrustSignals(),
      ],
    );
  }
}

class _OtpStep extends StatefulWidget {
  const _OtpStep({
    required this.controller,
    required this.phone,
    required this.onResend,
  });

  final TextEditingController controller;
  final String phone;
  final VoidCallback onResend;

  @override
  State<_OtpStep> createState() => _OtpStepState();
}

class _OtpStepState extends State<_OtpStep> {
  static const int _cooldown = 30;
  int _secondsLeft = _cooldown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _cooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft -= 1;
        } else {
          timer.cancel();
        }
      });
    });
  }

  void _handleResend() {
    widget.onResend();
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _secondsLeft == 0;
    final mm = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final ss = (_secondsLeft % 60).toString().padLeft(2, '0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: widget.controller,
          maxLength: 6,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '6-digit code',
            prefixIcon: Icon(Icons.pin_outlined),
            suffixIcon: Icon(Icons.close_rounded),
            counterText: '',
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: canResend ? _handleResend : null,
            child: Text(
              canResend ? 'Resend code' : 'Resend code in $mm:$ss',
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomerFinishStep extends StatelessWidget {
  const _CustomerFinishStep({
    required this.cityCtrl,
    required this.agreed,
    required this.onAgreedChanged,
    required this.onLegalTap,
  });

  final TextEditingController cityCtrl;
  final bool agreed;
  final ValueChanged<bool> onAgreedChanged;
  final ValueChanged<String> onLegalTap;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Column(
      children: <Widget>[
        TextField(
          controller: cityCtrl,
          decoration: const InputDecoration(
            labelText: 'Address / City (optional)',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          value: agreed,
          onChanged: (bool? value) => onAgreedChanged(value ?? false),
          contentPadding: EdgeInsets.zero,
          activeColor: servio.accent,
          title: RichText(
            text: TextSpan(
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: servio.textSecondary),
              children: <InlineSpan>[
                const TextSpan(text: 'I agree to '),
                TextSpan(
                  text: 'Terms',
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => onLegalTap('Terms of Service'),
                  style: TextStyle(color: servio.accent),
                ),
                const TextSpan(text: ' and '),
                TextSpan(
                  text: 'Privacy Policy',
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => onLegalTap('Privacy Policy'),
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
}

class _SkillsStep extends StatelessWidget {
  const _SkillsStep({
    required this.searchCtrl,
    required this.selected,
    required this.onToggle,
  });

  final TextEditingController searchCtrl;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  static const List<String> _options = <String>[
    'Plumbing',
    'Electrical',
    'Painting',
    'HVAC',
    'Carpentry',
    'Cleaning',
  ];

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: searchCtrl,
          decoration: InputDecoration(
            labelText: 'Search skills',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: searchCtrl.text.isEmpty
                ? null
                : IconButton(
                    onPressed: searchCtrl.clear,
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _options.map((String item) {
            final active = selected.contains(item);
            return FilterChip(
              selected: active,
              label: Text(item),
              selectedColor: servio.accent,
              checkmarkColor: Colors.white,
              labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: active ? Colors.white : servio.textSecondary,
                  ),
              onSelected: (_) => onToggle(item),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _AvailabilityStep extends StatelessWidget {
  const _AvailabilityStep({
    required this.serviceAreaCtrl,
    required this.availability,
    required this.onAvailabilityChanged,
  });

  final TextEditingController serviceAreaCtrl;
  final String availability;
  final ValueChanged<String> onAvailabilityChanged;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    const options = <String>['Weekdays', 'Weekends', 'Both'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: serviceAreaCtrl,
          decoration: const InputDecoration(
            labelText: 'Service area',
            prefixIcon: Icon(Icons.map_outlined),
          ),
        ),
        const SizedBox(height: 16),
        ServioCard(
          padding: const EdgeInsets.all(6),
          radius: ServioRadius.full,
          backgroundColor: servio.backgroundSoft,
          borderColor: Colors.transparent,
          child: Row(
            children: options.map((String option) {
              final active = availability == option;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onAvailabilityChanged(option),
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
      ],
    );
  }
}

class _PricingStep extends StatelessWidget {
  const _PricingStep({
    required this.currency,
    required this.rateCtrl,
    required this.onCurrencyChanged,
  });

  final String currency;
  final TextEditingController rateCtrl;
  final ValueChanged<String> onCurrencyChanged;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            SizedBox(
              width: 112,
              child: DropdownButtonFormField<String>(
                value: currency,
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(value: 'EGP', child: Text('EGP')),
                  DropdownMenuItem<String>(value: 'USD', child: Text('USD')),
                ],
                onChanged: (value) => onCurrencyChanged(value ?? currency),
                decoration: const InputDecoration(labelText: 'Currency'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: rateCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Hourly rate',
                  suffixIcon: rateCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: rateCtrl.clear,
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Set a rate between 50 and 2000. You can update it after approval.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: servio.textSecondary),
        ),
      ],
    );
  }
}

class _ApplicationSubmitted extends StatelessWidget {
  const _ApplicationSubmitted();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return ServioCard(
      radius: ServioRadius.lg,
      child: Column(
        children: <Widget>[
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: ServioColors.tint(servio.success),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, color: servio.success, size: 38),
          ),
          const SizedBox(height: 16),
          Text('Next Steps', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          const _SubmittedStep(
              number: '1', text: 'Team verifies your documents'),
          const _SubmittedStep(
              number: '2', text: 'Email notification in 2-3 business days'),
          const _SubmittedStep(
              number: '3', text: 'Approved technicians get full app access'),
          const SizedBox(height: 12),
          Text(
            'Need help? support@servio.app',
            style: theme.textTheme.bodySmall?.copyWith(
              color: servio.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmittedStep extends StatelessWidget {
  const _SubmittedStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 13,
            backgroundColor: servio.accent,
            child: Text(
              number,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _TrustSignals extends StatelessWidget {
  const _TrustSignals();

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    const items = <String>['Secure signup', 'No spam', 'Cancel anytime'];

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: items
          .map(
            (item) => Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.check_circle_outline_rounded,
                    color: servio.accent, size: 16),
                const SizedBox(width: 5),
                Text(
                  item,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: servio.textSecondary,
                      ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ServioColors.tint(servio.danger),
        borderRadius: BorderRadius.circular(ServioRadius.sm),
        border: Border.all(color: servio.danger.withValues(alpha: 0.28)),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: servio.danger,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
