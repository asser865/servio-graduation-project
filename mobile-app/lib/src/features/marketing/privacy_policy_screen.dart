import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';

/// Centralized keys to uniquely identify sections of the Privacy Policy.
enum PrivacySectionType {
  introduction,
  informationCollect,
  howWeUse,
  aiProcessing,
  locationInfo,
  sharing,
  escrow,
  security,
  userRights,
  retention,
  publicContent,
  children,
  thirdParty,
  compliance,
  changes,
  contactUs,
}

/// Represents a single paragraph block, containing optional sub-headers, text, and bullet lists.
class PrivacyParagraph {
  final String? subtitle;
  final String? text;
  final List<String>? bulletPoints;

  const PrivacyParagraph({
    this.subtitle,
    this.text,
    this.bulletPoints,
  });
}

/// Represents a top-level section of the Privacy Policy.
class PrivacySection {
  final PrivacySectionType type;
  final String sectionId;
  final String title;
  final List<PrivacyParagraph> paragraphs;

  const PrivacySection({
    required this.type,
    required this.sectionId,
    required this.title,
    required this.paragraphs,
  });
}

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollCtrl;
  late final AnimationController _entranceCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  // Search state
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  // Expansion state
  final Set<PrivacySectionType> _expandedSections = <PrivacySectionType>{};

  // GlobalKeys mapped to each section type for scroll navigation
  final Map<PrivacySectionType, GlobalKey> _sectionKeys = {
    for (final type in PrivacySectionType.values) type: GlobalKey(),
  };

  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController()..addListener(_onScroll);

    // Expand all sections initially to make it easy to scroll and search
    _expandedSections.addAll(PrivacySectionType.values);

    // Subtle fade and slide page entrance animation
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entranceCtrl, curve: ServioMotion.spring));

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final show = _scrollCtrl.offset > 300;
    if (show != _showScrollToTop) {
      setState(() => _showScrollToTop = show);
    }
  }

  void _scrollToTop() {
    _scrollCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  /// Smoothly scrolls to the designated section card.
  void _scrollToSection(PrivacySectionType type) {
    final key = _sectionKeys[type];
    if (key == null) return;

    final ctx = key.currentContext;
    if (ctx == null) return;

    // Ensure it is expanded so that scrolling aligns properly with full content
    if (!_expandedSections.contains(type)) {
      setState(() => _expandedSections.add(type));
    }

    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      alignment: 0.08,
    );
  }

  /// Toggles the expansion state of a section card.
  void _toggleSection(PrivacySectionType type) {
    setState(() {
      if (_expandedSections.contains(type)) {
        _expandedSections.remove(type);
      } else {
        _expandedSections.add(type);
      }
    });
  }

  /// Exports the entire policy text dynamically to the user's clipboard.
  Future<void> _copyPolicyToClipboard() async {
    final buffer = StringBuffer();
    buffer.writeln('SERVIO PRIVACY POLICY');
    buffer.writeln('Last Updated: May 2026');
    buffer.writeln();

    for (final sec in _privacySections) {
      buffer.writeln('${sec.sectionId}. ${sec.title}');
      buffer.writeln();
      for (final p in sec.paragraphs) {
        if (p.subtitle != null) {
          buffer.writeln(p.subtitle);
        }
        if (p.text != null) {
          buffer.writeln(p.text);
        }
        if (p.bulletPoints != null) {
          for (final pt in p.bulletPoints!) {
            buffer.writeln('• $pt');
          }
        }
        buffer.writeln();
      }
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString().trim()));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: <Widget>[
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Privacy Policy copied to clipboard.'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Interactive search matching logic that checks if the query matches the content.
  bool _sectionContainsQuery(PrivacySection section, String query) {
    if (query.isEmpty) return false;
    final lowercaseQuery = query.toLowerCase();

    if (section.title.toLowerCase().contains(lowercaseQuery)) return true;
    for (final p in section.paragraphs) {
      if (p.subtitle?.toLowerCase().contains(lowercaseQuery) ?? false) return true;
      if (p.text?.toLowerCase().contains(lowercaseQuery) ?? false) return true;
      if (p.bulletPoints?.any((pt) => pt.toLowerCase().contains(lowercaseQuery)) ?? false) {
        return true;
      }
    }
    return false;
  }

  /// Handles real-time search typing and auto-expands sections with matches.
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isNotEmpty) {
        for (final sec in _privacySections) {
          if (_sectionContainsQuery(sec, query)) {
            _expandedSections.add(sec.type);
          }
        }
      }
    });
  }

  /// Custom RichText builder that dynamically highlights query matches.
  List<TextSpan> _highlightText(BuildContext context, String text, String query) {
    if (query.isEmpty) {
      return [TextSpan(text: text)];
    }

    final List<TextSpan> spans = [];
    final lowercaseText = text.toLowerCase();
    final lowercaseQuery = query.toLowerCase();

    int start = 0;
    int indexOfMatch = lowercaseText.indexOf(lowercaseQuery, start);

    while (indexOfMatch != -1) {
      if (indexOfMatch > start) {
        spans.add(TextSpan(text: text.substring(start, indexOfMatch)));
      }

      final matchText = text.substring(indexOfMatch, indexOfMatch + query.length);
      spans.add(TextSpan(
        text: matchText,
        style: TextStyle(
          backgroundColor: Colors.yellow.withValues(alpha: 0.38),
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ));

      start = indexOfMatch + query.length;
      indexOfMatch = lowercaseText.indexOf(lowercaseQuery, start);
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final isTablet = MediaQuery.sizeOf(context).width >= 700;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: AnimatedScale(
        scale: _showScrollToTop ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        child: FloatingActionButton(
          mini: true,
          onPressed: _scrollToTop,
          backgroundColor: servio.accent,
          foregroundColor: Colors.white,
          tooltip: 'Scroll to top',
          child: const Icon(Icons.arrow_upward_rounded),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: CustomScrollView(
                  controller: _scrollCtrl,
                  slivers: <Widget>[
                    // ── STICKY APP BAR ───────────────────────────────────────────────
                    SliverAppBar(
                      pinned: true,
                      floating: true,
                      backgroundColor: theme.scaffoldBackgroundColor,
                      elevation: 0,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Back',
                      ),
                      title: _isSearching
                          ? TextField(
                              controller: _searchCtrl,
                              autofocus: true,
                              decoration: const InputDecoration(
                                hintText: 'Search policy…',
                                border: InputBorder.none,
                              ),
                              style: theme.textTheme.titleMedium,
                              onChanged: _onSearchChanged,
                            )
                          : const Text('Privacy Policy'),
                      actions: <Widget>[
                        if (_isSearching)
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              setState(() {
                                _isSearching = false;
                                _searchCtrl.clear();
                                _searchQuery = '';
                              });
                            },
                            tooltip: 'Clear search',
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.search_rounded),
                            onPressed: () => setState(() => _isSearching = true),
                            tooltip: 'Search privacy policy',
                          ),
                        IconButton(
                          icon: const Icon(Icons.copy_all_rounded),
                          onPressed: _copyPolicyToClipboard,
                          tooltip: 'Copy full policy',
                        ),
                      ],
                    ),

                    // ── BODY CONTENT ─────────────────────────────────────────────────
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 24.0 : 16.0,
                        vertical: 12.0,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          <Widget>[
                            // ── Last Updated Card ──────────────────────────────────────
                            Padding(
                              key: const ValueKey<String>('last-updated-card'),
                              padding: const EdgeInsets.only(bottom: 20),
                              child: _LastUpdatedCard(theme: theme, servio: servio),
                            ),

                            // ── Table of Contents ──────────────────────────────────────
                            if (!_isSearching) ...[
                              Text(
                                'Table of Contents',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: servio.accent,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 46,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _privacySections.length,
                                  itemBuilder: (context, index) {
                                    final sec = _privacySections[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8.0, bottom: 4.0),
                                      child: ActionChip(
                                        label: Text(
                                          '${sec.sectionId}. ${sec.title}',
                                          style: theme.textTheme.labelMedium?.copyWith(
                                            color: servio.accent,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        backgroundColor: servio.backgroundSoft,
                                        side: BorderSide(
                                          color: servio.accent.withValues(alpha: 0.14),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(ServioRadius.full),
                                        ),
                                        onPressed: () => _scrollToSection(sec.type),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // ── Search Matches Summary Banner ──────────────────────────
                            if (_searchQuery.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: Text(
                                  'Showing matching search results for "$_searchQuery":',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: servio.accent,
                                  ),
                                ),
                              ),
                            ],

                            // ── Sections List ──────────────────────────────────────────
                            ..._privacySections.map((sec) {
                              final isQueryMatched = _searchQuery.isEmpty ||
                                  _sectionContainsQuery(sec, _searchQuery);

                              if (!isQueryMatched) {
                                return const SizedBox.shrink();
                              }

                              final isExpanded = _expandedSections.contains(sec.type);

                              return Padding(
                                key: _sectionKeys[sec.type],
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _SectionCard(
                                  section: sec,
                                  isExpanded: isExpanded,
                                  searchQuery: _searchQuery,
                                  highlightBuilder: _highlightText,
                                  onToggle: () => _toggleSection(sec.type),
                                ),
                              );
                            }),

                            const SizedBox(height: 48),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A premium info-card displaying "Last Updated" information.
class _LastUpdatedCard extends StatelessWidget {
  const _LastUpdatedCard({
    required this.theme,
    required this.servio,
  });

  final ThemeData theme;
  final ServioThemeExtension servio;

  @override
  Widget build(BuildContext context) {
    return ServioCard(
      radius: ServioRadius.lg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: servio.backgroundSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_rounded,
                color: servio.accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Last Updated',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: servio.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'May 2026',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: servio.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: servio.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(ServioRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.verified_user_rounded, color: servio.success, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Active',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: servio.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dynamic, collapsible section card styled with rotating indicators and highlights.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.isExpanded,
    required this.searchQuery,
    required this.highlightBuilder,
    required this.onToggle,
  });

  final PrivacySection section;
  final bool isExpanded;
  final String searchQuery;
  final List<TextSpan> Function(BuildContext, String, String) highlightBuilder;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final isContactUs = section.type == PrivacySectionType.contactUs;

    // Highlight card background for the contact card
    final cardDecoration = isContactUs
        ? BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                servio.accent.withValues(alpha: 0.08),
                servio.backgroundSoft,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: servio.accent.withValues(alpha: 0.20), width: 1.5),
          )
        : null;

    return ServioCard(
      radius: ServioRadius.lg,
      child: Container(
        decoration: cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Section Card Header
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isContactUs
                            ? servio.accent.withValues(alpha: 0.16)
                            : servio.backgroundSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          section.sectionId,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: servio.accent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: highlightBuilder(context, section.title, searchQuery),
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: servio.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: servio.textSecondary,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Section Card Body (Smooth expandable animation)
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    ...section.paragraphs.map((p) => _buildParagraph(context, p)),
                  ],
                ),
              ),
              crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParagraph(BuildContext context, PrivacyParagraph p) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (p.subtitle != null) ...[
            Text.rich(
              TextSpan(
                children: highlightBuilder(context, p.subtitle!, searchQuery),
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: servio.accent,
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (p.text != null) ...[
            Text.rich(
              TextSpan(
                children: highlightBuilder(context, p.text!, searchQuery),
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: servio.textSecondary,
                height: 1.58,
              ),
            ),
          ],
          if (p.bulletPoints != null) ...[
            const SizedBox(height: 8),
            ...p.bulletPoints!.map((pt) => Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 6.5, right: 10),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: servio.accent.withValues(alpha: 0.60),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: highlightBuilder(context, pt, searchQuery),
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: servio.textSecondary,
                            height: 1.54,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

/// Centralized, structured static Privacy Policy sections database.
const List<PrivacySection> _privacySections = <PrivacySection>[
  PrivacySection(
    type: PrivacySectionType.introduction,
    sectionId: '1',
    title: 'Introduction',
    paragraphs: <PrivacyParagraph>[
      PrivacyParagraph(
        text: 'Welcome to SERVIO, an AI-powered home maintenance, repair, renovation, and finishing services marketplace. SERVIO is committed to protecting your privacy and ensuring the security of your personal information.',
      ),
      PrivacyParagraph(
        text: 'This Privacy Policy explains how we collect, use, store, share, and protect information when you use the SERVIO mobile application, website, and related services.',
      ),
      PrivacyParagraph(
        text: 'By using SERVIO, you agree to the practices described in this Privacy Policy.',
      ),
    ],
  ),
  PrivacySection(
    type: PrivacySectionType.informationCollect,
    sectionId: '2',
    title: 'Information We Collect',
    paragraphs: <PrivacyParagraph>[
      PrivacyParagraph(
        subtitle: '2.1 Information You Provide',
        text: 'When creating an account or using our services, we may collect:',
        bulletPoints: <String>[
          'Full name',
          'Email address',
          'Phone number',
          'Profile information',
          'Home or service location details',
          'Service requests and descriptions',
          'Photos uploaded for maintenance or renovation requests',
          'Reviews, ratings, and feedback',
          'Messages exchanged through the platform',
          'Verification documents submitted by service providers',
        ],
      ),
      PrivacyParagraph(
        subtitle: '2.2 Automatically Collected Information',
        text: 'We may automatically collect:',
        bulletPoints: <String>[
          'Device information',
          'Operating system information',
          'IP address',
          'Application usage data',
          'Login activity',
          'Location information (when permitted)',
          'Performance and diagnostic data',
        ],
      ),
      PrivacyParagraph(
        subtitle: '2.3 Payment Information',
        text: 'SERVIO uses secure third-party payment providers to process transactions. We do not store complete payment card information on our servers. Payment information is processed through authorized payment service providers using industry-standard security measures.',
      ),
    ],
  ),
  PrivacySection(
    type: PrivacySectionType.howWeUse,
    sectionId: '3',
    title: 'How We Use Your Information',
    paragraphs: <PrivacyParagraph>[
      PrivacyParagraph(
        text: 'We use collected information to:',
        bulletPoints: <String>[
          'Create and manage user accounts',
          'Process service bookings and requests',
          'Match users with suitable technicians and service providers',
          'Provide AI-powered recommendations',
          'Generate renovation and finishing cost estimates',
          'Calculate material quantities and project budgets',
          'Process payments and escrow transactions',
          'Send notifications and booking updates',
          'Provide customer support',
          'Improve platform performance and user experience',
          'Detect fraud, abuse, or security threats',
          'Comply with legal obligations',
        ],
      ),
    ],
  ),
  PrivacySection(
    type: PrivacySectionType.aiProcessing,
    sectionId: '4',
    title: 'Artificial Intelligence and Data Processing',
    paragraphs: <PrivacyParagraph>[
      PrivacyParagraph(
        text: 'SERVIO uses Artificial Intelligence (AI) and Machine Learning technologies to:',
        bulletPoints: <String>[
          'Recommend services and technicians',
          'Classify maintenance issues',
          'Estimate renovation and finishing costs',
          'Calculate material requirements',
          'Improve platform recommendations',
        ],
      ),
      PrivacyParagraph(
        text: 'AI-generated recommendations and estimates are intended to assist users in decision-making and should be considered estimates rather than guaranteed outcomes.',
      ),
    ],
  ),
  PrivacySection(
    type: PrivacySectionType.locationInfo,
    sectionId: '5',
    title: 'Location Information',
    paragraphs: <PrivacyParagraph>[
      PrivacyParagraph(
        text: 'Location information may be used to:',
        bulletPoints: <String>[
          'Identify nearby service providers',
          'Improve technician recommendations',
          'Estimate travel distances and service availability',
          'Enhance booking accuracy',
        ],
      ),
      PrivacyParagraph(
        text: 'Location services can be disabled through your device settings; however, some features may become limited.',
      ),
    ],
  ),
  PrivacySection(
    type: PrivacySectionType.sharing,
    sectionId: '6',
    title: 'Information Sharing',
    paragraphs: <PrivacyParagraph>[
      PrivacyParagraph(
        text: 'SERVIO does not sell personal information.',
      ),
      PrivacyParagraph(
        text: 'We may share information with:',
        bulletPoints: <String>[
          'Verified technicians and service providers involved in fulfilling your requests',
          'Payment service providers for transaction processing',
          'Cloud hosting and infrastructure providers',
          'Customer support and dispute resolution teams',
          'Government authorities when legally required',
          'Service partners necessary for platform operations',
        ],
      ),
      PrivacyParagraph(
        text: 'Information is shared only to the extent necessary for providing services and operating the platform.',
      ),
    ],
  ),
  PrivacySection(
    type: PrivacySectionType.escrow,
    sectionId: '7',
    title: 'Escrow and Payment Protection',
    paragraphs: <PrivacyParagraph>[
      PrivacyParagraph(
        text: 'SERVIO may use an escrow-based payment model where payments are temporarily held until service completion is confirmed or disputes are resolved.',
      ),
      PrivacyParagraph(
        text: 'Transaction-related information may be processed to:',
        bulletPoints: <String>[
          'Verify payments',
          'Prevent fraud',
          'Manage disputes',
          'Release funds appropriately',
        ],
      ),
    ],
  ),
  PrivacySection(
    type: PrivacySectionType.security,
    sectionId: '8',
    title: 'Data Security',
    paragraphs: <PrivacyParagraph>[
      PrivacyParagraph(
        text: 'SERVIO implements reasonable technical and organizational measures to protect user data, including:',
        bulletPoints: <String>[
          'Encrypted data transmission',
          'Secure authentication mechanisms',
          'Password hashing',
          'Access controls',
          'Security monitoring',
          'Regular security reviews',
        ],
      ),
      PrivacyParagraph(
        text: 'While we strive to protect your information, no online platform can guarantee absolute security.',
      ),
    ],
  ),
  PrivacySection(
    type: PrivacySectionType.userRights,
    sectionId: '9',
    title: 'User Rights',
    paragraphs: <PrivacyParagraph>[
      PrivacyParagraph(
        text: 'Depending on applicable laws, users may have the right to:',
        bulletPoints: <String>[
          'Access personal information',
          'Correct inaccurate information',
          'Update account details',
          'Request deletion of personal data',
          'Withdraw consent where applicable',
          'Request a copy of stored personal information',
        ],
      ),
      PrivacyParagraph(
        text: 'Requests may be submitted through SERVIO support channels.',
      ),
    ],
  ),
  PrivacySection(
    type: PrivacySectionType.retention,
    sectionId: '10',
    title: 'Data Retention',
    paragraphs: <PrivacyParagraph>[
      PrivacyParagraph(
        text: 'We retain personal information only as long as necessary to:',
        bulletPoints: <String>[
          'Provide platform services',
          'Maintain booking records',
          'Resolve disputes',
          'Meet legal and regulatory requirements',
          'Improve platform functionality',
        ],
      ),
      PrivacyParagraph(
        text: 'When information is no longer required, it may be deleted, anonymized, or securely archived.',
      ),
    ],
  ),
  PrivacySection(
    type: PrivacySectionType.publicContent,
    sectionId: '11',
    title: 'Reviews and Public Content',
    paragraphs: <PrivacyParagraph>[
      PrivacyParagraph(
        text: 'Reviews, ratings, and feedback submitted through SERVIO may be visible to other users. Users should avoid sharing sensitive personal information within public reviews or comments.',
      ),
    ],
  ),
  PrivacySection(
    type: PrivacySectionType.children,
    sectionId: '12',
    title: "Children's Privacy",
    paragraphs: <PrivacyParagraph>[
      PrivacyParagraph(
        text: 'SERVIO is not intended for individuals under the age required by applicable laws to independently use digital service platforms. We do not knowingly collect personal information from children without appropriate authorization.',
      ),
    ],
  ),
  PrivacySection(
    type: PrivacySectionType.thirdParty,
    sectionId: '13',
    title: 'Third-Party Services',
    paragraphs: <PrivacyParagraph>[
      PrivacyParagraph(
        text: 'SERVIO may integrate with third-party services such as:',
        bulletPoints: <String>[
          'Payment gateways',
          'Mapping and location services',
          'Notification services',
          'Analytics services',
        ],
      ),
      PrivacyParagraph(
        text: 'These third parties operate under their own privacy policies and terms of service.',
      ),
    ],
  ),
  PrivacySection(
    type: PrivacySectionType.compliance,
    sectionId: '14',
    title: 'Data Privacy Compliance',
    paragraphs: <PrivacyParagraph>[
      PrivacyParagraph(
        text: 'SERVIO is designed to follow recognized privacy and security principles, including data protection practices aligned with international privacy standards and applicable regulations.',
      ),
    ],
  ),
  PrivacySection(
    type: PrivacySectionType.changes,
    sectionId: '15',
    title: 'Changes to This Privacy Policy',
    paragraphs: <PrivacyParagraph>[
      PrivacyParagraph(
        text: 'SERVIO may update this Privacy Policy from time to time. Updated versions will be published within the application and website. Continued use of the platform after updates indicates acceptance of the revised policy.',
      ),
    ],
  ),
  PrivacySection(
    type: PrivacySectionType.contactUs,
    sectionId: '16',
    title: 'Contact Us',
    paragraphs: <PrivacyParagraph>[
      PrivacyParagraph(
        text: 'For privacy-related questions, requests, or concerns, users may contact SERVIO through the platform\'s support channels.',
      ),
      PrivacyParagraph(
        text: 'SERVIO\nSmarter Services for Every Home',
      ),
    ],
  ),
];
