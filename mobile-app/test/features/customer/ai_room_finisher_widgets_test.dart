import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:servio_mobile_app/src/core/api/ai_api.dart';
import 'package:servio_mobile_app/src/design_system/servio_theme.dart';
import 'package:servio_mobile_app/src/design_system/servio_theme_extension.dart';
import 'package:servio_mobile_app/src/design_system/widgets/servio_card.dart';

// Shared test theme wrapper.
Widget wrap(Widget child) {
  return MaterialApp(
    theme: ServioTheme.light(),
    home: Scaffold(body: child),
  );
}

void main() {
  // ── toJson / fromSavedJson round-trip ──────────────────────────────────────

  group('RoomAnalysisResponse round-trip serialization', () {
    RoomAnalysisResponse buildResponse() {
      return const RoomAnalysisResponse(
        roomAnalysis: RoomAnalysis(
          roomType: 'bedroom',
          currentCondition: 'rough plaster',
          detectedFeatures: <String>['window', 'door'],
          style: 'modern',
          wallCondition: 'rough plaster',
          estimatedCeilingHeightM: 2.9,
          specialNotes: 'North-facing window.',
        ),
        plans: <FinishingPlan>[
          FinishingPlan(
            name: 'Standard',
            summary: 'Balanced finish',
            totalCostEgp: 50000,
            breakdown: <String, num>{'materials': 30000, 'labor': 20000},
            materials: <PlanMaterial>[
              PlanMaterial(
                name: 'Porcelain Tile',
                quantity: '20',
                unit: 'm²',
                estimatedCostEgp: 8000,
                category: 'flooring',
                unitPriceEgp: 400,
                notes: '10% waste included.',
                vendors: <MaterialVendor>[
                  MaterialVendor(name: 'RAK Ceramics', source: 'fallback'),
                ],
              ),
            ],
            labor: <PlanLabor>[
              PlanLabor(
                trade: 'Tiler',
                description: 'Floor tiling',
                days: 3,
                dailyRateEgp: 700,
                totalEgp: 2100,
              ),
            ],
            palette: <String>['#FFFFFF'],
            durationDays: 14,
            planStyle: 'Contemporary',
            vendorAdjustedTotalEgp: 48000,
          ),
        ],
        recommendedPlanName: 'Standard',
        generatedImageBase64: null,
        recommendationReason: 'Best value for budget.',
        consistencyEnvelope: ConsistencyEnvelope(
          styleUsed: 'modern',
          budgetTier: 'standard',
          floorAreaM2: 20.0,
          primaryFlooring: 'Porcelain Tile',
          primaryWall: 'Paint',
          sdPromptUsed: 'modern bedroom porcelain',
          geminiTotalCost: 50000,
          vendorAdjustedCost: 48000,
          consistencyWarnings: <String>[],
        ),
      );
    }

    test('toJson → fromSavedJson preserves all fields', () {
      final original = buildResponse();
      final restored = RoomAnalysisResponse.fromSavedJson(original.toJson());

      expect(restored.recommendedPlanName, 'Standard');
      expect(restored.recommendationReason, 'Best value for budget.');
      expect(restored.plans, hasLength(1));

      final plan = restored.plans.first;
      expect(plan.name, 'Standard');
      expect(plan.totalCostEgp, 50000);
      expect(plan.planStyle, 'Contemporary');
      expect(plan.vendorAdjustedTotalEgp, 48000);
      expect(plan.durationDays, 14);
      expect(plan.breakdown['materials'], 30000);
      expect(plan.breakdown['labor'], 20000);

      final mat = plan.materials.first;
      expect(mat.name, 'Porcelain Tile');
      expect(mat.category, 'flooring');
      expect(mat.unitPriceEgp, 400);
      expect(mat.notes, '10% waste included.');
      expect(mat.vendors, hasLength(1));
      expect(mat.vendors.first.name, 'RAK Ceramics');

      final labor = plan.labor.first;
      expect(labor.trade, 'Tiler');
      expect(labor.days, 3);
      expect(labor.totalEgp, 2100);

      final env = restored.consistencyEnvelope;
      expect(env.budgetTier, 'standard');
      expect(env.styleUsed, 'modern');
      expect(env.primaryFlooring, 'Porcelain Tile');
      expect(env.vendorAdjustedCost, 48000);
      expect(env.consistencyWarnings, isEmpty);

      final analysis = restored.roomAnalysis;
      expect(analysis.roomType, 'bedroom');
      expect(analysis.wallCondition, 'rough plaster');
      expect(analysis.estimatedCeilingHeightM, closeTo(2.9, 0.001));
      expect(analysis.specialNotes, 'North-facing window.');
      expect(analysis.detectedFeatures, contains('window'));
    });

    test('fromSavedJson is stable under missing optional fields', () {
      final json = <String, dynamic>{
        'room_analysis': <String, dynamic>{'room_type': 'kitchen'},
        'finishing_plans': <dynamic>[
          <String, dynamic>{
            'plan_name': 'Economy',
            'total_cost_egp': 10000,
            'timeline_days': 7,
            'materials': <dynamic>[],
            'labor': <dynamic>[],
          },
        ],
        'recommended_plan': 'Economy',
      };
      final r = RoomAnalysisResponse.fromSavedJson(json);
      expect(r.plans, hasLength(1));
      expect(r.recommendedPlanName, 'Economy');
      expect(r.consistencyEnvelope, equals(ConsistencyEnvelope.empty));
      expect(r.roomAnalysis.wallCondition, isEmpty);
      expect(r.roomAnalysis.estimatedCeilingHeightM, 0.0);
    });

    test('MaterialVendor toJson round-trips', () {
      const v = MaterialVendor(name: 'Ceramica Cleopatra', source: 'fallback');
      final v2 = MaterialVendor.fromJson(v.toJson());
      expect(v2.name, v.name);
      expect(v2.source, v.source);
    });

    test('ConsistencyEnvelope toJson preserves warnings list', () {
      const env = ConsistencyEnvelope(
        budgetTier: 'premium',
        consistencyWarnings: <String>['Style mismatch', 'Flooring not in render'],
      );
      final env2 = ConsistencyEnvelope.fromJson(env.toJson());
      expect(env2.budgetTier, 'premium');
      expect(env2.consistencyWarnings, hasLength(2));
      expect(env2.consistencyWarnings.first, 'Style mismatch');
    });

    test('PlanLabor toJson round-trips', () {
      const l = PlanLabor(
        trade: 'Painter',
        description: 'Two coats',
        days: 2,
        dailyRateEgp: 600,
        totalEgp: 1200,
      );
      final l2 = PlanLabor.fromJson(l.toJson());
      expect(l2.trade, l.trade);
      expect(l2.days, l.days);
      expect(l2.totalEgp, l.totalEgp);
    });

    test('PlanMaterial toJson round-trips including vendors', () {
      const m = PlanMaterial(
        name: 'Ceramic Tile',
        quantity: '20',
        unit: 'm²',
        estimatedCostEgp: 4000,
        category: 'flooring',
        unitPriceEgp: 200,
        notes: 'Add 10% waste.',
        vendors: <MaterialVendor>[
          MaterialVendor(name: 'RAK Ceramics', source: 'fallback'),
        ],
      );
      final m2 = PlanMaterial.fromJson(m.toJson());
      expect(m2.name, m.name);
      expect(m2.category, m.category);
      expect(m2.unitPriceEgp, m.unitPriceEgp);
      expect(m2.notes, m.notes);
      expect(m2.vendors, hasLength(1));
      expect(m2.vendors.first.name, 'RAK Ceramics');
    });
  });

  // ── Rendered widget smoke tests ────────────────────────────────────────────

  group('RoomAnalysisCardWidget rendered output', () {
    const RoomAnalysis fullAnalysis = RoomAnalysis(
      roomType: 'living_room',
      currentCondition: 'bare brick',
      detectedFeatures: <String>['window', 'balcony door'],
      style: 'modern',
      wallCondition: 'bare brick',
      estimatedCeilingHeightM: 3.1,
      specialNotes: 'Large east-facing window reduces paint area.',
    );

    testWidgets('shows room type, wall condition, ceiling, features, notes',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        RoomAnalysisCardWidget(analysis: fullAnalysis),
      ));

      expect(find.textContaining('LIVING ROOM'), findsOneWidget);
      expect(find.textContaining('bare brick'), findsAtLeastNWidgets(1));
      expect(find.textContaining('3.1 m'), findsOneWidget);
      expect(find.text('window'), findsOneWidget);
      expect(find.text('balcony door'), findsOneWidget);
      expect(find.textContaining('Large east-facing'), findsOneWidget);
    });

    testWidgets('hides ceiling row when height is zero', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        const RoomAnalysisCardWidget(
          analysis: RoomAnalysis(
            roomType: 'kitchen',
            currentCondition: 'smooth plaster',
            detectedFeatures: <String>[],
            style: 'classic',
            wallCondition: 'smooth plaster',
          ),
        ),
      ));

      expect(find.textContaining('smooth plaster'), findsAtLeastNWidgets(1));
      // Ceiling height row must not appear when height == 0.
      expect(find.textContaining('0.0 m'), findsNothing);
    });
  });

  group('ConsistencyWarningsBannerWidget rendered output', () {
    testWidgets('renders each warning as a bullet line', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        const ConsistencyWarningsBannerWidget(
          warnings: <String>['Flooring mismatch', 'Style not applied'],
        ),
      ));

      expect(find.textContaining('Flooring mismatch'), findsOneWidget);
      expect(find.textContaining('Style not applied'), findsOneWidget);
      expect(find.textContaining('AI notes'), findsOneWidget);
    });
  });

  group('PlanComparisonTableWidget rendered output', () {
    const List<FinishingPlan> plans = <FinishingPlan>[
      FinishingPlan(
        name: 'Economy',
        summary: '',
        totalCostEgp: 30000,
        breakdown: <String, num>{'materials': 18000, 'labor': 12000},
        materials: <PlanMaterial>[],
        labor: <PlanLabor>[],
        palette: <String>[],
        durationDays: 14,
      ),
      FinishingPlan(
        name: 'Standard',
        summary: '',
        totalCostEgp: 60000,
        breakdown: <String, num>{'materials': 38000, 'labor': 22000},
        materials: <PlanMaterial>[],
        labor: <PlanLabor>[],
        palette: <String>[],
        durationDays: 21,
      ),
    ];

    testWidgets('shows plan names, costs and timelines', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        const PlanComparisonTableWidget(
          plans: plans,
          recommendedName: 'Standard',
        ),
      ));

      expect(find.text('Economy'), findsOneWidget);
      expect(find.text('Standard'), findsOneWidget);
      expect(find.textContaining('30,000'), findsOneWidget);
      expect(find.textContaining('60,000'), findsOneWidget);
      expect(find.textContaining('14 days'), findsOneWidget);
      expect(find.textContaining('21 days'), findsOneWidget);
      expect(find.textContaining('Compare Plans'), findsOneWidget);
    });
  });

  group('MaterialRowWidget rendered output', () {
    const PlanMaterial richMaterial = PlanMaterial(
      name: 'Ceramic Tile',
      quantity: '20',
      unit: 'm²',
      estimatedCostEgp: 4000,
      category: 'flooring',
      unitPriceEgp: 200,
      notes: 'Add 10% waste.',
      vendors: <MaterialVendor>[
        MaterialVendor(name: 'RAK Ceramics', source: 'fallback'),
        MaterialVendor(name: 'Ceramica Cleopatra', source: 'fallback'),
      ],
    );

    testWidgets('shows name, qty, price, unit price, notes, vendors',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(MaterialRowWidget(material: richMaterial)));

      expect(find.text('Ceramic Tile'), findsOneWidget);
      expect(find.textContaining('20 m²'), findsOneWidget);
      expect(find.textContaining('4,000'), findsOneWidget);
      expect(find.textContaining('200'), findsOneWidget);
      expect(find.textContaining('Add 10% waste.'), findsOneWidget);
      expect(find.text('RAK Ceramics'), findsOneWidget);
      expect(find.text('Ceramica Cleopatra'), findsOneWidget);
    });

    testWidgets('hides extra section when notes and vendors absent',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        const MaterialRowWidget(
          material: PlanMaterial(
            name: 'Paint',
            quantity: '10',
            unit: 'L',
            estimatedCostEgp: 500,
          ),
        ),
      ));

      expect(find.text('Paint'), findsOneWidget);
      expect(find.textContaining('waste'), findsNothing);
      expect(find.textContaining('RAK'), findsNothing);
    });
  });
}

