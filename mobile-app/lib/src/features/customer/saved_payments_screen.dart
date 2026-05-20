import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  IconData _getCardIcon(String type) {
    switch (type.toLowerCase()) {
      case 'visa':
        return Icons.payment_rounded;
      case 'mastercard':
        return Icons.credit_card_rounded;
      default:
        return Icons.credit_card_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Payments'),
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
                          const SizedBox(height: 24),
                          if (_cards.isEmpty)
                            // ── Empty-state card ─────────────────────────────────
                            ServioCard(
                              radius: ServioRadius.lg,
                              padding: const EdgeInsets.symmetric(
                                horizontal: ServioSpacing.cardPadding,
                                vertical: 36,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color:
                                          servio.accent.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(
                                          ServioRadius.xl),
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
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: 260,
                                    child: Text(
                                      'Your saved cards and payment options will appear here.',
                                      textAlign: TextAlign.center,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: servio.textSecondary,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  _AddPaymentButton(
                                      servio: servio, onTap: _showAddCardModal),
                                ],
                              ),
                            )
                          else
                            Expanded(
                              child: ListView.separated(
                                itemCount: _cards.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 16),
                                itemBuilder: (context, index) {
                                  final card = _cards[index];
                                  return ServioCard(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Icon(_getCardIcon(card.cardType),
                                            size: 36, color: servio.accent),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '•••• •••• •••• ${card.last4}',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Exp ${card.expiry}',
                                                style: TextStyle(
                                                    color: servio.textSecondary,
                                                    fontSize: 13),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (card.isDefault)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: servio.accent
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                  color: servio.accent
                                                      .withValues(alpha: 0.3)),
                                            ),
                                            child: Text('Default',
                                                style: TextStyle(
                                                    color: servio.accent,
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          )
                                        else
                                          TextButton(
                                            onPressed: () =>
                                                _setDefault(card.id),
                                            style: TextButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            child: const Text('Set Default',
                                                style: TextStyle(fontSize: 12)),
                                          ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: Icon(Icons.delete_outline,
                                              color: servio.danger),
                                          onPressed: () => _deleteCard(card.id),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 24),
                          if (_cards.isNotEmpty)
                            _AddPaymentButton(
                                servio: servio, onTap: _showAddCardModal),
                          const SizedBox(height: 24),
                          // ── Info hint ───────────────────────────────────────
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 16,
                                color: servio.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Your payment information is encrypted and secure.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: servio.textSecondary,
                                  ),
                                ),
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

class _AddPaymentButton extends StatelessWidget {
  const _AddPaymentButton({required this.servio, required this.onTap});

  final ServioThemeExtension servio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ServioRadius.full),
        onTap: onTap,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ServioRadius.full),
            border: Border.all(
              color: servio.accent.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.add_rounded,
                size: 20,
                color: servio.accent,
              ),
              const SizedBox(width: 8),
              Text(
                'Add payment method',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: servio.accent,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
