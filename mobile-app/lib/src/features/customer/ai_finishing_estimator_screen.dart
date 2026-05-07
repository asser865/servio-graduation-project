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

// ── Screen placeholder (replaced in Task 2) ────────────────────────────────────

class AiFinishingEstimatorScreen extends StatelessWidget {
  const AiFinishingEstimatorScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
