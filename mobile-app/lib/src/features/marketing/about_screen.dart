import 'package:flutter/material.dart';

import '../../design_system/servio_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Stitch Design token aliases (from Stitch design system)
// ─────────────────────────────────────────────────────────────────────────────
const Color _navyAnchor = Color(0xFF1A1D23);
const Color _taupeAccent = Color(0xFF9A8C73);
const Color _surfaceWarm = Color(0xFFF3EDE7);
const Color _textMuted = Color(0xFF6B6560);
const Color _primaryFixedDim = Color(0xFFC4C6CE);

// ─────────────────────────────────────────────────────────────────────────────
//  About Screen
// ─────────────────────────────────────────────────────────────────────────────
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F6),
      // ── Top App Bar ────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: const Color(0xCCFBF9F6), // surface/80
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: const Color(0xFFEFEEEB),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _navyAnchor),
          tooltip: 'Go back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'About SERVIO',
          style: TextStyle(
            color: _navyAnchor,
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: true,
        actions: const [SizedBox(width: 48)], // spacer for centering
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            _HeroSection(),
            _ServioStandardSection(),
            _TrustSafetySection(),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Section 1 — Hero / Mission
// ─────────────────────────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── "Our Mission" pill badge ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _surfaceWarm,
              borderRadius: BorderRadius.circular(ServioRadius.full),
            ),
            child: const Text(
              'OUR MISSION',
              style: TextStyle(
                color: _taupeAccent,
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Mission headline ─────────────────────────────────────────────
          const Text(
            'Elevating Home Care to a Premium Concierge Experience.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _navyAnchor,
              fontFamily: 'Poppins',
              fontSize: 28,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),

          // ── Body paragraph ───────────────────────────────────────────────
          const Text(
            'SERVIO connects discerning homeowners with elite, meticulously vetted artisans. We believe your home is a sanctuary, and the professionals who care for it should embody reliability, punctuality, and uncompromising quality.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textMuted,
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 1.75,
            ),
          ),
          const SizedBox(height: 24),

          // ── Editorial image canvas ───────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(ServioRadius.lg),
            child: Stack(
              children: [
                // Network image
                SizedBox(
                  height: 240,
                  width: double.infinity,
                  child: Image.network(
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuAOKq6x7fHcFSOis1zD61cl80tRBq6pMaMsgw6HGWKhJFgLNOiAvYp26lu0suFXk1-yifI4eTjY9rde4YQJPO_4f0q7s0KbabLUPWX563DkSfmgrOziR9UubmL4USOUd8XBKsJXmDOiO7iCfPh0bEnrEdq76rgWLRGUICCjTLeJIDuKhGugUz2Sv1wiKKSF1lo_9tXb3SquOPq2M0MTWSfQu2rVEWqjVXOFyhfY6cxxTfJ_5z6Lp4u-rAYLYxleZGF0kN3svpbE-F8Z',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFEFEEEB),
                      child: const Center(
                        child: Icon(Icons.home_work_outlined,
                            size: 64, color: _taupeAccent),
                      ),
                    ),
                  ),
                ),
                // Gradient overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          _navyAnchor.withValues(alpha: 0.4),
                        ],
                        stops: const [0.5, 1.0],
                      ),
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

// ─────────────────────────────────────────────────────────────────────────────
//  Section 2 — The SERVIO Standard (feature bento grid)
// ─────────────────────────────────────────────────────────────────────────────
class _ServioStandardSection extends StatelessWidget {
  const _ServioStandardSection();