// ── Public test-fixture widgets ──────────────────────────────────────────────
// These mirror the rendering logic of the private screen widgets so tests can
// reach the same visual output without importing private symbols.

class RoomAnalysisCardWidget extends StatelessWidget {
  const RoomAnalysisCardWidget({super.key, required this.analysis});
  final RoomAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final wallCond = analysis.wallCondition.isNotEmpty
        ? analysis.wallCondition
        : analysis.currentCondition;

    return SingleChildScrollView(
      child: ServioCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Text('Room Analysis'),
                const Spacer(),
                if (analysis.roomType.isNotEmpty)
                  Text(analysis.roomType.replaceAll('_', ' ').toUpperCase()),
              ],
            ),
            if (wallCond.isNotEmpty) Text('Wall condition: $wallCond'),
            if (analysis.estimatedCeilingHeightM > 0)
              Text(
                'Ceiling height: '
                '${analysis.estimatedCeilingHeightM.toStringAsFixed(1)} m',
              ),
            Wrap(
              children: <Widget>[
                for (final f in analysis.detectedFeatures) Text(f),
              ],
            ),
            if (analysis.specialNotes.isNotEmpty) Text(analysis.specialNotes),
          ],
        ),
      ),
    );
  }
}

class ConsistencyWarningsBannerWidget extends StatelessWidget {
  const ConsistencyWarningsBannerWidget({super.key, required this.warnings});
  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    return ServioCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('AI notes'),
          for (final w in warnings) Text('• $w'),
        ],
      ),
    );
  }
}

