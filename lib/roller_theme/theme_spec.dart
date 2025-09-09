// Lightweight ThemeSpec model for data-driven themes
class Range1 {
  final double min;
  final double max;
  Range1(this.min, this.max);

  factory Range1.fromJson(List<dynamic> arr) {
    if (arr.length < 2) return Range1(0, 0);
    return Range1((arr[0] as num).toDouble(), (arr[1] as num).toDouble());
  }

  List<double> toJson() => [min, max];
}

class RangeH {
  final List<List<double>> bands;
  RangeH(this.bands);

  factory RangeH.fromJson(dynamic value) {
    if (value == null) return RangeH([]);
    // value can be a single pair [a,b] or list of pairs
    if (value is List && value.isNotEmpty && value.first is num) {
      // single pair like [a,b]
      return RangeH([
        [(value[0] as num).toDouble(), (value[1] as num).toDouble()]
      ]);
    }
    // assume list of pairs
    final bands = <List<double>>[];
    for (final item in value as List) {
      bands.add([(item[0] as num).toDouble(), (item[1] as num).toDouble()]);
    }
    return RangeH(bands);
  }

  dynamic toJson() => bands;
}

class Range3 {
  final Range1? L;
  final Range1? C;
  final RangeH? H;
  Range3({this.L, this.C, this.H});

  factory Range3.fromJson(Map<String, dynamic>? m) {
    if (m == null) return Range3();
    Range1? tryRange(String key) {
      final v = m[key];
      if (v == null) return null;
      if (v is List) return Range1.fromJson(v);
      return null;
    }

    RangeH? tryH(String key) {
      final v = m[key];
      if (v == null) return null;
      return RangeH.fromJson(v);
    }

    return Range3(L: tryRange('L'), C: tryRange('C'), H: tryH('H'));
  }

  Map<String, dynamic> toJson() => {
        if (L != null) 'L': L!.toJson(),
        if (C != null) 'C': C!.toJson(),
        if (H != null) 'H': H!.toJson(),
      };
}

class RoleTarget {
  final Range1? L;
  final Range1? C;
  final RangeH? H;
  RoleTarget({this.L, this.C, this.H});

  factory RoleTarget.fromJson(Map<String, dynamic>? m) {
    if (m == null) return RoleTarget();
    Range1? tryRange(String key) {
      final v = m[key];
      if (v == null) return null;
      if (v is List) return Range1.fromJson(v);
      return null;
    }

    RangeH? tryH(String key) {
      final v = m[key];
      if (v == null) return null;
      return RangeH.fromJson(v);
    }

    return RoleTarget(L: tryRange('L'), C: tryRange('C'), H: tryH('H'));
  }

  Map<String, dynamic> toJson() => {
        if (L != null) 'L': L!.toJson(),
        if (C != null) 'C': C!.toJson(),
        if (H != null) 'H': H!.toJson(),
      };
}

class RoleTargets {
  final RoleTarget? anchor;
  final RoleTarget? secondary;
  final RoleTarget? accent;
  RoleTargets({this.anchor, this.secondary, this.accent});

