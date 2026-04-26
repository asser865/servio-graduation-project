import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/models/user_account.dart';
import 'core/services/storage_service.dart';
import 'core/state/app_state.dart';
import 'design_system/servio_theme.dart';
import 'design_system/servio_tokens.dart';
import 'features/auth/role_selection_screen.dart';
import 'features/customer/customer_dashboard_screen.dart';
import 'features/technician/technician_dashboard_screen.dart';

class ServioApp extends StatelessWidget {
  const ServioApp({required this.storage, super.key});

  final StorageService storage;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <ChangeNotifierProvider<ChangeNotifier>>[
        ChangeNotifierProvider<SessionProvider>(
          create: (_) => SessionProvider.load(storage),
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(storage),
        ),
        ChangeNotifierProvider<LocaleProvider>(
          create: (_) => LocaleProvider(storage),
        ),
        ChangeNotifierProvider<BookingsProvider>(
          create: (_) => BookingsProvider(storage),
        ),
        ChangeNotifierProvider<MessagesProvider>(
          create: (_) => MessagesProvider(),
        ),
      ],
      child: const _AppView(),
    );
  }
}

class _AppView extends StatelessWidget {
  const _AppView();

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeProvider>().mode;
    final locale = context.watch<LocaleProvider>().locale;

    return MaterialApp(
      title: 'SERVIO',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      themeAnimationCurve: ServioMotion.curve,
      themeAnimationDuration: ServioMotion.micro,
      theme: ServioTheme.light(),
      darkTheme: ServioTheme.dark(),
      locale: locale,
      supportedLocales: const <Locale>[
        Locale('en'),
        Locale('ar'),
      ],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _AuthGate(),
    );
  }
}

/// Shows the home screen for the logged-in user's role, or [RoleSelectionScreen].
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    if (!session.isLoggedIn) return const RoleSelectionScreen();
    return session.account!.role == UserRole.technician
        ? const TechnicianDashboardScreen()
        : const CustomerDashboardScreen();
  }
}
