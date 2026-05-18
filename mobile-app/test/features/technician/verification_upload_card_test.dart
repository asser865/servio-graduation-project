import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:servio_mobile_app/src/design_system/servio_theme_extension.dart';
import 'package:servio_mobile_app/src/design_system/servio_tokens.dart';
import 'package:servio_mobile_app/src/features/technician/verification_upload_screen.dart';

ThemeData _theme() {
  return ThemeData(
    useMaterial3: true,
    extensions: const <ThemeExtension<dynamic>>[
      ServioThemeExtension(
        backgroundSoft: ServioColors.backgroundSoftLight,
        surfaceAlt: ServioColors.surfaceAltLight,
        surfaceRaised: ServioColors.surfaceLight,
        textSecondary: ServioColors.textSecondaryLight,
        border: ServioColors.borderLight,
        accent: ServioColors.accent,
        accentLight: ServioColors.accentLight,
        neutralWarm: ServioColors.neutralWarm,
        success: ServioColors.success,
        warning: ServioColors.warning,
        info: ServioColors.info,
        danger: ServioColors.danger,
      ),
    ],
  );
}

Widget _buildNarrowCard() {
  return MaterialApp(
    theme: _theme(),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 132,
          child: VerificationUploadCard(
            title: 'National ID - Front',
            requiredLabel: true,
            fileName: 'national_id_front.jpg',
            errorText: 'National ID front is required.',
            onTap: () {},
            onRemove: () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('uploaded filename stays inside narrow document card',
      (tester) async {
    await tester.pumpWidget(_buildNarrowCard());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('National ID - Front'), findsOneWidget);
    expect(find.text('national_id_front.jpg'), findsOneWidget);
  });
}
