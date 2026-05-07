import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api/ai_api.dart';
import '../../core/api/api_client.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../../design_system/widgets/servio_status_chip.dart';

// ── Calculation engine ─────────────────────────────────────────────────────────
// Rates ported exactly from servio_frontend/js/html/ai-estimator.js RATES table.
// Values are EGP per sqm of floor area.

const Map<String, Map<String, double>> kEstimatorRates = <String, Map<String, double>>{
  'economy':  <String, double>{'labor': 12, 'materials': 8,  'logistics': 5,  'variance': 0.08},
  'standard': <String, double>{'labor': 28, 'materials': 18, 'logistics': 9,  'variance': 0.10},
  'premium':  <String, double>{'labor': 55, 'materials': 38, 'logistics': 17, 'variance': 0.12},
};

// Room multipliers ported from ROOM_MULTIPLIERS in ai-estimator.js.
const Map<String, double> kRoomMultipliers = <String, double>{
  'living-room': 1.00,
  'bedroom':     0.92,
  'kitchen':     1.35,
  'bathroom':    1.55,
  'office':      0.95,
  'balcony':     1.20,
};

class EstimatorResult {
  const EstimatorResult({
    required this.labor,
    required this.materials,
    required this.logistics,
    required this.total,
    required this.low,
    required this.high,
  });

  final double labor;
  final double materials;
  final double logistics;
  final double total;
  final int low;
  final int high;
}

/// Port of calcCosts() from ai-estimator.js.
EstimatorResult calcCosts({
  required String roomType,
  required String finishLevel,
  required double floorArea,
}) {
  final Map<String, double> rate = kEstimatorRates[finishLevel] ?? kEstimatorRates['standard']!;
  final double mult = kRoomMultipliers[roomType] ?? 1.0;

  final double labor     = floorArea * rate['labor']!     * mult;
  final double materials = floorArea * rate['materials']! * mult;
  final double logistics = floorArea * rate['logistics']! * mult;
  final double total     = labor + materials + logistics;
  final double variance  = total * rate['variance']!;

  return EstimatorResult(
    labor:     labor,
    materials: materials,
    logistics: logistics,
    total:     total,
    low:       (total - variance).round(),
    high:      (total + variance).round(),
  );
}

class EstimatorMaterials {
  const EstimatorMaterials({
    required this.floorTiles,
    required this.wallTiles,
    required this.paintLiters,
    required this.primerLiters,
    required this.groutKg,
    required this.adhesiveKg,
  });

  final double floorTiles;
  final double wallTiles;
  final double paintLiters;
  final double primerLiters;
  final double groutKg;
  final double adhesiveKg;
}

/// Port of renderMaterials() from ai-estimator.js.
EstimatorMaterials calcMaterials({
  required String roomType,
  required double floorArea,
  required double wallArea,
}) {
  const double tileWaste = 1.1;
  final bool hasWallTiles =
      roomType == 'kitchen' || roomType == 'bathroom';

  return EstimatorMaterials(
    floorTiles:   floorArea * tileWaste,
    wallTiles:    hasWallTiles ? wallArea * tileWaste : 0.0,
    paintLiters:  wallArea / 10 * 2,
    primerLiters: wallArea / 12,
    groutKg:      floorArea * 0.5,
    adhesiveKg:   floorArea * 5,
  );
}

// ── Vendor static data (ported from renderVendors() in ai-estimator.js) ────────

class _VendorData {
  const _VendorData({
    required this.name,
    required this.rating,
    required this.stock,
    required this.discount,
    required this.best,
  });

  final String name;
  final double rating;
  final String stock;   // 'in' | 'low'
  final int    discount;
  final bool   best;
}

// Sorted highest-discount first. CraftHub (8%) is always "BEST DEAL".
const List<_VendorData> _kVendors = <_VendorData>[
  _VendorData(name: 'CraftHub',    rating: 4.7, stock: 'in',  discount: 8, best: true),
  _VendorData(name: 'EliteFinish', rating: 4.8, stock: 'in',  discount: 5, best: false),
  _VendorData(name: 'ProBuild',    rating: 4.6, stock: 'low', discount: 2, best: false),
];

// ── Room options ───────────────────────────────────────────────────────────────

