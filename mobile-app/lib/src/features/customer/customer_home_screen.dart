import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/booking_model.dart';
import '../../core/state/app_state.dart';
import '../../core/state/workers_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_bottom_navigation_bar.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../../design_system/widgets/servio_section_heading.dart';
import '../../design_system/widgets/servio_status_chip.dart';
import 'ai_smart_match_screen.dart';
import 'ai_finishing_estimator_screen.dart';
import 'customer_profile_screen.dart';
import 'my_bookings_screen.dart';
import 'service_detail_screen.dart';
import 'services_marketplace_screen.dart';
import 'technician_listing_screen.dart';
import 'technician_profile_screen.dart';
import '../messages/messages_screen.dart';
import '../shared/notifications_screen.dart';
import '../shared/search_results_screen.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final userName = context.watch<SessionProvider>().account?.name ?? 'there';
    final unreadMessages = context.watch<MessagesProvider>().totalUnread;
    final locale = context.watch<LocaleProvider>().locale.languageCode;
    final recentBookings = context.watch<BookingsProvider>().upcoming;
    final featuredTechs =
        context.watch<WorkersProvider>().workers.take(3).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bottomNavigationBar: ServioBottomNavigationBar(
        items: <ServioBottomNavItem>[
          const ServioBottomNavItem(icon: Icons.home_rounded, label: 'Home'),
          const ServioBottomNavItem(
              icon: Icons.grid_view_rounded, label: 'Services'),
          const ServioBottomNavItem(
            icon: Icons.auto_awesome_rounded,
            label: 'Smart Match',
            highlighted: true,
          ),
          ServioBottomNavItem(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Messages',
            badgeCount: unreadMessages,
          ),
          const ServioBottomNavItem(
              icon: Icons.person_rounded, label: 'Profile'),
        ],
        currentIndex: 0,
        onTap: (int index) {
          if (index == 1) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ServicesMarketplaceScreen(),
              ),
            );
          } else if (index == 2) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AiSmartMatchScreen(),
              ),
            );
          } else if (index == 3) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const MessagesScreen(),
              ),
            );
          } else if (index == 4) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CustomerProfileScreen(),
              ),
            );
          }
        },
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverPersistentHeader(
              pinned: true,
              delegate: _FloatingHeaderDelegate(
                minExtentValue: 84,
                maxExtentValue: 84,
                child: Container(
                  height: 84,
                  color: Theme.of(context).scaffoldBackgroundColor,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            border: Border.all(color: servio.accent),
                            borderRadius:
                                BorderRadius.circular(ServioRadius.full),
                            boxShadow: ServioShadows.rest,
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(Icons.location_on_outlined,
                                  color: servio.accent, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Cairo, Egypt',
                                style: theme.textTheme.labelLarge
                                    ?.copyWith(color: servio.accent),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _CircleIconButton(
                        icon: Icons.notifications_none_rounded,
                        showUnreadDot: true,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const NotificationsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                  horizontal: ServioSpacing.screenPadding),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  <Widget>[
                    const SizedBox(height: 8),
                    Text(
                      'WELCOME BACK',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: servio.textSecondary,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(userName.split(' ').first,
                        style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 20),
                    TextField(
                      readOnly: true,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                const SearchResultsScreen(query: 'service'),
                          ),
                        );
                      },
                      decoration: InputDecoration(
                        hintText: 'What service do you need?',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: servio.surfaceAlt,
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(ServioRadius.full),
                          borderSide: BorderSide(color: servio.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(ServioRadius.full),
                          borderSide:
                              BorderSide(color: servio.accent, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      button: true,
                      enabled: true,
                      label: 'Book a Service',
                      child: ServioPrimaryButton(
                        label: 'Book a Service',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ServicesMarketplaceScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    _HeroBannerCard(
                      badgeLabel: 'NEW FEATURE',
                      title: 'AI Diagnosis for Repairs',
                      body: 'Snap a photo or describe your issue.',
                      ctaLabel: 'Ask AI Assistant',
                      icon: Icons.auto_awesome_rounded,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AiSmartMatchScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _HeroBannerCard(
                      title: 'Instant Finishing Estimates',
                      body:
                          'Estimate room projects with calm, transparent pricing.',
                      ctaLabel: 'Calculate Cost',
                      icon: Icons.calculate_rounded,
                      useWarmGradient: true,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AiFinishingEstimatorScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: ServioSpacing.sectionGap),
                    ServioSectionHeading(
                      title: 'Services',
                      actionLabel: 'See All',
                      onActionTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ServicesMarketplaceScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    GridView.count(
                      crossAxisCount: 4,
                      childAspectRatio: 0.9,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: <Widget>[
                        _ServiceItem(
                          icon: Icons.cleaning_services_rounded,
                          label: locale == 'ar' ? 'تنظيف' : 'Cleaning',
                        ),
                        _ServiceItem(
                          icon: Icons.plumbing_rounded,
                          label: locale == 'ar' ? 'سباكة' : 'Plumbing',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ServiceDetailScreen(
                                  serviceId: 'plumbing'),
                            ),
                          ),
                        ),
                        _ServiceItem(
                          icon: Icons.electrical_services_rounded,
                          label: locale == 'ar' ? 'كهرباء' : 'Electrical',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ServiceDetailScreen(
                                  serviceId: 'electrical'),
                            ),
                          ),
                        ),
                        _ServiceItem(
                          icon: Icons.format_paint_rounded,
                          label: locale == 'ar' ? 'دهان' : 'Painting',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ServiceDetailScreen(
                                  serviceId: 'painting'),
                            ),
                          ),
                        ),
                        _ServiceItem(
                          icon: Icons.ac_unit_rounded,
                          label: locale == 'ar' ? 'تكييف' : 'HVAC',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ServiceDetailScreen(
                                  serviceId: 'ac-maintenance'),
                            ),
                          ),
                        ),
                        _ServiceItem(
                          icon: Icons.handyman_rounded,
                          label: locale == 'ar' ? 'نجارة' : 'Carpentry',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ServiceDetailScreen(
                                  serviceId: 'carpentry'),
                            ),
                          ),
                        ),
                        _ServiceItem(
                            icon: Icons.local_shipping_rounded,
                            label: locale == 'ar' ? 'نقل' : 'Moving'),
                        _ServiceItem(
                          icon: Icons.more_horiz_rounded,
                          label: locale == 'ar' ? 'المزيد' : 'More',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ServicesMarketplaceScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: ServioSpacing.sectionGap),
                    ServioSectionHeading(
                      title:
                          locale == 'ar' ? 'النشاط الأخير' : 'Recent Activity',
                      actionLabel: locale == 'ar' ? 'عرض الكل' : 'See All',
                      onActionTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const MyBookingsScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (recentBookings.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(
                            bottom: ServioSpacing.sectionGap),
                        child: Text(
                          locale == 'ar'
                              ? 'لا توجد حجوزات نشطة.'
                              : 'No active bookings yet.',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: servio.textSecondary),
                        ),
                      )
                    else
                      ...recentBookings.take(2).map((BookingModel booking) =>
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ServioCard(
                              radius: ServioRadius.md,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Container(
                                    width: 4,
                                    height: 108,
                                    decoration: BoxDecoration(
                                      color: booking.status ==
                                              BookingStatus.inProgress
                                          ? servio.info
                                          : servio.warning,
                                      borderRadius: BorderRadius.circular(
                                          ServioRadius.full),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Row(
                                          children: <Widget>[
                                            Expanded(
                                              child: Text(
                                                booking.serviceName,
                                                style:
                                                    theme.textTheme.titleMedium,
                                              ),
                                            ),
                                            Text(
                                              booking.amount,
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                color: servio.accent,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: <Widget>[
                                            ServioStatusChip(
                                              label: booking.status ==
                                                      BookingStatus.inProgress
                                                  ? (locale == 'ar'
                                                      ? 'قيد التنفيذ'
                                                      : 'In Progress')
                                                  : (locale == 'ar'
                                                      ? 'قادم'
                                                      : 'Upcoming'),
                                              type: booking.status ==
                                                      BookingStatus.inProgress
                                                  ? ServioStatusChipType.info
                                                  : ServioStatusChipType
                                                      .warning,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              booking.date,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: servio.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        Row(
                                          children: <Widget>[
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: () {},
                                                child: Text(locale == 'ar'
                                                    ? 'احجز مجدداً'
                                                    : 'Book Again'),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            TextButton(
                                              onPressed: () {},
                                              child: Text(locale == 'ar'
                                                  ? 'التفاصيل'
                                                  : 'View Details'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )),
                    const SizedBox(height: ServioSpacing.sectionGap),
                    ServioSectionHeading(
                      title: locale == 'ar'
                          ? 'موصى بهم لك'
                          : 'Recommended For You',
                      actionLabel: locale == 'ar' ? 'عرض الكل' : 'See All',
                      onActionTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const TechnicianListingScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 230,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: featuredTechs.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (BuildContext context, int index) {
                          final tech = featuredTechs[index];
                          return _TechnicianCard(
                            name: tech.name,
                            specialty: tech.skills.isNotEmpty
                                ? tech.skills.first
                                : 'Technician',
                            rating: tech.rating.toStringAsFixed(1),
                            reviews: '${tech.reviewCount}',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => TechnicianProfileScreen(
                                    technicianId: tech.id),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
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

class _FloatingHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _FloatingHeaderDelegate({
    required this.minExtentValue,
    required this.maxExtentValue,
    required this.child,
  });

  final double minExtentValue;
  final double maxExtentValue;
  final Widget child;

  @override
  double get minExtent => minExtentValue;

  @override
  double get maxExtent => maxExtentValue;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _FloatingHeaderDelegate oldDelegate) {
    return oldDelegate.child != child ||
        oldDelegate.minExtentValue != minExtentValue ||
        oldDelegate.maxExtentValue != maxExtentValue;
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    this.showUnreadDot = false,
    this.onTap,
  });

  final IconData icon;
  final bool showUnreadDot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(ServioRadius.full),
              boxShadow: ServioShadows.rest,
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
        if (showUnreadDot)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: ServioColors.danger,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class _HeroBannerCard extends StatelessWidget {
  const _HeroBannerCard({
    required this.title,
    required this.body,
    required this.ctaLabel,
    required this.icon,
    required this.onTap,
    this.badgeLabel,
    this.useWarmGradient = false,
  });

  final String title;
  final String body;
  final String ctaLabel;
  final IconData icon;
  final VoidCallback onTap;
  final String? badgeLabel;
  final bool useWarmGradient;

  @override
  Widget build(BuildContext context) {
    final gradient =
        useWarmGradient ? ServioGradients.warm : ServioGradients.brand;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(ServioRadius.xl),
        boxShadow: ServioShadows.rest,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (badgeLabel != null) ...<Widget>[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: ServioGradients.accent,
                      borderRadius: BorderRadius.circular(ServioRadius.full),
                    ),
                    child: Text(
                      badgeLabel!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: useWarmGradient
                            ? ServioColors.textPrimaryLight
                            : Colors.white,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: useWarmGradient
                            ? ServioColors.textSecondaryLight
                            : Colors.white.withValues(alpha: 0.88),
                      ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color:
                          useWarmGradient ? ServioColors.accent : Colors.white,
                    ),
                    foregroundColor:
                        useWarmGradient ? ServioColors.accent : Colors.white,
                  ),
                  onPressed: onTap,
                  child: Text('$ctaLabel ->'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color:
                  Colors.white.withValues(alpha: useWarmGradient ? 0.45 : 0.12),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              icon,
              size: 40,
              color: useWarmGradient ? ServioColors.accent : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceItem extends StatelessWidget {
  const _ServiceItem({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: servio.backgroundSoft,
              borderRadius: BorderRadius.circular(ServioRadius.full),
            ),
            child: Icon(icon, color: servio.accent),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TechnicianCard extends StatelessWidget {
  const _TechnicianCard({
    required this.name,
    required this.specialty,
    required this.rating,
    required this.reviews,
    required this.onTap,
  });

  final String name;
  final String specialty;
  final String rating;
  final String reviews;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return SizedBox(
      width: 220,
      child: ServioCard(
        radius: ServioRadius.lg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: ServioGradients.warm,
                    shape: BoxShape.circle,
                    border: Border.all(color: servio.accent, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      name.split(' ').take(2).map((String e) => e[0]).join(),
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: ServioColors.deepBrown),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: ServioGradients.accent,
                    borderRadius: BorderRadius.circular(ServioRadius.full),
                  ),
                  child: Text(
                    'Verified',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: servio.backgroundSoft,
                    borderRadius: BorderRadius.circular(ServioRadius.sm),
                  ),
                  child: Text(
                    specialty,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: servio.accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '$rating rating  •  $reviews reviews',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: servio.textSecondary),
            ),
            const Spacer(),
            TextButton(
              onPressed: onTap,
              child: const Text('View Profile'),
            ),
          ],
        ),
      ),
    );
  }
}
