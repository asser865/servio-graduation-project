import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../../design_system/widgets/servio_section_heading.dart';
import '../customer/services_marketplace_screen.dart';
import 'contact_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('About SERVIO'),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: _AboutHero(
                onExplore: () => _openServices(context),
                onContact: () => _openContact(context),
              ),
            ),
            SliverToBoxAdapter(
              child: ColoredBox(
                color: servio.backgroundSoft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: _StatsStrip(),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                ServioSpacing.screenPadding,
                ServioSpacing.sectionGap,
                ServioSpacing.screenPadding,
                0,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  <Widget>[
                    const _StorySection(),
                    const SizedBox(height: ServioSpacing.sectionGap),
                    const _DifferenceSection(),
                    const SizedBox(height: ServioSpacing.sectionGap),
                    const _ValuesSection(),
                    const SizedBox(height: ServioSpacing.sectionGap),
                    _CtaBanner(
                      onStarted: () => _openServices(context),
                      onContact: () => _openContact(context),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _openServices(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ServicesMarketplaceScreen(),
      ),
    );
  }

  static void _openContact(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ContactScreen(),
      ),
    );
  }
}

class _AboutHero extends StatelessWidget {
  const _AboutHero({
    required this.onExplore,
    required this.onContact,
  });

  final VoidCallback onExplore;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 42, 20, 34),
      decoration: const BoxDecoration(gradient: ServioGradients.brand),
      child: Stack(
        children: <Widget>[
          PositionedDirectional(
            top: -48,
            end: -44,
            child: _SoftDisc(size: 150, color: ServioColors.accentLight),
          ),
          PositionedDirectional(
            bottom: -56,
            start: -48,
            child: _SoftDisc(size: 130, color: ServioColors.accent),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: _Kicker(
                  icon: Icons.verified_user_outlined,
                  label: 'Who we are',
                  dark: true,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Built for homeowners.',
                textAlign: TextAlign.center,
                style: theme.textTheme.displayLarge?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Trusted by thousands.',
                textAlign: TextAlign.center,
                style: theme.textTheme.displayLarge?.copyWith(
                  color: ServioColors.accentLight,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'SERVIO connects you with verified professionals for home maintenance, repairs, and improvements, making every booking simple, clear, and reliable.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final stack = constraints.maxWidth < 420;
                  final buttons = <Widget>[
                    Expanded(
                      child: ServioPrimaryButton(
                        label: 'Explore Services',
                        onPressed: onExplore,
                      ),
                    ),
                    const SizedBox(width: 12, height: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onContact,
                        style: OutlinedButton.styleFrom(
                          side:
                              const BorderSide(color: Colors.white, width: 1.4),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Get in Touch'),
                      ),
                    ),
                  ];

                  if (stack) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        buttons[0],
                        buttons[1],
                        buttons[2],
                      ],
                    );
                  }

                  return Row(children: buttons);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip();

  final List<_StatData> stats = const <_StatData>[
    _StatData('2,500', 'Verified Professionals', ServioGradients.brand),
    _StatData('15,000', 'Bookings Completed', ServioGradients.warm),
    _StatData('98%', 'Satisfaction Rate', ServioGradients.accent),
    _StatData('24/7', 'Customer Support', ServioGradients.brand),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final compact = constraints.maxWidth < 560;
        if (compact) {
          return SizedBox(
            height: 132,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: stats.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (BuildContext context, int index) {
                return SizedBox(
                  width: 178,
                  child: _StatCard(data: stats[index]),
                );
              },
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: stats
                .map(
                  (_StatData data) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _StatCard(data: data),
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _StorySection extends StatelessWidget {
  const _StorySection();

  static const List<_ChapterData> _chapters = <_ChapterData>[
    _ChapterData(
      '01',
      'The Problem',
      'Homeowners often struggle to find professionals they can trust, with uncertainty about quality, unclear pricing, and inconsistent communication.',
    ),
    _ChapterData(
      '02',
      'The Spark',
      'We asked what would happen if every professional was verified, every review was real, and every booking was transparent. That question became SERVIO.',
    ),
    _ChapterData(
      '03',
      'The Result',
      'Today, SERVIO helps homeowners discover verified professionals, compare transparent reviews, and book services with confidence in just a few steps.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const ServioSectionHeading(title: 'Our Story'),
        const SizedBox(height: 14),
        ServioCard(
          radius: ServioRadius.lg,
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: ServioGradients.warm,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(ServioRadius.lg),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(ServioRadius.md),
                        border: Border.all(color: servio.accent),
                      ),
                      child: const Icon(
                        Icons.auto_stories_outlined,
                        color: ServioColors.deepBrown,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'From frustration to a mission.',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: ServioColors.deepBrown,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'A marketplace built around confidence.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: ServioColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: _chapters
                      .map(
                        (_ChapterData chapter) =>
                            _ChapterTile(chapter: chapter),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DifferenceSection extends StatelessWidget {
  const _DifferenceSection();

  static const List<_FeatureData> _features = <_FeatureData>[
    _FeatureData(
      Icons.verified_outlined,
      'Verified Professionals',
      'Each provider goes through profile, identity, and quality checks before joining the platform.',
    ),
    _FeatureData(
      Icons.star_outline_rounded,
      'Real Customer Reviews',
      'Authentic, verified feedback helps you compare and choose with complete confidence.',
    ),
    _FeatureData(
      Icons.lock_outline_rounded,
      'Secure Payments',
      'Protected checkout with clear invoices and transparent, upfront service pricing.',
    ),
    _FeatureData(
      Icons.bolt_rounded,
      'Instant Booking',
      'Book the right professional in seconds with no lengthy calls, delays, or friction.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionIntro(
          kicker: 'Why choose us',
          title: 'What Makes SERVIO Different',
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final columns = constraints.maxWidth >= 700 ? 4 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _features.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: columns == 4 ? 0.9 : 0.82,
              ),
              itemBuilder: (BuildContext context, int index) {
                return _FeatureCard(data: _features[index]);
              },
            );
          },
        ),
      ],
    );
  }
}

class _ValuesSection extends StatelessWidget {
  const _ValuesSection();

  static const List<_ValueData> _values = <_ValueData>[
    _ValueData('01', 'Trust',
        'We prioritize safety, reliability, and accountability in every interaction.'),
    _ValueData('02', 'Transparency',
        'Clear profiles, honest reviews, and upfront pricing. No hidden surprises.'),
    _ValueData('03', 'Quality',
        'We focus on dependable outcomes and maintaining high service standards.'),
    _ValueData('04', 'Customer First',
        'Every feature and update is built to improve your experience.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SectionIntro(
          kicker: 'What drives us',
          title: 'Our Core Values',
          body: 'Every decision we make is guided by these four principles.',
          centered: true,
        ),
        const SizedBox(height: 16),
        ..._values.map(
          (_ValueData value) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ValueCard(data: value),
          ),
        ),
      ],
    );
  }
}

class _CtaBanner extends StatelessWidget {
  const _CtaBanner({
    required this.onStarted,
    required this.onContact,
  });

  final VoidCallback onStarted;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: ServioGradients.brand,
        borderRadius: BorderRadius.circular(ServioRadius.xl),
        boxShadow: ServioShadows.elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Ready to experience the difference?',
            style: theme.textTheme.headlineLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Join thousands of homeowners who trust SERVIO for their home services.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          ServioPrimaryButton(label: 'Get Started Free', onPressed: onStarted),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onContact,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white, width: 1.4),
              foregroundColor: Colors.white,
            ),
            child: const Text('Contact Us'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});

  final _StatData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return ServioCard(
      radius: ServioRadius.lg,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      data.value,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data.label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: servio.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
                height: 4, decoration: BoxDecoration(gradient: data.gradient)),
          ],
        ),
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({required this.chapter});

  final _ChapterData chapter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ServioColors.tint(servio.accent),
              borderRadius: BorderRadius.circular(ServioRadius.sm),
              border: Border.all(color: servio.accent.withValues(alpha: 0.28)),
            ),
            child: Center(
              child: Text(
                chapter.number,
                style:
                    theme.textTheme.labelLarge?.copyWith(color: servio.accent),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(chapter.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  chapter.body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: servio.textSecondary,
                    height: 1.55,
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

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.data});

  final _FeatureData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return ServioCard(
      radius: ServioRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: ServioColors.tint(servio.accent),
              borderRadius: BorderRadius.circular(ServioRadius.md),
              border: Border.all(color: servio.accent.withValues(alpha: 0.24)),
            ),
            child: Icon(data.icon, color: servio.accent),
          ),
          const SizedBox(height: 14),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              data.body,
              textAlign: TextAlign.center,
              overflow: TextOverflow.fade,
              style: theme.textTheme.bodySmall?.copyWith(
                color: servio.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueCard extends StatelessWidget {
  const _ValueCard({required this.data});

  final _ValueData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return ServioCard(
      radius: ServioRadius.lg,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        child: Stack(
          children: <Widget>[
            PositionedDirectional(
              top: -4,
              end: 12,
              child: ShaderMask(
                shaderCallback: (Rect bounds) =>
                    ServioGradients.accent.createShader(bounds),
                child: Text(
                  data.number,
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: ServioGradients.accent,
                      borderRadius: BorderRadius.circular(ServioRadius.full),
                    ),
                    child: Text(
                      data.number,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(data.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    data.body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: servio.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 0,
              child: Container(
                height: 4,
                decoration:
                    const BoxDecoration(gradient: ServioGradients.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionIntro extends StatelessWidget {
  const _SectionIntro({
    required this.kicker,
    required this.title,
    this.body,
    this.centered = false,
  });

  final String kicker;
  final String title;
  final String? body;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Column(
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          kicker.toUpperCase(),
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: theme.textTheme.labelSmall?.copyWith(
            color: servio.accent,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: theme.textTheme.headlineLarge,
        ),
        if (body != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            body!,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: servio.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _Kicker extends StatelessWidget {
  const _Kicker({
    required this.icon,
    required this.label,
    this.dark = false,
  });

  final IconData icon;
  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = dark ? ServioColors.accentLight : context.servio.accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ServioRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftDisc extends StatelessWidget {
  const _SoftDisc({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.14),
        ),
      ),
    );
  }
}

class _StatData {
  const _StatData(this.value, this.label, this.gradient);

  final String value;
  final String label;
  final LinearGradient gradient;
}

class _ChapterData {
  const _ChapterData(this.number, this.title, this.body);

  final String number;
  final String title;
  final String body;
}

class _FeatureData {
  const _FeatureData(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;
}

class _ValueData {
  const _ValueData(this.number, this.title, this.body);

  final String number;
  final String title;
  final String body;
}
