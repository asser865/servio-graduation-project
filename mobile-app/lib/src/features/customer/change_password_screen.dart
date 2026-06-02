import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  final _currentFocus = FocusNode();
  final _newFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    _currentFocus.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  // --- Real-time password check conditions ---
  bool get _hasMinLength => _newCtrl.text.length >= 8;
  bool get _hasUppercase => _newCtrl.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase => _newCtrl.text.contains(RegExp(r'[a-z]'));
  bool get _hasNumber => _newCtrl.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecialChar =>
      _newCtrl.text.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));

  int get _metRequirementsCount {
    int count = 0;
    if (_hasMinLength) count++;
    if (_hasUppercase) count++;
    if (_hasLowercase) count++;
    if (_hasNumber) count++;
    if (_hasSpecialChar) count++;
    return count;
  }

  bool get _isFormValid {
    final currentPassword = _currentCtrl.text;
    final newPassword = _newCtrl.text;
    final confirmPassword = _confirmCtrl.text;

    return currentPassword.isNotEmpty &&
        _metRequirementsCount == 5 &&
        newPassword != currentPassword &&
        confirmPassword == newPassword;
  }

  Future<void> _submit() async {
    if (!_isFormValid) return;

    setState(() {
      _isSubmitting = true;
    });

    final currentPassword = _currentCtrl.text;
    final newPassword = _newCtrl.text;

    final sessionProvider = context.read<SessionProvider>();
    final error = await sessionProvider.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: context.servio.danger,
        ),
      );
    } else {
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Password changed successfully!'),
          backgroundColor: context.servio.success,
        ),
      );

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : ServioColors.navyDark,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Change Password',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : ServioColors.navyDark,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(
            horizontal: ServioSpacing.screenPadding,
            vertical: 16,
          ),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: isDark ? servio.surfaceAlt : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? servio.border
                      : const Color.fromRGBO(26, 29, 35, 0.08),
                ),
                boxShadow: isDark ? ServioShadows.restDark : ServioShadows.rest,
              ),
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Security Details',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : ServioColors.navyDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ensure your account stays secure by using a strong password.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: servio.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- Current Password ---
                    Text(
                      'Current Password',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : ServioColors.navyDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _currentCtrl,
                      focusNode: _currentFocus,
                      obscureText: _obscureCurrent,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).requestFocus(_newFocus),
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        color: isDark ? Colors.white : ServioColors.navyDark,
                      ),
                      decoration: _buildInputDecoration(
                        hint: 'Enter current password',
                        obscure: _obscureCurrent,
                        onToggle: () => setState(
                            () => _obscureCurrent = !_obscureCurrent),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- New Password ---
                    Text(
                      'New Password',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : ServioColors.navyDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _newCtrl,
                      focusNode: _newFocus,
                      obscureText: _obscureNew,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).requestFocus(_confirmFocus),
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        color: isDark ? Colors.white : ServioColors.navyDark,
                      ),
                      decoration: _buildInputDecoration(
                        hint: 'Create new password',
                        obscure: _obscureNew,
                        onToggle: () =>
                            setState(() => _obscureNew = !_obscureNew),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // --- Password Requirements Card ---
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? servio.backgroundSoft
                            : const Color(0xFFFBFBF9),
                        border: Border.all(
                          color: isDark
                              ? servio.border
                              : const Color.fromRGBO(26, 29, 35, 0.05),
                        ),
                        borderRadius: BorderRadius.circular(ServioRadius.md),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Password requirements:',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: servio.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildChecklistItem('At least 8 characters', _hasMinLength),
                          const SizedBox(height: 10),
                          _buildChecklistItem('One uppercase letter', _hasUppercase),
                          const SizedBox(height: 10),
                          _buildChecklistItem('One lowercase letter', _hasLowercase),
                          const SizedBox(height: 10),
                          _buildChecklistItem('One number', _hasNumber),
                          const SizedBox(height: 10),
                          _buildChecklistItem('One special character', _hasSpecialChar),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- Password Strength Bar ---
                    _buildStrengthIndicator(_metRequirementsCount),
                    const SizedBox(height: 24),

                    // --- Confirm New Password ---
                    Text(
                      'Confirm New Password',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : ServioColors.navyDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _confirmCtrl,
                      focusNode: _confirmFocus,
                      obscureText: _obscureConfirm,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        color: isDark ? Colors.white : ServioColors.navyDark,
                      ),
                      decoration: _buildInputDecoration(
                        hint: 'Repeat new password',
                        obscure: _obscureConfirm,
                        onToggle: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // --- In-line mismatch error or self-reference check ---
                    if (_newCtrl.text.isNotEmpty &&
                        _confirmCtrl.text.isNotEmpty &&
                        _newCtrl.text != _confirmCtrl.text)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Text(
                          'Confirm Password must match the New Password.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: servio.danger,
                          ),
                        ),
                      ),
                    if (_newCtrl.text.isNotEmpty &&
                        _currentCtrl.text.isNotEmpty &&
                        _newCtrl.text == _currentCtrl.text)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Text(
                          'New Password cannot be identical to the Current Password.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: servio.danger,
                          ),
                        ),
                      ),

                    const SizedBox(height: 32),

                    // --- Action buttons with micro-tap scales ---
                    _SpringButton(
                      onPressed: _isFormValid ? _submit : null,
                      isLoading: _isSubmitting,
                      backgroundColor: isDark ? Colors.white : ServioColors.navyDark,
                      child: Text(
                        'Update Password',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? ServioColors.navyDark : Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SpringButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      backgroundColor: Colors.transparent,
                      borderColor: isDark ? servio.border : const Color.fromRGBO(26, 29, 35, 0.15),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : ServioColors.navyDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    required bool isDark,
  }) {
    final servio = context.servio;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        color: isDark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF9E9E9E),
      ),
      filled: true,
      fillColor: isDark ? servio.backgroundSoft : const Color(0xFFFBFBF9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ServioRadius.sm),
        borderSide: BorderSide(
          color: isDark ? servio.border : const Color.fromRGBO(26, 29, 35, 0.1),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ServioRadius.sm),
        borderSide: BorderSide(
          color: servio.accent,
          width: 1.5,
        ),
      ),
      suffixIcon: IconButton(
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            key: ValueKey<bool>(obscure),
            size: 20,
            color: isDark ? Colors.white54 : const Color(0xFF76777B),
          ),
        ),
        onPressed: onToggle,
      ),
    );
  }

  Widget _buildChecklistItem(String label, bool isMet) {
    final servio = context.servio;
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 200),
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: isMet ? Colors.green : servio.textSecondary,
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Icon(
              isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              key: ValueKey<bool>(isMet),
              size: 18,
              color: isMet ? Colors.green : servio.textSecondary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildStrengthIndicator(int metCount) {
    if (metCount == 0) return const SizedBox.shrink();

    final servio = context.servio;
    Color color;
    String strengthText;
    int segments;

    if (metCount <= 2) {
      color = servio.danger;
      strengthText = 'Weak';
      segments = 1;
    } else if (metCount <= 4) {
      color = servio.warning;
      strengthText = 'Medium';
      segments = 2;
    } else {
      color = Colors.green;
      strengthText = 'Strong';
      segments = 3;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Password strength: $strengthText',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: servio.textSecondary,
              ),
            ),
            Text(
              '${metCount * 20}%',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(3, (index) {
            final active = index < segments;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 4,
                margin: EdgeInsets.only(
                  right: index == 2 ? 0 : 6,
                ),
                decoration: BoxDecoration(
                  color: active ? color : servio.border.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _SpringButton extends StatefulWidget {
  const _SpringButton({
    required this.onPressed,
    required this.child,
    this.backgroundColor,
    this.borderColor,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool isLoading;

  @override
  State<_SpringButton> createState() => _SpringButtonState();
}

class _SpringButtonState extends State<_SpringButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: ServioMotion.fast,
      reverseDuration: ServioMotion.normal,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: ServioMotion.spring),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails _) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: isEnabled ? widget.onPressed : null,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedOpacity(
          duration: ServioMotion.fast,
          opacity: isEnabled ? 1.0 : 0.5,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              border: widget.borderColor != null
                  ? Border.all(color: widget.borderColor!)
                  : null,
              borderRadius: BorderRadius.circular(ServioRadius.sm),
            ),
            alignment: Alignment.center,
            child: widget.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : widget.child,
          ),
        ),
      ),
    );
  }
}
