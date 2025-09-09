class FlowEdge {
  final String from;
  final String to;
  const FlowEdge({required this.from, required this.to});

  factory FlowEdge.fromJson(Map<String, dynamic> j) =>
      FlowEdge(from: j['from'] as String, to: j['to'] as String);

  Map<String, dynamic> toJson() => {'from': from, 'to': to};
}

class HouseFlow {
  final List<String> rooms;
  final List<FlowEdge> edges;
  const HouseFlow({required this.rooms, required this.edges});

  factory HouseFlow.fromJson(Map<String, dynamic> j) => HouseFlow(
        rooms: (j['rooms'] as List<dynamic>? ?? []).cast<String>(),
        edges: (j['edges'] as List<dynamic>? ?? [])
            .map((e) => FlowEdge.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'rooms': rooms,
        'edges': edges.map((e) => e.toJson()).toList(),
      };
}
