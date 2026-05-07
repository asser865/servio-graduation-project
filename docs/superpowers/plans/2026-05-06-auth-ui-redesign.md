# Auth UI Dark Immersion Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign five Flutter auth screens (landing, role selection, login, sign-up basic info, sign-up OTP) to a dark-immersion style with full light/dark mode support, with zero changes to business logic.

**Architecture:** Two shared widgets (`AuthBackground`, `AuthCard`) are created first and consumed by all five screens. Dark mode: full-screen deep-brown→navy gradient. Light mode: same brand gradient anchors the top header, warm cream body below. All existing animations, state management, and provider calls are preserved exactly as-is.

**Tech Stack:** Flutter 3.x · Dart · Material 3 · `provider` · existing `ServioTokens` / `ServioTheme` design system.

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `mobile-app/lib/src/features/auth/widgets/auth_background.dart` | Full-screen background — dark gradient (dark) or gradient header + cream (light) |
| Create | `mobile-app/lib/src/features/auth/widgets/auth_card.dart` | Mode-aware card — glass (dark) or white elevated (light) |
| Modify | `mobile-app/lib/src/features/auth/auth_landing_screen.dart` | Add trust pills, use `AuthBackground` |
| Modify | `mobile-app/lib/src/features/auth/role_selection_screen.dart` | Use `AuthBackground`, new dark glass role cards |
| Modify | `mobile-app/lib/src/features/auth/login_screen.dart` | Use `AuthBackground` + `AuthCard` |
| Modify | `mobile-app/lib/src/features/auth/sign_up_screen.dart` | `AuthBackground` + `AuthCard` for steps 0–1 only |
| Create | `mobile-app/test/features/auth/widgets/auth_background_test.dart` | Widget tests |
| Create | `mobile-app/test/features/auth/widgets/auth_card_test.dart` | Widget tests |
| Create | `mobile-app/test/features/auth/auth_landing_screen_test.dart` | Smoke tests |
| Create | `mobile-app/test/features/auth/role_selection_screen_test.dart` | Smoke tests |
| Create | `mobile-app/test/features/auth/login_screen_redesign_test.dart` | Smoke tests |
| Create | `mobile-app/test/features/auth/sign_up_redesign_test.dart` | Smoke tests |

---

### Task 1: Create `AuthBackground` widget

**Files:**
- Create: `mobile-app/lib/src/features/auth/widgets/auth_background.dart`
- Create: `mobile-app/test/features/auth/widgets/auth_background_test.dart`

- [ ] **Step 1: Write the failing test**

Create `mobile-app/test/features/auth/widgets/auth_background_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servio/src/features/auth/widgets/auth_background.dart';

void main() {
  group('AuthBackground', () {
    testWidgets('full dark gradient covers screen in dark mode', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          body: Stack(children: const [
            Positioned.fill(child: AuthBackground()),
            Center(child: Text('content')),
          ]),
        ),
      ));
      expect(find.byType(AuthBackground), findsOneWidget);
      // No cream ColoredBox in dark mode
      expect(
        find.byWidgetPredicate(
            (w) => w is ColoredBox && w.color == const Color(0xFFFAF8F5)),
        findsNothing,
      );
    });

    testWidgets('cream body + gradient header in light mode', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.light),
        home: Scaffold(
          body: Stack(children: const [
            Positioned.fill(child: AuthBackground(lightHeaderHeight: 200)),
            Center(child: Text('content')),
          ]),
        ),
      ));
      expect(find.byType(AuthBackground), findsOneWidget);
      expect(
        find.byWidgetPredicate(
            (w) => w is ColoredBox && w.color == const Color(0xFFFAF8F5)),
        findsOneWidget,
      );
    });
  });
}
```

- [ ] **Step 2: Run — confirm FAIL**

```bash
cd mobile-app
flutter test test/features/auth/widgets/auth_background_test.dart
```

Expected: FAIL — `AuthBackground` not found.

- [ ] **Step 3: Create `mobile-app/lib/src/features/auth/widgets/auth_background.dart`**

