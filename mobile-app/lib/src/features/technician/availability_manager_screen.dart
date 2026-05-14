import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/user_account.dart';
import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../../design_system/widgets/servio_tab_shell.dart';
import 'time_off_calendar.dart';

class AvailabilityManagerScreen extends StatefulWidget {
  const AvailabilityManagerScreen({super.key});

  @override
  State<AvailabilityManagerScreen> createState() =>
      _AvailabilityManagerScreenState();
}

class _AvailabilityManagerScreenState extends State<AvailabilityManagerScreen> {
  late final List<_AvailabilityDay> _days;
  late final TextEditingController _serviceAreaCtrl;

  bool _availableNow = false;
  bool _loadingProfile = false;
  bool _savingSchedule = false;
  bool _savingAvailableNow = false;
  _AvailabilityPreset? _selectedPreset;
  String? _error;

  @override
  void initState() {
    super.initState();
    final account = context.read<SessionProvider>().account;
    _serviceAreaCtrl = TextEditingController(
      text: account?.locationLabel ?? '',
    );
    _days = _initialDays(account?.availability ?? const <AvailabilitySlot>[]);
    _selectedPreset = _matchingPreset(_days);
    _availableNow = account?.isAvailable ?? false;
    unawaited(_loadCurrentWorkerProfile());
  }

  @override
  void dispose() {
    _serviceAreaCtrl.dispose();
    super.dispose();
  }

  bool get _hasWorkingDays => _days.any((day) => day.enabled);
  bool get _isBusy => _savingSchedule || _savingAvailableNow;

  List<_AvailabilityDay> _initialDays(List<AvailabilitySlot> saved) {
    final savedByDay = <String, AvailabilitySlot>{
      for (final slot in saved) slot.day.toLowerCase(): slot,
    };
    final hasSavedSchedule = savedByDay.isNotEmpty;

    return _dayDefinitions.map((definition) {
      final savedSlot = savedByDay[definition.apiDay];
      return _AvailabilityDay(
        definition: definition,
        enabled: hasSavedSchedule ? savedSlot != null : definition.defaultOn,
        start:
            _parseApiTime(savedSlot?.from, const TimeOfDay(hour: 9, minute: 0)),
        end: _parseApiTime(savedSlot?.to, const TimeOfDay(hour: 17, minute: 0)),
      );
    }).toList();
  }

  void _syncFromAccount(UserAccount? account) {
    if (account == null) return;
    _availableNow = account.isAvailable;
    _serviceAreaCtrl.text = account.locationLabel;

    final freshDays = _initialDays(account.availability);
    for (var i = 0; i < _days.length; i += 1) {
      _days[i]
        ..enabled = freshDays[i].enabled
        ..start = freshDays[i].start
        ..end = freshDays[i].end;
    }
    _selectedPreset = _matchingPreset(_days);
  }

  Future<void> _loadCurrentWorkerProfile() async {
    setState(() => _loadingProfile = true);
    final session = context.read<SessionProvider>();
    final error = await session.loadCurrentWorkerProfile();
    if (!mounted) return;

    setState(() {
      if (error == null) {
        _syncFromAccount(session.account);
        _error = null;
      } else if (session.account == null) {
        _error = error;
      }
      _loadingProfile = false;
    });
  }

  Future<void> _toggleAvailableNow(bool value) async {
    if (_savingAvailableNow) return;

    final previous = _availableNow;
    final locale = context.read<LocaleProvider>().languageCode;
    setState(() {
      _availableNow = value;
      _savingAvailableNow = true;
      _error = null;
    });

    final session = context.read<SessionProvider>();
    final error = await session.toggleAvailableNow(value);
    if (!mounted) return;

    setState(() {
      _savingAvailableNow = false;
      if (error == null) {
        _availableNow = session.account?.isAvailable ?? value;
      } else {
        _availableNow = previous;
        _error = error;
      }
    });

    _showMessage(
      error ??
          (value
              ? _copy(
                  locale,
                  en: 'You are visible and accepting bookings.',
                  ar: 'You are visible and accepting bookings.',
                )
              : _copy(
                  locale,
                  en: 'You are offline. New bookings are paused.',
                  ar: 'You are offline. New bookings are paused.',
                )),
      isError: error != null,
    );
  }

  void _setDayEnabled(_AvailabilityDay day, bool value) {
    setState(() {
      day.enabled = value;
      _selectedPreset = _matchingPreset(_days);
      _error = null;
    });
  }

