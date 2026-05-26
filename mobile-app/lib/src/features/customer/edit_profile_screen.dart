import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  bool _saving = false;
  bool _isChanged = false;

  @override
  void initState() {
    super.initState();
    final account = context.read<SessionProvider>().account;
    _nameCtrl = TextEditingController(text: account?.name ?? '');
    _emailCtrl = TextEditingController(text: account?.email ?? '');
    _phoneCtrl = TextEditingController(text: account?.phone ?? '');

    _nameCtrl.addListener(_onInputChanged);
    _emailCtrl.addListener(_onInputChanged);
    _phoneCtrl.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onInputChanged);
    _emailCtrl.removeListener(_onInputChanged);
    _phoneCtrl.removeListener(_onInputChanged);
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    final account = context.read<SessionProvider>().account;
    final changed = _nameCtrl.text.trim() != (account?.name ?? '') ||
        _emailCtrl.text.trim().toLowerCase() != (account?.email ?? '').toLowerCase() ||
        _phoneCtrl.text.trim() != (account?.phone ?? '');
    if (changed != _isChanged) {
      setState(() => _isChanged = changed);
    }
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
      builder: (ctx) {
        final dialogTheme = Theme.of(ctx);
        final dialogServio = ctx.servio;
        final dialogIsDark = dialogTheme.brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: dialogIsDark ? dialogServio.surfaceAlt : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ServioRadius.md),
            ),
            title: Text(
              'Confirm Email Change',
              style: dialogTheme.textTheme.titleMedium?.copyWith(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'New email: $newEmail',
                  style: dialogTheme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Enter your current password to confirm:',
                  style: dialogTheme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'Inter',
                    color: dialogServio.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtrl,
                  obscureText: obscure,
                  autofocus: true,
                  style: dialogTheme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'Inter',
                  ),
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    labelStyle: TextStyle(
                      color: dialogServio.textSecondary,
                      fontFamily: 'Inter',
                    ),
                    filled: true,
                    fillColor: dialogIsDark ? dialogServio.backgroundSoft : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ServioRadius.sm),
                      borderSide: BorderSide(
                        color: dialogIsDark ? dialogServio.border : ServioColors.borderLight,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ServioRadius.sm),
                      borderSide: BorderSide(
                        color: dialogServio.accent,
                        width: 2,
                      ),
                    ),
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
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: dialogServio.textSecondary,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Confirm',
                  style: TextStyle(
                    color: dialogServio.accent,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;
    if (passwordCtrl.text.isEmpty) return;
    if (!mounted) return;

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
    final theme = Theme.of(context);
    final servio = context.servio;
    final isDark = theme.brightness == Brightness.dark;
    final account = context.watch<SessionProvider>().account;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Profile',
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: ServioSpacing.screenPadding, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Picture Section
                Center(
                  child: _InteractiveScale(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Avatar editing is simulated.')),
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 128,
                              height: 128,
                              decoration: BoxDecoration(
                                color: isDark ? servio.surfaceAlt : const Color(0xFFF3EDE7),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.scaffoldBackgroundColor,
                                  width: 4,
                                ),
                                boxShadow: ServioShadows.rest,
                              ),
                              child: Center(
                                child: Text(
                                  account?.initials ?? 'U',
                                  style: theme.textTheme.headlineLarge?.copyWith(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : ServioColors.deepBrown,
                                    fontSize: 36,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isDark ? servio.accent : ServioColors.navyDark,
                                  shape: BoxShape.circle,
                                  boxShadow: ServioShadows.elevated,
                                ),
                                child: const Icon(
                                  Icons.edit_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tap to change photo',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontFamily: 'Inter',
                            color: servio.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Form Section cozy card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? servio.surfaceAlt : const Color(0xFFF3EDE7).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(ServioRadius.lg),
                    border: Border.all(
                      color: isDark
                          ? servio.border
                          : const Color(0xFF9A8C73).withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Name Input
                      _FormInputLabel(
                        icon: Icons.person_outline_rounded,
                        label: 'Full Name',
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameCtrl,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'Inter',
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? servio.backgroundSoft : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(ServioRadius.sm),
                            borderSide: BorderSide(
                              color: isDark ? servio.border : ServioColors.borderLight,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(ServioRadius.sm),
                            borderSide: BorderSide(
                              color: servio.accent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Email Input
                      _FormInputLabel(
                        icon: Icons.mail_outline_rounded,
                        label: 'Email Address',
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'Inter',
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? servio.backgroundSoft : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(ServioRadius.sm),
                            borderSide: BorderSide(
                              color: isDark ? servio.border : ServioColors.borderLight,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(ServioRadius.sm),
                            borderSide: BorderSide(
                              color: servio.accent,
                              width: 2,
                            ),
                          ),
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: TextButton(
                              onPressed: _emailCtrl.text.trim().toLowerCase() ==
                                      (account?.email ?? '').toLowerCase()
                                  ? null
                                  : () => _handleEmailChange(_emailCtrl.text.trim()),
                              child: Text(
                                'Change',
                                style: TextStyle(
                                  color: _emailCtrl.text.trim().toLowerCase() ==
                                          (account?.email ?? '').toLowerCase()
                                      ? servio.textSecondary.withValues(alpha: 0.5)
                                      : servio.accent,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Phone Input
                      _FormInputLabel(
                        icon: Icons.phone_outlined,
                        label: 'Phone Number',
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'Inter',
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? servio.backgroundSoft : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(ServioRadius.sm),
                            borderSide: BorderSide(
                              color: isDark ? servio.border : ServioColors.borderLight,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(ServioRadius.sm),
                            borderSide: BorderSide(
                              color: servio.accent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Save Changes button with interactive scale spring micro-animation
                      _InteractiveScale(
                        onTap: (_isChanged && !_saving) ? _save : null,
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: (_isChanged && !_saving)
                                ? (isDark ? servio.accent : ServioColors.navyDark)
                                : (isDark ? servio.backgroundSoft : Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(ServioRadius.sm),
                            boxShadow: (_isChanged && !_saving)
                                ? [
                                    BoxShadow(
                                      color: (isDark ? servio.accent : ServioColors.navyDark)
                                          .withValues(alpha: 0.2),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    )
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.save_rounded,
                                  color: (_isChanged && !_saving)
                                      ? Colors.white
                                      : (isDark ? servio.textSecondary : Colors.grey.shade500),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _saving ? 'Saving...' : 'Save Changes',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.bold,
                                    color: (_isChanged && !_saving)
                                        ? Colors.white
                                        : (isDark ? servio.textSecondary : Colors.grey.shade500),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FormInputLabel extends StatelessWidget {
  const _FormInputLabel({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: servio.textSecondary,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontFamily: 'Inter',
            color: servio.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _InteractiveScale extends StatefulWidget {
  const _InteractiveScale({
    required this.child,
    this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_InteractiveScale> createState() => _InteractiveScaleState();
}

class _InteractiveScaleState extends State<_InteractiveScale> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onTap != null;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: isEnabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: ServioMotion.fast,
        curve: ServioMotion.spring,
        child: widget.child,
      ),
    );
  }
}