```dart
import 'package:flutter/material.dart';
import '../../../design_system/servio_tokens.dart';

/// Full-screen background for auth screens.
///
/// Dark mode: deep brown→navy gradient fills the entire screen.
/// Light mode: brand gradient anchors the top [lightHeaderHeight] px,
/// then warm cream below it with a 22 px rounded cutout.
///
/// Place as `Positioned.fill` as the first child of the screen's Stack:
/// ```dart
/// Positioned.fill(child: AuthBackground(lightHeaderHeight: 210))
/// ```
class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key, this.lightHeaderHeight = 240.0});

  final double lightHeaderHeight;

  static const _kDarkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3C2415), Color(0xFF222831), Color(0xFF1E2633)],
    stops: [0.0, 0.5, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark) {
      return const DecoratedBox(
        decoration: BoxDecoration(gradient: _kDarkGradient),
        child: SizedBox.expand(),
      );
    }

    final topPad = MediaQuery.of(context).padding.top;
    final headerEnd = topPad + lightHeaderHeight;

    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Color(0xFFFAF8F5))),
        Positioned(
          top: 0, left: 0, right: 0, height: headerEnd,
          child: const DecoratedBox(
              decoration: BoxDecoration(gradient: ServioGradients.brand)),
        ),
        Positioned(
          top: headerEnd - 22, left: 0, right: 0, height: 24,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFFFAF8F5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run — confirm PASS**

```bash
flutter test test/features/auth/widgets/auth_background_test.dart
```

Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add mobile-app/lib/src/features/auth/widgets/auth_background.dart \
        mobile-app/test/features/auth/widgets/auth_background_test.dart
git commit -m "feat: add AuthBackground widget for auth dark immersion"
```

---

### Task 2: Create `AuthCard` widget

**Files:**
- Create: `mobile-app/lib/src/features/auth/widgets/auth_card.dart`
- Create: `mobile-app/test/features/auth/widgets/auth_card_test.dart`

- [ ] **Step 1: Write the failing test**

Create `mobile-app/test/features/auth/widgets/auth_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servio/src/features/auth/widgets/auth_card.dart';

void main() {
  group('AuthCard', () {
    testWidgets('glass surface in dark mode — low opacity fill, no shadow',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: const Scaffold(body: AuthCard(child: Text('hi'))),
      ));
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
                of: find.byType(AuthCard), matching: find.byType(DecoratedBox))
            .first,
      );
      final deco = box.decoration as BoxDecoration;
      expect(deco.color!.alpha, lessThan(40)); // ≈ 0.07–0.15 opacity
      expect(deco.boxShadow, isNullOrEmpty);
    });

    testWidgets('white elevated card in light mode — opaque white, has shadow',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.light),
        home: const Scaffold(body: AuthCard(child: Text('hi'))),
      ));
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
                of: find.byType(AuthCard), matching: find.byType(DecoratedBox))
            .first,
      );
      final deco = box.decoration as BoxDecoration;
      expect(deco.color, equals(Colors.white));
      expect(deco.boxShadow, isNotEmpty);
    });
  });
}
```

- [ ] **Step 2: Run — confirm FAIL**

```bash
flutter test test/features/auth/widgets/auth_card_test.dart
```

Expected: FAIL — `AuthCard` not found.

- [ ] **Step 3: Create `mobile-app/lib/src/features/auth/widgets/auth_card.dart`**

```dart
import 'package:flutter/material.dart';
import '../../../design_system/servio_tokens.dart';

/// Mode-aware form card for auth screens.
///
/// Dark mode: frosted glass — rgba(255,255,255,0.07) fill.
/// Light mode: white elevated card with soft shadow.
class AuthCard extends StatelessWidget {
  const AuthCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0x12FFFFFF) : Colors.white,
        border: Border.all(
          color: isDark ? const Color(0x1CFFFFFF) : ServioColors.borderLight,
        ),
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        boxShadow: isDark ? null : ServioShadows.elevated,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
```

- [ ] **Step 4: Run — confirm PASS**

```bash
flutter test test/features/auth/widgets/auth_card_test.dart
```

Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add mobile-app/lib/src/features/auth/widgets/auth_card.dart \
        mobile-app/test/features/auth/widgets/auth_card_test.dart
git commit -m "feat: add AuthCard widget for auth dark/light form surface"
```

---

### Task 3: Redesign `auth_landing_screen.dart`

