import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/state/payments_provider.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/bookings_api.dart';
import '../../core/api/saved_cards_api.dart';
import '../../core/models/backend_booking_model.dart';
import '../../core/models/saved_card_model.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import 'booking_confirmation_screen.dart';
import 'booking_flow_data.dart';

class BookingStepThreeScreen extends StatefulWidget {
  const BookingStepThreeScreen({
    required this.data,
    super.key,
  });

  final BookingFlowData data;

  @override
  State<BookingStepThreeScreen> createState() => _BookingStepThreeScreenState();
}

class _BookingStepThreeScreenState extends State<BookingStepThreeScreen> {
  bool _termsAccepted = false;
  bool _useCredits = false;
  bool _loading = false;
  String? _error;
  late String _paymentMethodCode;
  String? _selectedCardId;
  List<SavedCardModel> _savedCards = <SavedCardModel>[];
  bool _cardsLoading = false;
  bool _savingCard = false;
  String? _cardsError;
  bool _showAddCardForm = false;
  late ApiClient _apiClient;
  late final TextEditingController _cardNumberController;
  late final TextEditingController _cardExpiryController;
  late final TextEditingController _cardLabelController;

  @override
  void initState() {
    super.initState();
    _paymentMethodCode =
        widget.data.paymentMethodCode == 'card' ? 'card' : 'cash';
    _selectedCardId =
        widget.data.savedCardId.isNotEmpty ? widget.data.savedCardId : null;
    _cardNumberController = TextEditingController();
    _cardExpiryController = TextEditingController();
    _cardLabelController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadSavedCards();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PaymentsProvider>().loadCredits();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apiClient = context.read<ApiClient>();
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardLabelController.dispose();
    super.dispose();
  }

  // ── helpers ──────────────────────────────────────────────────────────────────

  void _editServiceDetails() {
    Navigator.of(context)
      ..pop()
      ..pop();
  }

