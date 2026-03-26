import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'design_system/servio_theme.dart';
import 'design_system/servio_tokens.dart';
import 'features/onboarding/onboarding_screen.dart';

class ServioApp extends StatelessWidget {
  const ServioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SERVIO',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      themeAnimationCurve: ServioMotion.curve,
      themeAnimationDuration: ServioMotion.micro,
      theme: ServioTheme.light(),
      darkTheme: ServioTheme.dark(),
      supportedLocales: const <Locale>[
        Locale('en'),
        Locale('ar'),
      ],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const OnboardingScreen(),
    );
  }
}
