# Report a Problem Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a dedicated `ReportProblemScreen` in `features/shared/` and wire both the customer and technician profile "Report a Problem" nav tiles to it.

**Architecture:** Single `StatefulWidget` screen (mirrors `ContactScreen` pattern) — category dropdown + description text field, inline validation banners, simulated async submit. Shared between both roles since the form is identical.

**Tech Stack:** Flutter, `ServioCard`, `ServioPrimaryButton`, `ServioTokens`, `flutter_test`

---

## File Map

| File | Action |
|------|--------|
| `mobile-app/lib/src/features/shared/report_problem_screen.dart` | **Create** |
| `mobile-app/test/features/shared/report_problem_screen_test.dart` | **Create** |
| `mobile-app/lib/src/features/customer/customer_profile_screen.dart` | **Modify** — fix import + navigation |
| `mobile-app/lib/src/features/technician/technician_profile_screen.dart` | **Modify** — replace placeholder + add import |

---

### Task 1: Write failing widget tests for ReportProblemScreen

**Files:**
- Create: `mobile-app/test/features/shared/report_problem_screen_test.dart`

- [ ] **Step 1: Create the test file**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:servio_mobile_app/src/design_system/servio_theme.dart';
import 'package:servio_mobile_app/src/features/shared/report_problem_screen.dart';

void main() {
  Widget _wrap(Widget child, {bool dark = false}) {
    return MaterialApp(
      theme: dark ? ServioTheme.dark() : ServioTheme.light(),
      home: child,
    );
  }

  testWidgets('renders page title and description text', (tester) async {
    await tester.pumpWidget(_wrap(const ReportProblemScreen()));

    expect(find.text('Report a Problem'), findsWidgets);
    expect(
      find.textContaining('Found a bug or experiencing an issue'),
      findsOneWidget,
    );
  });

  testWidgets('shows category dropdown and description field', (tester) async {
    await tester.pumpWidget(_wrap(const ReportProblemScreen()));

    expect(find.text('Problem Category'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Submit Report'), findsOneWidget);
  });

  testWidgets('shows error banner when submitting empty form', (tester) async {
    await tester.pumpWidget(_wrap(const ReportProblemScreen()));

    await tester.tap(find.text('Submit Report'));
    await tester.pump();

    expect(
      find.text('Please complete the required fields before submitting.'),
      findsOneWidget,
    );
  });

  testWidgets('shows validation error when description is too short',
      (tester) async {
    await tester.pumpWidget(_wrap(const ReportProblemScreen()));

    // Open dropdown and pick a category
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bug / App Crash').last);
    await tester.pumpAndSettle();

    // Type a short description
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Describe the issue in detail…'),
      'short',
    );
    await tester.pump();

    await tester.tap(find.text('Submit Report'));
    await tester.pump();

    expect(
      find.text('Please provide at least 20 characters.'),
      findsOneWidget,
    );
  });

  testWidgets('shows success banner and clears form after valid submission',
      (tester) async {
    await tester.pumpWidget(_wrap(const ReportProblemScreen()));

    // Pick a category
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Payment Issue').last);
    await tester.pumpAndSettle();

    // Enter a valid description
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Describe the issue in detail…'),
      'The payment screen crashes when I try to pay.',
    );
    await tester.pump();

    await tester.tap(find.text('Submit Report'));
    await tester.pump(); // start submit

    // Advance past the 700ms delay
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(
      find.textContaining('Report submitted'),
      findsOneWidget,
    );
    // Form should be cleared — description is empty
    final editables = tester.widgetList<EditableText>(find.byType(EditableText));
    for (final e in editables) {
      expect(e.controller.text, isEmpty);
    }
  });
}
```

- [ ] **Step 2: Run tests to confirm they fail with "not found" error**

```
cd mobile-app
flutter test test/features/shared/report_problem_screen_test.dart
```

Expected output: `Error: 'package:servio_mobile_app/src/features/shared/report_problem_screen.dart': Target of URI doesn't exist.`

---

### Task 2: Create ReportProblemScreen implementation

