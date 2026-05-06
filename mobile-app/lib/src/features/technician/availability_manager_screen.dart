import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/user_account.dart';
import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../../design_system/widgets/servio_status_chip.dart';
import '../../design_system/widgets/servio_tab_shell.dart';

class AvailabilityManagerScreen extends StatefulWidget {
  const AvailabilityManagerScreen({super.key});

  @override
  State<AvailabilityManagerScreen> createState() =>
      _AvailabilityManagerScreenState();
}

class _AvailabilityManagerScreenState extends State<AvailabilityManagerScreen> {
  late final List<_AvailabilityDay> _days;
  late final TextEditingController _serviceAreaCtrl;
  late bool _availableNow;
  List<bool>? _pausedSnapshot;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final account = context.read<SessionProvider>().account;
    final savedAvailability =
        account?.availability ?? const <AvailabilitySlot>[];
    _serviceAreaCtrl = TextEditingController(
      text: account?.locationLabel ?? '',
    );
    _days = _initialDays(savedAvailability);
    _availableNow = _hasWorkingDays;
  }

  @override
  void dispose() {
    _serviceAreaCtrl.dispose();
    super.dispose();
  }

  bool get _hasWorkingDays => _days.any((day) => day.enabled);

  List<_AvailabilityDay> _initialDays(List<AvailabilitySlot> saved) {
    final hasSavedSchedule = saved.isNotEmpty;
    final savedByDay = <String, AvailabilitySlot>{
      for (final slot in saved) slot.day.toLowerCase(): slot,
    };

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

  void _setAvailableNow(bool value) {
    setState(() {
      _error = null;
      _availableNow = value;
      if (!value) {
        _pausedSnapshot = _days.map((day) => day.enabled).toList();
        for (final day in _days) {
          day.enabled = false;
        }
        return;
      }

      final snapshot = _pausedSnapshot;
      if (snapshot != null && snapshot.any((enabled) => enabled)) {
        for (var i = 0; i < _days.length; i += 1) {
          _days[i].enabled = snapshot[i];
        }
      } else {
        for (final day in _days) {
          day.enabled = day.definition.defaultOn;
        }
      }
      _pausedSnapshot = null;
    });
  }

  void _setDayOff(_AvailabilityDay day, bool isOff) {
    setState(() {
      _error = null;
      day.enabled = !isOff;
      _availableNow = _hasWorkingDays;
    });
  }

  Future<void> _pickTime(_AvailabilityDay day, {required bool isStart}) async {
    if (_saving || !day.enabled) return;

    final locale = context.read<LocaleProvider>().languageCode;
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? day.start : day.end,
      helpText: isStart
          ? _copy(locale, en: 'Start time', ar: 'وقت البداية')
          : _copy(locale, en: 'End time', ar: 'وقت النهاية'),
    );

    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        day.start = picked;
      } else {
        day.end = picked;
      }
    });
  }

  Future<void> _saveAvailability() async {
    final locale = context.read<LocaleProvider>().languageCode;
    if (!_hasWorkingDays) {
      setState(() {
        _error = _copy(
          locale,
          en: 'Turn on at least one working day before saving.',
          ar: 'فعّل يوم عمل واحداً على الأقل قبل الحفظ.',
        );
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final availability = _days
        .where((day) => day.enabled)
        .map((day) => <String, dynamic>{
              'day': day.definition.apiDay,
              'from': _formatApiTime(day.start),
              'to': _formatApiTime(day.end),
            })
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

    error ??= await session.updateAvailability(availability);
    if (!mounted) return;

    setState(() {
      _saving = false;
      _error = error;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ??
              _copy(
                locale,
                en: 'Availability updated.',
                ar: 'تم تحديث التوفر.',
              ),
        ),
        backgroundColor: error == null ? null : context.servio.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final locale = context.watch<LocaleProvider>().languageCode;
    final account = context.watch<SessionProvider>().account;
    final canSave = !_saving && _hasWorkingDays;
    final bottomInset = ServioTabShell.bottomOverlayInsetOf(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_copy(locale, en: 'Availability', ar: 'التوفر')),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            ServioSpacing.screenPadding,
            8,
            ServioSpacing.screenPadding,
            ServioSpacing.screenPadding + bottomInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                _copy(
                  locale,
                  en: 'Set your working hours and service area so customers can find you.',
                  ar: 'حدد ساعات عملك ومنطقة خدمتك لكي يجدك العملاء.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: servio.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              _AvailableNowCard(
                locale: locale,
                value: _availableNow,
                saving: _saving,
                onChanged: _setAvailableNow,
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 12),
                _NoticeCard(
                  icon: Icons.error_outline_rounded,
                  title: _copy(locale, en: 'Could not save', ar: 'تعذر الحفظ'),
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
                    ar: 'لا توجد أيام عمل محددة',
                  ),
                  message: _copy(
                    locale,
                    en: 'Turn on a day to keep your schedule available for customers.',
                    ar: 'فعّل يوماً ليظل جدولك متاحاً للعملاء.',
                  ),
                  color: servio.warning,
                ),
              ],
              const SizedBox(height: 24),
              _SectionTitle(
                icon: Icons.calendar_month_rounded,
                title: _copy(
                  locale,
                  en: 'Weekly Schedule',
                  ar: 'الجدول الأسبوعي',
                ),
              ),
              const SizedBox(height: 12),
              ..._days.map(
                (day) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ScheduleDayCard(
                    day: day,
                    locale: locale,
                    saving: _saving,
                    onOffChanged: (isOff) => _setDayOff(day, isOff),
                    onStartTap: () => _pickTime(day, isStart: true),
                    onEndTap: () => _pickTime(day, isStart: false),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _CoverageCard(
                account: account,
                locale: locale,
                serviceAreaController: _serviceAreaCtrl,
                saving: _saving,
                onServiceAreaChanged: () => setState(() => _error = null),
              ),
              const SizedBox(height: 24),
              ServioPrimaryButton(
                label: _copy(
                  locale,
                  en: 'Save Availability',
                  ar: 'حفظ التوفر',
                ),
                onPressed: canSave ? _saveAvailability : null,
                isLoading: _saving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvailableNowCard extends StatelessWidget {
  const _AvailableNowCard({
    required this.locale,
    required this.value,
    required this.saving,
    required this.onChanged,
  });

  final String locale;
  final bool value;
  final bool saving;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final statusType =
        value ? ServioStatusChipType.success : ServioStatusChipType.warning;

    return ServioCard(
      radius: ServioRadius.md,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: ServioColors.tint(value ? servio.success : servio.warning),
              borderRadius: BorderRadius.circular(ServioRadius.full),
            ),
            child: Icon(
              value ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
              color: value ? servio.success : servio.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      _copy(locale, en: 'Available Now', ar: 'متاح الآن'),
                      style: theme.textTheme.titleMedium,
                    ),
                    ServioStatusChip(
                      label: value
                          ? _copy(locale, en: 'Active', ar: 'نشط')
                          : _copy(locale, en: 'Paused', ar: 'متوقف'),
                      type: statusType,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _copy(
                    locale,
                    en: 'Toggle off to pause new requests.',
                    ar: 'أوقفه مؤقتاً لإيقاف الطلبات الجديدة.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: servio.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            activeColor: servio.success,
            onChanged: saving ? null : onChanged,
          ),
        ],
      ),
    );
  }
}

class _ScheduleDayCard extends StatelessWidget {
  const _ScheduleDayCard({
    required this.day,
    required this.locale,
    required this.saving,
    required this.onOffChanged,
    required this.onStartTap,
    required this.onEndTap,
  });

  final _AvailabilityDay day;
  final String locale;
  final bool saving;
  final ValueChanged<bool> onOffChanged;
  final VoidCallback onStartTap;
  final VoidCallback onEndTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final enabled = day.enabled && !saving;

    return ServioCard(
      radius: ServioRadius.sm,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      backgroundColor:
          day.enabled ? theme.colorScheme.surface : servio.surfaceAlt,
      borderColor:
          day.enabled ? servio.border : servio.border.withValues(alpha: 0.55),
      child: AnimatedOpacity(
        duration: ServioMotion.fast,
        opacity: saving ? 0.65 : 1,
        child: Row(
          children: <Widget>[
            _DayBadge(label: day.definition.label(locale)),
            const SizedBox(width: 8),
            Expanded(
              child: AnimatedSwitcher(
                duration: ServioMotion.normal,
                switchInCurve: ServioMotion.spring,
                switchOutCurve: ServioMotion.standard,
                child: day.enabled
                    ? Row(
                        key: ValueKey<String>('times-${day.definition.apiDay}'),
                        children: <Widget>[
                          Expanded(
                            child: _CompactTimePill(
                              label: _copy(
                                locale,
                                en: 'From',
                                ar: '\u0645\u0646',
                              ),
                              time: day.start.format(context),
                              enabled: enabled,
                              onTap: onStartTap,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _CompactTimePill(
                              label: _copy(
                                locale,
                                en: 'Until',
                                ar: '\u062d\u062a\u0649',
                              ),
                              time: day.end.format(context),
                              enabled: enabled,
                              onTap: onEndTap,
                            ),
                          ),
                        ],
                      )
                    : _DayOffSummary(
                        key: ValueKey<String>('off-${day.definition.apiDay}'),
                        locale: locale,
                      ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(ServioRadius.full),
              onTap: saving ? null : () => onOffChanged(day.enabled),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(4, 2, 0, 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Checkbox(
                      value: !day.enabled,
                      activeColor: servio.accent,
                      visualDensity: VisualDensity.compact,
                      onChanged:
                          saving ? null : (value) => onOffChanged(value ?? false),
                    ),
                    Text(
                      _copy(locale, en: 'Off', ar: '\u0625\u062c\u0627\u0632\u0629'),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: servio.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

class _CompactTimePill extends StatelessWidget {
  const _CompactTimePill({
    required this.label,
    required this.time,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String time;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final radius = BorderRadius.circular(ServioRadius.sm);

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
            border: Border.all(color: servio.border.withValues(alpha: 0.75)),
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
                  color: servio.textSecondary,
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
  const _DayBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Container(
      width: 52,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: servio.backgroundSoft,
        borderRadius: BorderRadius.circular(ServioRadius.sm),
        border: Border.all(color: servio.border.withValues(alpha: 0.75)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: servio.textSecondary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _DayOffSummary extends StatelessWidget {
  const _DayOffSummary({required this.locale, super.key});

  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
              _copy(locale, en: 'Day off', ar: 'يوم إجازة'),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionTitle(
          icon: Icons.location_on_outlined,
          title: _copy(locale, en: 'Service Area', ar: 'منطقة الخدمة'),
        ),
        const SizedBox(height: 12),
        ServioCard(
          radius: ServioRadius.md,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: serviceAreaController,
                enabled: !saving,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: _copy(
                    locale,
                    en: 'Service Area',
                    ar: 'منطقة الخدمة',
                  ),
                  hintText: _copy(
                    locale,
                    en: 'e.g. Cairo, Giza',
                    ar: 'مثال: القاهرة، الجيزة',
                  ),
                  prefixIcon: const Icon(Icons.place_outlined),
                ),
                onChanged: (_) => onServiceAreaChanged(),
              ),
              const SizedBox(height: 18),
              Text(
                _copy(
                  locale,
                  en: 'Service Categories',
                  ar: 'فئات الخدمة',
                ),
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
                    ar: 'لا توجد فئات محددة',
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
        ),
      ],
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

    return Container(
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: servio.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium,
          ),
        ),
      ],
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
    required this.en,
    required this.ar,
    required this.defaultOn,
  });

  final String apiDay;
  final String en;
  final String ar;
  final bool defaultOn;

  String label(String locale) => _copy(locale, en: en, ar: ar);
}

const List<_DayDefinition> _dayDefinitions = <_DayDefinition>[
  _DayDefinition(apiDay: 'monday', en: 'Mon', ar: 'إثن', defaultOn: true),
  _DayDefinition(apiDay: 'tuesday', en: 'Tue', ar: 'ثلا', defaultOn: true),
  _DayDefinition(apiDay: 'wednesday', en: 'Wed', ar: 'أرب', defaultOn: true),
  _DayDefinition(apiDay: 'thursday', en: 'Thu', ar: 'خمي', defaultOn: false),
  _DayDefinition(apiDay: 'friday', en: 'Fri', ar: 'جم', defaultOn: true),
  _DayDefinition(apiDay: 'saturday', en: 'Sat', ar: 'سبت', defaultOn: false),
  _DayDefinition(apiDay: 'sunday', en: 'Sun', ar: 'أحد', defaultOn: true),
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

String _copy(String locale, {required String en, required String ar}) {
  return locale == 'ar' ? ar : en;
}

String _categoryLabel(String value, String locale) {
  return switch (value.toLowerCase()) {
    'plumbing' => _copy(locale, en: 'Plumbing', ar: 'السباكة'),
    'electrical' => _copy(locale, en: 'Electrical', ar: 'الكهرباء'),
    'painting' => _copy(locale, en: 'Painting', ar: 'الدهانات'),
    'flooring' => _copy(locale, en: 'Flooring', ar: 'الأرضيات'),
    'carpentry' => _copy(locale, en: 'Carpentry', ar: 'النجارة'),
    'cleaning' => _copy(locale, en: 'Cleaning', ar: 'التنظيف'),
    'hvac' => _copy(locale, en: 'HVAC', ar: 'التكييف'),
    'other' => _copy(locale, en: 'Other', ar: 'أخرى'),
    _ => value,
  };
}
