import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import 'booking_flow_data.dart';
import 'booking_step_two_screen.dart';
import 'booking_strings.dart';
import 'widgets/booking_progress_indicator.dart';

class BookingStepOneScreen extends StatefulWidget {
  const BookingStepOneScreen({
    super.key,
    this.data = const BookingFlowData(),
  });

  final BookingFlowData data;

  @override
  State<BookingStepOneScreen> createState() => _BookingStepOneScreenState();
}

class _BookingStepOneScreenState extends State<BookingStepOneScreen> {
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.data.notes);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final isDark = theme.brightness == Brightness.dark;

    final navyAnchor =
        isDark ? const Color(0xFFE3D5CA) : const Color(0xFF1A1D23);
    final surfaceCard = isDark ? theme.colorScheme.surface : Colors.white;
    final cardBorder =
        const Color(0xFF9A8C73).withValues(alpha: isDark ? 0.15 : 0.1);

    return Scaffold(
      extendBody: true,
      backgroundColor: isDark
          ? ServioColors.backgroundDark
          : const Color(0xFFFAF8F5),
      appBar: AppBar(
        backgroundColor: isDark
            ? ServioColors.backgroundDark
            : const Color(0xFFF3EDE7).withValues(alpha: 0.8),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: navyAnchor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: const Color(0xFF9A8C73).withValues(alpha: 0.2),
          ),
        ),
      ),
      bottomNavigationBar: _BottomContinueBar(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => BookingStepTwoScreen(
                data: widget.data.copyWith(
                  notes: _notesController.text.trim(),
                ),
              ),
            ),
          );
        },
      ),
      body: Column(
        children: <Widget>[
          BookingProgressIndicator(
            currentStep: 1,
            totalSteps: 3,
            stepLabels: BookingStrings.stepLabels,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                ServioSpacing.screenPadding,
                24,
                ServioSpacing.screenPadding,
                100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Confirm Your Booking',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: navyAnchor,
                      height: 1.29,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _ServiceCard(
                    data: widget.data,
                    isDark: isDark,
                    navyAnchor: navyAnchor,
                    surfaceCard: surfaceCard,
                    cardBorder: cardBorder,
                    servio: servio,
                  ),
                  const SizedBox(height: 12),
                  _TechnicianCard(
                    data: widget.data,
                    isDark: isDark,
                    navyAnchor: navyAnchor,
                    surfaceCard: surfaceCard,
                    cardBorder: cardBorder,
                    servio: servio,
                    onChangeTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 24),
                  _JobDescriptionField(
                    controller: _notesController,
                    isDark: isDark,
                    navyAnchor: navyAnchor,
                    servio: servio,
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

// ── Bottom Action Bar ────────────────────────────────────────────────────────

class _BottomContinueBar extends StatelessWidget {
  const _BottomContinueBar({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        ServioSpacing.screenPadding,
        0,
        ServioSpacing.screenPadding,
        16 + bottomPadding,
      ),
      child: SizedBox(
        height: ServioSpacing.tapTarget + 8,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A1D23),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: const StadiumBorder(),
            padding: EdgeInsets.zero,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const <Widget>[
              Text(
                'Continue',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 20, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Service Card ─────────────────────────────────────────────────────────────

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.data,
    required this.isDark,
    required this.navyAnchor,
    required this.surfaceCard,
    required this.cardBorder,
    required this.servio,
  });

  final BookingFlowData data;
  final bool isDark;
  final Color navyAnchor;
  final Color surfaceCard;
  final Color cardBorder;
  final ServioThemeExtension servio;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ServioSpacing.cardPadding),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        border: Border.all(color: cardBorder),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color.fromRGBO(26, 29, 37, 0.03),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Brand icon box
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: ServioGradients.brand,
              borderRadius: BorderRadius.circular(ServioRadius.md),
              boxShadow: ServioShadows.rest,
            ),
            child: const Icon(
              Icons.plumbing_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: ServioSpacing.cardPadding),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  data.category.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: servio.accent,
                    letterSpacing: 0.08,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  data.serviceName,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: navyAnchor,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.priceLabel,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: navyAnchor,
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

// ── Technician Card ──────────────────────────────────────────────────────────

class _TechnicianCard extends StatelessWidget {
  const _TechnicianCard({
    required this.data,
    required this.isDark,
    required this.navyAnchor,
    required this.surfaceCard,
    required this.cardBorder,
    required this.servio,
    required this.onChangeTap,
  });

  final BookingFlowData data;
  final bool isDark;
  final Color navyAnchor;
  final Color surfaceCard;
  final Color cardBorder;
  final ServioThemeExtension servio;
  final VoidCallback onChangeTap;

  @override
  Widget build(BuildContext context) {
    final initials = data.technicianName.isNotEmpty
        ? data.technicianName.trim()[0].toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.all(ServioSpacing.cardPadding),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        border: Border.all(color: cardBorder),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color.fromRGBO(26, 29, 37, 0.03),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          // Avatar circle
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: ServioGradients.warm,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? const Color(0xFF262B34)
                    : const Color(0xFFF3EDE7),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: navyAnchor,
                ),
              ),
            ),
          ),
          const SizedBox(width: ServioSpacing.cardPadding),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        data.technicianName,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: navyAnchor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: onChangeTap,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: const Color(0xFF9A8C73),
                      ),
                      child: const Text(
                        'Change',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (data.specialty.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    data.specialty,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: servio.textSecondary,
                    ),
                  ),
                ],
                if (data.hourlyRate.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    data.hourlyRate,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: servio.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Job Description Field ────────────────────────────────────────────────────

class _JobDescriptionField extends StatelessWidget {
  const _JobDescriptionField({
    required this.controller,
    required this.isDark,
    required this.navyAnchor,
    required this.servio,
  });

  final TextEditingController controller;
  final bool isDark;
  final Color navyAnchor;
  final ServioThemeExtension servio;

  @override
  Widget build(BuildContext context) {
    final borderColor = const Color(0xFF9A8C73).withValues(alpha: 0.3);
    final focusBorderColor = const Color(0xFF9A8C73).withValues(alpha: 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(
            'Job Description',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: navyAnchor,
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: null,
          minLines: 5,
          textInputAction: TextInputAction.newline,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: navyAnchor,
          ),
          decoration: InputDecoration(
            hintText: 'e.g., Repaint living room walls, 3 coats...',
            hintStyle: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: servio.textSecondary.withValues(alpha: 0.5),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E2229) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ServioRadius.md),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ServioRadius.md),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ServioRadius.md),
              borderSide: BorderSide(color: focusBorderColor, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(ServioSpacing.cardPadding),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(
            'Describe any specific issues or requirements for the technician.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: servio.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
