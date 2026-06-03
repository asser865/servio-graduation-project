import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/ai_api.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/models/service_category.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_animated_entry.dart';
import '../../design_system/widgets/servio_tab_shell.dart';
import '../shared/search_results_screen.dart';
import 'smart_match_tutorial.dart';
import 'technician_profile_screen.dart';

/// Smart Match — AI service matching.
///
/// Two states live in this single tab-resident screen so the shell's floating
/// bottom navigation bar is never covered:
///   • Home    — hero, "How it Works", issue composer, category + recent chips.
///   • Results — AI analysis card, diagnostic results, top matched pros.
/// Tapping "Find Providers Now" runs the AI recommendation and swaps to the
/// results view; the header back button returns to the home view.
class AiSmartMatchScreen extends StatefulWidget {
  const AiSmartMatchScreen({super.key});

  @override
  State<AiSmartMatchScreen> createState() => _AiSmartMatchScreenState();
}

class _AiSmartMatchScreenState extends State<AiSmartMatchScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();

  bool _showResults = false;
  bool _loading = false;
  String? _error;
  AiRecommendationResponse? _recommendation;
  double _processedSeconds = 0;
  String? _selectedCategory;

  final List<String> _recentSearches = <String>[
    'Leaking Faucet',
    'AC Maintenance',
    'Apartment Cleaning',
  ];

  // ── First-run tutorial ──────────────────────────────────────────────────
  final ScrollController _homeScroll = ScrollController();
  final ScrollController _resultsScroll = ScrollController();
  final GlobalKey _inputKey = GlobalKey();
  final GlobalKey _chipsKey = GlobalKey();
  final GlobalKey _ctaKey = GlobalKey();
  final GlobalKey _analysisKey = GlobalKey();
  final GlobalKey _diagnosticKey = GlobalKey();
  final GlobalKey _proKey = GlobalKey();

  late final AnimationController _pulseController;
  OverlayEntry? _tutorialEntry;
  bool _tutorialActive = false;
  bool _tutorialBusy = false;
  bool _wasActive = false;
  // 0 input · 1 chips · 2 cta · 3 analysis · 4 diagnostic · 5 pro · 6 success
  int _tutorialStep = 0;
  Rect? _spotlightRect;

  static const List<_CategoryChipData> _categories = <_CategoryChipData>[
    _CategoryChipData('Plumbing', 'plumbing'),
    _CategoryChipData('Electrical', 'electrical'),
    _CategoryChipData('HVAC', 'hvac'),
    _CategoryChipData('Carpentry', 'carpentry'),
    _CategoryChipData('Cleaning', 'cleaning'),
    _CategoryChipData('Painting', 'painting'),
    _CategoryChipData('Appliance', 'appliance'),
    _CategoryChipData('Handyman', 'handyman'),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _homeScroll.dispose();
    _resultsScroll.dispose();
    _pulseController.dispose();
    _tutorialEntry?.remove();
    _tutorialEntry = null;
    super.dispose();
  }

  String _serviceCategory(String service) {
    const map = <String, String>{
      'Plumbing': 'plumbing',
      'Electrical': 'electrical',
      'A/C': 'hvac',
      'Carpentry': 'carpentry',
      'Cleaning': 'cleaning',
      'Painting': 'painting',
      'Appliance Repair': 'appliance',
      'Handyman': 'handyman',
    };
    return map[service] ?? normalizeServiceCategory(service);
  }

  void _pushRecentSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _recentSearches
      ..removeWhere((s) => s.toLowerCase() == trimmed.toLowerCase())
      ..insert(0, trimmed);
    if (_recentSearches.length > 6) {
      _recentSearches.removeRange(6, _recentSearches.length);
    }
  }

  Future<void> _analyze() async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() => _error = 'Please describe your issue first.');
      return;
    }
    FocusScope.of(context).unfocus();
    final stopwatch = Stopwatch()..start();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = context.read<ApiClient>();
      // Problem, budget, and location all live in the single prompt — the AI
      // service extracts them from the description text itself.
      final recommendation = await AiApi(client).recommend(description: query);
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _recommendation = recommendation;
        _processedSeconds = stopwatch.elapsedMilliseconds / 1000;
        _pushRecentSearch(query);
        _showResults = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'AI service unavailable. Try again later.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resetToHome() {
    setState(() {
      _showResults = false;
      _error = null;
    });
  }

  /// Clears all Smart Match state back to a fresh Home view. Called when the
  /// tab is re-entered so returning users start over (the tab is kept alive
  /// in the shell's IndexedStack, so this must be done manually).
  void _resetSmartMatch() {
    if (!mounted || _tutorialActive) return;
    setState(() {
      _showResults = false;
      _loading = false;
      _error = null;
      _recommendation = null;
      _selectedCategory = null;
      _controller.clear();
    });
    if (_homeScroll.hasClients) _homeScroll.jumpTo(0);
  }

  // ── Tutorial: lifecycle ──────────────────────────────────────────────────

  void _maybeStartTutorial() {
    if (!mounted || _tutorialActive) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    _startTutorial(overlay);
  }

  void _startTutorial(OverlayState overlay) {
    _tutorialActive = true;
    _tutorialStep = 0;
    _tutorialEntry = OverlayEntry(builder: _buildTutorialOverlay);
    overlay.insert(_tutorialEntry!);
    _goToStep(0);
  }

  void _dismissTutorial() {
    _tutorialActive = false;
    _tutorialEntry?.remove();
    _tutorialEntry = null;
    // Tutorial is a pure demo — wipe any demo state so the user lands on a
    // clean, empty Home view ready for their own prompt.
    if (mounted) {
      setState(() {
        _showResults = false;
        _loading = false;
        _tutorialBusy = false;
        _error = null;
        _recommendation = null;
        _selectedCategory = null;
        _controller.clear();
      });
      if (_homeScroll.hasClients) _homeScroll.jumpTo(0);
    }
  }

  /// Canned recommendation used only to drive the Step-4 walkthrough. No
  /// backend call is made during the tutorial.
  AiRecommendationResponse _demoRecommendation() {
    return const AiRecommendationResponse(
      predictedCategory: 'plumbing',
      confidence: 0.96,
      serviceName: 'Under-Sink Leak Repair',
      priceRange: '200 – 500 EGP',
      scenario: 'single',
      steps: <ServiceStep>[],
      recommendedWorkers: <RecommendedWorker>[
        RecommendedWorker(
          id: '',
          name: 'David Miller',
          matchLabel: '97%',
          reason: 'Specializes in leak detection and pipe repair.',
          averageRating: 4.9,
          totalReviews: 124,
          locationLabel: 'Nasr City',
          categories: <String>['plumbing'],
          matchScore: 97,
          hourlyRate: 135,
          yearsExperience: 6,
          completedJobs: 80,
        ),
      ],
    );
  }

  // ── Tutorial: step machine ───────────────────────────────────────────────

  GlobalKey? _targetKeyForStep(int step) {
    switch (step) {
      case 0:
        return _inputKey;
      case 1:
        return _chipsKey;
      case 2:
        return _ctaKey;
      case 3:
        return _analysisKey;
      case 4:
        return _diagnosticKey;
      case 5:
        return _proKey;
      default:
        return null;
    }
  }

  Rect? _rectOf(GlobalKey? key) {
    final ctx = key?.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _goToStep(int step) async {
    if (!_tutorialActive) return;
    setState(() => _tutorialStep = step);
    _tutorialEntry?.markNeedsBuild();
    await WidgetsBinding.instance.endOfFrame;
    if (!_tutorialActive || !mounted) return;

    final key = _targetKeyForStep(step);
    final ctx = key?.currentContext;
    if (ctx != null && ctx.mounted) {
      await Scrollable.ensureVisible(
        ctx,
        duration: ServioMotion.micro,
        alignment: 0.25,
        curve: ServioMotion.spring,
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    if (!_tutorialActive || !mounted) return;
    setState(() => _spotlightRect = _rectOf(key));
    _tutorialEntry?.markNeedsBuild();
  }

  Future<void> _tutorialNext() async {
    switch (_tutorialStep) {
      case 0:
      case 1:
        _goToStep(_tutorialStep + 1);
        break;
      case 2:
        await _tutorialShowDemoResults();
        break;
      case 3:
      case 4:
        _goToStep(_tutorialStep + 1);
        break;
      case 5:
        _showSuccess();
        break;
    }
  }

  void _tutorialBack() {
    if (_tutorialStep == 0 || _tutorialStep == 3) return;
    _goToStep(_tutorialStep - 1);
  }

  /// Step 3 → 4 transition. Shows a brief faux "analyzing" beat, then reveals
  /// DEMO results (no backend call) so the user can see the results steps.
  Future<void> _tutorialShowDemoResults() async {
    setState(() => _tutorialBusy = true);
    _tutorialEntry?.markNeedsBuild();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!_tutorialActive || !mounted) return;
    setState(() {
      _tutorialBusy = false;
      _recommendation = _demoRecommendation();
      _processedSeconds = 1.2;
      _showResults = true;
    });
    _tutorialEntry?.markNeedsBuild();
    // Allow the AnimatedSwitcher swap + results layout to settle.
    await Future<void>.delayed(const Duration(milliseconds: 420));
    await _goToStep(3);
  }

  void _showSuccess() {
    setState(() {
      _tutorialStep = 6;
      _spotlightRect = null;
    });
    _tutorialEntry?.markNeedsBuild();
  }

  // ── Tutorial: overlay rendering ──────────────────────────────────────────

  Widget _buildTutorialOverlay(BuildContext context) {
    final size = MediaQuery.of(context).size;

    if (_tutorialStep == 6) {
      return Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.66)),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: TutorialSuccessCard(
                onPrimary: _dismissTutorial,
                onClose: _dismissTutorial,
              ),
            ),
          ),
        ],
      );
    }

    final rect = _spotlightRect;

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (BuildContext context, _) {
                final pulse =
                    _tutorialStep == 2 ? _pulseController.value : 0.0;
                // No target rect yet → just a plain dim (RectTween.end must be
                // non-null, so the tween path is only used once we have a rect).
                if (rect == null) {
                  return CustomPaint(
                    size: size,
                    painter: SpotlightPainter(rect: null, pulse: pulse),
                  );
                }
                return TweenAnimationBuilder<Rect?>(
                  tween: RectTween(end: rect),
                  duration: ServioMotion.micro,
                  curve: ServioMotion.spring,
                  builder: (BuildContext context, Rect? animRect, _) {
                    return CustomPaint(
                      size: size,
                      painter: SpotlightPainter(rect: animRect, pulse: pulse),
                    );
                  },
                );
              },
            ),
          ),
        ),
        _positionedCoachCard(size, rect),
      ],
    );
  }

  Widget _positionedCoachCard(Size size, Rect? rect) {
    final centerY = rect?.center.dy ?? size.height / 2;
    final placeBelow = centerY < size.height * 0.5;

    return AnimatedPositioned(
      duration: ServioMotion.micro,
      curve: ServioMotion.spring,
      left: 16,
      right: 16,
      top: placeBelow
          ? ((rect?.bottom ?? size.height * 0.3) + 16)
          : null,
      bottom: placeBelow
          ? null
          : (size.height - (rect?.top ?? size.height * 0.6) + 16),
      child: _coachCardForStep(),
    );
  }

  Widget _coachCardForStep() {
    switch (_tutorialStep) {
      case 0:
        return TutorialCoachCard(
          stepLabel: 'STEP 1 OF 4',
          emoji: '✨',
          title: 'Describe Your Issue',
          onNext: _tutorialNext,
          onSkip: _dismissTutorial,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const <Widget>[
              Text(
                "Tell us what's happening in your home using natural language.",
              ),
              SizedBox(height: 12),
              TutorialTypewriter(
                text: 'My kitchen sink is leaking underneath and water is '
                    'dripping onto the floor.',
              ),
            ],
          ),
        );
      case 1:
        return TutorialCoachCard(
          stepLabel: 'STEP 2 OF 4',
          emoji: '🧠',
          title: 'AI Understands Your Request',
          onNext: _tutorialNext,
          onBack: _tutorialBack,
          onSkip: _dismissTutorial,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const <Widget>[
              Text('Smart Match identifies:'),
              SizedBox(height: 10),
              TutorialCheckList(
                items: <String>[
                  'Service category',
                  'Urgency level',
                  'Required expertise',
                ],
              ),
              SizedBox(height: 8),
              TutorialDetectionList(
                detections: <String>[
                  'Plumbing detected',
                  'Medium urgency',
                  'Residential repair',
                ],
              ),
            ],
          ),
        );
      case 2:
        return TutorialCoachCard(
          stepLabel: 'STEP 3 OF 4',
          emoji: '🎯',
          title: 'Find Your Best Match',
          nextLabel: 'Next',
          busy: _tutorialBusy,
          onNext: _tutorialNext,
          onBack: _tutorialBack,
          onSkip: _dismissTutorial,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const <Widget>[
              Text('Our AI compares professionals using:'),
              SizedBox(height: 10),
              TutorialCheckList(
                items: <String>[
                  'Expertise',
                  'Availability',
                  'Location',
                  'Ratings',
                  'Budget compatibility',
                ],
              ),
            ],
          ),
        );
      case 3:
        return TutorialCoachCard(
          stepLabel: 'STEP 4 OF 4',
          emoji: '⚡',
          title: 'AI Analysis',
          onNext: _tutorialNext,
          onSkip: _dismissTutorial,
          body: const Text(
            'The AI evaluates your issue, verifies availability, and ranks '
            'local professionals.',
          ),
        );
      case 4:
        return TutorialCoachCard(
          stepLabel: 'STEP 4 OF 4',
          emoji: '📋',
          title: 'Issue Diagnosis',
          onNext: _tutorialNext,
          onBack: _tutorialBack,
          onSkip: _dismissTutorial,
          body: const Text(
            'Smart Match identifies likely causes and urgency levels — '
            'including the urgent badge and confidence score.',
          ),
        );
      default:
        return TutorialCoachCard(
          stepLabel: 'STEP 4 OF 4',
          emoji: '⭐',
          title: 'Personalized Recommendations',
          onNext: _tutorialNext,
          onBack: _tutorialBack,
          onSkip: _dismissTutorial,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const <Widget>[
              Text('Every recommendation is ranked using:'),
              SizedBox(height: 10),
              TutorialCheckList(
                items: <String>[
                  'Expertise Match',
                  'Location Match',
                  'Budget Match',
                  'Availability Match',
                ],
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Track tab activation. The Smart Match tab is kept alive in the shell's
    // IndexedStack, so we manually react to it being (re-)entered: reset to a
    // fresh Home view and replay the tutorial every time.
    final active = ServioTabShell.isPageActiveOf(context);
    if (active && !_wasActive) {
      _wasActive = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resetSmartMatch();
        _maybeStartTutorial();
      });
    } else if (!active) {
      _wasActive = false;
    }

    return Scaffold(
      backgroundColor: ServioColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: ServioColors.backgroundLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1D23)),
          onPressed: () {
            if (_showResults) {
              _resetToHome();
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
        title: Text(
          'Servio',
          style: theme.textTheme.titleLarge?.copyWith(
            color: const Color(0xFF1A1D23),
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: const <Widget>[
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.auto_awesome_outlined, color: Color(0xFF1A1D23)),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: ServioMotion.tabSwitch,
        child: _showResults
            ? _ResultsView(
                key: const ValueKey<String>('results'),
                recommendation: _recommendation!,
                processedSeconds: _processedSeconds,
                serviceCategory: _serviceCategory,
                scrollController: _resultsScroll,
                analysisKey: _analysisKey,
                diagnosticKey: _diagnosticKey,
                proKey: _proKey,
              )
            : _buildHome(context),
      ),
    );
  }

  Widget _buildHome(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = ServioTabShell.bottomOverlayInsetOf(context);

    return SingleChildScrollView(
      key: const ValueKey<String>('home'),
      controller: _homeScroll,
      padding: EdgeInsets.fromLTRB(
        ServioSpacing.screenPadding,
        8,
        ServioSpacing.screenPadding,
        ServioSpacing.screenPadding + bottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Hero
          const Center(child: _HeroIcon()),
          const SizedBox(height: 20),
          Text(
            'Smart Matching for\nReal Home Issues',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineLarge?.copyWith(
              color: const Color(0xFF1A1D23),
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Describe your problem naturally. Our AI will analyze it '
            'and find the perfect professionals for the job.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: ServioColors.textSecondaryLight,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          // How it Works (collapsible — the tutorial covers this in depth)
          const _HowItWorksSection(),
          const SizedBox(height: 28),
          // Issue input
          KeyedSubtree(
            key: _inputKey,
            child: _IssueInput(controller: _controller),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 20),
          // Category chips
          KeyedSubtree(
            key: _chipsKey,
            child: _CategoryChips(
              categories: _categories,
              selected: _selectedCategory,
              onSelected: (label) {
                setState(() {
                  _selectedCategory =
                      _selectedCategory == label ? null : label;
                });
              },
            ),
          ),
          const SizedBox(height: 24),
          // Recent searches
          Text(
            'RECENT SEARCHES',
            style: theme.textTheme.labelSmall?.copyWith(
              color: ServioColors.textSecondaryLight,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          _RecentSearches(
            searches: _recentSearches,
            onTap: (q) {
              setState(() {
                _controller.text = q;
                _controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: _controller.text.length),
                );
                _error = null;
              });
            },
          ),
          const SizedBox(height: 28),
          // CTA
          KeyedSubtree(
            key: _ctaKey,
            child: _PrimaryCta(
              label: _loading ? 'Analyzing Issue...' : 'Find Providers Now',
              icon: _loading
                  ? Icons.hourglass_empty_rounded
                  : Icons.search_rounded,
              loading: _loading,
              onTap: _analyze,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Home: hero icon ──────────────────────────────────────────────────────────

class _HeroIcon extends StatelessWidget {
  const _HeroIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ServioColors.backgroundSoftLight.withValues(alpha: 0.6),
        shape: BoxShape.circle,
      ),
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          gradient: ServioGradients.brand,
          borderRadius: BorderRadius.circular(ServioRadius.xxl),
          boxShadow: ServioShadows.elevated,
        ),
        child: const Icon(
          Icons.auto_awesome_rounded,
          color: Colors.white,
          size: 34,
        ),
      ),
    );
  }
}

// ─── Home: How it Works stepper ───────────────────────────────────────────────

/// Collapsible "How it Works" — collapsed by default so it stays compact and
/// doesn't duplicate the in-app tutorial, but is one tap away for reference.
class _HowItWorksSection extends StatefulWidget {
  const _HowItWorksSection();

  @override
  State<_HowItWorksSection> createState() => _HowItWorksSectionState();
}

class _HowItWorksSectionState extends State<_HowItWorksSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'How it Works',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF1A1D23),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _expanded ? 'Hide' : '3 quick steps',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: ServioColors.textSecondaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                duration: ServioMotion.fast,
                turns: _expanded ? 0.5 : 0,
                child: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: ServioColors.accent),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: ServioMotion.micro,
          curve: ServioMotion.spring,
          alignment: Alignment.topCenter,
          child: _expanded
              ? const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: _HowItWorks(),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const List<List<String>> _steps = <List<String>>[
    <String>[
      'Describe the Issue',
      "Use everyday language to tell us what's going wrong in your home.",
    ],
    <String>[
      'AI Analysis',
      'Our system identifies the exact type of service and parts needed.',
    ],
    <String>[
      'Connect with Pros',
      'Review matches and book highly-rated local professionals instantly.',
    ],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List<Widget>.generate(_steps.length, (int index) {
        return _StepRow(
          number: index + 1,
          title: _steps[index][0],
          description: _steps[index][1],
          isFirst: index == 0,
          isLast: index == _steps.length - 1,
        );
      }),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.title,
    required this.description,
    required this.isFirst,
    required this.isLast,
  });

  final int number;
  final String title;
  final String description;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = isFirst;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Number + connecting line
          Column(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: active
                        ? const Color(0xFF1A1D23)
                        : ServioColors.borderLight,
                    width: active ? 2 : 1.5,
                  ),
                ),
                child: Text(
                  '$number',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: active
                        ? const Color(0xFF1A1D23)
                        : ServioColors.textSecondaryLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: ServioColors.borderLight,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          // Title + description
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF1A1D23),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: ServioColors.textSecondaryLight,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Home: issue input ────────────────────────────────────────────────────────

