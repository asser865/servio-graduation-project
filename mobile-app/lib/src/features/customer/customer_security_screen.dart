import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import 'change_password_screen.dart';

class CustomerSecurityScreen extends StatelessWidget {
  const CustomerSecurityScreen({super.key});

  void _showPlaceholder(BuildContext context, String feature) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ServioRadius.md),
        ),
        title: Text(
          feature,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text('$feature is coming soon.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'OK',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                color: ServioColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSignOutConfirmation(BuildContext context) {
    final servio = context.servio;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: isDark ? servio.surfaceAlt : Colors.white,
          title: Text(
            'Sign Out of All Devices',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : ServioColors.navyDark,
            ),
          ),
          content: Text(
            'Are you sure you want to sign out of all devices? You will need to log back in to access your account.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              color: servio.textSecondary,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: servio.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await context.read<SessionProvider>().logout();
              },
              child: Text(
                'Sign Out',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: servio.danger,
                ),
              ),
            ),
          ],
        );
      },
    );
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
          'Security',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : ServioColors.navyDark,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: isDark ? servio.border : const Color.fromRGBO(26, 29, 35, 0.05),
            height: 1.0,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: ServioSpacing.screenPadding,
            vertical: 24,
          ),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Intro Header Section ---
                  Text(
                    'Security',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : ServioColors.navyDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage your credentials and monitor account access.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: servio.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Security Actions Grouped Card ---
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? servio.surfaceAlt : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? servio.border
                            : const Color.fromRGBO(26, 29, 35, 0.08),
                      ),
                      boxShadow: isDark ? ServioShadows.restDark : ServioShadows.rest,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SecuritySpringTile(
                            label: 'Change Password',
                            icon: Icons.lock_outline_rounded,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const ChangePasswordScreen(),
                              ),
                            ),
                            isDark: isDark,
                          ),
                          _buildDivider(isDark, servio.border),
                          _SecuritySpringTile(
                            label: 'Two-Factor Authentication',
                            icon: Icons.verified_user_outlined,
                            onTap: () => _showPlaceholder(
                                context, 'Two-Factor Authentication'),
                            isDark: isDark,
                          ),
                          _buildDivider(isDark, servio.border),
                          _SecuritySpringTile(
                            label: 'Enable SMS Authentication',
                            icon: Icons.sms_outlined,
                            onTap: () => _showPlaceholder(
                                context, 'SMS Authentication'),
                            isDark: isDark,
                          ),
                          _buildDivider(isDark, servio.border),
                          _SecuritySpringTile(
                            label: 'Login Activity',
                            icon: Icons.history_rounded,
                            onTap: () =>
                                _showPlaceholder(context, 'Login Activity'),
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // --- Logout Action Section ---
                  Center(
                    child: Column(
                      children: [
                        _SpringSignOutButton(
                          onPressed: () => _showSignOutConfirmation(context),
                          backgroundColor: isDark ? servio.surfaceAlt : Colors.white,
                          borderColor: servio.danger.withValues(alpha: 0.2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.logout_rounded,
                                size: 20,
                                color: servio.danger,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Sign Out of All Devices',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: servio.danger,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'For security, we recommend signing out of all devices if you suspect unauthorized access.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: servio.textSecondary,
                              height: 1.4,
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
      ),
    );
  }

  Widget _buildDivider(bool isDark, Color border) {
    return Container(
      color: isDark ? border : const Color.fromRGBO(26, 29, 35, 0.05),
      height: 1.0,
      margin: const EdgeInsets.only(left: 72, right: 16),
    );
  }
}

class _SecuritySpringTile extends StatefulWidget {
  const _SecuritySpringTile({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  @override
  State<_SecuritySpringTile> createState() => _SecuritySpringTileState();
}

class _SecuritySpringTileState extends State<_SecuritySpringTile>
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

  void _onTapDown(TapDownDetails _) => _controller.forward();
  void _onTapUp(TapUpDetails _) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Circular leading container for icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? servio.backgroundSoft
                        : const Color(0xFFF3EDE7),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    widget.icon,
                    size: 20,
                    color: widget.isDark ? Colors.white : ServioColors.navyDark,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark ? Colors.white : ServioColors.navyDark,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: servio.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpringSignOutButton extends StatefulWidget {
  const _SpringSignOutButton({
    required this.onPressed,
    required this.child,
    this.backgroundColor,
    this.borderColor,
  });

  final VoidCallback onPressed;
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  State<_SpringSignOutButton> createState() => _SpringSignOutButtonState();
}

class _SpringSignOutButtonState extends State<_SpringSignOutButton>
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

  void _onTapDown(TapDownDetails _) => _controller.forward();
  void _onTapUp(TapUpDetails _) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onPressed,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 48,
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            border: widget.borderColor != null
                ? Border.all(color: widget.borderColor!)
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );
  }
}
