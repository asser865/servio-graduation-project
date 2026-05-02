import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/booking_model.dart';
import '../../core/state/app_state.dart';
import '../../core/state/workers_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_bottom_navigation_bar.dart';
import '../../design_system/widgets/servio_card.dart';

import '../../design_system/widgets/servio_section_heading.dart';
import '../../design_system/widgets/servio_status_chip.dart';
import 'ai_smart_match_screen.dart';

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
    final unreadMessages = context.watch<MessagesProvider>().totalUnread;

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
      body: const _HomeBody(),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final servio = context.servio;
    
    final userName = context.watch<SessionProvider>().account?.name ?? 'there';
    final firstName = userName.split(' ').first;
    final recentBookings = context.watch<BookingsProvider>().upcoming;
    final featuredTechs = context.watch<WorkersProvider>().workers.take(4).toList();
    final locale = context.watch<LocaleProvider>().locale.languageCode;

    // Greeting logic
    final hour = DateTime.now().hour;
    String greeting = 'Good evening';
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    }

    return Stack(
      children: <Widget>[
        // Background Hero Gradient
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: MediaQuery.of(context).padding.top + 280,
          child: Container(
            decoration: BoxDecoration(
              gradient: isDark ? ServioGradients.brandDark : ServioGradients.brand,
            ),
          ),
        ),
        // Scrollable Content
        RefreshIndicator(
          color: servio.accent,
          onRefresh: () async => Future<void>.delayed(const Duration(seconds: 1)),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: <Widget>[
                // Top Header inside SafeArea
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: ServioSpacing.screenPadding, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // Top Row: Greeting, Location, Notification
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    greeting,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: isDark ? ServioColors.navyDark.withValues(alpha: 0.7) : Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    firstName,
                                    style: theme.textTheme.headlineLarge?.copyWith(
                                      color: isDark ? ServioColors.navyDark : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Location Selector
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: (isDark ? ServioColors.navyDark : Colors.white).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(ServioRadius.full),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.location_on_rounded, 
                                    size: 16, 
                                    color: isDark ? ServioColors.navyDark : Colors.white,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Cairo',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: isDark ? ServioColors.navyDark : Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded, 
                                    size: 16, 
                                    color: isDark ? ServioColors.navyDark : Colors.white,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Notification Bell
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
                                );
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: (isDark ? ServioColors.navyDark : Colors.white).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(ServioRadius.full),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: <Widget>[
                                    Icon(
                                      Icons.notifications_none_rounded,
                                      color: isDark ? ServioColors.navyDark : Colors.white,
                                    ),
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
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        // Search Bar embedded in hero
                        _HeroSearchBar(isDark: isDark),
                        const SizedBox(height: 60), // Space for overlap
                      ],
                    ),
                  ),
                ),
                // Overlapping Content
                Transform.translate(
                  offset: const Offset(0, -42),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: ServioSpacing.screenPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // Floating Active Booking Card
                        if (recentBookings.isNotEmpty)
                          _FloatingBookingCard(booking: recentBookings.first, locale: locale)
                        else
                          const _FloatingEmptyBookingCard(),
                        
                        const SizedBox(height: ServioSpacing.sectionGap),
                        
                        // Categories Grid
                        ServioSectionHeading(
                          title: locale == 'ar' ? 'الخدمات' : 'Services',
                          actionLabel: locale == 'ar' ? 'عرض الكل' : 'See All',
                          onActionTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => const ServicesMarketplaceScreen()),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _CategoriesGrid(locale: locale),
                        
                        const SizedBox(height: ServioSpacing.sectionGap),

                        // AI Features Banner
                        _HeroBannerCard(
                          badgeLabel: 'NEW FEATURE',
                          title: 'AI Smart Match',
                          body: 'Snap a photo and let AI find the perfect pro.',
                          ctaLabel: 'Try AI Assistant',
                          icon: Icons.auto_awesome_rounded,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => const AiSmartMatchScreen()),
                            );
                          },
                        ),
                        const SizedBox(height: ServioSpacing.sectionGap),

                        // Featured Professionals
                        ServioSectionHeading(
                          title: locale == 'ar' ? 'موصى بهم لك' : 'Recommended For You',
                          actionLabel: locale == 'ar' ? 'عرض الكل' : 'See All',
                          onActionTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => const TechnicianListingScreen()),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _FeaturedProfessionals(featuredTechs: featuredTechs),
                        
                        const SizedBox(height: 40),
                      ],
                    ),
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