**Files:**
- Create: `mobile-app/lib/src/features/shared/report_problem_screen.dart`

- [ ] **Step 3: Create the screen file**

```dart
import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';

class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key});

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  String? _selectedCategory;
  bool _isSubmitting = false;
  String? _successMessage;
  String? _errorMessage;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _successMessage = null;
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      setState(() {
        _errorMessage =
            'Please complete the required fields before submitting.';
      });
      return;
    }

    setState(() => _isSubmitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      _successMessage =
          'Report submitted. Our team will investigate and follow up if needed.';
      _selectedCategory = null;
      _descriptionController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Report a Problem'),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: <Widget>[
            const SliverToBoxAdapter(child: _ReportHero()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  <Widget>[
                    _ReportFormCard(
                      formKey: _formKey,
                      descriptionController: _descriptionController,
                      selectedCategory: _selectedCategory,
                      isSubmitting: _isSubmitting,
                      successMessage: _successMessage,
                      errorMessage: _errorMessage,
                      onCategoryChanged: (val) =>
                          setState(() => _selectedCategory = val),
                      onSubmit: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero ─────────────────────────────────────────────────────────────────────

class _ReportHero extends StatelessWidget {
  const _ReportHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 42, 20, 38),
      color: servio.warning,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          PositionedDirectional(
            top: -52,
            start: -42,
            child: _SoftDisc(
                size: 142, color: Colors.white.withValues(alpha: 0.08)),
          ),
          PositionedDirectional(
            bottom: -58,
            end: -46,
            child: _SoftDisc(
                size: 160, color: Colors.white.withValues(alpha: 0.06)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(ServioRadius.full),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.flag_outlined,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Report an issue',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Report a Problem',
                textAlign: TextAlign.center,
                style: theme.textTheme.displayLarge
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                'Found a bug or experiencing an issue? Let us know so we can fix it.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SoftDisc extends StatelessWidget {
  const _SoftDisc({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

// ── Form card ─────────────────────────────────────────────────────────────────

class _ReportFormCard extends StatelessWidget {
  const _ReportFormCard({
    required this.formKey,
    required this.descriptionController,
    required this.selectedCategory,
    required this.isSubmitting,
    required this.onCategoryChanged,
    required this.onSubmit,
    this.successMessage,
    this.errorMessage,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController descriptionController;
  final String? selectedCategory;
  final bool isSubmitting;
  final String? successMessage;
  final String? errorMessage;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onSubmit;

  static const List<String> _categories = <String>[
    'Bug / App Crash',
    'Wrong Information',
    'Payment Issue',
    'Account Problem',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return ServioCard(
      radius: ServioRadius.lg,
      padding: const EdgeInsets.all(20),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: ServioColors.tint(servio.warning),
                    borderRadius: BorderRadius.circular(ServioRadius.sm),
                    border: Border.all(
                        color: servio.warning.withValues(alpha: 0.22)),
                  ),
                  child: Icon(Icons.flag_outlined, color: servio.warning),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Submit a report',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        "Tell us what went wrong and we'll look into it.",
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: servio.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Problem Category',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: _categories
                  .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
                  .toList(),
              onChanged: onCategoryChanged,
              validator: (val) =>
                  val == null ? 'Please select a category.' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: descriptionController,
              minLines: 4,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Describe the issue in detail…',
                alignLabelWithHint: true,
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Description is required.';
                }
                if (val.trim().length < 20) {
                  return 'Please provide at least 20 characters.';
                }
                return null;
              },
            ),
            if (successMessage != null || errorMessage != null) ...<Widget>[
              const SizedBox(height: 14),
              _InlineMessage(
                message: successMessage ?? errorMessage!,
                color: successMessage != null ? servio.success : servio.danger,
                icon: successMessage != null
                    ? Icons.check_circle_outline_rounded
                    : Icons.error_outline_rounded,
              ),
            ],
            const SizedBox(height: 18),
            ServioPrimaryButton(
              label: 'Submit Report',
              isLoading: isSubmitting,
              onPressed: isSubmitting ? null : onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Inline message banner ────────────────────────────────────────────────────

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.message,
    required this.color,
    required this.icon,
  });

  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ServioRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run failing tests — they should now pass**

```
cd mobile-app
flutter test test/features/shared/report_problem_screen_test.dart
```

Expected: `All tests passed.`

- [ ] **Step 5: Commit**

```bash
git add mobile-app/lib/src/features/shared/report_problem_screen.dart \
        mobile-app/test/features/shared/report_problem_screen_test.dart