  factory RoleTargets.fromJson(Map<String, dynamic>? m) {
    if (m == null) return RoleTargets();
    return RoleTargets(
      anchor: RoleTarget.fromJson(m['anchor'] as Map<String, dynamic>?),
      secondary: RoleTarget.fromJson(m['secondary'] as Map<String, dynamic>?),
      accent: RoleTarget.fromJson(m['accent'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toJson() => {
        if (anchor != null) 'anchor': anchor!.toJson(),
        if (secondary != null) 'secondary': secondary!.toJson(),
        if (accent != null) 'accent': accent!.toJson(),
      };
}

class ThemeSpec {
  final String id;
  final String label;
  final List<String> aliases;
  final Range3? neutrals;
  final Range3? accents;
  final RoleTargets? roleTargets;
  final List<List<double>> forbiddenHues;
  final List<String> harmonyBias;
  final Map<String, double> weights;
  // v2 additions (backward-compatible)
  final List<String> corePrinciples; // docs only
  final List<List<double>> allowedHueRanges; // accent-allowed hue bands
  final VarietyControls? varietyControls; // min/max + inclusion rules

  ThemeSpec({
    required this.id,
    required this.label,
    this.aliases = const [],
    this.neutrals,
    this.accents,
    this.roleTargets,
    this.forbiddenHues = const [],
    this.harmonyBias = const [],
    this.weights = const {},
    this.corePrinciples = const [],
    this.allowedHueRanges = const [],
    this.varietyControls,
  });

  factory ThemeSpec.fromJson(Map<String, dynamic> m) {
    List<String> parseAliases(dynamic a) {
      if (a == null) return [];
      return (a as List).map((e) => e.toString()).toList();
    }

    List<List<double>> parseForbidden(dynamic f) {
      if (f == null) return [];
      final out = <List<double>>[];
      for (final item in f as List) {
        out.add([(item[0] as num).toDouble(), (item[1] as num).toDouble()]);
      }
      return out;
    }

    List<String> parseHarmony(dynamic h) {
      if (h == null) return [];
      return (h as List).map((e) => e.toString()).toList();
    }

    List<String> parseCore(dynamic v) {
      if (v == null) return [];
      return (v as List).map((e) => e.toString()).toList();
    }

    List<List<double>> parseBands(dynamic v) {
      if (v == null) return [];
      final out = <List<double>>[];
      for (final band in (v as List)) {
        if (band is List && band.length >= 2) {
          out.add([(band[0] as num).toDouble(), (band[1] as num).toDouble()]);
        }
      }
      return out;
    }

    Map<String, double> parseWeights(dynamic w) {
      if (w == null) return {};
      final map = <String, double>{};
      for (final entry in (w as Map).entries) {
        map[entry.key.toString()] = (entry.value as num).toDouble();
      }
      return map;
    }

    return ThemeSpec(
      id: m['id'] as String,
      label: m['label'] as String,
      aliases: parseAliases(m['aliases']),
      neutrals: Range3.fromJson((m['neutrals'] as Map<String, dynamic>?)),
      accents: Range3.fromJson((m['accents'] as Map<String, dynamic>?)),
      roleTargets:
          RoleTargets.fromJson((m['roleTargets'] as Map<String, dynamic>?)),
      forbiddenHues: parseForbidden(m['forbiddenHues']),
      harmonyBias: parseHarmony(m['harmonyBias']),
      weights: parseWeights(m['weights']),
      corePrinciples: parseCore(m['core_principles']),
      allowedHueRanges: parseBands(m['allowed_hue_ranges']),
      varietyControls: VarietyControls.fromJson(
          m['variety_controls'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        if (aliases.isNotEmpty) 'aliases': aliases,
        if (neutrals != null) 'neutrals': neutrals!.toJson(),
        if (accents != null) 'accents': accents!.toJson(),
        if (roleTargets != null) 'roleTargets': roleTargets!.toJson(),
        if (forbiddenHues.isNotEmpty) 'forbiddenHues': forbiddenHues,
        if (harmonyBias.isNotEmpty) 'harmonyBias': harmonyBias,
        if (weights.isNotEmpty) 'weights': weights,
        if (corePrinciples.isNotEmpty) 'core_principles': corePrinciples,
        if (allowedHueRanges.isNotEmpty) 'allowed_hue_ranges': allowedHueRanges,
        if (varietyControls != null)
          'variety_controls': varietyControls!.toJson(),
      };
}

class VarietyControls {
  final int minColors;
  final int maxColors;
  final bool mustIncludeNeutral;
  final bool mustIncludeAccent;
  const VarietyControls({
    required this.minColors,
    required this.maxColors,
    required this.mustIncludeNeutral,
    required this.mustIncludeAccent,
  });
  factory VarietyControls.fromJson(Map<String, dynamic>? m) {
    if (m == null)
      return const VarietyControls(
          minColors: 0,
          maxColors: 99,
          mustIncludeNeutral: false,
          mustIncludeAccent: false);
    int _i(String k, int d) => (m[k] == null) ? d : (m[k] as num).toInt();
    bool _b(String k, bool d) => (m[k] == null) ? d : (m[k] as bool);
    return VarietyControls(
      minColors: _i('min_colors', 0),
      maxColors: _i('max_colors', 99),
      mustIncludeNeutral: _b('must_include_neutral', false),
      mustIncludeAccent: _b('must_include_accent', false),
    );
  }
  Map<String, dynamic> toJson() => {
        'min_colors': minColors,
        'max_colors': maxColors,
        'must_include_neutral': mustIncludeNeutral,
        'must_include_accent': mustIncludeAccent,
      };
}