**Files:**
- Modify: `mobile-app/lib/src/features/auth/auth_landing_screen.dart`
- Create: `mobile-app/test/features/auth/auth_landing_screen_test.dart`

- [ ] **Step 1: Write the failing test**

Create `mobile-app/test/features/auth/auth_landing_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servio/src/features/auth/auth_landing_screen.dart';
import 'package:servio/src/features/auth/widgets/auth_background.dart';

Widget _build({Brightness brightness = Brightness.dark}) => MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: const AuthLandingScreen(),
    );

void main() {
  group('AuthLandingScreen', () {
    testWidgets('shows SERVIO brand text', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.text('SERVIO'), findsOneWidget);
    });

    testWidgets('shows both action buttons', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('shows trust pills', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.text('Verified professionals'), findsOneWidget);
      expect(find.text('Top-rated every time'), findsOneWidget);
    });

    testWidgets('uses AuthBackground', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.byType(AuthBackground), findsOneWidget);
    });

    testWidgets('uses AuthBackground in light mode too', (tester) async {
      await tester.pumpWidget(_build(brightness: Brightness.light));
      await tester.pumpAndSettle();
      expect(find.byType(AuthBackground), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run — confirm FAIL on trust pills + AuthBackground**

```bash
flutter test test/features/auth/auth_landing_screen_test.dart
```

Expected: FAIL on "trust pills" and "uses AuthBackground" tests.

- [ ] **Step 3: Rewrite `auth_landing_screen.dart`**

Replace the entire file with:

```dart
import 'package:flutter/material.dart';

import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import 'login_screen.dart';
import 'role_selection_screen.dart';
import 'widgets/auth_background.dart';

class AuthLandingScreen extends StatefulWidget {
  const AuthLandingScreen({super.key});

  @override
  State<AuthLandingScreen> createState() => _AuthLandingScreenState();
}

class _AuthLandingScreenState extends State<AuthLandingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: ServioMotion.page,
    )..forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1E2633) : ServioColors.backgroundLight,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: AuthBackground(lightHeaderHeight: 260),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: ServioSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 48),

                  // ── Brand ──────────────────────────────────────
                  _BrandMark(controller: _entranceController),

                  const SizedBox(height: 36),

                  // ── Trust pills ────────────────────────────────
                  _TrustPill(
                    controller: _entranceController,
                    intervalStart: 0.25,
                    icon: Icons.shield_outlined,
                    label: 'Verified professionals',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _TrustPill(
                    controller: _entranceController,
                    intervalStart: 0.35,
                    icon: Icons.star_outline_rounded,
                    label: 'Top-rated every time',
                    isDark: isDark,
                  ),

                  const Spacer(),

                  // ── CTAs ───────────────────────────────────────
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _entranceController,
                      curve: const Interval(0.4, 0.9,
                          curve: ServioMotion.spring),
                    )),
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _entranceController,
                        curve: const Interval(0.4, 0.8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          ServioPrimaryButton(
                            label: 'Sign In',
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => const LoginScreen()),
                            ),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => const RoleSelectionScreen()),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.22)
                                    : ServioColors.deepBrown,
                                width: 1.5,
                              ),
                              foregroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.75)
                                  : ServioColors.deepBrown,
                            ),
                            child: const Text('Create Account'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
          .animate(CurvedAnimation(
              parent: controller,
              curve:
                  const Interval(0.0, 0.5, curve: ServioMotion.spring))),
      child: FadeTransition(
        opacity: CurvedAnimation(
            parent: controller, curve: const Interval(0.0, 0.4)),
        child: Column(
          children: <Widget>[
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18), width: 1.5),
              ),
              child: const Icon(Icons.person_outline_rounded,
                  size: 26, color: Colors.white),
            ),
            const SizedBox(height: 14),
            Text(
              'SERVIO',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3.5,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'PREMIUM HOME SERVICES',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.45),
                    letterSpacing: 2.0,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _TrustPill extends StatelessWidget {
  const _TrustPill({
    required this.controller,
    required this.intervalStart,
    required this.icon,
    required this.label,
    required this.isDark,
  });
  final AnimationController controller;
  final double intervalStart;
  final IconData icon;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(
          parent: controller,
          curve: Interval(intervalStart, intervalStart + 0.3)),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.92),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.09)
                : ServioColors.borderLight,
          ),
          borderRadius: BorderRadius.circular(ServioRadius.md),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isDark
                    ? ServioColors.accentLight.withValues(alpha: 0.18)
                    : ServioColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon,
                  size: 14,
                  color: isDark
                      ? ServioColors.accentLight
                      : ServioColors.accent),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.70)
                        : ServioColors.textPrimaryLight,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run — confirm PASS**

