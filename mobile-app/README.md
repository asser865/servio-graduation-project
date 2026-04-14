# SERVIO Mobile App

This folder contains a minimal Flutter scaffold for the SERVIO mobile design system.

## Included

- [servio_design_tokens.json](/c:/Users/Mostafa%20Abdelaal/servio-graduation-project/mobile-app/design/servio_design_tokens.json)
- [servio_tokens.dart](/c:/Users/Mostafa%20Abdelaal/servio-graduation-project/mobile-app/lib/src/design_system/servio_tokens.dart)
- [servio_theme.dart](/c:/Users/Mostafa%20Abdelaal/servio-graduation-project/mobile-app/lib/src/design_system/servio_theme.dart)
- [servio_theme_extension.dart](/c:/Users/Mostafa%20Abdelaal/servio-graduation-project/mobile-app/lib/src/design_system/servio_theme_extension.dart)
- [servio_primary_button.dart](/c:/Users/Mostafa%20Abdelaal/servio-graduation-project/mobile-app/lib/src/design_system/widgets/servio_primary_button.dart)
- [servio_card.dart](/c:/Users/Mostafa%20Abdelaal/servio-graduation-project/mobile-app/lib/src/design_system/widgets/servio_card.dart)
- [servio_status_chip.dart](/c:/Users/Mostafa%20Abdelaal/servio-graduation-project/mobile-app/lib/src/design_system/widgets/servio_status_chip.dart)
- [design_showcase_screen.dart](/c:/Users/Mostafa%20Abdelaal/servio-graduation-project/mobile-app/lib/src/features/design_showcase/design_showcase_screen.dart)

## Current scope

Implemented:

- light and dark `ThemeData`
- token constants aligned with the approved SERVIO palette
- 300ms theme animation
- app-level EN/AR locale support
- initial reusable widgets for button, card, section heading, and status chip

Not implemented yet:

- bundled Poppins and Inter font assets
- full RTL review for each layout
- shared bottom nav, bottom sheet, toast, and skeleton components
- real feature flows and routing

## Next steps

1. Add the Poppins and Inter assets to `pubspec.yaml`.
2. Build the remaining shared components from the design prompt.
3. Replace the showcase screen with the first real customer or onboarding flow.

## Run

From `mobile-app`:

```bash
flutter pub get
flutter run
```