class _RoomOption {
  const _RoomOption({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String   key;
  final String   label;
  final IconData icon;
}

const List<_RoomOption> _kRooms = <_RoomOption>[
  _RoomOption(key: 'living-room', label: 'Living Room', icon: Icons.weekend_outlined),
  _RoomOption(key: 'kitchen',     label: 'Kitchen',     icon: Icons.kitchen_outlined),
  _RoomOption(key: 'bedroom',     label: 'Bedroom',     icon: Icons.bed_outlined),
  _RoomOption(key: 'bathroom',    label: 'Bathroom',    icon: Icons.bathtub_outlined),
  _RoomOption(key: 'office',      label: 'Office',      icon: Icons.work_outline_rounded),
  _RoomOption(key: 'balcony',     label: 'Balcony',     icon: Icons.deck_outlined),
];

// ── Finish level options ───────────────────────────────────────────────────────

class _LevelOption {
  const _LevelOption({
    required this.key,
    required this.label,
    required this.totalPerSqm,
    required this.description,
  });

  final String key;
  final String label;
  final int    totalPerSqm;
  final String description;
}

const List<_LevelOption> _kLevels = <_LevelOption>[
  _LevelOption(key: 'economy',  label: 'Economy',  totalPerSqm: 25,  description: 'Basic materials, functional finish'),
  _LevelOption(key: 'standard', label: 'Standard', totalPerSqm: 55,  description: 'Mid-range materials, quality finish'),
  _LevelOption(key: 'premium',  label: 'Premium',  totalPerSqm: 110, description: 'High-end materials, luxury finish'),
];

// ── Helpers ────────────────────────────────────────────────────────────────────

/// Formats an integer with thousands-separator commas. e.g. 3250 → "3,250"
String _fmtInt(num n) => n.round().toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);

// ── Main screen ────────────────────────────────────────────────────────────────

class AiFinishingEstimatorScreen extends StatefulWidget {
  const AiFinishingEstimatorScreen({super.key});

