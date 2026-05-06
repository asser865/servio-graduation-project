# FAQ Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the FAQ accordion from the Contact Us page into a standalone `FaqScreen` and add it to the Legal section of both customer and technician profile pages.

**Architecture:** `FaqScreen` is a new `StatefulWidget` in `features/marketing/` (alongside Terms, Privacy, About). The FAQ content and accordion logic are extracted verbatim from `_FaqSection` in `contact_screen.dart`, which is then deleted. Both profile screens get a new FAQ nav tile in their Legal group.

**Tech Stack:** Flutter, `ServioCard`, `ServioTokens`, `flutter_test`

---

## File Map

| File | Action |
|------|--------|
| `mobile-app/lib/src/features/marketing/faq_screen.dart` | **Create** |
| `mobile-app/test/features/marketing/faq_screen_test.dart` | **Create** |
| `mobile-app/lib/src/features/marketing/contact_screen.dart` | **Modify** — remove `_FaqSection`, `_FaqSectionState`, `_FaqItemData` |
| `mobile-app/lib/src/features/customer/customer_profile_screen.dart` | **Modify** — add FAQ nav tile |
| `mobile-app/lib/src/features/technician/technician_profile_screen.dart` | **Modify** — add FAQ nav tile |

---

### Task 1: Write failing tests for FaqScreen

**Files:**
- Create: `mobile-app/test/features/marketing/faq_screen_test.dart`

- [ ] **Step 1: Create the test directory and test file**

```dart
// mobile-app/test/features/marketing/faq_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:servio_mobile_app/src/design_system/servio_theme.dart';
import 'package:servio_mobile_app/src/features/marketing/faq_screen.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: ServioTheme.light(),
      home: child,
    );
  }

  testWidgets('renders FAQ appbar title and heading', (tester) async {
    await tester.pumpWidget(wrap(const FaqScreen()));

    expect(find.text('FAQ'), findsOneWidget);
    expect(find.text('Frequently Asked Questions'), findsOneWidget);
    expect(find.text('QUICK ANSWERS'), findsOneWidget);
  });

  testWidgets('renders all 4 question tiles', (tester) async {
    await tester.pumpWidget(wrap(const FaqScreen()));

    expect(find.text('Booking or account issue?'), findsOneWidget);
    expect(find.text('Want to join as a professional?'), findsOneWidget);
    expect(find.text('How does SERVIO verify professionals?'), findsOneWidget);
    expect(find.text('Just browsing?'), findsOneWidget);
  });

  testWidgets('answers are hidden by default', (tester) async {
    await tester.pumpWidget(wrap(const FaqScreen()));

    expect(find.textContaining('Log in to your account'), findsNothing);
    expect(find.textContaining('Sign up as a technician'), findsNothing);
    expect(find.textContaining('profile review'), findsNothing);
    expect(find.textContaining('compare professionals'), findsNothing);
  });

  testWidgets('tapping a question expands its answer', (tester) async {
    await tester.pumpWidget(wrap(const FaqScreen()));

    await tester.tap(find.text('Want to join as a professional?'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sign up as a technician'), findsOneWidget);
  });

  testWidgets('tapping an expanded question collapses it', (tester) async {
    await tester.pumpWidget(wrap(const FaqScreen()));

    await tester.tap(find.text('Want to join as a professional?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sign up as a technician'), findsOneWidget);

    await tester.tap(find.text('Want to join as a professional?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sign up as a technician'), findsNothing);
  });

  testWidgets('first answer references Report a Problem, not the contact form',
      (tester) async {
    await tester.pumpWidget(wrap(const FaqScreen()));

    await tester.tap(find.text('Booking or account issue?'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Report a Problem'), findsOneWidget);
    expect(find.textContaining('contact form above'), findsNothing);
  });
}
```

- [ ] **Step 2: Run tests — confirm they fail with import error**

```
cd mobile-app
flutter test test/features/marketing/faq_screen_test.dart
```

Expected: `Error: 'package:servio_mobile_app/src/features/marketing/faq_screen.dart': Target of URI doesn't exist.`

