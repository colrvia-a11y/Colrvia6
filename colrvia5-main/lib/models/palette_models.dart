class PaintColor {
  final String name; // e.g., "Pure White"
  final String code; // hex like #F8F8F6 or brand code
  final double? lrv; // 0..100 if available
  final String? undertone; // e.g., "warm", "cool", "green-gray"
  const PaintColor({required this.name, required this.code, this.lrv, this.undertone});

  factory PaintColor.fromJson(Map<String, dynamic> j) => PaintColor(
        name: j['name'] ?? '',
        code: (j['hex'] ?? j['code'] ?? '#000000').toString(),
        lrv: j['LRV'] == null ? null : (j['LRV'] as num).toDouble(),
        undertone: j['undertone'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'hex': code,
        if (lrv != null) 'LRV': lrv,
        if (undertone != null) 'undertone': undertone,
      };
}

class PaletteRoles {
  final PaintColor anchor; // main wall
  final PaintColor secondary; // trim/ceiling or cabinets
  final PaintColor accent; // door/built-ins/one wall
  const PaletteRoles({required this.anchor, required this.secondary, required this.accent});

  PaletteRoles copyWith({PaintColor? anchor, PaintColor? secondary, PaintColor? accent}) =>
      PaletteRoles(anchor: anchor ?? this.anchor, secondary: secondary ?? this.secondary, accent: accent ?? this.accent);
}

class Palette {
  final String brand; // SherwinWilliams, BenjaminMoore, Behr
  final PaletteRoles roles;
  final Map<String, dynamic>? rationale;
  final String? id; // optional paletteId from backend

  const Palette({required this.brand, required this.roles, this.rationale, this.id});

  factory Palette.fromJson(Map<String, dynamic> j) {
    final roles = j['roles'] as Map<String, dynamic>;
    PaintColor _pc(String k) => PaintColor.fromJson((roles[k] as Map).cast<String, dynamic>());
    return Palette(
      brand: j['brand'] ?? 'SherwinWilliams',
      roles: PaletteRoles(anchor: _pc('anchor'), secondary: _pc('secondary'), accent: _pc('accent')),
      rationale: (j['rationale'] as Map?)?.cast<String, dynamic>(),
      id: j['id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'brand': brand,
        'roles': {
          'anchor': roles.anchor.toJson(),
          'secondary': roles.secondary.toJson(),
          'accent': roles.accent.toJson(),
        },
        if (rationale != null) 'rationale': rationale,
        if (id != null) 'id': id,
      };
}
