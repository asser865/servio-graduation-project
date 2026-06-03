import 'package:flutter/material.dart';

import '../../design_system/servio_tokens.dart';

/// Presentational pieces for the Smart Match coach-mark tutorial.
///
/// All layout/animation for the first-run overlay lives here so the Smart
/// Match screen itself stays focused on the (approved) product UI. The screen
/// owns the step state machine and feeds rects + callbacks into these widgets.

// ─── Spotlight dim + cutout painter ───────────────────────────────────────────

class SpotlightPainter extends CustomPainter {
  const SpotlightPainter({
    required this.rect,
    this.radius = 18,
    this.dim = 0.66,
    this.pulse = 0,
  });

  /// Target rect in global (overlay) coordinates. Null → fully dimmed.
  final Rect? rect;
  final double radius;
  final double dim;

  /// 0–1 pulse phase used to draw an expanding glow ring (step 3 CTA).
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: dim);
    final full = Offset.zero & size;

    if (rect == null) {
      canvas.drawRect(full, dimPaint);
      return;
    }

    final cut = RRect.fromRectAndRadius(
      rect!.inflate(8),
      Radius.circular(radius),
    );

    final overlayPath = Path.combine(
      PathOperation.difference,
      Path()..addRect(full),
      Path()..addRRect(cut),
    );
    canvas.drawPath(overlayPath, dimPaint);

    // Pulsing outer glow ring (only when pulse > 0).
    if (pulse > 0) {
      final glow = RRect.fromRectAndRadius(
        rect!.inflate(8 + pulse * 12),
        Radius.circular(radius + pulse * 12),
      );
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = ServioColors.accent.withValues(alpha: (1 - pulse) * 0.7);
      canvas.drawRRect(glow, glowPaint);
    }

    // Crisp accent border around the spotlight.
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = ServioColors.accent.withValues(alpha: 0.9);
    canvas.drawRRect(cut, border);
  }

  @override
  bool shouldRepaint(SpotlightPainter old) =>
      old.rect != rect ||
      old.radius != radius ||
      old.dim != dim ||
      old.pulse != pulse;
}

// ─── Coach card ───────────────────────────────────────────────────────────────

class TutorialCoachCard extends StatelessWidget {
  const TutorialCoachCard({
    required this.stepLabel,
    required this.emoji,
    required this.title,
    required this.body,
    required this.onNext,
    required this.onSkip,
    this.onBack,
    this.nextLabel = 'Next',
    this.busy = false,
    super.key,
  });

  final String stepLabel;
  final String emoji;
  final String title;
  final Widget body;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback? onBack;
  final String nextLabel;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ServioRadius.xl),
          boxShadow: ServioShadows.elevated,
          border: Border.all(color: ServioColors.accent.withValues(alpha: 0.18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              stepLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: ServioColors.accent,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF1A1D23),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DefaultTextStyle.merge(
              style: theme.textTheme.bodyMedium?.copyWith(
                color: ServioColors.textSecondaryLight,
                height: 1.4,
              ),
              child: body,
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                GestureDetector(
                  onTap: busy ? null : onSkip,
                  child: Text(
                    'Skip Tutorial',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: ServioColors.textSecondaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                if (onBack != null) ...<Widget>[
                  _OutlineButton(label: 'Back', onTap: busy ? null : onBack!),
                  const SizedBox(width: 10),
                ],
                _GradientButton(
                  label: nextLabel,
                  busy: busy,
                  onTap: busy ? null : onNext,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ServioRadius.lg),
          border: Border.all(color: ServioColors.borderLight, width: 1.5),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: const Color(0xFF1A1D23),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: ServioGradients.brand,
          borderRadius: BorderRadius.circular(ServioRadius.lg),
          boxShadow: ServioShadows.rest,
        ),
        child: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

// ─── Static check list (features the AI evaluates) ────────────────────────────

class TutorialCheckList extends StatelessWidget {
  const TutorialCheckList({required this.items, super.key});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (String item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.check_rounded,
                        size: 16, color: ServioColors.accent),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

// ─── Animated AI detections (step 2) ──────────────────────────────────────────

class TutorialDetectionList extends StatefulWidget {
  const TutorialDetectionList({required this.detections, super.key});

  final List<String> detections;

  @override
  State<TutorialDetectionList> createState() => _TutorialDetectionListState();
}

class _TutorialDetectionListState extends State<TutorialDetectionList> {
  int _revealed = 0;

  @override
  void initState() {
    super.initState();
    _reveal();
  }

  Future<void> _reveal() async {
    for (int i = 0; i < widget.detections.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      setState(() => _revealed = i + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List<Widget>.generate(widget.detections.length, (int index) {
        final visible = index < _revealed;
        return AnimatedOpacity(
          duration: ServioMotion.normal,
          opacity: visible ? 1 : 0,
          child: AnimatedSlide(
            duration: ServioMotion.normal,
            curve: ServioMotion.spring,
            offset: visible ? Offset.zero : const Offset(0, 0.3),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: ServioColors.neutralWarm.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(ServioRadius.full),
                border:
                    Border.all(color: ServioColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.check_circle_rounded,
                      size: 14, color: ServioColors.accent),
                  const SizedBox(width: 6),
                  Text(
                    widget.detections[index],
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF1A1D23),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─── Demo typewriter (step 1 — shown inside the card, not the real field) ─────

class TutorialTypewriter extends StatefulWidget {
  const TutorialTypewriter({required this.text, super.key});

  final String text;

  @override
  State<TutorialTypewriter> createState() => _TutorialTypewriterState();
}

class _TutorialTypewriterState extends State<TutorialTypewriter> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    for (int i = 0; i <= widget.text.length; i++) {
      await Future<void>.delayed(
          Duration(milliseconds: i == 0 ? 300 : 30));
      if (!mounted) return;
      setState(() => _count = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = widget.text.substring(0, _count);
    final typing = _count < widget.text.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ServioColors.backgroundSoftLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(ServioRadius.lg),
        border: Border.all(color: ServioColors.borderLight),
      ),
      child: Text.rich(
        TextSpan(
          children: <TextSpan>[
            TextSpan(text: shown),
            if (typing)
              const TextSpan(
                text: '|',
                style: TextStyle(color: ServioColors.accent),
              ),
          ],
        ),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF262B34),
          height: 1.4,
        ),
      ),
    );
  }
}

// ─── Success card (final screen) ──────────────────────────────────────────────

class TutorialSuccessCard extends StatelessWidget {
  const TutorialSuccessCard({
    required this.onPrimary,
    required this.onClose,
    super.key,
  });

  final VoidCallback onPrimary;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ServioRadius.xxl),
          boxShadow: ServioShadows.elevated,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: ServioGradients.brand,
                borderRadius: BorderRadius.circular(ServioRadius.xxl),
                boxShadow: ServioShadows.elevated,
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 34),
            ),
            const SizedBox(height: 18),
            Text(
              "✨ You're Ready!",
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF1A1D23),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Smart Match helps you find the right professional faster '
              'than browsing manually.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: ServioColors.textSecondaryLight,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: onPrimary,
                child: Container(
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: ServioGradients.brand,
                    borderRadius: BorderRadius.circular(ServioRadius.xl),
                    boxShadow: ServioShadows.rest,
                  ),
                  child: Text(
                    'Start Using Smart Match',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: onClose,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Close',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: ServioColors.textSecondaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