class _HeroSearchBar extends StatelessWidget {
  const _HeroSearchBar({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SearchResultsScreen(query: '')),
        );
      },
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(ServioRadius.full),
          boxShadow: isDark ? ServioShadows.elevatedDark : ServioShadows.elevated,
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.search_rounded, color: servio.textSecondary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'What do you need help with?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: servio.textSecondary,
                ),
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: ServioGradients.accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingBookingCard extends StatelessWidget {
  const _FloatingBookingCard({
    required this.booking,
    required this.locale,
  });

  final BookingModel booking;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    final isInProgress = booking.status == BookingStatus.inProgress;
    final statusType = isInProgress ? ServioStatusChipType.info : ServioStatusChipType.warning;
    final statusLabel = isInProgress 
      ? (locale == 'ar' ? 'قيد التنفيذ' : 'En Route') 
      : (locale == 'ar' ? 'قادم' : 'Upcoming');

    return ServioCard(
      radius: ServioRadius.xl,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: ServioColors.tint(servio.accent),
                  borderRadius: BorderRadius.circular(ServioRadius.md),
                ),
                child: Icon(Icons.build_circle_outlined, color: servio.accent, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      booking.serviceName,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      booking.date,
                      style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
                    ),
                  ],
                ),
              ),
              ServioStatusChip(label: statusLabel, type: statusType),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: servio.border),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const MyBookingsScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ServioRadius.full)),
                  ),
                  child: Text(locale == 'ar' ? 'التفاصيل' : 'View Details'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: servio.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ServioRadius.full)),
                  ),
                  child: Text(locale == 'ar' ? 'تتبع الطلب' : 'Track Status'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FloatingEmptyBookingCard extends StatelessWidget {
  const _FloatingEmptyBookingCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return ServioCard(
      radius: ServioRadius.xl,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: servio.backgroundSoft,
              borderRadius: BorderRadius.circular(ServioRadius.md),
            ),
            child: Icon(Icons.check_circle_outline_rounded, color: servio.textSecondary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('No active bookings', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Ready to tackle your next project?',
                  style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoriesGrid extends StatelessWidget {
  const _CategoriesGrid({required this.locale});
  
  final String locale;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      childAspectRatio: 0.85,
      crossAxisSpacing: 12,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: <Widget>[
        _CategoryItem(
          icon: Icons.cleaning_services_rounded,
          label: locale == 'ar' ? 'تنظيف' : 'Cleaning',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ServiceDetailScreen(serviceId: 'cleaning')),
          ),
        ),
        _CategoryItem(
          icon: Icons.plumbing_rounded,
          label: locale == 'ar' ? 'سباكة' : 'Plumbing',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ServiceDetailScreen(serviceId: 'plumbing')),
          ),
        ),
        _CategoryItem(
          icon: Icons.electrical_services_rounded,
          label: locale == 'ar' ? 'كهرباء' : 'Electrical',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ServiceDetailScreen(serviceId: 'electrical')),
          ),
        ),
        _CategoryItem(
          icon: Icons.format_paint_rounded,
          label: locale == 'ar' ? 'دهان' : 'Painting',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ServiceDetailScreen(serviceId: 'painting')),
          ),
        ),
        _CategoryItem(
          icon: Icons.ac_unit_rounded,
          label: locale == 'ar' ? 'تكييف' : 'HVAC',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ServiceDetailScreen(serviceId: 'ac-maintenance')),
          ),
        ),
        _CategoryItem(
          icon: Icons.handyman_rounded,
          label: locale == 'ar' ? 'نجارة' : 'Carpentry',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ServiceDetailScreen(serviceId: 'carpentry')),
          ),
        ),
        _CategoryItem(
          icon: Icons.local_shipping_rounded,
          label: locale == 'ar' ? 'نقل' : 'Moving',
        ),
        _CategoryItem(
          icon: Icons.more_horiz_rounded,
          label: locale == 'ar' ? 'المزيد' : 'More',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ServicesMarketplaceScreen()),
          ),
        ),
      ],
    );
  }
}

