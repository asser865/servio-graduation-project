import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/saved_cards_api.dart';
import '../../core/models/saved_card_model.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';

class SavedPaymentsScreen extends StatefulWidget {
  const SavedPaymentsScreen({super.key});

  @override
  State<SavedPaymentsScreen> createState() => _SavedPaymentsScreenState();
}

class _SavedPaymentsScreenState extends State<SavedPaymentsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  List<SavedCardModel> _cards = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: ServioMotion.page,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.6, curve: ServioMotion.spring),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.1, 0.7, curve: ServioMotion.spring),
      ),
    );
    _animController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchCards());
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _fetchCards() async {
    try {
      if (mounted) {
        setState(() {
          _loading = true;
          _error = null;
        });
      }
      final api = SavedCardsApi(context.read<ApiClient>());
      final cards = await api.getSavedCards();
      if (mounted) {
        setState(() {
          _cards = cards;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load cards.';
        });
      }
    }
  }

  Future<void> _deleteCard(String id) async {
    try {
      final api = SavedCardsApi(context.read<ApiClient>());
      await api.deleteCard(id);
      await _fetchCards();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete card.')));
      }
    }
  }

  Future<void> _setDefault(String id) async {
    try {
      final api = SavedCardsApi(context.read<ApiClient>());
      await api.setDefault(id);
      await _fetchCards();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to set default card.')));
      }
    }
  }

  void _showAddCardModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddCardSheet(onAdded: _fetchCards),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Methods'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Padding(
            padding: const EdgeInsets.all(ServioSpacing.screenPadding),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const SizedBox(height: 8),
                          if (_cards.isEmpty)
                            // ── Redesigned Empty-state card ───────────────────────────
                            ServioCard(
                              radius: ServioRadius.lg,
                              padding: const EdgeInsets.symmetric(
                                horizontal: ServioSpacing.cardPadding,
                                vertical: 48,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: servio.accent.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(ServioRadius.xl),
                                    ),
                                    child: Icon(
                                      Icons.credit_card_rounded,
                                      size: 34,
                                      color: servio.accent,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'No saved payment methods yet',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: 260,
                                    child: Text(
                                      'Your saved cards and payment options will appear here.',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: servio.textSecondary,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  _AddPaymentButton(onTap: _showAddCardModal),
                                ],
                              ),
                            )
                          else
                            // ── Cards List Redesign ───────────────────────────────────
                            Expanded(
                              child: ListView.separated(
                                itemCount: _cards.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 16),
                                itemBuilder: (context, index) {
                                  final card = _cards[index];
                                  return _SavedCardWidget(
                                    card: card,
                                    onDelete: () => _deleteCard(card.id),
                                    onSetDefault: () => _setDefault(card.id),
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 24),
                          if (_cards.isNotEmpty)
                            _AddPaymentButton(onTap: _showAddCardModal),
                          const SizedBox(height: 32),
                          // ── Trust Security Indicators ────────────────────────────
                          const _SecurityTrustIndicators(),
                          const SizedBox(height: 8),
                        ],
                      ),
          ),
        ),
      ),
    );
  }
}

class _SavedCardWidget extends StatefulWidget {
  const _SavedCardWidget({
    required this.card,
    required this.onDelete,
    required this.onSetDefault,
  });

  final SavedCardModel card;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  @override
  State<_SavedCardWidget> createState() => _SavedCardWidgetState();
}