  void _showLegalNotice(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title will open from the legal center.')),
    );
  }

  Future<void> _loadSavedCards() async {
    setState(() {
      _cardsLoading = true;
      _cardsError = null;
    });
    try {
      final cards = await SavedCardsApi(_apiClient).getSavedCards();
      if (!mounted) return;
      setState(() {
        _savedCards = cards;
        if (_selectedCardId == null && cards.isNotEmpty) {
          SavedCardModel? defaultCard;
          for (final card in cards) {
            if (card.isDefault) {
              defaultCard = card;
              break;
            }
          }
          _selectedCardId = (defaultCard ?? cards.first).id;
        }
        _showAddCardForm = _paymentMethodCode == 'card' && cards.isEmpty;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _cardsError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _cardsError = 'Could not load saved cards.');
    } finally {
      if (mounted) setState(() => _cardsLoading = false);
    }
  }

  Future<void> _saveCard() async {
    final digits = _cardNumberController.text.replaceAll(RegExp(r'\D'), '');
    final expiry = _cardExpiryController.text.replaceAll(' ', '');
    if (digits.length < 12 || !RegExp(r'^\d+$').hasMatch(digits)) {
      setState(() => _cardsError = 'Enter a valid card number.');
      return;
    }
    if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(expiry)) {
      setState(() => _cardsError = 'Enter expiry as MM/YY.');
      return;
    }

    setState(() {
      _savingCard = true;
      _cardsError = null;
    });
    try {
      final card = await SavedCardsApi(_apiClient).addCard(
        last4: digits.substring(digits.length - 4),
        expiry: expiry,
        cardType: _detectCardType(digits),
        label: _cardLabelController.text.trim(),
      );
      if (!mounted) return;
      final cards = await SavedCardsApi(_apiClient).getSavedCards();
      if (!mounted) return;
      setState(() {
        _savedCards = cards;
        _selectedCardId = card.id;
        _showAddCardForm = false;
        _cardNumberController.clear();
        _cardExpiryController.clear();
        _cardLabelController.clear();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _cardsError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _cardsError = 'Could not save card.');
    } finally {
      if (mounted) setState(() => _savingCard = false);
    }
  }

  Future<void> _confirmBooking() async {
    if (!_termsAccepted) return;

    final data = widget.data;
    if (!data.isScheduledDateAvailable) {
      setState(() {
        _error = 'Technician is not available on this day';
      });
      return;
    }
    if (_paymentMethodCode == 'card' && (_selectedCardId ?? '').isEmpty) {
      setState(() {
        _error = 'Select or add a saved card to continue.';
        _showAddCardForm = _savedCards.isEmpty;
      });
      return;
    }

    final canCreateBackendBooking = data.technicianId.isNotEmpty &&
        (data.serviceId.isNotEmpty || data.category.isNotEmpty);
    final selectedCard = _selectedCard;
    var confirmationData = data.copyWith(
      paymentMethodCode: _paymentMethodCode,
      paymentMethod: _paymentMethodCode == 'card' ? 'Credit Card' : 'Cash',
      savedCardId: _paymentMethodCode == 'card' ? _selectedCardId ?? '' : '',
      savedCardLabel:
          _paymentMethodCode == 'card' ? selectedCard?.displayLabel ?? '' : '',
      savedCardLast4:
          _paymentMethodCode == 'card' ? selectedCard?.last4 ?? '' : '',
    );

    if (!canCreateBackendBooking) {
      setState(() {
        _error =
            'Cannot create booking without a valid technician and service.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final booking = await BookingsApi(_apiClient).createBooking(
        workerId: data.technicianId,
        serviceId: data.serviceId,
        serviceCategory: data.category,
        serviceName: data.serviceName,
        scheduledDate: data.scheduledDateTime ??
            DateTime.now().add(const Duration(days: 1)),
        scheduledTime: _backendSlotFromLabel(data.time),
        address: data.location,
        addressCity: data.addressCity.isNotEmpty ? data.addressCity : 'Cairo',
        addressStreet: data.addressStreet.isNotEmpty ? data.addressStreet : '',
        notes: data.notes,
        paymentMethod: _paymentMethodCode,
        savedCardId: _paymentMethodCode == 'card' ? _selectedCardId : null,
      );
      confirmationData = _confirmationDataFromBackend(
        confirmationData,
        booking,
      );
      if (!mounted) return;
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Booking failed. Please try again.';
      });
      return;
    }
    setState(() => _loading = false);

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookingConfirmationScreen(data: confirmationData),
      ),
    );
  }

  // ── build ────────────────────────────────────────────────────────────────────

  SavedCardModel? get _selectedCard {
    final id = _selectedCardId;
    if (id == null) return null;
    for (final card in _savedCards) {
      if (card.id == id) return card;
    }
    return null;
  }

  String get _paymentLabel =>
      _paymentMethodCode == 'card' ? 'Credit Card' : 'Cash';

  String _detectCardType(String digits) {
    if (digits.startsWith('4')) return 'visa';
    if (digits.startsWith('5')) return 'mastercard';
    if (digits.startsWith('3')) return 'amex';
    return 'other';
  }

  Widget _buildPaymentSelector(ThemeData theme, ServioThemeExtension servio) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return ServioCard(
      radius: ServioRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Payment Method',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _PaymentChoice(
                  icon: Icons.payments_outlined,
                  label: 'Cash',
                  selected: _paymentMethodCode == 'cash',
                  onTap: () => setState(() {
                    _paymentMethodCode = 'cash';
                    _error = null;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PaymentChoice(
                  icon: Icons.credit_card_rounded,
                  label: 'Credit Card',
                  selected: _paymentMethodCode == 'card',
                  onTap: () => setState(() {
                    _paymentMethodCode = 'card';
                    _showAddCardForm = _savedCards.isEmpty;
                    _error = null;
                  }),
                ),
              ),
            ],
          ),
          AnimatedSwitcher(
            duration: reduceMotion ? Duration.zero : ServioMotion.normal,
            switchInCurve: ServioMotion.spring,
            switchOutCurve: ServioMotion.standard,
            child: _paymentMethodCode == 'card'
                ? Padding(
                    key: const ValueKey<String>('card-payment-panel'),
                    padding: const EdgeInsets.only(top: 16),
                    child: _buildCardPicker(theme, servio),
                  )
                : const SizedBox.shrink(key: ValueKey<String>('cash-panel')),
          ),
        ],
      ),
    );
  }

  Widget _buildCardPicker(ThemeData theme, ServioThemeExtension servio) {
    if (_cardsLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final error = _cardsError;
    final showForm = _savedCards.isEmpty || _showAddCardForm;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (error != null) ...<Widget>[
          Text(
            error,
            style: theme.textTheme.bodySmall?.copyWith(color: servio.danger),
          ),
          const SizedBox(height: 10),
        ],
        if (showForm)
          _buildAddCardForm(theme, servio)
        else ...<Widget>[
          ...List<Widget>.generate(_savedCards.length, (int index) {
            final card = _savedCards[index];
            return TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : Duration(milliseconds: 320 + (index * 70)),
              curve: ServioMotion.curve,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, (1 - value) * 12),
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: index == _savedCards.length - 1 ? 0 : 10,
                ),
                child: _SavedCardChoice(
                  card: card,
                  selected: card.id == _selectedCardId,
                  onTap: () => setState(() {
                    _selectedCardId = card.id;
                    _error = null;
                  }),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey<String>('booking-add-card-button'),
            onPressed: () => setState(() => _showAddCardForm = true),
            icon: const Icon(Icons.add_card_rounded),
            label: const Text('Add New Card'),
          ),
        ],
        if (!showForm && error != null)
          TextButton(
            onPressed: _loadSavedCards,
            child: const Text('Retry'),
          ),
      ],
    );
  }

  Widget _buildAddCardForm(ThemeData theme, ServioThemeExtension servio) {
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : ServioMotion.normal,
      curve: ServioMotion.curve,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: servio.surfaceAlt,
        borderRadius: BorderRadius.circular(ServioRadius.md),
        border: Border.all(color: servio.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Add Card',
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('booking-card-number-field'),
            controller: _cardNumberController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Card number',
              hintText: '4242 4242 4242 4242',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey<String>('booking-card-expiry-field'),
            controller: _cardExpiryController,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(
              labelText: 'Expiry',
              hintText: 'MM/YY',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey<String>('booking-card-label-field'),
            controller: _cardLabelController,
            decoration: const InputDecoration(
              labelText: 'Label',
              hintText: 'Personal',
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              if (_savedCards.isNotEmpty) ...<Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _savingCard
                        ? null
                        : () => setState(() => _showAddCardForm = false),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: ServioPrimaryButton(
                  key: const ValueKey<String>('booking-save-card-button'),
                  label: _savingCard ? 'Saving...' : 'Save Card',
                  isLoading: _savingCard,
                  onPressed: _savingCard ? null : _saveCard,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    final baseRate = _moneyValue(widget.data.amount);
    final platformFee = (baseRate * 0.05).round();
    final estimatedTotal = baseRate + platformFee;
    final estimatedTotalLabel = _moneyLabel(estimatedTotal);
    final availabilityError = widget.data.isScheduledDateAvailable
        ? null
        : 'Technician is not available on this day';
    final visibleError = availabilityError ?? _error;
    final cardReady =
        _paymentMethodCode != 'card' || (_selectedCardId ?? '').isNotEmpty;
    final canConfirm =
        _termsAccepted && !_loading && availabilityError == null && cardReady;

    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back to step 2',
        ),
        title: const Text('Review & Confirm'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ServioSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // ── Step indicator ───────────────────────────────────────────────
              _StepIndicator(currentStep: 3),
              const SizedBox(height: 24),

              // ── Service Details review ───────────────────────────────────────
              _SectionCard(
                title: 'Service Details',
                onEdit: _editServiceDetails,
                children: <Widget>[
                  _ReviewRow(
                      label: 'Technician', value: widget.data.technicianName),
                  _ReviewRow(label: 'Service', value: widget.data.serviceName),
                  _ReviewRow(label: 'Date', value: widget.data.date),
                  _ReviewRow(label: 'Time', value: widget.data.time),
                  _ReviewRow(
                      label: 'Address',
                      value: widget.data.location,
                      isLast: true),
                ],
              ),
              const SizedBox(height: 16),

              // ── Payment review ───────────────────────────────────────────────
              _buildPaymentSelector(theme, servio),
              const SizedBox(height: 16),

              _SectionCard(
                title: 'Payment',
                children: <Widget>[
                  _ReviewRow(label: 'Method', value: _paymentLabel),
                  if (_paymentMethodCode == 'card' &&
                      (_selectedCard?.displayLabel ?? '').isNotEmpty)
                    _ReviewRow(
                      label: 'Card',
                      value: _selectedCard!.displayLabel,
                    ),
                  _ReviewRow(label: 'Base Rate', value: '$baseRate EGP'),
                  _ReviewRow(
                      label: 'Platform Fee', value: '$platformFee EGP (5%)'),
                  _ReviewRow(
                    label: 'Est. Total',
                    value: estimatedTotalLabel,
                    valueColor: servio.accent,
                    isBold: true,
                    isLast: true,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Order Summary card ───────────────────────────────────────────
              ServioCard(
                radius: ServioRadius.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Order Summary',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    // Technician mini-profile
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
                              widget.data.technicianName
                                  .trim()
                                  .split(' ')
                                  .where((w) => w.isNotEmpty)
                                  .take(2)
                                  .map((w) => w[0])
                                  .join()
                                  .toUpperCase(),
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: ServioColors.deepBrown,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                widget.data.technicianName,
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                widget.data.specialty,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: servio.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    // Pricing rows
                    _PriceLine(
                        label: 'Base rate (1 hr min)', value: '$baseRate EGP'),
                    const SizedBox(height: 8),
                    _PriceLine(
                        label: 'Platform fee (5%)', value: '$platformFee EGP'),
                    const SizedBox(height: 8),
                    _PriceLine(label: 'Parts & materials', value: 'As quoted'),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    _PriceLine(
                      label: 'Estimated Total',
                      value: estimatedTotalLabel,
                      isBold: true,
                      valueColor: servio.accent,
                    ),
                    const SizedBox(height: 20),
                    // Trust signals
                    ...<_TrustItem>[
                      const _TrustItem(
                          'Free cancellation up to 2 hours before'),
                      const _TrustItem('SERVIO Service Guarantee'),
                      const _TrustItem('Identity & licence verified'),
                      const _TrustItem('No hidden fees'),
                    ].map((_TrustItem item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: <Widget>[
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color:
                                      ServioColors.tint(ServioColors.success),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_rounded,
                                    color: ServioColors.success, size: 12),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.text,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: servio.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Error banner ────────────────────────────────────────────────
              if (visibleError != null) ...<Widget>[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ServioColors.tint(ServioColors.danger),
                    borderRadius: BorderRadius.circular(ServioRadius.md),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.error_outline_rounded,
                          color: ServioColors.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          visibleError,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: ServioColors.danger),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Credits toggle ───────────────────────────────────────────────
              Consumer<PaymentsProvider>(
                builder: (context, payments, _) {
                  final balance = payments.totalCreditBalance;
                  if (balance <= 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ServioCard(
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.wallet_rounded, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Text('Use Credits', style: TextStyle(fontWeight: FontWeight.w600)),
                                Text(
                                  'Balance: EGP ${balance.toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _useCredits,
                            onChanged: (v) => setState(() => _useCredits = v),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // ── Terms & Conditions consent ────────────────────────────────────
              ServioCard(
                radius: ServioRadius.md,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _termsAccepted,
                        onChanged: (bool? v) =>
                            setState(() => _termsAccepted = v ?? false),
                        activeColor: servio.accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: servio.textSecondary),
                          children: <InlineSpan>[
                            const TextSpan(text: 'I agree to the '),
                            TextSpan(
                              text: 'Terms of Service',
                              recognizer: TapGestureRecognizer()
                                ..onTap =
                                    () => _showLegalNotice('Terms of Service'),
                              style: TextStyle(
                                color: servio.accent,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              recognizer: TapGestureRecognizer()
                                ..onTap =
                                    () => _showLegalNotice('Privacy Policy'),
                              style: TextStyle(
                                color: servio.accent,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const TextSpan(
                              text:
                                  '. By confirming this booking you authorise the escrow hold.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Bottom action row ────────────────────────────────────────────
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: servio.border),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(ServioRadius.md),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Opacity(
                      opacity: canConfirm ? 1.0 : 0.5,
                      child: ServioPrimaryButton(
                        label: _loading ? 'Confirming…' : 'Confirm Booking',
                        onPressed: canConfirm ? _confirmBooking : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    const labels = <String>['Details', 'Date & Time', 'Confirm'];

    return Row(
      children: List<Widget>.generate(3, (int i) {
        final step = i + 1;
        final isDone = step < currentStep;
        final isActive = step == currentStep;

        return Expanded(
          child: Row(
            children: <Widget>[
              // Circle
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: isActive || isDone ? ServioGradients.brand : null,
                  color: isActive || isDone ? null : servio.surfaceAlt,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        isActive || isDone ? Colors.transparent : servio.border,
                  ),
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 14)
                      : Text(
                          '$step',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: isActive
                                        ? Colors.white
                                        : servio.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      labels[i],
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isActive
                                ? Theme.of(context).colorScheme.onSurface
                                : servio.textSecondary,
                            fontWeight:
                                isActive ? FontWeight.w700 : FontWeight.w400,
                          ),
                    ),
                    if (i < 2)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: isDone ? ServioGradients.accent : null,
                          color: isDone ? null : servio.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _PaymentChoice extends StatelessWidget {
  const _PaymentChoice({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return InkWell(
      borderRadius: BorderRadius.circular(ServioRadius.md),
      onTap: onTap,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : ServioMotion.normal,
        curve: ServioMotion.curve,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color:
              selected ? ServioColors.tint(servio.accent) : servio.surfaceAlt,
          borderRadius: BorderRadius.circular(ServioRadius.md),
          border: Border.all(
            color: selected ? servio.accent : servio.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: selected ? servio.accent : servio.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected ? servio.accent : theme.colorScheme.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedCardChoice extends StatelessWidget {
  const _SavedCardChoice({
    required this.card,
    required this.selected,
    required this.onTap,
  });

  final SavedCardModel card;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return InkWell(
      borderRadius: BorderRadius.circular(ServioRadius.md),
      onTap: onTap,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : ServioMotion.normal,
        curve: ServioMotion.curve,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : servio.surfaceAlt,
          borderRadius: BorderRadius.circular(ServioRadius.md),
          border: Border.all(
            color: selected ? servio.accent : servio.border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected ? ServioShadows.rest : const <BoxShadow>[],
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.credit_card_rounded, color: servio.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    card.displayLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (card.expiry.isNotEmpty)
                    Text(
                      'Expires ${card.expiry}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: servio.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: ServioMotion.fast,
              child: selected
                  ? Icon(
                      Icons.check_circle_rounded,
                      key: const ValueKey<String>('selected'),
                      color: servio.success,
                    )
                  : Icon(
                      Icons.radio_button_unchecked_rounded,
                      key: const ValueKey<String>('unselected'),
                      color: servio.textSecondary,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
    this.onEdit,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return ServioCard(
      radius: ServioRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (onEdit != null)
                GestureDetector(
                  onTap: onEdit,
                  child: Text(
                    'Edit',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: servio.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
    this.isLast = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: servio.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: valueColor ?? theme.colorScheme.onSurface,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: servio.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: valueColor ?? theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _TrustItem {
  const _TrustItem(this.text);
  final String text;
}

BookingFlowData _confirmationDataFromBackend(
  BookingFlowData original,
  BackendBooking booking,
) {
  final shortId = booking.id.length >= 6
      ? booking.id.substring(booking.id.length - 6).toUpperCase()
      : booking.id.toUpperCase();
  return original.copyWith(
    backendId: booking.id,
    reference: '#SRV-$shortId',
    amount: booking.totalAmount > 0
        ? '${booking.totalAmount.toStringAsFixed(0)} EGP'
        : original.amount,
    pin: booking.pin,
    paymentMethod:
        booking.paymentMethod.toLowerCase() == 'card' ? 'Credit Card' : 'Cash',
    paymentMethodCode:
        booking.paymentMethod.toLowerCase() == 'card' ? 'card' : 'cash',
    savedCardLabel: booking.paymentCardLabel.isNotEmpty
        ? booking.paymentCardLabel
        : booking.paymentCardLast4.isNotEmpty
            ? 'Card ending ${booking.paymentCardLast4}'
            : '',
    savedCardLast4: booking.paymentCardLast4,
    statusCode: booking.status,
    statusLabel: _statusLabelFromBackend(booking.status),
    createdAt: booking.createdAt,
  );
}

String _statusLabelFromBackend(String status) {
  return switch (status.toLowerCase()) {
    'pending' => 'Pending',
    'confirmed' || 'accepted' || 'scheduled' => 'Confirmed',
    'en_route' || 'enroute' => 'En Route',
    'arrived' => 'Arrived',
    'in_progress' || 'inprogress' => 'In Progress',
    'awaiting_customer_confirmation' => 'Awaiting Confirmation',
    'pending_admin_review' => 'Under Review',
    'completed' || 'done' => 'Completed',
    'cancelled' || 'canceled' => 'Cancelled',
    'rejected' => 'Rejected',
    'disputed' => 'Disputed',
    _ => 'Pending',
  };
}

String _backendSlotFromLabel(String label) {
  final match = RegExp(r'(\d{1,2})(?::\d{2})?\s*(AM|PM)?', caseSensitive: false)
      .firstMatch(label);
  if (match == null) return '10:00';

  var hour = int.tryParse(match.group(1) ?? '') ?? 10;
  final meridiem = match.group(2)?.toUpperCase();
  if (meridiem == 'PM' && hour < 12) hour += 12;
  if (meridiem == 'AM' && hour == 12) hour = 0;
  hour = hour.clamp(0, 23).toInt();
  return '${hour.toString().padLeft(2, '0')}:00';
}

int _moneyValue(String value) {
  final numeric = value.replaceAll(RegExp(r'[^0-9]'), '');
  return int.tryParse(numeric) ?? 0;
}

String _moneyLabel(int value) => '$value EGP';
