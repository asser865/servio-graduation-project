import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/api/ai_api.dart';
import 'core/api/api_client.dart';
import 'core/api/bookings_api.dart';
import 'core/api/messages_api.dart';
import 'core/api/token_storage.dart';
import 'core/api/users_api.dart';
import 'core/services/storage_service.dart';
import 'core/state/app_state.dart';
import 'core/state/customer_addresses_state.dart';
import 'core/state/room_finishing_provider.dart';
import 'core/state/services_state.dart';
import 'core/state/notifications_provider.dart';
import 'core/state/workers_state.dart';
import 'design_system/servio_theme.dart';
import 'design_system/servio_tokens.dart';
import 'features/onboarding/splash_screen.dart';

class ServioApp extends StatelessWidget {
  const ServioApp({required this.storage, super.key});

  final StorageService storage;

  @override
  Widget build(BuildContext context) {
    final tokenStorage = FlutterSecureTokenStorage(legacyStorage: storage);

    return MultiProvider(
      providers: [
        Provider<TokenStorage>.value(value: tokenStorage),
        Provider<ApiClient>(
          create: (_) => ApiClient(tokenStorage: tokenStorage),
        ),
        ChangeNotifierProvider<SessionProvider>(
          create: (ctx) => SessionProvider.load(
            storage,
            ctx.read<ApiClient>(),
            tokenStorage: ctx.read<TokenStorage>(),
          ),
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(storage),
        ),
        ChangeNotifierProvider<LocaleProvider>(
          create: (_) => LocaleProvider(storage),
        ),
        ChangeNotifierProvider<BookingsProvider>(
          create: (ctx) => BookingsProvider(
            storage,
            BookingsApi(ctx.read<ApiClient>()),
          ),
        ),
        ChangeNotifierProvider<CustomerAddressesProvider>(
          create: (ctx) => CustomerAddressesProvider(
            UsersApi(ctx.read<ApiClient>()),
          ),
        ),
        ChangeNotifierProvider<MessagesProvider>(
          create: (ctx) => MessagesProvider(
            MessagesApi(ctx.read<ApiClient>()),
          ),
        ),
        ChangeNotifierProvider<ServicesProvider>(
          create: (ctx) => ServicesProvider(ctx.read<ApiClient>()),
        ),
        ChangeNotifierProvider<WorkersProvider>(
          create: (ctx) => WorkersProvider(ctx.read<ApiClient>()),
        ),
        ChangeNotifierProvider<NotificationsProvider>(
          create: (ctx) => NotificationsProvider(
            storage,
            ctx.read<ApiClient>(),
          ),
        ),
        ChangeNotifierProvider<RoomFinishingProvider>(
          create: (ctx) => RoomFinishingProvider(AiApi(ctx.read<ApiClient>())),
        ),
      ],
      child: const _AppView(),
    );
  }
}

class _AppView extends StatefulWidget {
  const _AppView();

  @override
  State<_AppView> createState() => _AppViewState();
}

class _AppViewState extends State<_AppView> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        context.read<NotificationsProvider>().refresh();
      }
    }
  }

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
      home: const SplashScreen(),
    );
  }
}
