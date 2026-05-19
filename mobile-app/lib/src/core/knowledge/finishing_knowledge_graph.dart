import '../api/ai_api.dart';

/// Minimal in-app knowledge-graph adapter. The repo has no graphify or
/// knowledge-node abstraction yet, so this layer keeps the finishing model
/// output structured for any future graphify pipeline. The schema is
/// intentionally simple: typed nodes + directed labelled edges, both
/// JSON-serialisable so they can be exported as a graphify document.
class KnowledgeNode {
  const KnowledgeNode({
    required this.id,
    required this.type,
    required this.label,
    this.attributes = const <String, Object?>{},
  });

  final String id;
  final String type;
  final String label;
  final Map<String, Object?> attributes;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'type': type,
        'label': label,
        'attributes': attributes,
      };
}

class KnowledgeEdge {
  const KnowledgeEdge({
    required this.fromId,
    required this.toId,
    required this.relation,
  });

  final String fromId;
  final String toId;
  final String relation;

  Map<String, Object?> toJson() => <String, Object?>{
        'from': fromId,
        'to': toId,
        'relation': relation,
      };
}

/// Holds the structured nodes/edges derived from a [RoomAnalysisResponse].
/// Views read [nodes] and [edges] directly — none of this logic lives in
/// widgets.
class FinishingKnowledgeGraph {
  const FinishingKnowledgeGraph({
    required this.nodes,
    required this.edges,
  });

  final List<KnowledgeNode> nodes;
  final List<KnowledgeEdge> edges;

  bool get isEmpty => nodes.isEmpty;

  Iterable<KnowledgeNode> nodesOfType(String type) =>
      nodes.where((KnowledgeNode n) => n.type == type);

  Iterable<KnowledgeEdge> edgesFrom(String nodeId) =>
      edges.where((KnowledgeEdge e) => e.fromId == nodeId);

  Map<String, Object?> toJson() => <String, Object?>{
        'nodes': nodes.map((KnowledgeNode n) => n.toJson()).toList(),
        'edges': edges.map((KnowledgeEdge e) => e.toJson()).toList(),
      };

  /// Build a graph from an AI finishing analysis. Schema:
  ///
  ///   room ─[has_condition]→ condition
  ///   room ─[has_feature]→ feature*
  ///   room ─[recommends]→ recommended_plan
  ///   room ─[alternative]→ alt_plan*
  ///   plan ─[uses]→ material*
  ///   plan ─[palette]→ color*
  ///   plan ─[renders]→ rendered_image    (only on recommended plan)
  factory FinishingKnowledgeGraph.fromAnalysis(RoomAnalysisResponse res) {
    final nodes = <KnowledgeNode>[];
    final edges = <KnowledgeEdge>[];

    final room = res.roomAnalysis;
    const roomId = 'room:current';

    nodes.add(KnowledgeNode(
      id: roomId,
      type: 'room',
      label: room.roomType.isEmpty ? 'Analysed room' : room.roomType,
      attributes: <String, Object?>{
        'style': room.style,
        'detected_features': room.detectedFeatures,
      },
    ));

    if (room.currentCondition.isNotEmpty) {
      const condId = 'condition:current';
      nodes.add(KnowledgeNode(
        id: condId,
        type: 'condition',
        label: room.currentCondition,
      ));
      edges.add(const KnowledgeEdge(
        fromId: roomId,
        toId: condId,
        relation: 'has_condition',
      ));
    }

    for (var i = 0; i < room.detectedFeatures.length; i++) {
      final featId = 'feature:$i';
      nodes.add(KnowledgeNode(
        id: featId,
        type: 'feature',
        label: room.detectedFeatures[i],
      ));
      edges.add(KnowledgeEdge(
        fromId: roomId,
        toId: featId,
        relation: 'has_feature',
      ));
    }

    for (var p = 0; p < res.plans.length; p++) {
      final plan = res.plans[p];
      final planId = 'plan:$p';
      final isRecommended = plan.name == res.recommendedPlanName;

      nodes.add(KnowledgeNode(
        id: planId,
        type: 'plan',
        label: plan.name,
        attributes: <String, Object?>{
          'summary': plan.summary,
          'total_cost_egp': plan.totalCostEgp,
          'duration_days': plan.durationDays,
          'recommended': isRecommended,
        },
      ));
      edges.add(KnowledgeEdge(
        fromId: roomId,
        toId: planId,
        relation: isRecommended ? 'recommends' : 'alternative',
      ));

      for (var m = 0; m < plan.materials.length; m++) {
        final mat = plan.materials[m];
        final matId = '$planId:material:$m';
        nodes.add(KnowledgeNode(
          id: matId,
          type: 'material',
          label: mat.name,
          attributes: <String, Object?>{
            'quantity': mat.quantity,
            'unit': mat.unit,
            'estimated_cost_egp': mat.estimatedCostEgp,
          },
        ));
        edges.add(KnowledgeEdge(
          fromId: planId,
          toId: matId,
          relation: 'uses',
        ));
      }

      for (var c = 0; c < plan.palette.length; c++) {
        final colorId = '$planId:color:$c';
        nodes.add(KnowledgeNode(
          id: colorId,
          type: 'color',
          label: plan.palette[c],
        ));
        edges.add(KnowledgeEdge(
          fromId: planId,
          toId: colorId,
          relation: 'palette',
        ));
      }

      if (isRecommended &&
          res.generatedImageBase64 != null &&
          res.generatedImageBase64!.isNotEmpty) {
        const renderId = 'render:recommended';
        nodes.add(const KnowledgeNode(
          id: renderId,
          type: 'rendered_image',
          label: 'AI render of recommended finish',
          attributes: <String, Object?>{'encoding': 'base64'},
        ));
        edges.add(KnowledgeEdge(
          fromId: planId,
          toId: renderId,
          relation: 'renders',
        ));
      }
    }

    return FinishingKnowledgeGraph(nodes: nodes, edges: edges);
  }
}
