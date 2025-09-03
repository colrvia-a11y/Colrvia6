// lib/models/paint.dart
class PaintColor {
  final String id;
  final String brand;
  final String name;
  final double lrv;
  final String undertone;
  final List<String>? similarIds;
  final List<String>? companionIds;

  const PaintColor({
    required this.id,
    required this.brand,
    required this.name,
    required this.lrv,
    required this.undertone,
    this.similarIds,
    this.companionIds,
  });

  factory PaintColor.fromJson(Map<String, dynamic> j) => PaintColor(
        id: j['id'] as String,
        brand: j['brand'] as String,
        name: j['name'] as String,
        lrv: (j['lrv'] ?? 0).toDouble(),
        undertone: j['undertone'] ?? 'neutral',
        similarIds: (j['similarIds'] as List?)?.cast<String>(),
        companionIds: (j['companionIds'] as List?)?.cast<String>(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'brand': brand,
        'name': name,
        'lrv': lrv,
        'undertone': undertone,
        if (similarIds != null) 'similarIds': similarIds,
        if (companionIds != null) 'companionIds': companionIds,
      };
}
