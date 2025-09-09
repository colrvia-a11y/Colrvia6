import 'package:cloud_firestore/cloud_firestore.dart';

class PlanPlacement {
  final String area;
  final String colorId;
  final String sheen;

  const PlanPlacement({
    required this.area,
    required this.colorId,
    required this.sheen,
  });

  factory PlanPlacement.fromJson(Map<String, dynamic> j) => PlanPlacement(
        area: j['area'] as String,
        colorId: j['colorId'] as String,
        sheen: j['sheen'] as String,
      );

  Map<String, dynamic> toJson() => {
        'area': area,
        'colorId': colorId,
        'sheen': sheen,
      };
}

class AccentRule {
  final String context;
  final String guidance;

  const AccentRule({
    required this.context,
    required this.guidance,
  });

  factory AccentRule.fromJson(Map<String, dynamic> j) => AccentRule(
        context: j['context'] as String,
        guidance: j['guidance'] as String,
      );

  Map<String, dynamic> toJson() => {
        'context': context,
        'guidance': guidance,
      };
}

class DoDontEntry {
  final String doText;
  final String dontText;

  const DoDontEntry({
    required this.doText,
    required this.dontText,
  });

  factory DoDontEntry.fromJson(Map<String, dynamic> j) => DoDontEntry(
        doText: j['do'] as String,
        dontText: j['dont'] as String,
      );

  Map<String, dynamic> toJson() => {
        'do': doText,
        'dont': dontText,
      };
}

class RoomPlaybookItem {
  final String roomType;
  final List<PlanPlacement> placements;
  final String notes;

  const RoomPlaybookItem({
    required this.roomType,
    required this.placements,
    required this.notes,
  });

  factory RoomPlaybookItem.fromJson(Map<String, dynamic> j) => RoomPlaybookItem(
        roomType: j['roomType'] as String,
        placements: (j['placements'] as List<dynamic>? ?? [])
            .map((e) => PlanPlacement.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        notes: j['notes'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'roomType': roomType,
        'placements': placements.map((e) => e.toJson()).toList(),
        'notes': notes,
      };
}

class ColorPlan {
  final String id;
  final String projectId;
  final String name;
  final String vibe;
  final List<String> paletteColorIds;
  final List<PlanPlacement> placementMap;
  final List<String> cohesionTips;
  final List<AccentRule> accentRules;
  final List<DoDontEntry> doDont;
  final List<String> sampleSequence;
  final List<RoomPlaybookItem> roomPlaybook;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isFallback;

  const ColorPlan({
    required this.id,
    required this.projectId,
    required this.name,
    required this.vibe,
    required this.paletteColorIds,
    required this.placementMap,
    required this.cohesionTips,
    required this.accentRules,
    required this.doDont,
    required this.sampleSequence,
    required this.roomPlaybook,
    required this.createdAt,
    required this.updatedAt,
    this.isFallback = false,
  });

  factory ColorPlan.fromJson(String id, Map<String, dynamic> j) => ColorPlan(
        id: id,
        projectId: j['projectId'] as String,
        name: j['name'] as String,
        vibe: j['vibe'] as String? ?? '',
        paletteColorIds:
            (j['paletteColorIds'] as List<dynamic>? ?? []).cast<String>(),
        placementMap: (j['placementMap'] as List<dynamic>? ?? [])
            .map((e) => PlanPlacement.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        cohesionTips:
            (j['cohesionTips'] as List<dynamic>? ?? []).cast<String>(),
        accentRules: (j['accentRules'] as List<dynamic>? ?? [])
            .map((e) => AccentRule.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        doDont: (j['doDont'] as List<dynamic>? ?? [])
            .map((e) => DoDontEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        sampleSequence:
            (j['sampleSequence'] as List<dynamic>? ?? []).cast<String>(),
        roomPlaybook: (j['roomPlaybook'] as List<dynamic>? ?? [])
            .map((e) => RoomPlaybookItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        createdAt: (j['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt: (j['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        isFallback: j['isFallback'] == true,
      );

  Map<String, dynamic> toJson() => {
        'projectId': projectId,
        'name': name,
        'vibe': vibe,
        'paletteColorIds': paletteColorIds,
        'placementMap': placementMap.map((e) => e.toJson()).toList(),
        'cohesionTips': cohesionTips,
        'accentRules': accentRules.map((e) => e.toJson()).toList(),
        'doDont': doDont.map((e) => e.toJson()).toList(),
        'sampleSequence': sampleSequence,
        'roomPlaybook': roomPlaybook.map((e) => e.toJson()).toList(),
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        if (isFallback) 'isFallback': true,
      };

  ColorPlan copyWith({
    String? id,
    String? projectId,
    String? name,
    String? vibe,
    List<String>? paletteColorIds,
    List<PlanPlacement>? placementMap,
    List<String>? cohesionTips,
    List<AccentRule>? accentRules,
    List<DoDontEntry>? doDont,
    List<String>? sampleSequence,
    List<RoomPlaybookItem>? roomPlaybook,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isFallback,
  }) {
    return ColorPlan(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      vibe: vibe ?? this.vibe,
      paletteColorIds: paletteColorIds ?? this.paletteColorIds,
      placementMap: placementMap ?? this.placementMap,
      cohesionTips: cohesionTips ?? this.cohesionTips,
      accentRules: accentRules ?? this.accentRules,
      doDont: doDont ?? this.doDont,
      sampleSequence: sampleSequence ?? this.sampleSequence,
      roomPlaybook: roomPlaybook ?? this.roomPlaybook,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isFallback: isFallback ?? this.isFallback,
    );
  }
}