  static const List<_FeatureData> _features = [
    _FeatureData(
      icon: Icons.calendar_month_outlined,
      title: 'Effortless Booking',
      body: 'Schedule appointments at your convenience with our streamlined interface.',
    ),
    _FeatureData(
      icon: Icons.fact_check_outlined,
      title: 'Elite Verification',
      body: 'Every artisan passes a rigorous multi-step background and skill check.',
    ),
    _FeatureData(
      icon: Icons.notifications_active_outlined,
      title: 'Real-Time Updates',
      body: 'Stay informed with live tracking and instant notifications for your service.',
    ),
    _FeatureData(
      icon: Icons.star_rate_rounded,
      title: 'Curated Reviews',
      body: 'Read authentic feedback from other discerning homeowners in your area.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F3F0), // surface-container-low
        border: Border.symmetric(
          horizontal: BorderSide(color: Color(0xFFE4E2DF), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The SERVIO Standard',
            style: TextStyle(
              color: _navyAnchor,
              fontFamily: 'Poppins',
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Designed for seamless, professional interactions.',
            style: TextStyle(
              color: _textMuted,
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 20),
          // 2×2 grid of feature cards
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.9,
            children: _features
                .map((f) => _FeatureCard(data: f))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _FeatureData {
  const _FeatureData({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;
}

class _FeatureCard extends StatefulWidget {
  const _FeatureCard({required this.data});
  final _FeatureData data;

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: ServioMotion.normal,
        curve: ServioMotion.spring,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFBF9F6),
          borderRadius: BorderRadius.circular(ServioRadius.lg),
          border: Border.all(
            color: _hovered
                ? _taupeAccent.withValues(alpha: 0.5)
                : _taupeAccent.withValues(alpha: 0.2),
          ),
          boxShadow: ServioShadows.rest,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon circle with hover transition
            AnimatedContainer(
              duration: ServioMotion.normal,
              curve: ServioMotion.spring,
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _hovered ? _taupeAccent : _surfaceWarm,
              ),
              child: Icon(
                widget.data.icon,
                color: _hovered ? _surfaceWarm : _taupeAccent,
                size: 22,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.data.title,
              style: const TextStyle(
                color: _navyAnchor,
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                widget.data.body,
                style: const TextStyle(
                  color: _textMuted,
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Section 3 — Trust & Safety (dark card)
// ─────────────────────────────────────────────────────────────────────────────
class _TrustSafetySection extends StatelessWidget {
  const _TrustSafetySection();

  static const List<_TrustItem> _items = [
    _TrustItem(icon: Icons.shield_outlined, label: 'Secure, Cashless Payments'),
    _TrustItem(icon: Icons.verified_outlined, label: 'Comprehensive Background Checks'),
    _TrustItem(icon: Icons.health_and_safety_outlined, label: '\$1M Property Protection Guarantee'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: _navyAnchor,
          borderRadius: BorderRadius.circular(ServioRadius.xl),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Subtle dot-grid pattern overlay
            Positioned.fill(
              child: CustomPaint(painter: _DotGridPainter()),
            ),
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shield icon accent
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _surfaceWarm.withValues(alpha: 0.12),
                      border: Border.all(
                        color: _taupeAccent.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.gpp_good_rounded,
                      color: _taupeAccent,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Uncompromising Trust',
                    style: TextStyle(
                      color: _surfaceWarm,
                      fontFamily: 'Poppins',
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your peace of mind is the foundation of SERVIO. We employ bank-grade security protocols and comprehensive vetting processes to ensure your home remains a safe sanctuary.',
                    style: TextStyle(
                      color: _primaryFixedDim,
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      height: 1.65,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Trust badges list
                  ..._items.map((item) => _TrustBadge(item: item)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustItem {
  const _TrustItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.item});
  final _TrustItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(ServioRadius.md),
        ),
        child: Row(
          children: [
            Icon(item.icon, color: _taupeAccent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                style: const TextStyle(
                  color: _surfaceWarm,
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Dot-grid background painter (replicates Stitch's radial-gradient pattern)
// ─────────────────────────────────────────────────────────────────────────────
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dotColor = Color(0x1AF3EDE7); // surface-warm at ~10% opacity
    const spacing = 24.0;
    const radius = 1.0;

    final paint = Paint()..color = dotColor;

    for (double x = 2; x < size.width; x += spacing) {
      for (double y = 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