  Future<void> _pickTime(_AvailabilityDay day, {required bool isStart}) async {
    if (_isBusy || !day.enabled) return;

    final locale = context.read<LocaleProvider>().languageCode;
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? day.start : day.end,
      helpText: isStart
          ? _copy(locale, en: 'Start time', ar: 'Start time')
          : _copy(locale, en: 'End time', ar: 'End time'),
    );

    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        day.start = picked;
      } else {
        day.end = picked;
      }
      _selectedPreset = _matchingPreset(_days);
      _error = null;
    });
  }

  void _applyPreset(_AvailabilityPreset preset) {
    setState(() {
      for (final day in _days) {
        switch (preset) {
          case _AvailabilityPreset.weekdays:
            day.enabled = day.definition.isWeekday;
            day.start = const TimeOfDay(hour: 9, minute: 0);
            day.end = const TimeOfDay(hour: 17, minute: 0);
            break;
          case _AvailabilityPreset.weekends:
            day.enabled = day.definition.isWeekend;
            day.start = const TimeOfDay(hour: 10, minute: 0);
            day.end = const TimeOfDay(hour: 15, minute: 0);
            break;
          case _AvailabilityPreset.everyDay:
            day.enabled = true;
            day.start = const TimeOfDay(hour: 9, minute: 0);
            day.end = const TimeOfDay(hour: 17, minute: 0);
            break;
          case _AvailabilityPreset.clear:
            day.enabled = false;
            break;
        }
      }
      _selectedPreset = preset;
      _error = null;
    });
  }

  _AvailabilityPreset? _matchingPreset(List<_AvailabilityDay> days) {
    if (days.every((day) => !day.enabled)) {
      return _AvailabilityPreset.clear;
    }

    final everyDay = days.every((day) {
      return day.enabled &&
          day.start == const TimeOfDay(hour: 9, minute: 0) &&
          day.end == const TimeOfDay(hour: 17, minute: 0);
    });
    if (everyDay) return _AvailabilityPreset.everyDay;

    final weekdays = days.every((day) {
      if (day.enabled != day.definition.isWeekday) return false;
      if (!day.enabled) return true;
      return day.start == const TimeOfDay(hour: 9, minute: 0) &&
          day.end == const TimeOfDay(hour: 17, minute: 0);
    });
    if (weekdays) return _AvailabilityPreset.weekdays;

    final weekends = days.every((day) {
      if (day.enabled != day.definition.isWeekend) return false;
      if (!day.enabled) return true;
      return day.start == const TimeOfDay(hour: 10, minute: 0) &&
          day.end == const TimeOfDay(hour: 15, minute: 0);
    });
    if (weekends) return _AvailabilityPreset.weekends;

    return null;
  }

  String? _validateSchedule(String locale) {
    final activeDays = _days.where((day) => day.enabled).toList();
    if (activeDays.isEmpty) {
      return _copy(
        locale,
        en: 'Enable at least one working day before saving.',
        ar: 'Enable at least one working day before saving.',
      );
    }

    for (final day in activeDays) {
      if (_minutes(day.end) <= _minutes(day.start)) {
        return _copy(
          locale,
          en: 'End time must be after start time for ${day.definition.fullLabel(locale)}.',
          ar: 'End time must be after start time for ${day.definition.fullLabel(locale)}.',
        );
      }
    }

    return null;
  }

  Future<void> _saveAvailability() async {
    final locale = context.read<LocaleProvider>().languageCode;
    final validationError = _validateSchedule(locale);
    if (validationError != null) {
      setState(() => _error = validationError);
      _showMessage(validationError, isError: true);
      return;
    }

    setState(() {
      _savingSchedule = true;
      _error = null;
    });

    final slots = _days
        .where((day) => day.enabled)
        .map(
          (day) => AvailabilitySlot(
            day: day.definition.apiDay,
            from: _formatApiTime(day.start),
            to: _formatApiTime(day.end),
          ),
        )
        .toList();

    final session = context.read<SessionProvider>();
    final serviceArea = _serviceAreaCtrl.text.trim();
    final previousServiceArea = session.account?.locationLabel.trim() ?? '';
    String? error;

    if (serviceArea != previousServiceArea) {
      error = await session.updateProfile(<String, dynamic>{
        'locationLabel': serviceArea,
      });
    }

    error ??= await session.updateWorkerAvailability(slots);
    if (!mounted) return;

    setState(() {
      if (error == null) {
        _syncFromAccount(session.account);
      }
      _savingSchedule = false;
      _error = error;
    });

    _showMessage(
      error ??
          _copy(
            locale,
            en: 'Availability updated.',
            ar: 'Availability updated.',
          ),
      isError: error != null,
    );
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? context.servio.danger : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final locale = context.watch<LocaleProvider>().languageCode;
    final account = context.watch<SessionProvider>().account;
    final bottomInset = ServioTabShell.bottomOverlayInsetOf(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        top: false,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    ServioSpacing.screenPadding,
                    MediaQuery.paddingOf(context).top + 12,
                    ServioSpacing.screenPadding,
                    112 + bottomInset,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _AvailabilityHeaderCard(
                            locale: locale,
                            availableNow: _availableNow,
                            saving: _savingAvailableNow,
                            loading: _loadingProfile,
                            onChanged: _toggleAvailableNow,
                          ),
                          if (_error != null) ...<Widget>[
                            const SizedBox(height: 12),
                            _NoticeCard(
                              icon: Icons.error_outline_rounded,
                              title: _copy(
                                locale,
                                en: 'Availability needs attention',
                                ar: 'Availability needs attention',
                              ),
                              message: _error!,
                              color: servio.danger,
                            ),
                          ],
                          if (!_hasWorkingDays) ...<Widget>[
                            const SizedBox(height: 12),
                            _NoticeCard(
                              icon: Icons.event_busy_rounded,
                              title: _copy(
                                locale,
                                en: 'No working days selected',
                                ar: 'No working days selected',
                              ),
                              message: _copy(
                                locale,
                                en: 'Add at least one day before saving a bookable schedule.',
                                ar: 'Add at least one day before saving a bookable schedule.',
                              ),
                              color: servio.warning,
                            ),
                          ],
                          const SizedBox(height: 18),
                          _WeeklySchedulePanel(
                            locale: locale,
                            days: _days,
                            busy: _isBusy,
                            selectedPreset: _selectedPreset,
                            onPresetSelected: _applyPreset,
                            onDayChanged: _setDayEnabled,
                            onStartTap: (day) => _pickTime(day, isStart: true),
                            onEndTap: (day) => _pickTime(day, isStart: false),
                          ),
                          const SizedBox(height: 18),
                          _CoverageCard(
                            account: account,
                            locale: locale,
                            serviceAreaController: _serviceAreaCtrl,
                            saving: _isBusy,
                            onServiceAreaChanged: () {
                              setState(() => _error = null);
                            },
                          ),
                          const SizedBox(height: 18),
                          TimeOffCalendarCard(
                            availability: account?.availability ??
                                const <AvailabilitySlot>[],
                            blockedDates:
                                account?.blockedDates ?? const <String>[],
                            locale: locale,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              left: ServioSpacing.screenPadding,
              child: _FloatingBackButton(
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    ServioSpacing.screenPadding,
                    10,
                    ServioSpacing.screenPadding,
                    12 + bottomInset,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: SizedBox(
                        width: double.infinity,
                        child: ServioPrimaryButton(
                          label: _savingSchedule
                              ? _copy(
                                  locale,
                                  en: 'Saving...',
                                  ar: 'Saving...',
                                )
                              : _copy(
                                  locale,
                                  en: 'Save Availability',
                                  ar: 'Save Availability',
                                ),
                          onPressed: _savingSchedule ? null : _saveAvailability,
                          isLoading: _savingSchedule,
                        ),
                      ),
                    ),
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

class _FloatingBackButton extends StatefulWidget {
  const _FloatingBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_FloatingBackButton> createState() => _FloatingBackButtonState();
}

class _FloatingBackButtonState extends State<_FloatingBackButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: ServioMotion.fast,
      reverseDuration: ServioMotion.normal,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _controller, curve: ServioMotion.spring),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _controller.forward();
  void _onTapUp(TapUpDetails _) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Back',
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onPressed,
        child: ScaleTransition(
          scale: _scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: ServioGradients.brand,
              shape: BoxShape.circle,
              boxShadow: ServioShadows.rest,
            ),
            child: const SizedBox(
              width: 46,
              height: 46,
              child: Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvailabilityHeaderCard extends StatelessWidget {
  const _AvailabilityHeaderCard({
    required this.locale,
    required this.availableNow,
    required this.saving,
    required this.loading,
    required this.onChanged,
  });

  final String locale;
  final bool availableNow;
  final bool saving;
  final bool loading;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final isDark = theme.brightness == Brightness.dark;
    final headlineColor = isDark ? Colors.white : ServioColors.deepBrown;
    final supportColor = headlineColor.withValues(alpha: 0.72);

    return ServioCard(
      radius: ServioRadius.lg,
      elevated: true,
      padding: EdgeInsets.zero,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isDark ? ServioGradients.brand : ServioGradients.warm,
          borderRadius: BorderRadius.circular(ServioRadius.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _copy(locale, en: 'Availability', ar: 'Availability'),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: headlineColor,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          _copy(
                            locale,
                            en: 'Set when customers can book you.',
                            ar: 'Set when customers can book you.',
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: supportColor,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedContainer(
                    duration: _motion(context, ServioMotion.normal),
                    curve: ServioMotion.spring,
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(ServioRadius.md),
                    ),
                    child: Icon(
                      availableNow
                          ? Icons.online_prediction_rounded
                          : Icons.power_settings_new_rounded,
                      color: availableNow ? servio.success : servio.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.74),
                  borderRadius: BorderRadius.circular(ServioRadius.md),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _AvailabilityStatusPill(
                        locale: locale,
                        availableNow: availableNow,
                        saving: saving || loading,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Switch.adaptive(
                      value: availableNow,
                      activeColor: servio.success,
                      onChanged: saving ? null : onChanged,
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

class _AvailabilityStatusPill extends StatelessWidget {
  const _AvailabilityStatusPill({
    required this.locale,
    required this.availableNow,
    required this.saving,
  });

  final String locale;
  final bool availableNow;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final color = availableNow ? servio.success : servio.warning;

    return AnimatedContainer(
      duration: _motion(context, ServioMotion.normal),
      curve: ServioMotion.spring,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: ServioColors.tint(color),
        borderRadius: BorderRadius.circular(ServioRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedSwitcher(
            duration: _motion(context, ServioMotion.fast),
            child: saving
                ? SizedBox(
                    key: const ValueKey<String>('saving'),
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  )
                : Icon(
                    availableNow
                        ? Icons.check_circle_rounded
                        : Icons.pause_circle_rounded,
                    key: ValueKey<bool>(availableNow),
                    size: 17,
                    color: color,
                  ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: AnimatedSwitcher(
              duration: _motion(context, ServioMotion.fast),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: child,
              ),
              child: Text(
                availableNow
                    ? _copy(
                        locale,
                        en: 'Accepting bookings',
                        ar: 'Accepting bookings',
                      )
                    : _copy(locale, en: 'Offline', ar: 'Offline'),
                key: ValueKey<bool>(availableNow),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklySchedulePanel extends StatelessWidget {
  const _WeeklySchedulePanel({
    required this.locale,
    required this.days,
    required this.busy,
    required this.selectedPreset,
    required this.onPresetSelected,
    required this.onDayChanged,
    required this.onStartTap,
    required this.onEndTap,
  });

  final String locale;
  final List<_AvailabilityDay> days;
  final bool busy;
  final _AvailabilityPreset? selectedPreset;
  final ValueChanged<_AvailabilityPreset> onPresetSelected;
  final void Function(_AvailabilityDay day, bool value) onDayChanged;
  final ValueChanged<_AvailabilityDay> onStartTap;
  final ValueChanged<_AvailabilityDay> onEndTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return ServioCard(
      radius: ServioRadius.lg,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: ServioColors.tint(servio.accent),
                  borderRadius: BorderRadius.circular(ServioRadius.md),
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  color: servio.accent,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _copy(
                        locale,
                        en: 'Weekly schedule',
                        ar: 'Weekly schedule',
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _copy(
                        locale,
                        en: 'Use backend day keys and 24-hour time.',
                        ar: 'Use backend day keys and 24-hour time.',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: servio.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _PresetRail(
            locale: locale,
            busy: busy,
            selectedPreset: selectedPreset,
            onSelected: onPresetSelected,
          ),
          const SizedBox(height: 14),
          ...days.map(
            (day) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ScheduleDayRow(
                day: day,
                locale: locale,
                busy: busy,
                onChanged: (value) => onDayChanged(day, value),
                onStartTap: () => onStartTap(day),
                onEndTap: () => onEndTap(day),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetRail extends StatelessWidget {
  const _PresetRail({
    required this.locale,
    required this.busy,
    required this.selectedPreset,
    required this.onSelected,
  });

  final String locale;
  final bool busy;
  final _AvailabilityPreset? selectedPreset;
  final ValueChanged<_AvailabilityPreset> onSelected;

  @override
  Widget build(BuildContext context) {
    final presets = <_PresetButtonData>[
      _PresetButtonData(
        preset: _AvailabilityPreset.weekdays,
        label: _copy(locale, en: 'Weekdays', ar: 'Weekdays'),
      ),
      _PresetButtonData(
        preset: _AvailabilityPreset.weekends,
        label: _copy(locale, en: 'Weekends', ar: 'Weekends'),
      ),
      _PresetButtonData(
        preset: _AvailabilityPreset.everyDay,
        label: _copy(locale, en: 'Every day', ar: 'Every day'),
      ),
      _PresetButtonData(
        preset: _AvailabilityPreset.clear,
        label: _copy(locale, en: 'Clear', ar: 'Clear'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        final useTwoRows = constraints.maxWidth < 320;

        if (useTwoRows) {
          final chipWidth = (constraints.maxWidth - gap) / 2;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: presets.map((preset) {
              return SizedBox(
                width: chipWidth,
                child: _PresetButton(
                  data: preset,
                  enabled: !busy,
                  selected: selectedPreset == preset.preset,
                  onTap: () => onSelected(preset.preset),
                ),
              );
            }).toList(),
          );
        }

        return Row(
          children: presets.map((preset) {
            final isLast = identical(preset, presets.last);
            return Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.only(end: isLast ? 0 : gap),
                child: _PresetButton(
                  data: preset,
                  enabled: !busy,
                  selected: selectedPreset == preset.preset,
                  onTap: () => onSelected(preset.preset),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({
    required this.data,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  final _PresetButtonData data;
  final bool enabled;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final radius = BorderRadius.circular(ServioRadius.md);

    final foreground = selected
        ? servio.accent
        : enabled
            ? theme.colorScheme.onSurface
            : servio.textSecondary;

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: _motion(context, ServioMotion.normal),
          curve: ServioMotion.spring,
          constraints: const BoxConstraints(minHeight: 36),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? ServioColors.tint(servio.accent)
                : enabled
                    ? servio.surfaceAlt
                    : servio.backgroundSoft,
            borderRadius: radius,
            border: Border.all(
              color: selected
                  ? servio.accent.withValues(alpha: 0.7)
                  : servio.border.withValues(alpha: 0.72),
            ),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: servio.accent.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              data.label,
              maxLines: 1,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduleDayRow extends StatelessWidget {
  const _ScheduleDayRow({
    required this.day,
    required this.locale,
    required this.busy,
    required this.onChanged,
    required this.onStartTap,
    required this.onEndTap,
  });

  final _AvailabilityDay day;
  final String locale;
  final bool busy;
  final ValueChanged<bool> onChanged;
  final VoidCallback onStartTap;
  final VoidCallback onEndTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final enabled = day.enabled;
    final invalid = enabled && _minutes(day.end) <= _minutes(day.start);

    return AnimatedContainer(
      duration: _motion(context, ServioMotion.normal),
      curve: ServioMotion.spring,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: enabled ? theme.colorScheme.surface : servio.surfaceAlt,
        borderRadius: BorderRadius.circular(ServioRadius.md),
        border: Border.all(
          color: invalid
              ? servio.danger
              : enabled
                  ? servio.accent.withValues(alpha: 0.36)
                  : servio.border.withValues(alpha: 0.72),
        ),
      ),
      child: AnimatedSize(
        duration: _motion(context, ServioMotion.normal),
        curve: ServioMotion.spring,
        alignment: Alignment.topCenter,
        child: Row(
          children: <Widget>[
            _DayBadge(
              shortLabel: day.definition.label(locale),
              fullLabel: day.definition.fullLabel(locale),
              enabled: enabled,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AnimatedSwitcher(
                duration: _motion(context, ServioMotion.normal),
                switchInCurve: ServioMotion.spring,
                switchOutCurve: ServioMotion.standard,
                transitionBuilder: (child, animation) {
                  final offset = Tween<Offset>(
                    begin: const Offset(0.06, 0),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: offset, child: child),
                  );
                },
                child: enabled
                    ? Row(
                        key: ValueKey<String>(
                            'enabled-${day.definition.apiDay}'),
                        children: <Widget>[
                          Expanded(
                            child: _CompactTimePill(
                              label: _copy(locale, en: 'From', ar: 'From'),
                              time: _formatApiTime(day.start),
                              enabled: !busy,
                              onTap: onStartTap,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _CompactTimePill(
                              label: _copy(locale, en: 'Until', ar: 'Until'),
                              time: _formatApiTime(day.end),
                              enabled: !busy,
                              isError: invalid,
                              onTap: onEndTap,
                            ),
                          ),
                        ],
                      )
                    : _DayOffSurface(
                        key: ValueKey<String>('off-${day.definition.apiDay}'),
                        locale: locale,
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Switch.adaptive(
              value: enabled,
              activeColor: servio.accent,
              onChanged: busy ? null : onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactTimePill extends StatelessWidget {
  const _CompactTimePill({
    required this.label,
    required this.time,
    required this.enabled,
    required this.onTap,
    this.isError = false,
  });

  final String label;
  final String time;
  final bool enabled;
  final bool isError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final radius = BorderRadius.circular(ServioRadius.sm);
    final borderColor =
        isError ? servio.danger : servio.border.withValues(alpha: 0.75);

    return Material(
      color: enabled ? servio.surfaceAlt : servio.backgroundSoft,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: enabled ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: ServioSpacing.tapTarget),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: radius,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isError ? servio.danger : servio.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 1),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  time,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isError ? servio.danger : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayBadge extends StatelessWidget {
  const _DayBadge({
    required this.shortLabel,
    required this.fullLabel,
    required this.enabled,
  });

  final String shortLabel;
  final String fullLabel;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Tooltip(
      message: fullLabel,
      child: AnimatedContainer(
        duration: _motion(context, ServioMotion.normal),
        width: 50,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled
              ? ServioColors.tint(servio.accent)
              : servio.backgroundSoft,
          borderRadius: BorderRadius.circular(ServioRadius.sm),
          border: Border.all(
            color: enabled
                ? servio.accent.withValues(alpha: 0.35)
                : servio.border.withValues(alpha: 0.75),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            shortLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              color: enabled ? servio.accent : servio.textSecondary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _DayOffSurface extends StatelessWidget {
  const _DayOffSurface({required this.locale, super.key});

  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Container(
      constraints: const BoxConstraints(minHeight: ServioSpacing.tapTarget),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: servio.backgroundSoft,
        borderRadius: BorderRadius.circular(ServioRadius.sm),
        border: Border.all(color: servio.border.withValues(alpha: 0.65)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.event_busy_rounded, size: 18, color: servio.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _copy(locale, en: 'Day off', ar: 'Day off'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: servio.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverageCard extends StatelessWidget {
  const _CoverageCard({
    required this.account,
    required this.locale,
    required this.serviceAreaController,
    required this.saving,
    required this.onServiceAreaChanged,
  });

  final UserAccount? account;
  final String locale;
  final TextEditingController serviceAreaController;
  final bool saving;
  final VoidCallback onServiceAreaChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final rawCategories = account?.categories.isNotEmpty == true
        ? account!.categories
        : account?.skills ?? const <String>[];

    return ServioCard(
      radius: ServioRadius.lg,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.location_on_outlined, size: 19, color: servio.accent),
              const SizedBox(width: 8),
              Text(
                _copy(locale, en: 'Service area', ar: 'Service area'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: serviceAreaController,
            enabled: !saving,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: _copy(locale, en: 'Service area', ar: 'Service area'),
              hintText: _copy(locale, en: 'Cairo, Giza', ar: 'Cairo, Giza'),
              prefixIcon: const Icon(Icons.place_outlined),
            ),
            onChanged: (_) => onServiceAreaChanged(),
          ),
          const SizedBox(height: 16),
          Text(
            _copy(locale, en: 'Service categories', ar: 'Service categories'),
            style: theme.textTheme.labelLarge?.copyWith(
              color: servio.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (rawCategories.isEmpty)
            _FieldSurface(
              icon: Icons.handyman_outlined,
              label: _copy(
                locale,
                en: 'No categories selected',
                ar: 'No categories selected',
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: rawCategories
                  .map(
                    (category) => _CategoryChip(
                      label: _categoryLabel(category, locale),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _FieldSurface extends StatelessWidget {
  const _FieldSurface({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: servio.surfaceAlt,
        borderRadius: BorderRadius.circular(ServioRadius.sm),
        border: Border.all(color: servio.border),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: servio.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: servio.backgroundSoft,
        borderRadius: BorderRadius.circular(ServioRadius.full),
        border: Border.all(color: servio.border),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: _motion(context, ServioMotion.fast),
      curve: ServioMotion.spring,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ServioColors.tint(color),
        borderRadius: BorderRadius.circular(ServioRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityDay {
  _AvailabilityDay({
    required this.definition,
    required this.enabled,
    required this.start,
    required this.end,
  });

  final _DayDefinition definition;
  bool enabled;
  TimeOfDay start;
  TimeOfDay end;
}

class _DayDefinition {
  const _DayDefinition({
    required this.apiDay,
    required this.labelEn,
    required this.fullEn,
    required this.defaultOn,
    required this.isWeekend,
  });

  final String apiDay;
  final String labelEn;
  final String fullEn;
  final bool defaultOn;
  final bool isWeekend;

  bool get isWeekday => !isWeekend;
  String label(String locale) => _copy(locale, en: labelEn, ar: labelEn);
  String fullLabel(String locale) => _copy(locale, en: fullEn, ar: fullEn);
}

class _PresetButtonData {
  const _PresetButtonData({
    required this.preset,
    required this.label,
  });

  final _AvailabilityPreset preset;
  final String label;
}

enum _AvailabilityPreset { weekdays, weekends, everyDay, clear }

const List<_DayDefinition> _dayDefinitions = <_DayDefinition>[
  _DayDefinition(
    apiDay: 'saturday',
    labelEn: 'Sat',
    fullEn: 'Saturday',
    defaultOn: false,
    isWeekend: true,
  ),
  _DayDefinition(
    apiDay: 'sunday',
    labelEn: 'Sun',
    fullEn: 'Sunday',
    defaultOn: false,
    isWeekend: true,
  ),
  _DayDefinition(
    apiDay: 'monday',
    labelEn: 'Mon',
    fullEn: 'Monday',
    defaultOn: true,
    isWeekend: false,
  ),
  _DayDefinition(
    apiDay: 'tuesday',
    labelEn: 'Tue',
    fullEn: 'Tuesday',
    defaultOn: true,
    isWeekend: false,
  ),
  _DayDefinition(
    apiDay: 'wednesday',
    labelEn: 'Wed',
    fullEn: 'Wednesday',
    defaultOn: true,
    isWeekend: false,
  ),
  _DayDefinition(
    apiDay: 'thursday',
    labelEn: 'Thu',
    fullEn: 'Thursday',
    defaultOn: true,
    isWeekend: false,
  ),
  _DayDefinition(
    apiDay: 'friday',
    labelEn: 'Fri',
    fullEn: 'Friday',
    defaultOn: true,
    isWeekend: false,
  ),
];

TimeOfDay _parseApiTime(String? value, TimeOfDay fallback) {
  if (value == null || value.isEmpty) return fallback;
  final parts = value.split(':');
  if (parts.length < 2) return fallback;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return fallback;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return fallback;
  return TimeOfDay(hour: hour, minute: minute);
}

String _formatApiTime(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;

String _copy(String locale, {required String en, required String ar}) {
  return locale == 'ar' ? ar : en;
}

Duration _motion(BuildContext context, Duration duration) {
  return MediaQuery.of(context).disableAnimations ? Duration.zero : duration;
}

String _categoryLabel(String value, String locale) {
  return switch (value.toLowerCase()) {
    'plumbing' => _copy(locale, en: 'Plumbing', ar: 'Plumbing'),
    'electrical' => _copy(locale, en: 'Electrical', ar: 'Electrical'),
    'painting' => _copy(locale, en: 'Painting', ar: 'Painting'),
    'flooring' => _copy(locale, en: 'Flooring', ar: 'Flooring'),
    'carpentry' => _copy(locale, en: 'Carpentry', ar: 'Carpentry'),
    'cleaning' => _copy(locale, en: 'Cleaning', ar: 'Cleaning'),
    'hvac' => _copy(locale, en: 'HVAC', ar: 'HVAC'),
    'appliance' => _copy(locale, en: 'Appliance', ar: 'Appliance'),
    'handyman' => _copy(locale, en: 'Handyman', ar: 'Handyman'),
    'renovation' => _copy(locale, en: 'Renovation', ar: 'Renovation'),
    'other' => _copy(locale, en: 'Other', ar: 'Other'),
    _ => value,
  };
}
