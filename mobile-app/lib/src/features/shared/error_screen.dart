import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../customer/customer_home_screen.dart';

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({
    super.key,
    this.title = 'Page Not Found',
    this.body = 'The screen you requested could not be found.',
    this.code = '404',
  });

  final String title;
  final String body;
  final String code;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ServioSpacing.screenPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                code,
                textAlign: TextAlign.center,
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 80,
                  color: servio.accent.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(height: 10),
              Icon(Icons.error_outline_rounded, size: 48, color: servio.accent),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: servio.textSecondary),
              ),
              const SizedBox(height: 24),
              ServioPrimaryButton(
                label: 'Go Home',
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(builder: (_) => const CustomerHomeScreen()),
                    (Route<dynamic> route) => false,
                  );
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Try Again')),
            ],
          ),
        ),
      ),
    );
  }
}