class _IssueInput extends StatelessWidget {
  const _IssueInput({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ServioRadius.xl),
        border: Border.all(color: ServioColors.borderLight),
        boxShadow: ServioShadows.rest,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: TextField(
        controller: controller,
        maxLines: 5,
        minLines: 4,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: const Color(0xFF262B34),
          height: 1.4,
        ),
        decoration: InputDecoration(
          isCollapsed: true,
          hintText:
              "E.g., My kitchen sink is leaking underneath, and there's a "
              'weird buzzing sound coming from the garbage disposal...',
          hintStyle: theme.textTheme.bodyLarge?.copyWith(
            color: ServioColors.textSecondaryLight.withValues(alpha: 0.7),
            height: 1.4,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

// ─── Home: category chips ─────────────────────────────────────────────────────

class _CategoryChipData {
  const _CategoryChipData(this.label, this.canonical);

  final String label;
  final String canonical;
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<_CategoryChipData> categories;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (BuildContext context, int index) {
          final cat = categories[index];
          final isSelected = selected == cat.label;

          return GestureDetector(
            onTap: () => onSelected(cat.label),
            child: AnimatedContainer(
              duration: ServioMotion.fast,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected
                    ? ServioColors.neutralWarm.withValues(alpha: 0.55)
                    : Colors.white,
                borderRadius: BorderRadius.circular(ServioRadius.full),
                border: Border.all(
                  color: isSelected
                      ? ServioColors.accent
                      : ServioColors.borderLight,
                ),
              ),
              child: Text(
                cat.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isSelected
                      ? const Color(0xFF8A5A2B)
                      : const Color(0xFF1A1D23),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Home: recent searches ────────────────────────────────────────────────────

class _RecentSearches extends StatelessWidget {
  const _RecentSearches({required this.searches, required this.onTap});

  final List<String> searches;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: searches.map((String q) {
        return GestureDetector(
          onTap: () => onTap(q),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: ServioColors.backgroundSoftLight.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(ServioRadius.full),
              border: Border.all(color: ServioColors.borderLight),
            ),
            child: Text(
              q,
              style: theme.textTheme.labelLarge?.copyWith(
                color: const Color(0xFF1A1D23),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Shared: primary CTA ──────────────────────────────────────────────────────

class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          gradient: loading ? null : ServioGradients.brand,
          color: loading ? ServioColors.navySoft : null,
          borderRadius: BorderRadius.circular(ServioRadius.xl),
          boxShadow: loading ? null : ServioShadows.elevated,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Results view ─────────────────────────────────────────────────────────────

class _ResultsView extends StatelessWidget {
  const _ResultsView({
    required this.recommendation,
    required this.processedSeconds,
    required this.serviceCategory,
    this.scrollController,
    this.analysisKey,
    this.diagnosticKey,
    this.proKey,
    super.key,
  });

  final AiRecommendationResponse recommendation;
  final double processedSeconds;
  final String Function(String) serviceCategory;
  final ScrollController? scrollController;
  final GlobalKey? analysisKey;
  final GlobalKey? diagnosticKey;
  final GlobalKey? proKey;

  @override
  Widget build(BuildContext context) {
    final bottomInset = ServioTabShell.bottomOverlayInsetOf(context);

    return SingleChildScrollView(
      controller: scrollController,
      padding: EdgeInsets.only(bottom: ServioSpacing.screenPadding + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 8),
          // Analysis card
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: ServioSpacing.screenPadding),
            child: KeyedSubtree(
              key: analysisKey,
              child: ServioAnimatedEntry(
                child: _AnalysisCard(
                  recommendation: recommendation,
                  processedSeconds: processedSeconds,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          // Diagnostic results
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: ServioSpacing.screenPadding),
            child: KeyedSubtree(
              key: diagnosticKey,
              child: ServioAnimatedEntry(
                delay: const Duration(milliseconds: 80),
                child: _DiagnosticResults(
                  recommendation: recommendation,
                  serviceCategory: serviceCategory,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          // Top matched pros
          ServioAnimatedEntry(
            delay: const Duration(milliseconds: 160),
            child: _TopMatchedPros(
              recommendation: recommendation,
              serviceCategory: serviceCategory,
              proKey: proKey,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Results: analysis card ───────────────────────────────────────────────────

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({
    required this.recommendation,
    required this.processedSeconds,
  });

  final AiRecommendationResponse recommendation;
  final double processedSeconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final workerCount = recommendation.recommendedWorkers.length;
    final categoryLabel = recommendation.predictedCategory.isNotEmpty
        ? serviceCategoryLabel(recommendation.predictedCategory)
        : 'service';
    final serviceName = recommendation.serviceName.isNotEmpty
        ? recommendation.serviceName
        : categoryLabel;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ServioRadius.xl),
        boxShadow: ServioShadows.rest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  gradient: ServioGradients.brand,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.support_agent_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Smart Match Analysis',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF1A1D23),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Processed in ${processedSeconds.toStringAsFixed(1)}s',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: servio.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _AnalysisRow(
            title: 'Analyzing issue:',
            body: ' Detected a $serviceName problem from your description.',
          ),
          const SizedBox(height: 12),
          _AnalysisRow(
            title: 'Scanning local pros:',
            body: ' Filtering for verified $categoryLabel specialists in '
                'your area.',
          ),
          const SizedBox(height: 12),
          _AnalysisRow(
            title: 'Verifying availability:',
            body: workerCount > 0
                ? ' Confirmed $workerCount available '
                    '${workerCount == 1 ? 'pro' : 'pros'} ready to help.'
                : ' Searching for available pros nearby.',
          ),
        ],
      ),
    );
  }
}

class _AnalysisRow extends StatelessWidget {
  const _AnalysisRow({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(Icons.check_circle_outline_rounded,
              color: ServioColors.accent, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: <TextSpan>[
                TextSpan(
                  text: title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF1A1D23),
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                TextSpan(
                  text: body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: ServioColors.textSecondaryLight,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Results: diagnostic results ──────────────────────────────────────────────

class _Diagnostic {
  const _Diagnostic({
    required this.title,
    required this.urgent,
    required this.scorePercent,
    required this.description,
  });

  final String title;
  final bool urgent;
  final int? scorePercent;
  final String description;
}

class _DiagnosticResults extends StatelessWidget {
  const _DiagnosticResults({
    required this.recommendation,
    required this.serviceCategory,
  });

  final AiRecommendationResponse recommendation;
  final String Function(String) serviceCategory;

  List<_Diagnostic> _buildItems() {
    final overall = recommendation.confidence <= 0
        ? null
        : (recommendation.confidence <= 1
                ? recommendation.confidence * 100
                : recommendation.confidence)
            .round();

    if (recommendation.isMulti && recommendation.steps.isNotEmpty) {
      return recommendation.steps.map((ServiceStep step) {
        return _Diagnostic(
          title: step.service,
          urgent: step.urgency == 'urgent',
          scorePercent: null,
          description: step.urgency == 'urgent'
              ? 'Needs immediate professional attention.'
              : 'Can be scheduled after the priority fix.',
        );
      }).toList();
    }

    final categoryLabel = recommendation.predictedCategory.isNotEmpty
        ? serviceCategoryLabel(recommendation.predictedCategory)
        : 'Service';
    final title = recommendation.serviceName.isNotEmpty
        ? recommendation.serviceName
        : '$categoryLabel Issue';
    final description = recommendation.priceRange.isNotEmpty
        ? 'Estimated ${recommendation.priceRange}. Professional attention '
            'recommended.'
        : 'Professional attention recommended for this issue.';

    return <_Diagnostic>[
      _Diagnostic(
        title: title,
        urgent: (overall ?? 0) >= 80,
        scorePercent: overall,
        description: description,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _buildItems();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Diagnostic Results',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: const Color(0xFF1A1D23),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (BuildContext context, int index) {
              return _DiagnosticCard(item: items[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _DiagnosticCard extends StatelessWidget {
  const _DiagnosticCard({required this.item});

  final _Diagnostic item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeColor =
        item.urgent ? const Color(0xFFC2410C) : const Color(0xFF6B6560);
    final badgeBg =
        item.urgent ? const Color(0xFFFCE4D6) : const Color(0xFFEDEAE5);
    final badgeLabel = item.urgent ? 'URGENT' : 'FLEXIBLE';
    final badgeIcon =
        item.urgent ? Icons.warning_amber_rounded : Icons.schedule_rounded;

    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ServioRadius.xl),
        boxShadow: ServioShadows.rest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(ServioRadius.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(badgeIcon, size: 13, color: badgeColor),
                    const SizedBox(width: 4),
                    Text(
                      badgeLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: badgeColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.scorePercent != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '${item.scorePercent}%',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF1A1D23),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Match',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: ServioColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            item.title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: const Color(0xFF1A1D23),
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              item.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: ServioColors.textSecondaryLight,
                height: 1.35,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Results: top matched pros ────────────────────────────────────────────────

class _TopMatchedPros extends StatelessWidget {
  const _TopMatchedPros({
    required this.recommendation,
    required this.serviceCategory,
    this.proKey,
  });

  final AiRecommendationResponse recommendation;
  final String Function(String) serviceCategory;
  final GlobalKey? proKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workers = recommendation.recommendedWorkers;
    final catKey = recommendation.isMulti && recommendation.steps.isNotEmpty
        ? serviceCategory(recommendation.steps.first.service)
        : recommendation.predictedCategory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: ServioSpacing.screenPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Top Matched Pros',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: const Color(0xFF1A1D23),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Based on diagnostic urgency and exact skills',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ServioColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SearchResultsScreen(query: ''),
                  ),
                ),
                child: Text(
                  'View all',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: ServioColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (workers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: ServioSpacing.screenPadding),
            child: Text(
              'No matches found. Try describing your issue in more detail.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: ServioColors.textSecondaryLight,
              ),
            ),
          )
        else
          ...List<Widget>.generate(workers.length, (int index) {
            final worker = workers[index];
            final card = Padding(
              padding: const EdgeInsets.fromLTRB(
                  ServioSpacing.screenPadding, 0, ServioSpacing.screenPadding, 16),
              child: _ProCard(
                worker: worker,
                recommendation: recommendation,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TechnicianProfileScreen(
                      technicianId: worker.id.isEmpty ? null : worker.id,
                      selectedServiceCategory: catKey.isEmpty ? null : catKey,
                      selectedServiceName: recommendation.serviceName.isEmpty
                          ? null
                          : recommendation.serviceName,
                    ),
                  ),
                ),
              ),
            );
            // Spotlight target = the first (top) matched professional card.
            return index == 0 && proKey != null
                ? KeyedSubtree(key: proKey, child: card)
                : card;
          }),
      ],
    );
  }
}

class _ProCard extends StatelessWidget {
  const _ProCard({
    required this.worker,
    required this.recommendation,
    required this.onTap,
  });

  final RecommendedWorker worker;
  final AiRecommendationResponse recommendation;
  final VoidCallback onTap;

  int get _skillMatch {
    if (worker.matchScore != null) return worker.matchScore!.round().clamp(0, 100);
    if (worker.averageRating != null) {
      return (worker.averageRating! / 5 * 100).round().clamp(0, 100);
    }
    return 92;
  }

  int get _budgetMatch => worker.hourlyRate != null ? 95 : 90;

  int get _locationMatch =>
      (worker.locationLabel != null && worker.locationLabel!.isNotEmpty)
          ? 98
          : 85;

  String get _roleLabel {
    if (worker.categories.isEmpty) return 'Verified Pro';
    final label = serviceCategoryLabel(worker.categories.first);
    final master =
        (worker.yearsExperience ?? 0) >= 5 || (worker.completedJobs ?? 0) >= 50;
    return master ? 'Master $label' : '$label Specialist';
  }

  List<String> get _reasons {
    final out = <String>[];
    if (worker.reason.trim().isNotEmpty) {
      final first = worker.reason.trim().split(RegExp(r'(?<=[.!?])\s+')).first;
      out.add(first.length > 60 ? '${first.substring(0, 57)}...' : first);
    } else if (worker.categories.isNotEmpty) {
      out.add('Specializes in ${serviceCategoryLabel(worker.categories.first)}');
    }
    out.add('Fits your budget');
    out.add('Available today');
    return out.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final hasImage =
        worker.profileImage != null && worker.profileImage!.isNotEmpty;
    final initial = worker.name.isNotEmpty ? worker.name[0].toUpperCase() : '?';
    final rateLabel = worker.hourlyRate != null
        ? '${worker.hourlyRate!.round()} EGP/hr'
        : (recommendation.priceRange.isNotEmpty
            ? recommendation.priceRange
            : 'Est.');
    final aggregate = ((_skillMatch + _budgetMatch + _locationMatch) / 3) / 100;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ServioRadius.xl),
        boxShadow: ServioShadows.rest,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Photo + overlay info pill
          Stack(
            children: <Widget>[
              SizedBox(
                height: 180,
                width: double.infinity,
                child: hasImage
                    ? Image.network(
                        worker.profileImage!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _PhotoFallback(),
                      )
                    : _PhotoFallback(initial: initial),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(ServioRadius.lg),
                    boxShadow: ServioShadows.rest,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Flexible(
                                  child: Text(
                                    worker.name.isEmpty
                                        ? 'Professional'
                                        : worker.name,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: const Color(0xFF1A1D23),
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.verified_rounded,
                                    size: 15, color: ServioColors.accent),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A1D23),
                                    borderRadius:
                                        BorderRadius.circular(ServioRadius.sm),
                                  ),
                                  child: Text(
                                    '$_skillMatch% MATCH',
                                    style:
                                        theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _roleLabel,
                                    style:
                                        theme.textTheme.labelSmall?.copyWith(
                                      color: servio.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Text(
                            rateLabel,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: const Color(0xFF1A1D23),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'FLAT RATE EST.',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: servio.textSecondary,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Stat labels
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    _StatLabel(label: 'SKILLMATCH', value: _skillMatch),
                    _StatLabel(label: 'BUDGET', value: _budgetMatch),
                    _StatLabel(label: 'LOCATION', value: _locationMatch),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(ServioRadius.full),
                  child: LinearProgressIndicator(
                    value: aggregate,
                    minHeight: 6,
                    backgroundColor: ServioColors.backgroundSoftLight,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        ServioColors.accent),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Why This Match',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF1A1D23),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ..._reasons.map(
                  (String r) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(Icons.check_circle_outline_rounded,
                              size: 16, color: ServioColors.accent),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            r,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF1A1D23),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: ServioGradients.brand,
                      borderRadius: BorderRadius.circular(ServioRadius.lg),
                      boxShadow: ServioShadows.rest,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          'Book Now',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatLabel extends StatelessWidget {
  const _StatLabel({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        children: <TextSpan>[
          TextSpan(
            text: '$label: ',
            style: theme.textTheme.labelSmall?.copyWith(
              color: ServioColors.textSecondaryLight,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
          TextSpan(
            text: '$value%',
            style: theme.textTheme.labelSmall?.copyWith(
              color: const Color(0xFF1A1D23),
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback({this.initial = '?'});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: ServioGradients.warm),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Color(0xFF1A1D23),
          fontSize: 40,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