class _CategoryItem extends StatefulWidget {
  const _CategoryItem({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  State<_CategoryItem> createState() => _CategoryItemState();
}

class _CategoryItemState extends State<_CategoryItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, 
      duration: ServioMotion.fast,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: ServioMotion.spring),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          children: <Widget>[
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: servio.backgroundSoft,
                borderRadius: BorderRadius.circular(ServioRadius.lg),
              ),
              child: Icon(widget.icon, color: servio.accent, size: 28),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedProfessionals extends StatelessWidget {
  const _FeaturedProfessionals({required this.featuredTechs});

  final List<dynamic> featuredTechs;

  @override
  Widget build(BuildContext context) {
    if (featuredTechs.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 240,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: featuredTechs.length,
        clipBehavior: Clip.none,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (BuildContext context, int index) {
          final tech = featuredTechs[index];
          return _ProfessionalCard(tech: tech);
        },
      ),
    );
  }
}

class _ProfessionalCard extends StatefulWidget {
  const _ProfessionalCard({required this.tech});

  final dynamic tech;

  @override
  State<_ProfessionalCard> createState() => _ProfessionalCardState();
}

class _ProfessionalCardState extends State<_ProfessionalCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: ServioMotion.fast);
    _scale = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: ServioMotion.spring),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final tech = widget.tech;
    final name = tech.name as String;
    final specialty = tech.skills.isNotEmpty ? tech.skills.first as String : 'Specialist';

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TechnicianProfileScreen(technicianId: tech.id),
          ),
        );
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: SizedBox(
          width: 240,
          child: ServioCard(
            radius: ServioRadius.xl,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: ServioGradients.warm,
                        shape: BoxShape.circle,
                        border: Border.all(color: servio.border, width: 1),
                      ),
                      child: Center(
                        child: Text(
                          name.split(' ').take(2).map((String e) => e[0]).join(),
                          style: theme.textTheme.titleMedium?.copyWith(color: ServioColors.deepBrown),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: ServioColors.tint(servio.success),
                        borderRadius: BorderRadius.circular(ServioRadius.full),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.verified_rounded, size: 14, color: servio.success),
                          const SizedBox(width: 4),
                          Text(
                            'Verified',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: servio.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  specialty,
                  style: theme.textTheme.bodyMedium?.copyWith(color: servio.textSecondary),
                ),
                const Spacer(),
                Row(
                  children: <Widget>[
                    Icon(Icons.star_rounded, size: 18, color: const Color(0xFFF59E0B)),
                    const SizedBox(width: 4),
                    Text(
                      tech.rating.toStringAsFixed(1),
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${tech.reviewCount})',
                      style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
  });

  final String title;
  final String body;
  final String ctaLabel;
  final IconData icon;
  final VoidCallback onTap;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: isDark ? ServioGradients.brandDark : ServioGradients.brand,
          borderRadius: BorderRadius.circular(ServioRadius.xl),
          boxShadow: isDark ? ServioShadows.elevatedDark : ServioShadows.elevated,
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(
                icon,
                size: 120,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (badgeLabel != null) ...<Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: servio.accent,
                      borderRadius: BorderRadius.circular(ServioRadius.full),
                    ),
                    child: Text(
                      badgeLabel!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  title,
                  style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: <Widget>[
                    Text(
                      ctaLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: servio.accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 16, color: servio.accent),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