git commit -m "feat: add ReportProblemScreen with category, description, and inline success state"
```

---

### Task 3: Wire customer profile navigation

**Files:**
- Modify: `mobile-app/lib/src/features/customer/customer_profile_screen.dart`

Current state (line ~15): `import '../messages/messages_screen.dart';`  
Current state (line ~105-109):
```dart
onTap: () => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => const MessagesScreen(),
  ),
),
```

- [ ] **Step 6: Replace the import**

In `mobile-app/lib/src/features/customer/customer_profile_screen.dart`, remove the `messages_screen.dart` import line and add the new import. The import block currently includes:

```dart
import '../messages/messages_screen.dart';
```

Replace it with:

```dart
import '../shared/report_problem_screen.dart';
```

(The `MessagesScreen` import is only used by this one `onTap` — removing it will be safe. Verify with `flutter analyze` in Step 8.)

- [ ] **Step 7: Replace the onTap navigation**

Find the `_NavTile` for 'Report a Problem' in `customer_profile_screen.dart` (around line 100–110). Replace:

```dart
_NavTile(
  icon: Icons.flag_outlined,
  iconColor: context.servio.warning,
  label: 'Report a Problem',
  subtitle: 'Send us feedback or issues',
  onTap: () => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const MessagesScreen(),
    ),
  ),
),
```

With:

```dart
_NavTile(
  icon: Icons.flag_outlined,
  iconColor: context.servio.warning,
  label: 'Report a Problem',
  subtitle: 'Send us feedback or issues',
  onTap: () => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const ReportProblemScreen(),
    ),
  ),
),
```

- [ ] **Step 8: Verify no analyzer errors**

```
cd mobile-app
flutter analyze lib/src/features/customer/customer_profile_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 9: Commit**

```bash
git add mobile-app/lib/src/features/customer/customer_profile_screen.dart
git commit -m "fix: wire customer profile Report a Problem to ReportProblemScreen"
```

---

### Task 4: Wire technician profile navigation

**Files:**
- Modify: `mobile-app/lib/src/features/technician/technician_profile_screen.dart`

Current state (line ~94-95):
```dart
onTap: () =>
    _showPlaceholder(context, 'Report a Problem'),
```

- [ ] **Step 10: Add the import**

In `mobile-app/lib/src/features/technician/technician_profile_screen.dart`, add after the existing imports:

```dart
import '../shared/report_problem_screen.dart';
```

Place it alongside the other `../` feature imports at the top.

- [ ] **Step 11: Replace the onTap**

Find the `_NavTile` for 'Report a Problem' in `technician_profile_screen.dart` (around line 89–96). Replace:

```dart
_NavTile(
  icon: Icons.flag_outlined,
  iconColor: context.servio.warning,
  label: 'Report a Problem',
  subtitle: 'Send us feedback or issues',
  onTap: () =>
      _showPlaceholder(context, 'Report a Problem'),
),
```

With:

```dart
_NavTile(
  icon: Icons.flag_outlined,
  iconColor: context.servio.warning,
  label: 'Report a Problem',
  subtitle: 'Send us feedback or issues',
  onTap: () => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const ReportProblemScreen(),
    ),
  ),
),
```

- [ ] **Step 12: Verify no analyzer errors**

```
cd mobile-app
flutter analyze lib/src/features/technician/technician_profile_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 13: Run the full test suite**

```
cd mobile-app
flutter test
```

Expected: All tests pass. Zero new failures.

- [ ] **Step 14: Final commit**

```bash
git add mobile-app/lib/src/features/technician/technician_profile_screen.dart
git commit -m "fix: wire technician profile Report a Problem to ReportProblemScreen"
```