```bash
flutter test test/features/auth/auth_landing_screen_test.dart
```

Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add mobile-app/lib/src/features/auth/auth_landing_screen.dart \
        mobile-app/test/features/auth/auth_landing_screen_test.dart
git commit -m "feat: redesign auth landing — dark immersion + trust pills"
```

---

### Task 4: Redesign `role_selection_screen.dart`

**Files:**
- Modify: `mobile-app/lib/src/features/auth/role_selection_screen.dart`
- Create: `mobile-app/test/features/auth/role_selection_screen_test.dart`

- [ ] **Step 1: Write the failing test**

Create `mobile-app/test/features/auth/role_selection_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servio/src/features/auth/role_selection_screen.dart';
import 'package:servio/src/features/auth/widgets/auth_background.dart';

Widget _build({Brightness brightness = Brightness.dark}) => MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: const RoleSelectionScreen(),
    );

void main() {
  group('RoleSelectionScreen', () {
    testWidgets('shows role question heading', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.textContaining('How will you'), findsOneWidget);
    });

    testWidgets('shows both role options', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.text('I need a service'), findsOneWidget);
      expect(find.text("I'm a technician"), findsOneWidget);
    });

    testWidgets('Continue button disabled until role selected', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      final btn = tester.widget<ElevatedButton>(find.ancestor(
          of: find.text('Continue'), matching: find.byType(ElevatedButton)));
      expect(btn.onPressed, isNull);
    });

    testWidgets('tapping a role card enables Continue', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      await tester.tap(find.text('I need a service'));
      await tester.pump();
      final btn = tester.widget<ElevatedButton>(find.ancestor(
          of: find.text('Continue'), matching: find.byType(ElevatedButton)));
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('uses AuthBackground', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.byType(AuthBackground), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run — confirm FAIL on AuthBackground test**

```bash
flutter test test/features/auth/role_selection_screen_test.dart
```

Expected: FAIL on "uses AuthBackground".

- [ ] **Step 3: Rewrite `role_selection_screen.dart`**

Replace the entire file with:

```dart
import 'package:flutter/material.dart';

import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import 'auth_role.dart';
import 'sign_up_screen.dart';
import 'widgets/auth_background.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  AuthRole? _selectedRole;
  late final AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: ServioMotion.page,
    )..forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  void _continue() {
    if (_selectedRole == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => SignUpScreen(role: _selectedRole!)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1E2633) : ServioColors.backgroundLight,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: AuthBackground(lightHeaderHeight: 210),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: ServioSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 16),

                  // ── Back button ──────────────────────────────
                  _AuthBackButton(onTap: () => Navigator.of(context).pop()),

                  const SizedBox(height: 20),

                  // ── Heading ──────────────────────────────────
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.25),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _entranceController,
                      curve: const Interval(0.0, 0.55,
                          curve: ServioMotion.spring),
                    )),
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                          parent: _entranceController,
                          curve: const Interval(0.0, 0.45)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'How will you\nuse SERVIO?',
                            style: theme.textTheme.headlineLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Choose your role to get started.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Role cards ───────────────────────────────
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _entranceController,
                      curve: const Interval(0.2, 0.75,
                          curve: ServioMotion.spring),
                    )),
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                          parent: _entranceController,
                          curve: const Interval(0.2, 0.65)),
                      child: Column(
                        children: <Widget>[
                          _RoleCard(
                            icon: Icons.home_repair_service_rounded,
                            title: 'I need a service',
                            subtitle: 'Book trusted home professionals',
                            isSelected: _selectedRole == AuthRole.customer,
                            isDark: isDark,
                            onTap: () => setState(
                                () => _selectedRole = AuthRole.customer),
                          ),
                          const SizedBox(height: 14),
                          _RoleCard(
                            icon: Icons.handyman_rounded,
                            title: "I'm a technician",
                            subtitle: 'Offer your skills and earn',
                            isSelected: _selectedRole == AuthRole.technician,
                            isDark: isDark,
                            onTap: () => setState(
                                () => _selectedRole = AuthRole.technician),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  AnimatedOpacity(
                    opacity: _selectedRole == null ? 0.45 : 1.0,
                    duration: ServioMotion.micro,
                    child: ServioPrimaryButton(
                      label: 'Continue',
                      onPressed: _selectedRole == null ? null : _continue,
                    ),
                  ),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared frosted back button (used by role selection + can be reused)
// ─────────────────────────────────────────────────────────────────────────────

class _AuthBackButton extends StatelessWidget {
  const _AuthBackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: ServioSpacing.tapTarget,
        height: ServioSpacing.tapTarget,
        alignment: Alignment.center,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.15), width: 1),
          ),
          child: const Icon(Icons.arrow_back_rounded,
              size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Role selection card
// ─────────────────────────────────────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = isDark
        ? (isSelected
            ? ServioColors.accentLight.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.06))
        : (isSelected
            ? ServioColors.accent.withValues(alpha: 0.07)
            : Colors.white);
    final borderColor = isDark
        ? (isSelected
            ? ServioColors.accentLight.withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.10))
        : (isSelected ? ServioColors.accent : ServioColors.borderLight);
    final titleColor = isDark
        ? Colors.white.withValues(alpha: isSelected ? 0.95 : 0.75)
        : (isSelected ? ServioColors.deepBrown : ServioColors.textPrimaryLight);
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.40)
        : ServioColors.textSecondaryLight;
    final checkColor =
        isDark ? ServioColors.accentLight : ServioColors.accent;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: ServioMotion.micro,
        curve: ServioMotion.spring,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(ServioRadius.lg),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark
                    ? ServioColors.accentLight.withValues(alpha: 0.18)
                    : ServioColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  size: 22,
                  color:
                      isDark ? ServioColors.accentLight : ServioColors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title,
                      style: theme.textTheme.titleSmall?.copyWith(
                          color: titleColor, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: subtitleColor)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: ServioMotion.micro,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? checkColor.withValues(alpha: 0.18)
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? checkColor
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.20)
                          : ServioColors.borderLight),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? Icon(Icons.check_rounded, size: 12, color: checkColor)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run — confirm PASS**

```bash
flutter test test/features/auth/role_selection_screen_test.dart
```

Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add mobile-app/lib/src/features/auth/role_selection_screen.dart \
        mobile-app/test/features/auth/role_selection_screen_test.dart
git commit -m "feat: redesign role selection screen — dark immersion + glass role cards"
```

---

### Task 5: Redesign `login_screen.dart`

**Files:**
- Modify: `mobile-app/lib/src/features/auth/login_screen.dart`
- Create: `mobile-app/test/features/auth/login_screen_redesign_test.dart`

- [ ] **Step 1: Write the failing test**

Create `mobile-app/test/features/auth/login_screen_redesign_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servio/src/core/state/app_state.dart';
import 'package:servio/src/features/auth/login_screen.dart';
import 'package:servio/src/features/auth/widgets/auth_background.dart';
import 'package:servio/src/features/auth/widgets/auth_card.dart';

Widget _build({Brightness brightness = Brightness.dark}) =>
    ChangeNotifierProvider<SessionProvider>(
      create: (_) => SessionProvider(),
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: const LoginScreen(),
      ),
    );

void main() {
  group('LoginScreen redesign', () {
    testWidgets('shows Welcome back heading', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.textContaining('Welcome back'), findsOneWidget);
    });

    testWidgets('uses AuthBackground', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.byType(AuthBackground), findsOneWidget);
    });

    testWidgets('uses AuthCard for form', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.byType(AuthCard), findsOneWidget);
    });

    testWidgets('has email and password fields', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Email address'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
    });

    testWidgets('has Log In button', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.text('Log In'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run — confirm FAIL on AuthBackground + AuthCard**

```bash
flutter test test/features/auth/login_screen_redesign_test.dart
```

Expected: FAIL on "uses AuthBackground" and "uses AuthCard".

- [ ] **Step 3: Modify `login_screen.dart`**

**3a. Add imports** (after existing imports):

```dart
import 'widgets/auth_background.dart';
import 'widgets/auth_card.dart';
```

**3b. In `build()`, add `isDark` and remove `onGradient`:**

Remove:
```dart
final onGradient = isDark ? ServioColors.navyDark : Colors.white;
```

**3c. Replace `Scaffold` + the `Positioned` gradient block:**

Old:
```dart
return Scaffold(
  body: Stack(
    children: <Widget>[
      // ── Gradient header ───────────────────────────────────
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: MediaQuery.of(context).padding.top + 280,
        child: Container(
          decoration: BoxDecoration(
            gradient:
                isDark ? ServioGradients.brandDark : ServioGradients.brand,
          ),
        ),
      ),
```

New:
```dart
return Scaffold(
  backgroundColor:
      isDark ? const Color(0xFF1E2633) : ServioColors.backgroundLight,
  body: Stack(
    children: <Widget>[
      const Positioned.fill(
        child: AuthBackground(lightHeaderHeight: 210),
      ),
```

**3d. Update back button container colour:**

Old:
```dart
color: Colors.white.withValues(alpha: 0.15),
```

New:
```dart
color: Colors.white.withValues(alpha: 0.10),
```

**3e. Update brand icon — always white (remove `onGradient`):**

Old:
```dart
color: onGradient,
```
(the `Icon` inside the brand circle)

New:
```dart
color: Colors.white,
```

**3f. Update heading `displayLarge` text colour:**

Old:
```dart
style: theme.textTheme.displayLarge?.copyWith(
  color: onGradient,
  height: 1.1,
),
```

New:
```dart
style: theme.textTheme.displayLarge?.copyWith(
  color: Colors.white,
  fontWeight: FontWeight.w900,
  height: 1.1,
),
```

**3g. Update subtitle colour:**

Old:
```dart
color: onGradient.withValues(alpha: 0.7),
```

New:
```dart
color: Colors.white.withValues(alpha: 0.45),
```

**3h. Replace `ServioCard` with `AuthCard`:**

Old:
```dart
child: ServioCard(
  elevated: true,
  radius: ServioRadius.xl,
  padding: const EdgeInsets.all(24),
  child: Column(
```

New:
```dart
child: AuthCard(
  padding: const EdgeInsets.all(20),
  child: Column(
```

**3i. Update section label colour:**

Old:
```dart
color: servio.textSecondary,
```
(inside the `'YOUR CREDENTIALS'` Text)

New:
```dart
color: isDark
    ? ServioColors.accentLight.withValues(alpha: 0.65)
    : ServioColors.accent,
```

**3j. Update divider colours** (there are two — under section label and in "or continue with" row). Replace both:

Old:
```dart
Divider(color: servio.border),
```
and
```dart
Expanded(child: Divider(color: servio.border)),
```

New:
```dart
Divider(
  color: isDark
      ? Colors.white.withValues(alpha: 0.10)
      : ServioColors.borderLight,
),
```
and:
```dart
Expanded(
  child: Divider(
    color: isDark
        ? Colors.white.withValues(alpha: 0.10)
        : ServioColors.borderLight,
  ),
),
```

**3k. Add `style` override to both social buttons** (Google + Apple):

For each `OutlinedButton.icon` in the social row, add:
```dart
style: isDark
    ? OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0x1CFFFFFF)),
        backgroundColor: const Color(0x0DFFFFFF),
        foregroundColor: Colors.white.withValues(alpha: 0.60),
      )
    : null,
```

**3l. Update "New to SERVIO?" text colour:**

Old:
```dart
style: theme.textTheme.bodySmall
    ?.copyWith(color: servio.textSecondary),
```

New:
```dart
style: theme.textTheme.bodySmall?.copyWith(
  color: isDark
      ? Colors.white.withValues(alpha: 0.35)
      : ServioColors.textSecondaryLight,
),
```

- [ ] **Step 4: Run — confirm PASS**

```bash
flutter test test/features/auth/login_screen_redesign_test.dart
```

Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add mobile-app/lib/src/features/auth/login_screen.dart \
        mobile-app/test/features/auth/login_screen_redesign_test.dart
git commit -m "feat: redesign login screen — dark immersion with AuthBackground + AuthCard"
```

---

### Task 6: Redesign `sign_up_screen.dart` — Steps 0 & 1

**Files:**
- Modify: `mobile-app/lib/src/features/auth/sign_up_screen.dart`
- Create: `mobile-app/test/features/auth/sign_up_redesign_test.dart`

> **Context:** The sign-up screen uses a single `Scaffold` + `Stack` for all 7 steps. All step content lives inside one `ServioCard`. Steps 0–1 get the dark-immersion treatment; steps 2+ keep the existing light gradient header + cream card.

- [ ] **Step 1: Write the failing test**

Create `mobile-app/test/features/auth/sign_up_redesign_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servio/src/core/state/app_state.dart';
import 'package:servio/src/features/auth/auth_role.dart';
import 'package:servio/src/features/auth/sign_up_screen.dart';
import 'package:servio/src/features/auth/widgets/auth_background.dart';
import 'package:servio/src/features/auth/widgets/auth_card.dart';

Widget _build({AuthRole role = AuthRole.customer,
    Brightness brightness = Brightness.dark}) =>
    ChangeNotifierProvider<SessionProvider>(
      create: (_) => SessionProvider(),
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: SignUpScreen(role: role),
      ),
    );

void main() {
  group('SignUpScreen step 0 redesign', () {
    testWidgets('uses AuthBackground on step 0 (dark)', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.byType(AuthBackground), findsOneWidget);
    });

    testWidgets('uses AuthBackground on step 0 (light)', (tester) async {
      await tester.pumpWidget(_build(brightness: Brightness.light));
      await tester.pumpAndSettle();
      expect(find.byType(AuthBackground), findsOneWidget);
    });

    testWidgets('uses AuthCard for form on step 0', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.byType(AuthCard), findsOneWidget);
    });

    testWidgets('shows 4 text fields on step 0', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsAtLeastNWidgets(4));
    });
  });
}
```

- [ ] **Step 2: Run — confirm FAIL**

```bash
flutter test test/features/auth/sign_up_redesign_test.dart
```

Expected: FAIL on AuthBackground + AuthCard tests.

- [ ] **Step 3: Add imports to `sign_up_screen.dart`**

At the top of the file, add:

```dart
import 'widgets/auth_background.dart';
import 'widgets/auth_card.dart';
```

- [ ] **Step 4: Replace the `Positioned` gradient block with a conditional background**

In `build()`, locate (around line 270):

```dart
// ── Gradient header ───────────────────────────────────
Positioned(
  top: 0,
  left: 0,
  right: 0,
  height: MediaQuery.of(context).padding.top + 200,
  child: Container(
    decoration: BoxDecoration(
      gradient:
          isDark ? ServioGradients.brandDark : ServioGradients.brand,
    ),
  ),
),
```

Replace with:

```dart
// ── Background — dark immersion for steps 0–1, gradient header for 2+ ──
if (_step <= 1)
  const Positioned.fill(
    child: AuthBackground(lightHeaderHeight: 200),
  ),
if (_step > 1)
  Positioned(
    top: 0,
    left: 0,
    right: 0,
    height: MediaQuery.of(context).padding.top + 200,
    child: Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? ServioGradients.brandDark
            : ServioGradients.brand,
      ),
    ),
  ),
```

- [ ] **Step 5: Update `Scaffold.backgroundColor`**

Old:
```dart
return Scaffold(
  body: Stack(
```

New:
```dart
return Scaffold(
  backgroundColor: (_step <= 1 && isDark)
      ? const Color(0xFF1E2633)
      : (isDark ? ServioColors.backgroundDark : ServioColors.backgroundLight),
  body: Stack(
```

- [ ] **Step 6: Update back-button icon colour for steps 0–1**

Locate the back button inside the top bar row (around line 305):

```dart
child: Icon(
  Icons.arrow_back_rounded,
  color: isDark
      ? ServioColors.navyDark
      : Colors.white,
  size: 20,
),
```

Replace with:

```dart
child: Icon(
  Icons.arrow_back_rounded,
  color: Colors.white,
  size: 20,
),
```

- [ ] **Step 7: Update "Create Account" title colour in top bar for steps 0–1**

Locate (around line 315):

```dart
style: theme.textTheme.titleMedium?.copyWith(
  color: isDark
      ? ServioColors.navyDark
      : Colors.white,
  fontWeight: FontWeight.w600,
),
```

Replace with:

```dart
style: theme.textTheme.titleMedium?.copyWith(
  color: _step <= 1
      ? Colors.white
      : (isDark ? ServioColors.textPrimaryDark : ServioColors.textPrimaryLight),
  fontWeight: FontWeight.w600,
),
```

- [ ] **Step 8: Replace `ServioCard` with `AuthCard` for steps 0–1**

Locate the single main card (around line 332):

```dart
// ── Main card ──────────────────────────────────
ServioCard(
  elevated: true,
  radius: ServioRadius.xl,
  padding: const EdgeInsets.all(20),
  child: Column(
```

Replace with:

```dart
// ── Main card ──────────────────────────────────
if (_step <= 1)
  AuthCard(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Progress section (hidden on submitted step)
        if (!_isSubmittedStep) ...<Widget>[
          Row(
            children: <Widget>[
              _RoleBadge(role: widget.role),
              const Spacer(),
              Text(
                'Step ${_step + 1}/$_totalSteps',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.45)
                      : ServioColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Progress(value: (_step + 1) / _totalSteps),
          const SizedBox(height: 22),
        ],
```

> **Note:** The `AuthCard` block only wraps steps 0 and 1. The original `ServioCard` block must remain for steps 2+. Use an `if (_step <= 1)` / `if (_step > 1)` split. Both branches contain the same inner content (copy the `Column` children); the only difference is the wrapping widget (`AuthCard` vs `ServioCard`). To avoid duplicating the inner content, extract the card body into a private method `_buildCardContent()` that is called by both branches.

Extract helper **before** `build()`:

```dart
Widget _buildCardContent(BuildContext context) {
  final theme = Theme.of(context);
  final servio = context.servio;
  final isDark = theme.brightness == Brightness.dark;
  // ... (move the entire Column(...) that was inside ServioCard here)
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      // (paste the existing Column children here unchanged)
    ],
  );
}
```

Then in `build()`:

```dart
if (_step <= 1)
  AuthCard(
    padding: const EdgeInsets.all(20),
    child: _buildCardContent(context),
  ),
if (_step > 1)
  ServioCard(
    elevated: true,
    radius: ServioRadius.xl,
    padding: const EdgeInsets.all(20),
    child: _buildCardContent(context),
  ),
```

- [ ] **Step 9: Run — confirm PASS**

```bash
flutter test test/features/auth/sign_up_redesign_test.dart
```

Expected: PASS (4 tests).

- [ ] **Step 10: Run full test suite**

```bash
flutter test
```

Expected: all tests pass. Fix any regressions.

- [ ] **Step 11: Commit**

```bash
git add mobile-app/lib/src/features/auth/sign_up_screen.dart \
        mobile-app/test/features/auth/sign_up_redesign_test.dart
git commit -m "feat: redesign sign-up steps 0 & 1 — dark immersion with AuthBackground + AuthCard"
```

---

### Task 7: Final smoke test

**Files:** No changes.

- [ ] **Step 1: Run the app**

```bash
cd mobile-app && flutter run
```

Walk through both user paths:

**Path A — New user:**
1. Landing → trust pills visible, gradient fills the screen in dark mode / header only in light mode
2. Tap "Create Account" → Role Selection → both role cards render, tap one → check selects, Continue enables
3. Continue → Sign Up Step 0 → glass card visible (dark) / white card (light), 4 fields, password strength bar
4. (Skip OTP) → tap back → confirm step 2+ still shows light cream style (no regression)

**Path B — Returning user:**
1. Landing → tap "Sign In" → Login screen → glass/white card, heading "Welcome back.", fields + remember me + forgot password
2. Entrance animations play correctly

- [ ] **Step 2: Final test run**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 3: Final commit if any lint fixes**

```bash
git add -A
git commit -m "chore: auth dark immersion redesign — final cleanup"
```
