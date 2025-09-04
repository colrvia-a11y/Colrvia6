// Defines the data schema for the application

class PaletteColor {
  final String paintId;
  final bool locked;
  final int position;
  final String brand;
  final String name;
  final String code;
  final String hex;

  PaletteColor({
    required this.paintId,
    required this.locked,
    required this.position,
    required this.brand,
    required this.name,
    required this.code,
    required this.hex,
  });

  Map<String, dynamic> toJson() => {
    'paintId': paintId,
    'locked': locked,
    'position': position,
    'brand': brand,
    'name': name,
    'code': code,
    'hex': hex,
  };
}

class ColorPlan {
  final List<PaletteColor> colors;

  ColorPlan({
    required this.colors,
  });

  Map<String, dynamic> toJson() => {
    'colors': colors.map((c) => c.toJson()).toList(),
  };
}
