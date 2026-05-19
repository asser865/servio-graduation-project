import 'package:flutter_test/flutter_test.dart';

import 'package:servio_mobile_app/src/core/api/ai_api.dart';
import 'package:servio_mobile_app/src/core/knowledge/finishing_knowledge_graph.dart';

void main() {
  test('builds nodes/edges for room + plans + materials + render', () {
    final res = RoomAnalysisResponse.fromJson(<String, dynamic>{
      'data': <String, dynamic>{
        'room_analysis': <String, dynamic>{
          'room_type': 'kitchen',
          'current_condition': 'old cabinets',
          'detected_features': <String>['sink', 'window'],
          'style': 'modern',
        },
        'finishing_plans': <Map<String, dynamic>>[
          <String, dynamic>{
            'plan_name': 'Plan A',
            'description': 'A',
            'total_cost_egp': 10000,
            'duration_days': 6,
            'color_palette': <String>['#FFFFFF', '#000000'],
            'materials': <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'Tiles',
                'quantity': '20',
                'unit': 'm²',
                'estimated_cost_egp': 4000,
              },
            ],
          },
          <String, dynamic>{
            'plan_name': 'Plan B',
            'description': 'B',
            'total_cost_egp': 6000,
            'color_palette': <String>[],
            'materials': <Map<String, dynamic>>[],
          },
        ],
        'recommended_plan': 'Plan A',
      },
      'generated_room_image': 'aGVsbG8=',
    });

    final graph = FinishingKnowledgeGraph.fromAnalysis(res);

    // 1 room + 1 condition + 2 features + 2 plans + 1 material + 2 colors + 1 render
    expect(graph.nodes.length, 10);
    expect(graph.nodesOfType('room'), hasLength(1));
    expect(graph.nodesOfType('plan'), hasLength(2));
    expect(graph.nodesOfType('feature'), hasLength(2));
    expect(graph.nodesOfType('material'), hasLength(1));
    expect(graph.nodesOfType('color'), hasLength(2));
    expect(graph.nodesOfType('rendered_image'), hasLength(1));

    // Recommended plan gets recommends edge; the other gets alternative.
    final recommendsEdges = graph.edges
        .where((KnowledgeEdge e) => e.relation == 'recommends')
        .toList();
    expect(recommendsEdges, hasLength(1));

    final altEdges = graph.edges
        .where((KnowledgeEdge e) => e.relation == 'alternative')
        .toList();
    expect(altEdges, hasLength(1));

    // Only recommended plan emits a render edge.
    final renderEdges = graph.edges
        .where((KnowledgeEdge e) => e.relation == 'renders')
        .toList();
    expect(renderEdges, hasLength(1));
  });

  test('handles missing render gracefully', () {
    final res = RoomAnalysisResponse.fromJson(<String, dynamic>{
      'data': <String, dynamic>{
        'room_analysis': <String, dynamic>{
          'room_type': 'bedroom',
          'detected_features': <String>[],
        },
        'finishing_plans': <Map<String, dynamic>>[
          <String, dynamic>{
            'plan_name': 'Only Plan',
            'total_cost_egp': 5000,
          },
        ],
        'recommended_plan': 'Only Plan',
      },
    });

    final graph = FinishingKnowledgeGraph.fromAnalysis(res);
    expect(graph.nodesOfType('rendered_image'), isEmpty);
    expect(graph.nodesOfType('plan'), hasLength(1));
  });
}