---

### Task 2: Create FaqScreen

**Files:**
- Create: `mobile-app/lib/src/features/marketing/faq_screen.dart`

- [ ] **Step 3: Create the screen file**

```dart
// mobile-app/lib/src/features/marketing/faq_screen.dart
import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> with TickerProviderStateMixin {
  final Set<int> _openIndexes = <int>{};

  static const List<_FaqItemData> _items = <_FaqItemData>[
    _FaqItemData(
      'Booking or account issue?',
      'Log in to your account and use Report a Problem in your profile, or contact us via the Contact Us page. Our team will investigate and get back to you within 24 hours.',
    ),
    _FaqItemData(
      'Want to join as a professional?',
      'Sign up as a technician and we will guide you through verification. It typically takes 2-3 business days to get verified.',
    ),
    _FaqItemData(
      'How does SERVIO verify professionals?',
      'Every professional goes through profile review, identity verification, and skill assessment before accepting bookings.',
    ),
    _FaqItemData(
      'Just browsing?',
      'Explore services and book when you are ready. You can compare professionals, read reviews, and get estimates before signing up.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('FAQ'),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            ServioSpacing.screenPadding,
            28,
            ServioSpacing.screenPadding,
            40,
          ),
          children: <Widget>[
            Text(
              'QUICK ANSWERS',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: servio.accent,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Frequently Asked Questions',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineLarge,
            ),
            const SizedBox(height: 24),
            ...List<Widget>.generate(_items.length, (int index) {
              final item = _items[index];
              final expanded = _openIndexes.contains(index);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ServioCard(
                  radius: ServioRadius.md,
                  padding: EdgeInsets.zero,
                  borderColor:
                      expanded ? servio.accent.withValues(alpha: 0.42) : null,
                  child: Column(
                    children: <Widget>[
                      InkWell(
                        borderRadius: BorderRadius.circular(ServioRadius.md),
                        onTap: () {
                          setState(() {
                            if (expanded) {
                              _openIndexes.remove(index);
                            } else {
                              _openIndexes.add(index);
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  item.question,
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              AnimatedRotation(
                                turns: expanded ? 0.5 : 0,
                                duration: ServioMotion.normal,
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: expanded
                                      ? servio.accent
                                      : servio.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      AnimatedSize(
                        duration: ServioMotion.normal,
                        curve: ServioMotion.spring,
                        child: expanded
                            ? Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Text(
                                  item.answer,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: servio.textSecondary,
                                    height: 1.55,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _FaqItemData {
  const _FaqItemData(this.question, this.answer);

  final String question;
  final String answer;
}
```

- [ ] **Step 4: Run tests — all 6 must pass**

```
cd mobile-app
flutter test test/features/marketing/faq_screen_test.dart
```

Expected: `+6: All tests passed!`

- [ ] **Step 5: Run analyzer**

```
cd mobile-app
flutter analyze lib/src/features/marketing/faq_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add mobile-app/lib/src/features/marketing/faq_screen.dart \
        mobile-app/test/features/marketing/faq_screen_test.dart
git commit -m "feat: add FaqScreen with expandable accordion items"
```

---

### Task 3: Remove FAQ from contact_screen.dart

**Files:**
- Modify: `mobile-app/lib/src/features/marketing/contact_screen.dart`

The file currently has (around lines 108–112):
```dart
                    const SizedBox(height: ServioSpacing.sectionGap),
                    const _FaqSection(),
                    const SizedBox(height: 28),
```

And three classes at the bottom of the file starting around line 456:
- `class _FaqSection extends StatefulWidget`
- `class _FaqSectionState extends State<_FaqSection> with TickerProviderStateMixin`
- `class _FaqItemData`

- [ ] **Step 7: Remove the `_FaqSection` call and its spacer from the sliver list**

In `contact_screen.dart`, find this block in the `SliverChildListDelegate`:
```dart
                    const SizedBox(height: ServioSpacing.sectionGap),
                    const _FaqSection(),
                    const SizedBox(height: 28),
```

Replace it with just:
```dart
                    const SizedBox(height: 28),
```