class _SavedCardWidgetState extends State<_SavedCardWidget> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final isDark = theme.brightness == Brightness.dark;
    final card = widget.card;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: ServioMotion.fast,
        curve: ServioMotion.spring,
        child: AnimatedContainer(
          duration: ServioMotion.normal,
          curve: ServioMotion.spring,
          decoration: BoxDecoration(
            color: card.isDefault
                ? (isDark ? theme.colorScheme.surface : Colors.white)
                : (isDark ? servio.surfaceAlt : const Color(0xFFF3EDE7).withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(ServioRadius.lg),
            border: Border.all(
              color: card.isDefault
                  ? (_isPressed ? servio.accent : servio.accent.withValues(alpha: 0.6))
                  : (_isPressed ? servio.accent.withValues(alpha: 0.4) : servio.accent.withValues(alpha: 0.15)),
              width: card.isDefault ? 1.5 : 1,
            ),
            boxShadow: card.isDefault
                ? [
                    BoxShadow(
                      color: isDark 
                          ? Colors.black.withValues(alpha: 0.30) 
                          : servio.accent.withValues(alpha: 0.08),
                      blurRadius: _isPressed ? 16 : 12,
                      offset: Offset(0, _isPressed ? 6 : 4),
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Cool Accent-Gradient verified star tag floating in top-right
              if (card.isDefault)
                Positioned(
                  top: 14,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: ServioGradients.accent,
                      borderRadius: BorderRadius.circular(ServioRadius.full),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.stars_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'DEFAULT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(ServioSpacing.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _CardBrandBadge(cardType: card.cardType),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${card.cardType[0].toUpperCase()}${card.cardType.substring(1)} ending in ${card.last4}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Expires ${card.expiry}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: servio.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: servio.border.withValues(alpha: 0.35),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Simplified Secured checkmark badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: servio.success.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(ServioRadius.sm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_user_rounded,
                                size: 13,
                                color: servio.success,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Secured',
                                style: TextStyle(
                                  color: servio.success,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            if (!card.isDefault) ...[
                              TextButton(
                                onPressed: widget.onSetDefault,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Set as Default',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            TextButton.icon(
                              onPressed: widget.onDelete,
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                size: 16,
                                color: servio.danger,
                              ),
                              label: Text(
                                'Delete',
                                style: TextStyle(
                                  color: servio.danger,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardBrandBadge extends StatelessWidget {
  const _CardBrandBadge({required this.cardType});

  final String cardType;

  @override
  Widget build(BuildContext context) {
    final type = cardType.toLowerCase();

    if (type == 'visa') {
      return Container(
        width: 60,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF1434CB),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 6,
              top: 15,
              child: Container(
                width: 12,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Center(
              child: Padding(
                padding: EdgeInsets.only(left: 12),
                child: Text(
                  'VISA',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (type == 'mastercard') {
      return Container(
        width: 60,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D23),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 14,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Color(0xFFEB001B),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: 14,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFFF79E1B).withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        width: 60,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFE4E2DF),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(
          Icons.credit_card_rounded,
          color: Color(0xFF76777B),
          size: 20,
        ),
      );
    }
  }
}

class _AddPaymentButton extends StatefulWidget {
  const _AddPaymentButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_AddPaymentButton> createState() => _AddPaymentButtonState();
}

class _AddPaymentButtonState extends State<_AddPaymentButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapCancel: () => setState(() => _isPressed = false),
      onTapUp: (_) => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: ServioMotion.fast,
        curve: ServioMotion.spring,
        child: SizedBox(
          height: 110,
          child: CustomPaint(
            painter: _DashedRectPainter(
              color: servio.accent.withValues(alpha: 0.4),
              strokeWidth: 1.5,
              gap: 6.0,
              radius: ServioRadius.lg,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: _isPressed
                    ? servio.accent.withValues(alpha: 0.08)
                    : (isDark ? servio.surfaceAlt : theme.colorScheme.surface),
                borderRadius: BorderRadius.circular(ServioRadius.lg),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? theme.colorScheme.surface : servio.backgroundSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 24,
                      color: isDark ? Colors.white : ServioColors.navyDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add Payment Method',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecurityTrustIndicators extends StatelessWidget {
  const _SecurityTrustIndicators();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final isDark = theme.brightness == Brightness.dark;

    return Opacity(
      opacity: 0.6,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 28,
                  color: isDark ? Colors.white : ServioColors.navyDark,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '256-bit Encryption',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        'Your data is safe',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: servio.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.gpp_good_outlined,
                  size: 28,
                  color: isDark ? Colors.white : ServioColors.navyDark,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Fraud Protection',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        '24/7 monitoring',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: servio.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
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

class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.gap,
    required this.radius,
  });

  final Color color;
  final double strokeWidth;
  final double gap;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));

    final dashWidth = gap;
    final dashSpace = gap;

    final Path dashedPath = Path();
    double distance = 0.0;
    for (final PathMetric measure in path.computeMetrics()) {
      while (distance < measure.length) {
        dashedPath.addPath(
          measure.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
      distance = 0.0;
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AddCardSheet extends StatefulWidget {
  const _AddCardSheet({required this.onAdded});
  final VoidCallback onAdded;

  @override
  State<_AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends State<_AddCardSheet> {
  final _numberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _numberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final rawNum = _numberController.text.replaceAll(' ', '');
    final exp = _expiryController.text.replaceAll(' ', '');
    final cvv = _cvvController.text;

    if (rawNum.length < 16) return;
    if (exp.length < 5) return;
    if (cvv.length < 3) return;

    setState(() => _saving = true);
    try {
      final first = rawNum[0];
      String type = 'other';
      if (first == '4') type = 'visa';
      if (first == '5') type = 'mastercard';
      if (first == '3') type = 'amex';

      final api = SavedCardsApi(context.read<ApiClient>());
      await api.addCard(
        last4: rawNum.substring(rawNum.length - 4),
        expiry: exp,
        cardType: type,
        label: 'Personal Card',
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onAdded();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save card.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add Payment Method',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          TextField(
            controller: _numberController,
            keyboardType: TextInputType.number,
            maxLength: 19,
            decoration: const InputDecoration(
                labelText: 'Card Number', counterText: ''),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _CardNumberFormatter(),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _expiryController,
                  keyboardType: TextInputType.number,
                  maxLength: 7,
                  decoration: const InputDecoration(
                      labelText: 'Expiry (MM / YY)', counterText: ''),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _ExpiryFormatter(),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _cvvController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration:
                      const InputDecoration(labelText: 'CVV', counterText: ''),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  obscureText: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ServioPrimaryButton(
            label: _saving ? 'Saving...' : 'Save Card',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    text = text.replaceAll(RegExp(r'\D'), '');
    var formatted = '';
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) {
        formatted += ' ';
      }
      formatted += text[i];
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    text = text.replaceAll(RegExp(r'\D'), '');
    var formatted = '';
    for (int i = 0; i < text.length; i++) {
      if (i == 2) {
        formatted += ' / ';
      }
      formatted += text[i];
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