  @override
  State<AiFinishingEstimatorScreen> createState() =>
      _AiFinishingEstimatorScreenState();
}

class _AiFinishingEstimatorScreenState
    extends State<AiFinishingEstimatorScreen> {
  int _step = 0;

  // Step 1
  String? _roomType;

  // Step 2
  bool _isMetric = true;
  final TextEditingController _lengthCtrl = TextEditingController();
  final TextEditingController _widthCtrl  = TextEditingController();
  final TextEditingController _heightCtrl = TextEditingController(text: '2.7');
  String? _lengthError;
  String? _widthError;
  String? _heightError;

  // Step 3
  String? _finishLevel;

  // Step 4 (computed on entering step 4)
  EstimatorResult? _result;

  @override
  void initState() {
    super.initState();
    // Rebuild whenever dimension text changes (for live preview + button enable)
    _lengthCtrl.addListener(_onDimChange);
    _widthCtrl.addListener(_onDimChange);
    _heightCtrl.addListener(_onDimChange);
  }

  void _onDimChange() => setState(() {});

  @override
  void dispose() {
    _lengthCtrl.dispose();
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  // ── Geometry helpers ────────────────────────────────────────────────────────

  double _toM(String val) {
    final double v = double.tryParse(val.trim()) ?? 0;
    return _isMetric ? v : v * 0.3048;
  }

  double get _floorArea =>
      _toM(_lengthCtrl.text) * _toM(_widthCtrl.text);

  double get _wallArea {
    final double l = _toM(_lengthCtrl.text);
    final double w = _toM(_widthCtrl.text);
    final double h = _toM(_heightCtrl.text);
    return 2 * (l + w) * h;
  }

  // ── Validation ──────────────────────────────────────────────────────────────

  bool get _dimsAllPositive {
    final double l = double.tryParse(_lengthCtrl.text.trim()) ?? 0;
    final double w = double.tryParse(_widthCtrl.text.trim()) ?? 0;
    final double h = double.tryParse(_heightCtrl.text.trim()) ?? 0;
    return l >= 0.5 && w >= 0.5 && h > 0;
  }

  bool _validateDims() {
    final double maxLW = _isMetric ? 50.0  : 164.0;
    final double minH  = _isMetric ?  1.0  :   3.3;
    final double maxH  = _isMetric ? 10.0  :  32.8;
    final String unit  = _isMetric ? 'm'   : 'ft';

    final double l = double.tryParse(_lengthCtrl.text.trim()) ?? 0;
    final double w = double.tryParse(_widthCtrl.text.trim())  ?? 0;
    final double h = double.tryParse(_heightCtrl.text.trim()) ?? 0;

    bool valid = true;
    String? lErr, wErr, hErr;

    if (l < 0.5 || l > maxLW) {
      lErr = 'Enter a value between 0.5 and $maxLW $unit';
      valid = false;
    }
    if (w < 0.5 || w > maxLW) {
      wErr = 'Enter a value between 0.5 and $maxLW $unit';
      valid = false;
    }
    if (h < minH || h > maxH) {
      hErr = 'Enter a value between $minH and $maxH $unit';
      valid = false;
    }

    setState(() {
      _lengthError = lErr;
      _widthError  = wErr;
      _heightError = hErr;
    });
    return valid;
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  bool get _canContinue {
    switch (_step) {
      case 0: return _roomType != null;
      case 1: return _dimsAllPositive;
      case 2: return _finishLevel != null;
      default: return false;
    }
  }

  void _onContinue() {
    if (_step == 1 && !_validateDims()) return;
    setState(() {
      _step++;
      if (_step == 3) {
        _result = calcCosts(
          roomType:    _roomType!,
          finishLevel: _finishLevel!,
          floorArea:   _floorArea,
        );
      }
    });
  }

  void _onBack() {
    if (_step > 0) setState(() => _step--);
  }

  void _reset() {
    _lengthCtrl.clear();
    _widthCtrl.clear();
    _heightCtrl.text = '2.7';
    setState(() {
      _step        = 0;
      _roomType    = null;
      _finishLevel = null;
      _result      = null;
      _isMetric    = true;
      _lengthError = null;
      _widthError  = null;
      _heightError = null;
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ServioThemeExtension servio = context.servio;
    final double progress = (_step + 1) / 4;
    final bool isResults = _step == 3;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cost Estimator'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: (_step > 0 && !isResults)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _onBack,
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Step ${_step + 1} of 4',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: servio.textSecondary),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (BuildContext ctx, BoxConstraints c) => Stack(
                children: <Widget>[
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: servio.backgroundSoft,
                      borderRadius: BorderRadius.circular(ServioRadius.full),
                    ),
                  ),
                  AnimatedContainer(
                    duration: ServioMotion.normal,
                    curve: ServioMotion.spring,
                    height: 8,
                    width: c.maxWidth * progress,
                    decoration: BoxDecoration(
                      gradient: ServioGradients.accent,
                      borderRadius: BorderRadius.circular(ServioRadius.full),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: ServioMotion.micro,
              transitionBuilder: (Widget child, Animation<double> anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: _buildStep(),
            ),
            const SizedBox(height: 24),
            if (!isResults) ...<Widget>[
              ServioPrimaryButton(
                label: _step == 2 ? 'Calculate Estimate' : 'Continue',
                onPressed: _canContinue ? _onContinue : null,
              ),
              if (_step > 0) ...<Widget>[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _onBack,
                  child: Text(
                    'Back',
                    style: TextStyle(color: servio.textSecondary),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      0 => _StepRoomType(
          key: const ValueKey<int>(0),
          selectedRoomType: _roomType,
          onSelect: (String rt) => setState(() => _roomType = rt),
        ),
      1 => _StepDimensions(
          key: const ValueKey<int>(1),
          isMetric: _isMetric,
          onUnitChange: (bool v) => setState(() {
            _isMetric    = v;
            _lengthError = null;
            _widthError  = null;
            _heightError = null;
          }),
          lengthCtrl:  _lengthCtrl,
          widthCtrl:   _widthCtrl,
          heightCtrl:  _heightCtrl,
          lengthError: _lengthError,
          widthError:  _widthError,
          heightError: _heightError,
          floorArea:   _floorArea,
          wallArea:    _wallArea,
        ),
      2 => _StepFinishLevel(
          key: const ValueKey<int>(2),
          selectedLevel: _finishLevel,
          onSelect: (String lvl) => setState(() => _finishLevel = lvl),
        ),
      _ => _StepResults(
          key: const ValueKey<int>(3),
          result:      _result!,
          roomType:    _roomType!,
          finishLevel: _finishLevel!,
          floorArea:   _floorArea,
          wallArea:    _wallArea,
          onReset:     _reset,
        ),
    };
  }
}

// ── Step 1: Room type ──────────────────────────────────────────────────────────

class _StepRoomType extends StatelessWidget {
  const _StepRoomType({
    super.key,
    required this.selectedRoomType,
    required this.onSelect,
  });

  final String?               selectedRoomType;
  final ValueChanged<String>  onSelect;

  @override
  Widget build(BuildContext context) {
    final ServioThemeExtension servio = context.servio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Select Room Type',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Choose the room you want to estimate.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: servio.textSecondary),
        ),
        const SizedBox(height: 8),
        const ServioStatusChip(label: 'AI POWERED'),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _kRooms.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:   2,
            crossAxisSpacing: 12,
            mainAxisSpacing:  12,
            childAspectRatio: 1.5,
          ),
          itemBuilder: (BuildContext context, int index) {
            final _RoomOption room     = _kRooms[index];
            final bool        selected = room.key == selectedRoomType;

            return GestureDetector(
              onTap: () => onSelect(room.key),
              child: AnimatedContainer(
                duration: ServioMotion.micro,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selected
                      ? servio.accent
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(ServioRadius.md),
                  border: Border.all(
                    color: selected ? servio.accent : servio.border,
                    width: selected ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment:  MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      room.icon,
                      color: selected ? Colors.white : servio.accent,
                      size: 28,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      room.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: selected ? Colors.white : null,
                          ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── Step 2: Dimensions ─────────────────────────────────────────────────────────

class _StepDimensions extends StatelessWidget {
  const _StepDimensions({
    super.key,
    required this.isMetric,
    required this.onUnitChange,
    required this.lengthCtrl,
    required this.widthCtrl,
    required this.heightCtrl,
    this.lengthError,
    this.widthError,
    this.heightError,
    required this.floorArea,
    required this.wallArea,
  });

  final bool                    isMetric;
  final ValueChanged<bool>      onUnitChange;
  final TextEditingController   lengthCtrl;
  final TextEditingController   widthCtrl;
  final TextEditingController   heightCtrl;
  final String?                 lengthError;
  final String?                 widthError;
  final String?                 heightError;
  final double                  floorArea;
  final double                  wallArea;

  String get _unit => isMetric ? 'm' : 'ft';

  String _fmtArea(double sqm) => isMetric
      ? '${sqm.toStringAsFixed(1)} m²'
      : '${(sqm / 0.0929).toStringAsFixed(1)} ft²';

  @override
  Widget build(BuildContext context) {
    final ServioThemeExtension servio      = context.servio;
    final bool                 showPreview = floorArea > 0 && wallArea > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Room Dimensions',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const ServioStatusChip(label: 'AI POWERED'),
        const SizedBox(height: 20),
        // Unit toggle
        ServioCard(
          padding:         const EdgeInsets.all(6),
          radius:          ServioRadius.full,
          backgroundColor: servio.backgroundSoft,
          borderColor:     Colors.transparent,
          child: Row(
            children: <Widget>[
              _UnitBtn(
                label:  'Meters',
                active: isMetric,
                onTap:  () => onUnitChange(true),
              ),
              _UnitBtn(
                label:  'Feet',
                active: !isMetric,
                onTap:  () => onUnitChange(false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller:       lengthCtrl,
          keyboardType:     const TextInputType.numberWithOptions(decimal: true),
          inputFormatters:  <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
            labelText: 'Length',
            suffixText: _unit,
            errorText: lengthError,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller:       widthCtrl,
          keyboardType:     const TextInputType.numberWithOptions(decimal: true),
          inputFormatters:  <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
            labelText: 'Width',
            suffixText: _unit,
            errorText: widthError,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller:       heightCtrl,
          keyboardType:     const TextInputType.numberWithOptions(decimal: true),
          inputFormatters:  <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
            labelText:   'Ceiling Height',
            suffixText:  _unit,
            errorText:   heightError,
            helperText:  isMetric ? 'Standard: 2.7 m' : 'Standard: 8.9 ft',
          ),
        ),
        // Live area preview
        AnimatedSize(
          duration: ServioMotion.normal,
          curve:    ServioMotion.spring,
          child: showPreview
              ? Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: ServioCard(
                    backgroundColor: servio.backgroundSoft,
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: _AreaPill(
                            label: 'Floor Area',
                            value: _fmtArea(floorArea),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _AreaPill(
                            label: 'Wall Area',
                            value: _fmtArea(wallArea),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _UnitBtn extends StatelessWidget {
  const _UnitBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String       label;
  final bool         active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ServioThemeExtension servio = context.servio;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: ServioMotion.micro,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? servio.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(ServioRadius.full),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: active ? Colors.white : servio.textSecondary,
                ),
          ),
        ),
      ),
    );
  }
}

class _AreaPill extends StatelessWidget {
  const _AreaPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: context.servio.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: context.servio.accent),
        ),
      ],
    );
  }
}

// ── Step 3: Finishing level ────────────────────────────────────────────────────

class _StepFinishLevel extends StatelessWidget {
  const _StepFinishLevel({
    super.key,
    required this.selectedLevel,
    required this.onSelect,
  });

  final String?              selectedLevel;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final ServioThemeExtension servio = context.servio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Finishing Level',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Select the quality tier for your project.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: servio.textSecondary),
        ),
        const SizedBox(height: 20),
        ...List<Widget>.generate(_kLevels.length, (int i) {
          final _LevelOption lvl      = _kLevels[i];
          final bool         selected = lvl.key == selectedLevel;

          return Padding(
            padding: EdgeInsets.only(bottom: i < _kLevels.length - 1 ? 12 : 0),
            child: GestureDetector(
              onTap: () => onSelect(lvl.key),
              child: AnimatedContainer(
                duration: ServioMotion.micro,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selected
                      ? servio.accent.withValues(alpha: 0.08)
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(ServioRadius.card),
                  border: Border.all(
                    color: selected ? servio.accent : servio.border,
                    width: selected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            lvl.label,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: selected ? servio.accent : null,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lvl.description,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: servio.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          '~${lvl.totalPerSqm} EGP/m²',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                color: selected
                                    ? servio.accent
                                    : servio.textSecondary,
                              ),
                        ),
                        if (selected) ...<Widget>[
                          const SizedBox(height: 4),
                          Icon(
                            Icons.check_circle_rounded,
                            color: servio.accent,
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── Step 4: Results ────────────────────────────────────────────────────────────

class _StepResults extends StatefulWidget {
  const _StepResults({
    super.key,
    required this.result,
    required this.roomType,
    required this.finishLevel,
    required this.floorArea,
    required this.wallArea,
    required this.onReset,
  });

  final EstimatorResult result;
  final String          roomType;
  final String          finishLevel;
  final double          floorArea;
  final double          wallArea;
  final VoidCallback    onReset;

  @override
  State<_StepResults> createState() => _StepResultsState();
}

class _StepResultsState extends State<_StepResults> {
  bool                     _barsAnimated  = false;
  List<RecommendedWorker>  _techs         = <RecommendedWorker>[];
  bool                     _loadingTechs  = false;

  late final EstimatorMaterials _materials = calcMaterials(
    roomType:  widget.roomType,
    floorArea: widget.floorArea,
    wallArea:  widget.wallArea,
  );

  @override
  void initState() {
    super.initState();
    // Animate bars 300 ms after entering results (mirrors website's setTimeout 300)
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _barsAnimated = true);
    });
    _loadTechs();
  }

  Future<void> _loadTechs() async {
    setState(() => _loadingTechs = true);
    try {
      final ApiClient client = context.read<ApiClient>();
      final String roomLabel =
          widget.roomType.replaceAll('-', ' ');
      final AiRecommendationResponse res = await AiApi(client).recommend(
        description:
            'Finishing a $roomLabel with ${widget.finishLevel} quality at '
            '${widget.floorArea.toStringAsFixed(1)} sqm',
      );
      if (mounted) {
        setState(
          () => _techs = res.recommendedWorkers.take(3).toList(),
        );
      }
    } catch (_) {
      // Silently hide section on error — matches website behaviour.
    } finally {
      if (mounted) setState(() => _loadingTechs = false);
    }
  }

  String get _roomLabel => const <String, String>{
        'living-room': 'Living Room',
        'kitchen':     'Kitchen',
        'bedroom':     'Bedroom',
        'bathroom':    'Bathroom',
        'office':      'Office',
        'balcony':     'Balcony',
      }[widget.roomType] ??
      widget.roomType;

  String get _levelLabel => const <String, String>{
        'economy':  'Economy',
        'standard': 'Standard',
        'premium':  'Premium',
      }[widget.finishLevel] ??
      widget.finishLevel;

  @override
  Widget build(BuildContext context) {
    final EstimatorResult      r      = widget.result;
    final ServioThemeExtension servio = context.servio;
    final ThemeData            theme  = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const ServioStatusChip(
          label: 'ESTIMATE READY',
          type:  ServioStatusChipType.success,
        ),
        const SizedBox(height: 16),
        Text(
          'Total Estimated Range',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: servio.textSecondary),
        ),
        const SizedBox(height: 8),
        Text(
          '${_fmtInt(r.low)} EGP – ${_fmtInt(r.high)} EGP',
          style: theme.textTheme.displayLarge?.copyWith(
            fontSize:   28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        // Meta chips
        Wrap(
          spacing:    8,
          runSpacing: 8,
          children: <Widget>[
            _MetaChip(label: _roomLabel),
            _MetaChip(label: _levelLabel),
            _MetaChip(label: '${widget.floorArea.toStringAsFixed(1)} m²'),
          ],
        ),
        const SizedBox(height: 24),
        // Cost breakdown
        Text('Cost Breakdown', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        _AnimatedBreakdownBar(
          label:    'Labor',
          amount:   r.labor,
          total:    r.total,
          animated: _barsAnimated,
          color:    servio.accent,
        ),
        const SizedBox(height: 10),
        _AnimatedBreakdownBar(
          label:    'Materials',
          amount:   r.materials,
          total:    r.total,
          animated: _barsAnimated,
          color:    const Color(0xFFB8975A),
        ),
        const SizedBox(height: 10),
        _AnimatedBreakdownBar(
          label:    'Logistics',
          amount:   r.logistics,
          total:    r.total,
          animated: _barsAnimated,
          color:    servio.textSecondary,
        ),
        const SizedBox(height: 24),
        // Materials list
        Text('Estimated Materials', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        ServioCard(
          child: _MaterialsTable(
            materials: _materials,
            floorArea: widget.floorArea,
          ),
        ),
        const SizedBox(height: 24),
        // Vendor quotes
        Text('Vendor Quotes', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        ..._kVendors.map((_VendorData v) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _VendorCard(vendor: v, materialsCost: r.materials),
        )),
        const SizedBox(height: 24),
        // AI recommended technicians
        if (_loadingTechs) ...<Widget>[
          Text('Recommended Technicians', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          const _TechsSkeletonRow(),
          const SizedBox(height: 24),
        ] else if (_techs.isNotEmpty) ...<Widget>[
          Text('Recommended Technicians', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          ..._techs.map((RecommendedWorker t) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TechCard(worker: t),
          )),
          const SizedBox(height: 24),
        ],
        // Disclaimer
        ServioCard(
          backgroundColor: servio.backgroundSoft,
          child: Text(
            'This is an estimate. Actual prices may vary based on vendor, '
            'materials, and site conditions.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: servio.textSecondary),
          ),
        ),
        const SizedBox(height: 20),
        // Reset
        TextButton.icon(
          onPressed: widget.onReset,
          icon:  const Icon(Icons.refresh_rounded),
          label: const Text('Calculate Another Room'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Breakdown bar ──────────────────────────────────────────────────────────────

class _AnimatedBreakdownBar extends StatelessWidget {
  const _AnimatedBreakdownBar({
    required this.label,
    required this.amount,
    required this.total,
    required this.animated,
    required this.color,
  });

  final String label;
  final double amount;
  final double total;
  final bool   animated;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    final double pct       = total > 0 ? amount / total : 0.0;
    final String formatted = '${_fmtInt(amount)} EGP';
    final String pctLabel  = '${(pct * 100).round()}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(label)),
            Text(
              formatted,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: color),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 36,
              child: Text(
                pctLabel,
                textAlign: TextAlign.right,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: context.servio.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(ServioRadius.full),
          child: Stack(
            children: <Widget>[
              Container(height: 10, color: context.servio.backgroundSoft),
              TweenAnimationBuilder<double>(
                tween:    Tween<double>(begin: 0.0, end: animated ? pct : 0.0),
                duration: const Duration(milliseconds: 600),
                curve:    Curves.easeOut,
                builder:  (BuildContext _, double value, Widget? __) =>
                    FractionallySizedBox(
                  widthFactor: value,
                  child: Container(height: 10, color: color),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Materials table ────────────────────────────────────────────────────────────

class _MaterialsTable extends StatelessWidget {
  const _MaterialsTable({
    required this.materials,
    required this.floorArea,
  });

  final EstimatorMaterials materials;
  final double             floorArea;

  @override
  Widget build(BuildContext context) {
    final List<(String, String, String)> rows = <(String, String, String)>[
      ('Floor Tiles', '${materials.floorTiles.toStringAsFixed(1)} m²',    '+10% waste'),
      if (materials.wallTiles > 0)
        ('Wall Tiles', '${materials.wallTiles.toStringAsFixed(1)} m²',    'Walls'),
      ('Paint',      '${materials.paintLiters.toStringAsFixed(1)} L',     '2 coats'),
      ('Primer',     '${materials.primerLiters.toStringAsFixed(1)} L',    'Pre-paint'),
      ('Grout',      '${materials.groutKg.toStringAsFixed(1)} kg',        'Joints'),
      ('Adhesive',   '${(floorArea * 5).toStringAsFixed(0)} kg',          'Fixing'),
    ];

    return Column(
      children: <Widget>[
        // Header row
        Row(
          children: <Widget>[
            Expanded(
              flex: 3,
              child: Text(
                'Material',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: context.servio.textSecondary),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'Qty',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: context.servio.textSecondary),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'Note',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: context.servio.textSecondary),
              ),
            ),
          ],
        ),
        const Divider(height: 16),
        ...rows.map(((String, String, String) row) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: <Widget>[
              Expanded(flex: 3, child: Text(row.$1)),
              Expanded(
                flex: 2,
                child: Text(
                  row.$2,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: context.servio.accent),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  row.$3,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: context.servio.textSecondary),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
}

// ── Vendor card ────────────────────────────────────────────────────────────────

class _VendorCard extends StatelessWidget {
  const _VendorCard({
    required this.vendor,
    required this.materialsCost,
  });

  final _VendorData vendor;
  final double      materialsCost;

  @override
  Widget build(BuildContext context) {
    final ServioThemeExtension servio       = context.servio;
    final int                  price        =
        (materialsCost * (1 - vendor.discount / 100)).round();
    final String               formattedPrice = _fmtInt(price);

    return ServioCard(
      borderColor: vendor.best ? servio.accent : servio.border,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(vendor.name,
                        style: Theme.of(context).textTheme.titleMedium),
                    if (vendor.best) ...<Widget>[
                      const SizedBox(width: 8),
                      const ServioStatusChip(
                        label: 'BEST DEAL',
                        type:  ServioStatusChipType.success,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    const Icon(Icons.star_rounded,
                        size: 14, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text(
                      '${vendor.rating}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width:  6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: vendor.stock == 'in'
                            ? Colors.green
                            : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      vendor.stock == 'in' ? 'In Stock' : 'Limited Stock',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: servio.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '$formattedPrice EGP',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: servio.accent),
              ),
              Text(
                '-${vendor.discount}% off',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tech card ──────────────────────────────────────────────────────────────────

class _TechCard extends StatelessWidget {
  const _TechCard({required this.worker});

  final RecommendedWorker worker;

  @override
  Widget build(BuildContext context) {
    final ServioThemeExtension servio = context.servio;

    return ServioCard(
      child: Row(
        children: <Widget>[
          Container(
            width:  44,
            height: 44,
            decoration: const BoxDecoration(
              gradient: ServioGradients.warm,
              shape:    BoxShape.circle,
            ),
            child: Center(
              child: Text(
                worker.name.isNotEmpty
                    ? worker.name[0].toUpperCase()
                    : 'T',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: ServioColors.deepBrown),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(worker.name,
                    style: Theme.of(context).textTheme.titleSmall),
                if (worker.reason.isNotEmpty)
                  Text(
                    worker.reason,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: servio.textSecondary),
                    maxLines:  1,
                    overflow:  TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ServioStatusChip(label: worker.matchLabel),
        ],
      ),
    );
  }
}

// ── Technician skeleton ────────────────────────────────────────────────────────

class _TechsSkeletonRow extends StatelessWidget {
  const _TechsSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(3, (int i) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 2 ? 8.0 : 0.0),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color:        context.servio.backgroundSoft,
                borderRadius: BorderRadius.circular(ServioRadius.card),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Meta chip ──────────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ServioThemeExtension servio = context.servio;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:        servio.backgroundSoft,
        borderRadius: BorderRadius.circular(ServioRadius.full),
        border:       Border.all(color: servio.border),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
