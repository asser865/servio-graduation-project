import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/bookings_api.dart';
import '../../core/api/payments_api.dart';
import '../../core/api/saved_cards_api.dart';
import '../../core/models/backend_booking_model.dart';
import '../../core/models/saved_card_model.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import 'booking_confirmation_screen.dart';
import 'booking_flow_data.dart';
import 'booking_strings.dart';
import 'widgets/booking_progress_indicator.dart';

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
  bool _loading = false;
  String? _error;
  late String _paymentMethodCode;
  String? _selectedCardId;
  List<SavedCardModel> _savedCards = <SavedCardModel>[];
  bool _cardsLoading = false;
  String? _cardsError;
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

  Future<void> _showAddCardDialog() async {
    _cardNumberController.clear();
    _cardExpiryController.clear();
    _cardLabelController.text = 'Personal';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        String labelSelection = 'Personal';
        bool dialogSaving = false;
        String? dialogError;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> handleSave() async {
              final digits =
                  _cardNumberController.text.replaceAll(RegExp(r'\D'), '');
              final expiry =
                  _cardExpiryController.text.replaceAll(' ', '');
              if (digits.length < 12 ||
                  !RegExp(r'^\d+$').hasMatch(digits)) {
                setDialogState(
                    () => dialogError = 'Enter a valid card number.');
                return;
              }
              if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(expiry)) {
                setDialogState(
                    () => dialogError = 'Enter expiry as MM/YY.');
                return;
              }
              setDialogState(() {
                dialogSaving = true;
                dialogError = null;
              });
              try {
                final card = await SavedCardsApi(_apiClient).addCard(
                  last4: digits.substring(digits.length - 4),
                  expiry: expiry,
                  cardType: _detectCardType(digits),
                  label: labelSelection,
                );
                if (!mounted) return;
                final cards =
                    await SavedCardsApi(_apiClient).getSavedCards();
                if (!mounted) return;
                setState(() {
                  _savedCards = cards;
                  _selectedCardId = card.id;
                });
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              } on ApiException catch (e) {
                setDialogState(() {
                  dialogSaving = false;
                  dialogError = e.message;
                });
              } catch (_) {
                setDialogState(() {
                  dialogSaving = false;
                  dialogError = 'Could not save card. Try again.';
                });
              }
            }

            final isDark =
                Theme.of(context).brightness == Brightness.dark;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ServioRadius.lg),
              ),
              backgroundColor:
                  isDark ? ServioColors.backgroundSoftDark : Colors.white,
              title: const Text(
                'Add New Card',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextField(
                      key: const ValueKey<String>(
                          'booking-card-number-field'),
                      controller: _cardNumberController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Card Number',
                        hintText: '•••• •••• •••• ••••',
                        prefixIcon:
                            const Icon(Icons.credit_card_rounded),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(ServioRadius.md),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey<String>(
                          'booking-card-expiry-field'),
                      controller: _cardExpiryController,
                      keyboardType: TextInputType.datetime,
                      decoration: InputDecoration(
                        labelText: 'Expiry',
                        hintText: 'MM/YY',
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(ServioRadius.md),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <String>['Personal', 'Work']
                          .map((label) {
                        final isSelected = labelSelection == label;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                                left: label == 'Work' ? 8 : 0),
                            child: GestureDetector(
                              onTap: () {
                                setDialogState(
                                    () => labelSelection = label);
                                _cardLabelController.text = label;
                              },
                              child: AnimatedContainer(
                                duration: ServioMotion.fast,
                                curve: ServioMotion.spring,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFF3EDE7)
                                          .withValues(alpha: 0.7)
                                      : (isDark
                                          ? const Color(0xFF1E2229)
                                          : const Color(0xFFF5F5F5)),
                                  borderRadius: BorderRadius.circular(
                                      ServioRadius.md),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF9A8C73)
                                        : const Color(0xFF9A8C73)
                                            .withValues(alpha: 0.3),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? const Color(0xFF9A8C73)
                                          : (isDark
                                              ? ServioColors
                                                  .textPrimaryDark
                                              : ServioColors
                                                  .backgroundDark),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (dialogError != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        dialogError!,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: ServioColors.danger,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: dialogSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                dialogSaving
                    ? const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2),
                        ),
                      )
                    : TextButton(
                        key: const ValueKey<String>(
                            'booking-save-card-button'),
                        onPressed: handleSave,
                        child: const Text(
                          'Save Card',
                          style:
                              TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmBooking() async {
    if (!_termsAccepted) return;

    final data = widget.data;
    if (!data.isScheduledDateAvailable) {
      setState(() => _error = 'Technician is not available on this day');
      return;
    }
    if (_paymentMethodCode == 'card' && (_selectedCardId ?? '').isEmpty) {
      setState(() => _error = 'Select or add a saved card to continue.');
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
      setState(() => _error =
          'Cannot create booking without a valid technician and service.');
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
      confirmationData = _confirmationDataFromBackend(confirmationData, booking);
      if (!mounted) return;

      if (_paymentMethodCode == 'card') {
        try {
          final paymentData = await PaymentsApi(_apiClient).holdPayment(
            bookingId: booking.id,
            savedCardId: _selectedCardId,
          );
          final paymentId = paymentData['_id'] as String? ?? '';
          confirmationData = confirmationData.copyWith(paymentId: paymentId);
        } on ApiException catch (e) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _error = 'Payment hold failed: ${e.message}';
          });
          return;
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _error = 'Could not hold payment. Please try again.';
          });
          return;
        }
      }
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

  // ── build helpers ────────────────────────────────────────────────────────────

  SavedCardModel? get _selectedCard {
    final id = _selectedCardId;
    if (id == null) return null;
    for (final card in _savedCards) {
      if (card.id == id) return card;
    }
    return null;
  }

  String _detectCardType(String digits) {
    if (digits.startsWith('4')) return 'visa';
    if (digits.startsWith('5')) return 'mastercard';
    if (digits.startsWith('3')) return 'amex';
    return 'other';
  }

  Widget _buildPaymentSelector(
      ThemeData theme, ServioThemeExtension servio) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return ServioCard(
      radius: ServioRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Payment Method',
            style:
                theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
                : const SizedBox.shrink(
                    key: ValueKey<String>('cash-panel')),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (error != null) ...<Widget>[
          Text(
            error,
            style: theme.textTheme.bodySmall?.copyWith(color: servio.danger),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loadSavedCards,
            child: const Text('Retry'),
          ),
          const SizedBox(height: 8),
        ],
        if (_savedCards.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'No saved cards.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: servio.textSecondary),
            ),
          )
        else ...<Widget>[
          ...List<Widget>.generate(_savedCards.length, (int index) {
            final card = _savedCards[index];
            return TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : Duration(milliseconds: 320 + (index * 70)),
              curve: ServioMotion.curve,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, (1 - value) * 12),
                  child: child,
                ),
              ),
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
        ],
        OutlinedButton.icon(
          key: const ValueKey<String>('booking-add-card-button'),
          onPressed: _showAddCardDialog,
          icon: const Icon(Icons.add_card_rounded),
          label: const Text('Add New Card'),
          style: OutlinedButton.styleFrom(
            minimumSize:
                const Size(double.infinity, ServioSpacing.tapTarget),
            side: const BorderSide(
              color: Color.fromRGBO(154, 140, 115, 0.4),
            ),
            foregroundColor: const Color(0xFF9A8C73),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final isDark = theme.brightness == Brightness.dark;
    final navyAnchor =
        isDark ? ServioColors.textPrimaryDark : ServioColors.backgroundDark;

    final baseRate = _moneyValue(widget.data.amount);
    final platformFee = (baseRate * 0.10).round();
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

    return Scaffold(
      extendBody: true,
      backgroundColor:
          isDark ? ServioColors.backgroundDark : const Color(0xFFFAF8F5),
      appBar: AppBar(
        backgroundColor: isDark
            ? ServioColors.backgroundDark.withValues(alpha: 0.95)
            : const Color(0xFFFBF9F6).withValues(alpha: 0.95),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: navyAnchor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Review & Confirm',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: navyAnchor,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.help_outline_rounded, color: navyAnchor),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: const Color(0xFF9A8C73).withValues(alpha: 0.2),
          ),
        ),
      ),
      bottomNavigationBar: _BottomConfirmBar(
        loading: _loading,
        onPressed: canConfirm ? _confirmBooking : null,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            BookingProgressIndicator(
              currentStep: 3,
              totalSteps: 3,
              stepLabels: BookingStrings.stepLabels,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  ServioSpacing.screenPadding,
                  8,
                  ServioSpacing.screenPadding,
                  100,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // ── Service details review ────────────────────────────────
                    _SectionCard(
                      title: 'Service Details',
                      onEdit: _editServiceDetails,
                      children: <Widget>[
                        _ReviewRow(
                            label: 'Technician',
                            value: widget.data.technicianName),
                        _ReviewRow(
                            label: 'Service',
                            value: widget.data.serviceName),
                        _ReviewRow(
                            label: 'Date', value: widget.data.date),
                        _ReviewRow(
                            label: 'Time', value: widget.data.time),
                        _ReviewRow(
                            label: 'Address',
                            value: widget.data.location,
                            isLast: true),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Payment selector ──────────────────────────────────────
                    _buildPaymentSelector(theme, servio),
                    const SizedBox(height: 16),

                    // ── Summary ───────────────────────────────────────────────
                    ServioCard(
                      radius: ServioRadius.lg,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Summary',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 16),
                          _PriceLine(
                              label: 'Base Rate',
                              value: '$baseRate EGP'),
                          const SizedBox(height: 8),
                          _PriceLine(
                              label: 'Platform Fee (10%)',
                              value: '$platformFee EGP'),
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
                          ...<_TrustItem>[
                            const _TrustItem(
                                'Free cancellation up to 2 hours before'),
                            const _TrustItem('SERVIO Service Guarantee'),
                            const _TrustItem(
                                'Identity & licence verified'),
                            const _TrustItem('No hidden fees'),
                          ].map(
                            (_TrustItem item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: <Widget>[
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: ServioColors.tint(
                                          ServioColors.success),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                        Icons.check_rounded,
                                        color: ServioColors.success,
                                        size: 12),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      item.text,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              color: servio.textSecondary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Error banner ──────────────────────────────────────────
                    if (visibleError != null) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ServioColors.tint(ServioColors.danger),
                          borderRadius:
                              BorderRadius.circular(ServioRadius.md),
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

                    // ── Terms & conditions ────────────────────────────────────
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
                              onChanged: (bool? v) => setState(
                                  () => _termsAccepted = v ?? false),
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
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: servio.textSecondary),
                                children: <InlineSpan>[
                                  const TextSpan(text: 'I agree to the '),
                                  TextSpan(
                                    text: 'Terms of Service',
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => _showLegalNotice(
                                          'Terms of Service'),
                                    style: TextStyle(
                                      color: servio.accent,
                                      fontWeight: FontWeight.w600,
                                      decoration:
                                          TextDecoration.underline,
                                    ),
                                  ),
                                  const TextSpan(
                                    text:
                                        ' and confirm that I am present at the service location for the technician\'s arrival.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
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

// ── Bottom action bar ──────────────────────────────────────────────────────────

class _BottomConfirmBar extends StatelessWidget {
  const _BottomConfirmBar({this.onPressed, this.loading = false});

  final VoidCallback? onPressed;
  final bool loading;

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
      child: ServioPrimaryButton(
        label: loading ? 'Confirming…' : 'Confirm Booking',
        isLoading: loading,
        onPressed: onPressed,
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

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
          color: selected
              ? ServioColors.tint(servio.accent)
              : servio.surfaceAlt,
          borderRadius: BorderRadius.circular(ServioRadius.md),
          border: Border.all(
            color: selected ? servio.accent : servio.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon,
                color:
                    selected ? servio.accent : servio.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected
                      ? servio.accent
                      : theme.colorScheme.onSurface,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
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
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (card.expiry.isNotEmpty)
                    Text(
                      'Expires ${card.expiry}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: servio.textSecondary),
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
    this.isLast = false,
  });

  final String label;
  final String value;
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
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
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
            style: theme.textTheme.bodySmall
                ?.copyWith(color: servio.textSecondary),
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

// ── Private helpers ────────────────────────────────────────────────────────────

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
    paymentMethod: booking.paymentMethod.toLowerCase() == 'card'
        ? 'Credit Card'
        : 'Cash',
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
  final match =
      RegExp(r'(\d{1,2})(?::\d{2})?\s*(AM|PM)?', caseSensitive: false)
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
