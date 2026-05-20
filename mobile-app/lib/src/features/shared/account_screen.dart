import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../auth/auth_landing_screen.dart';

const String _deleteConfirmationWord = 'delete';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ServioCard(
              radius: ServioRadius.lg,
              child: Column(
                children: <Widget>[
                  _AccountTile(
                    label: 'Deactivate Account',
                    icon: Icons.pause_circle_outline_rounded,
                    description: 'Temporarily disable your account.',
                    onTap: () => _showDeactivateDialog(context),
                  ),
                  Divider(
                    height: 1,
                    color: servio.border.withValues(alpha: 0.5),
                  ),
                  _AccountTile(
                    label: 'Delete Account',
                    icon: Icons.delete_outline_rounded,
                    description:
                        'Permanently delete your account and all data.',
                    isDestructive: true,
                    onTap: () => _showDeleteDialog(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Deleting your account is permanent and cannot be undone. '
              'All bookings, reviews, and personal data will be removed.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: servio.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showDeactivateDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Deactivate Account'),
        content: const Text(
          'Your account will be temporarily deactivated. '
          'You can reactivate it by logging in again.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final session = ctx.read<SessionProvider>();
              await session.logout();
              if (ctx.mounted) {
                Navigator.of(ctx).pushAndRemoveUntil(
                  MaterialPageRoute<void>(
                      builder: (_) => const AuthLandingScreen()),
                  (Route<dynamic> _) => false,
                );
              }
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final TextEditingController _confirmationController = TextEditingController();
  bool _deleting = false;
  String? _deleteError;

  bool get _canDelete =>
      _confirmationController.text.toLowerCase() == _deleteConfirmationWord;

  bool get _hasInvalidConfirmation =>
      _confirmationController.text.isNotEmpty &&
      !_deleteConfirmationWord.startsWith(
        _confirmationController.text.toLowerCase(),
      );

  double get _confirmationProgress =>
      _confirmationController.text.length / _deleteConfirmationWord.length;

  @override
  void initState() {
    super.initState();
    _confirmationController.addListener(_handleConfirmationChanged);
  }

  @override
  void dispose() {
    _confirmationController
      ..removeListener(_handleConfirmationChanged)
      ..dispose();
    super.dispose();
  }

  void _handleConfirmationChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final horizontalInset = size.width < 360 ? 12.0 : 20.0;
    final dialogSurface =
        isDark ? servio.surfaceRaised : theme.colorScheme.surface;
    final dialogInputSurface =
        isDark ? theme.colorScheme.surface : servio.backgroundSoft;
    final dialogTextColor = theme.colorScheme.onSurface;
    final dialogSecondaryColor = servio.textSecondary;
    final dialogBorderColor = servio.border;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: dialogSurface,
            borderRadius: BorderRadius.circular(ServioRadius.xl),
            border: Border.all(
              color: servio.danger.withValues(alpha: isDark ? 0.55 : 0.35),
            ),
            boxShadow:
                isDark ? ServioShadows.elevatedDark : ServioShadows.elevated,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ServioRadius.xl),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    height: 3,
                    color: servio.danger,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 14, 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _DeleteDialogIcon(danger: servio.danger),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Delete Account',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: servio.danger,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'This will permanently delete your account '
                                  'and all associated data. This action '
                                  'cannot be undone.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: dialogSecondaryColor,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey<String>(
                            'delete-account-close-button',
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          color: dialogSecondaryColor,
                          tooltip: 'Close',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: dialogBorderColor.withValues(alpha: 0.85),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _DeleteWarning(danger: servio.danger),
                        const SizedBox(height: 18),
                        Text(
                          'TYPE DELETE TO CONFIRM',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: servio.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          key: const ValueKey<String>(
                            'delete-account-confirm-input',
                          ),
                          controller: _confirmationController,
                          autofocus: true,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.done,
                          inputFormatters: const <TextInputFormatter>[
                            _DeleteConfirmationFormatter(),
                          ],
                          onSubmitted: (_) => _deleteAccountIfConfirmed(),
                          cursorColor: servio.danger,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: dialogTextColor,
                          ),
                          decoration: InputDecoration(
                            hintText: 'DELETE',
                            hintStyle: theme.textTheme.bodyMedium?.copyWith(
                              color: dialogSecondaryColor,
                            ),
                            filled: true,
                            fillColor: dialogInputSurface,
                            enabledBorder: _confirmationInputBorder(
                              color: _hasInvalidConfirmation
                                  ? servio.danger
                                  : dialogBorderColor,
                            ),
                            focusedBorder: _confirmationInputBorder(
                              color: _hasInvalidConfirmation
                                  ? servio.danger
                                  : servio.accent,
                              width: 1.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _DeleteConfirmationMeter(
                          progress: _confirmationProgress,
                          danger: servio.danger,
                        ),
                        if (_deleteError != null) ...<Widget>[
                          const SizedBox(height: 12),
                          Text(
                            _deleteError!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: servio.danger,
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        LayoutBuilder(
                          builder: (BuildContext context,
                              BoxConstraints constraints) {
                            final stackActions = constraints.maxWidth < 330;
                            return Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 10,
                              runSpacing: 10,
                              children: <Widget>[
                                SizedBox(
                                  width: stackActions
                                      ? constraints.maxWidth
                                      : null,
                                  child: TextButton(
                                    key: const ValueKey<String>(
                                      'delete-account-cancel-button',
                                    ),
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    style: TextButton.styleFrom(
                                      foregroundColor: dialogTextColor,
                                    ),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                SizedBox(
                                  width: stackActions
                                      ? constraints.maxWidth
                                      : null,
                                  child: FilledButton(
                                    key: const ValueKey<String>(
                                      'delete-account-confirm-button',
                                    ),
                                    onPressed: _canDelete && !_deleting
                                        ? _deleteAccountIfConfirmed
                                        : null,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: servio.danger,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor:
                                          servio.danger.withValues(alpha: 0.45),
                                      disabledForegroundColor:
                                          Colors.white.withValues(alpha: 0.65),
                                      minimumSize: const Size(0, 48),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 13,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          ServioRadius.sm,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      _deleting
                                          ? 'Deleting...'
                                          : 'Delete My Account',
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
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

  OutlineInputBorder _confirmationInputBorder({
    required Color color,
    double width = 1,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(ServioRadius.sm),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  Future<void> _deleteAccountIfConfirmed() async {
    if (!_canDelete || _deleting) {
      return;
    }
    final session = context.read<SessionProvider?>();
    if (session == null) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _deleting = true;
      _deleteError = null;
    });
    final error = await session.deleteAccount();
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _deleting = false;
        _deleteError = error;
      });
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const AuthLandingScreen()),
      (Route<dynamic> _) => false,
    );
  }
}

class _DeleteConfirmationFormatter extends TextInputFormatter {
  const _DeleteConfirmationFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalizedValue = newValue.text.toLowerCase();
    final isAllowedPrefix = _deleteConfirmationWord.startsWith(normalizedValue);
    final isAllowedLength =
        newValue.text.length <= _deleteConfirmationWord.length;

    if (isAllowedPrefix && isAllowedLength) {
      return newValue;
    }
    return oldValue;
  }
}

class _DeleteDialogIcon extends StatelessWidget {
  const _DeleteDialogIcon({required this.danger});

  final Color danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ServioRadius.md),
      ),
      child: Icon(
        Icons.delete_outline_rounded,
        color: danger,
        size: 24,
      ),
    );
  }
}

class _DeleteWarning extends StatelessWidget {
  const _DeleteWarning({required this.danger});

  final Color danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ServioRadius.sm),
        border: Border.all(color: danger.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.warning_amber_rounded,
            color: danger,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You will lose all your bookings, earnings history, reviews, '
              'and profile data.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: danger,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteConfirmationMeter extends StatelessWidget {
  const _DeleteConfirmationMeter({
    required this.progress,
    required this.danger,
  });

  final double progress;
  final Color danger;

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
    final isConfirmed = clampedProgress == 1;

    return AnimatedContainer(
      duration: ServioMotion.fast,
      curve: ServioMotion.standard,
      height: 22,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: danger.withValues(alpha: isConfirmed ? 0.24 : 0.10),
        borderRadius: BorderRadius.circular(ServioRadius.full),
        border: Border.all(
          color: danger.withValues(alpha: isConfirmed ? 0.45 : 0.20),
        ),
      ),
      child: AnimatedFractionallySizedBox(
        duration: ServioMotion.fast,
        curve: ServioMotion.standard,
        widthFactor: clampedProgress,
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: danger.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(ServioRadius.full),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.label,
    required this.icon,
    required this.description,
    required this.onTap,
    this.isDestructive = false,
  });

  final String label;
  final IconData icon;
  final String description;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final color = isDestructive ? servio.danger : null;

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 22, color: color ?? servio.textSecondary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: servio.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: color ?? servio.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
