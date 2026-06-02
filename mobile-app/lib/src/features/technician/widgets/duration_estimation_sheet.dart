import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design_system/servio_theme_extension.dart';
import '../../../design_system/servio_tokens.dart';
import '../../../design_system/widgets/servio_primary_button.dart';

/// Presets in minutes shown as quick-select chips.
const _kPresets = [30, 60, 90, 120, 180, 240];

/// Shows a bottom sheet for selecting estimated job duration.
/// Returns the chosen duration in minutes, or null if dismissed.
Future<int?> showDurationEstimationSheet(BuildContext context,
    {int initialMinutes = 60}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _DurationEstimationSheet(initialMinutes: initialMinutes),
  );
}

class _DurationEstimationSheet extends StatefulWidget {
  const _DurationEstimationSheet({this.initialMinutes = 60});
  final int initialMinutes;

  @override
  State<_DurationEstimationSheet> createState() =>
      _DurationEstimationSheetState();
}

class _DurationEstimationSheetState
    extends State<_DurationEstimationSheet> {
  late int _selectedMinutes;
  final _customController = TextEditingController();
  bool _customMode = false;
  String? _error;

  static String _label(int min) {
    if (min < 60) return '${min}m';
    if (min % 60 == 0) return '${min ~/ 60}h';
    return '${min ~/ 60}h ${min % 60}m';
  }

  @override
  void initState() {
    super.initState();
    _selectedMinutes = widget.initialMinutes;
    if (!_kPresets.contains(_selectedMinutes)) {
      _customMode = true;
      _customController.text = _selectedMinutes.toString();
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _confirm() {
    int value = _selectedMinutes;
    if (_customMode) {
      final parsed = int.tryParse(_customController.text.trim());
      if (parsed == null || parsed < 15 || parsed > 480) {
        setState(() => _error = 'Enter a value between 15 and 480 minutes.');
        return;
      }
      value = parsed;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(
          ServioSpacing.screenPadding,
          ServioSpacing.screenPadding,
          ServioSpacing.screenPadding,
          ServioSpacing.screenPadding + bottom),
      decoration: BoxDecoration(
        color: servio.surfaceRaised,
        borderRadius: BorderRadius.circular(ServioRadius.xl),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: servio.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(ServioRadius.full),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Estimate Duration',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'How long do you estimate this job will take?',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: servio.textSecondary),
          ),
          const SizedBox(height: 20),
          // Preset chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kPresets.map((min) {
              final selected = !_customMode && _selectedMinutes == min;
              return ChoiceChip(
                label: Text(_label(min)),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _selectedMinutes = min;
                    _customMode = false;
                    _error = null;
                  });
                },
                selectedColor: servio.accent,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : null,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Custom input
          Row(
            children: <Widget>[
              const Text('Custom: '),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _customController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: 'min',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(ServioRadius.md),
                    ),
                  ),
                  onChanged: (v) {
                    setState(() {
                      _customMode = true;
                      _error = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text('minutes', style: theme.textTheme.bodySmall),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(
                    color: servio.danger, fontSize: 12)),
          ],
          const SizedBox(height: 24),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ServioPrimaryButton(
                  label: 'Confirm',
                  onPressed: _confirm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