(Keep only the bottom padding. Remove the sectionGap spacer and the `_FaqSection()` call.)

- [ ] **Step 8: Delete the three FAQ classes at the bottom of contact_screen.dart**

Remove the entire block from `class _FaqSection extends StatefulWidget {` to the end of the file (the final `}`), which includes:
- `_FaqSection` widget
- `_FaqSectionState` state class
- `_FaqItemData` data class

The file should now end after the `_SoftDisc` class or `_HeroKicker` class (whichever is last before the removed FAQ classes).

- [ ] **Step 9: Run analyzer to confirm no dangling references**

```
cd mobile-app
flutter analyze lib/src/features/marketing/contact_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 10: Run the full test suite**

```
cd mobile-app
flutter test
```

Expected: same pass/fail count as before this task — no new failures.

- [ ] **Step 11: Commit**

```bash
git add mobile-app/lib/src/features/marketing/contact_screen.dart
git commit -m "refactor: remove FAQ section from Contact Us page"
```

---

### Task 4: Wire FAQ nav tile in customer profile

**Files:**
- Modify: `mobile-app/lib/src/features/customer/customer_profile_screen.dart`

- [ ] **Step 12: Add the import**

In `customer_profile_screen.dart`, add alongside the existing marketing imports:
```dart
import '../marketing/faq_screen.dart';
```

- [ ] **Step 13: Add the FAQ nav tile to the Legal group**

Find the Legal `_MenuGroup` in `customer_profile_screen.dart`. It currently ends with the Privacy Policy tile:
```dart
                        _NavTile(
                          icon: Icons.privacy_tip_outlined,
                          iconColor: context.servio.accent,
                          label: 'Privacy Policy',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PrivacyPolicyScreen(),
                            ),
                          ),
                        ),
```

Add the FAQ tile **after** Privacy Policy, before the closing `],` of the children list:
```dart
                        _NavTile(
                          icon: Icons.quiz_outlined,
                          iconColor: context.servio.accent,
                          label: 'FAQ',
                          subtitle: 'Frequently asked questions',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const FaqScreen(),
                            ),
                          ),
                        ),
```

- [ ] **Step 14: Run analyzer**

```
cd mobile-app
flutter analyze lib/src/features/customer/customer_profile_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 15: Commit**

```bash
git add mobile-app/lib/src/features/customer/customer_profile_screen.dart
git commit -m "feat: add FAQ nav tile to customer profile Legal section"
```

---

### Task 5: Wire FAQ nav tile in technician profile

**Files:**
- Modify: `mobile-app/lib/src/features/technician/technician_profile_screen.dart`

- [ ] **Step 16: Add the import**

In `technician_profile_screen.dart`, add alongside the existing marketing imports:
```dart
import '../marketing/faq_screen.dart';
```

- [ ] **Step 17: Add the FAQ nav tile to the Legal group**

Find the Legal `_MenuGroup` in `technician_profile_screen.dart`. It currently ends with the Privacy Policy tile:
```dart
                        _NavTile(
                          icon: Icons.privacy_tip_outlined,
                          iconColor: context.servio.accent,
                          label: 'Privacy Policy',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PrivacyPolicyScreen(),
                            ),
                          ),
                        ),
```

Add the FAQ tile **after** Privacy Policy, before the closing `],` of the children list:
```dart
                        _NavTile(
                          icon: Icons.quiz_outlined,
                          iconColor: context.servio.accent,
                          label: 'FAQ',
                          subtitle: 'Frequently asked questions',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const FaqScreen(),
                            ),
                          ),
                        ),
```

- [ ] **Step 18: Run analyzer**

```
cd mobile-app
flutter analyze lib/src/features/technician/technician_profile_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 19: Run full test suite**

```
cd mobile-app
flutter test
```

Expected: same pass/fail baseline — no new failures introduced.

- [ ] **Step 20: Commit**

```bash
git add mobile-app/lib/src/features/technician/technician_profile_screen.dart
git commit -m "feat: add FAQ nav tile to technician profile Legal section"
```