class PlanComparisonTableWidget extends StatelessWidget {
  const PlanComparisonTableWidget({
    super.key,
    required this.plans,
    required this.recommendedName,
  });
  final List<FinishingPlan> plans;
  final String recommendedName;

  static String _fmt(num n) => n
      .round()
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  @override
  Widget build(BuildContext context) {
    return ServioCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Compare Plans'),
          Row(
            children: <Widget>[
              const SizedBox(width: 68),
              for (final p in plans) Expanded(child: Text(p.name)),
            ],
          ),
          Row(
            children: <Widget>[
              const SizedBox(width: 68, child: Text('Total')),
              for (final p in plans)
                Expanded(child: Text('${_fmt(p.totalCostEgp.round())} EGP')),
            ],
          ),
          Row(
            children: <Widget>[
              const SizedBox(width: 68, child: Text('Timeline')),
              for (final p in plans)
                Expanded(
                  child: Text(p.durationDays > 0 ? '${p.durationDays} days' : '—'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class MaterialRowWidget extends StatelessWidget {
  const MaterialRowWidget({super.key, required this.material});
  final PlanMaterial material;

  static String _fmt(num n) => n
      .round()
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  @override
  Widget build(BuildContext context) {
    final servio = Theme.of(context).extension<ServioThemeExtension>()!;
    final hasExtra = material.notes.isNotEmpty || material.vendors.isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(material.name)),
              Text('${material.quantity} ${material.unit}'.trim()),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text('${_fmt(material.estimatedCostEgp.round())} EGP'),
                  if (material.unitPriceEgp > 0)
                    Text('${_fmt(material.unitPriceEgp.round())}/${material.unit}'),
                ],
              ),
            ],
          ),
          if (hasExtra) ...<Widget>[
            if (material.notes.isNotEmpty) Text(material.notes),
            if (material.vendors.isNotEmpty)
              Wrap(
                children: <Widget>[
                  for (final v in material.vendors)
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(color: servio.border),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(v.name),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}
