import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';

/// Saved Payments screen — displays stored payment methods.
///
/// Currently renders a polished empty-state with a placeholder
/// "Add payment method" button. Wire up a real payment API when
/// the backend endpoint is available.
class SavedPaymentsScreen extends StatefulWidget {
  const SavedPaymentsScreen({super.key});

  @override
  State<SavedPaymentsScreen> createState() => _SavedPaymentsScreenState();
}

class _SavedPaymentsScreenState extends State<SavedPaymentsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: ServioMotion.page,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.6, curve: ServioMotion.spring),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.1, 0.7, curve: ServioMotion.spring),
      ),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Payments'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Padding(
            padding: const EdgeInsets.all(ServioSpacing.screenPadding),
            child: Column(
              children: <Widget>[
                const SizedBox(height: 48),
                // ── Empty-state card ─────────────────────────────────
                ServioCard(
                  radius: ServioRadius.lg,
                  padding: const EdgeInsets.symmetric(
                    horizontal: ServioSpacing.cardPadding,
                    vertical: 36,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Icon container
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: servio.accent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(ServioRadius.xl),
                        ),
                        child: Icon(
                          Icons.credit_card_rounded,
                          size: 34,
                          color: servio.accent,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No saved payment methods yet',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 260,
                        child: Text(
                          'Your saved cards and payment options will appear here.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: servio.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Placeholder CTA — disabled until backend integration
                      _AddPaymentButton(servio: servio),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Info hint ───────────────────────────────────────
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 16,
                      color: servio.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your payment information is encrypted and secure.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: servio.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Add payment CTA (placeholder) ─────────────────────────────────────────────

class _AddPaymentButton extends StatelessWidget {
  const _AddPaymentButton({required this.servio});

  final ServioThemeExtension servio;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ServioRadius.full),
        // TODO(payments): Navigate to add-payment flow when API is available.
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Payment integration coming soon.'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ServioRadius.sm),
              ),
            ),
          );
        },
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ServioRadius.full),
            border: Border.all(
              color: servio.accent.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.add_rounded,
                size: 20,
                color: servio.accent,
              ),
              const SizedBox(width: 8),
              Text(
                'Add payment method',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: servio.accent,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
