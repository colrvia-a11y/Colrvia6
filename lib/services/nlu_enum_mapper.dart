// lib/services/nlu_enum_mapper.dart
import 'dart:math';
import 'package:color_canvas/services/interview_engine.dart';

/// Maps free-form utterances to schema enum values.
/// Pure Dart (no deps); token + synonym + fuzzy heuristics.
class EnumMapper {
  EnumMapper._();
  static final EnumMapper instance = EnumMapper._();

  /// Returns (value, confidence 0..1) or null if low confidence.
  ({String value, double confidence})? mapSingle(
      InterviewPrompt prompt, String utterance) {
    final table = _buildLexicon(prompt);
    final u = _norm(utterance);
    // Exact contains / token Jaccard / prefix / synonym hits
    double best = 0;
    String? bestVal;
    for (final e in table) {
      final score = _score(u, e);
      if (score > best) {
        best = score;
        bestVal = e.value;
      }
    }
    if (bestVal == null) return null;
    if (best < 0.62) return null; // threshold tuned for safety
    return (value: bestVal, confidence: best);
  }

  /// Multi-select parser: splits on commas/and; maps each chunk.
  /// Respects prompt.minItems/maxItems if provided.
  List<String> mapMulti(InterviewPrompt prompt, String utterance) {
    if (prompt.options.isEmpty) return const [];
    final parts = utterance
        .replaceAll(RegExp(r"[/&]|plus"), ',')
        .split(RegExp(r"\s*,\s*|\s+and\s+|\s+or\s+", caseSensitive: false))
        .map(_norm)
        .where((s) => s.isNotEmpty)
        .toList();

    final table = _buildLexicon(prompt);
    final chosen = <String>[];

    for (final p in parts) {
      double best = 0;
      String? bestVal;
      for (final e in table) {
        final s = _score(p, e);
        if (s > best) {
          best = s;
          bestVal = e.value;
        }
      }
      if (bestVal != null && best >= 0.62 && !chosen.contains(bestVal)) {
        chosen.add(bestVal);
        if (prompt.maxItems != null && chosen.length >= prompt.maxItems!) break;
      }
    }

    // Handle shortcuts
    final allWords = utterance.toLowerCase();
    if (chosen.isEmpty &&
        (allWords.contains('all of them') ||
            allWords.contains('select all') ||
            allWords.contains('everything'))) {
      return prompt.options.map((o) => o.value).toList();
    }

    // Enforce minItems
    if (prompt.minItems != null && chosen.length < prompt.minItems!) {
      return chosen; // caller can prompt to add more
    }
    return chosen;
  }

  // ---------- internals ----------

  List<_Lex> _buildLexicon(InterviewPrompt prompt) {
    final out = <_Lex>[];
    for (final o in prompt.options) {
      final base = _norm(o.label);
      final raw = _norm(o.value);
      final syns = {
        ..._expandCamel(o.value),
        ..._expandLabel(o.label),
        ..._builtinSynonyms(o.value),
      }.map(_norm).where((s) => s.isNotEmpty).toSet();
      out.add(_Lex(value: o.value, forms: {base, raw, ...syns}));
    }
    return out;
  }

  String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9+\s]"), ' ')
      .replaceAll(RegExp(r"\s+"), ' ')
      .trim();

  Set<String> _expandCamel(String v) {
    var s = v.replaceAll('_', ' ').replaceAll('+', ' plus ');
    s = s.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    return {s};
  }

  Set<String> _expandLabel(String l) {
    final w = l.toLowerCase();
    final out = <String>{w};
    if (w.contains('kinda')) out.add(w.replaceAll('kinda', 'kind of'));
    return out;
  }

  Set<String> _builtinSynonyms(String value) {
    switch (value) {
      case 'veryBright':
        return {'very bright', 'tons of light', 'super bright', 'flooded'};
      case 'kindaBright':
        return {
          'pretty bright',
          'fairly bright',
          'some light',
          'medium bright'
        };
      case 'dim':
        return {'dim', 'dark', 'little light', 'not much light'};
      case 'cozyYellow_2700K':
        return {
          'warm bulbs',
          'yellow light',
          '2700',
          'cozy',
          'soft white warm'
        };
      case 'neutral_3000_3500K':
        return {'neutral', '3000', '3500', 'soft white'};
      case 'brightWhite_4000KPlus':
        return {'cool white', 'bright white', '4000', 'daylight'};
      case 'loveIt':
        return {'yes', 'love it', 'i like it', 'for sure'};
      case 'maybe':
        return {'maybe', 'not sure', 'depends'};
      case 'noThanks':
        return {'no', 'no thanks', 'skip it', 'rather not'};
      case 'yes':
        return {'yes', 'yep', 'sure', 'affirmative', 'ok'};
      case 'no':
        return {'no', 'nope', 'negative'};
      // Room types
      case 'kitchen':
        return {'kitchen'};
      case 'bathroom':
        return {'bathroom', 'bath', 'restroom'};
      case 'bedroom':
        return {'bedroom', 'primary bedroom', 'master bedroom', 'nursery'};
      case 'livingRoom':
        return {'living room', 'family room', 'den'};
      case 'diningRoom':
        return {'dining', 'dining room'};
      case 'office':
        return {'office', 'study'};
      case 'kidsRoom':
        return {'kids room', 'kid room', 'playroom'};
      case 'laundryMudroom':
        return {'laundry', 'mudroom', 'laundry room'};
      case 'entryHall':
        return {'entry', 'hall', 'hallway', 'foyer'};
      default:
        return {};
    }
  }

  double _score(String utter, _Lex lex) {
    // Exact contains
    if (lex.forms.any((f) => utter.contains(f))) return 1.0;
    final tokensU = utter.split(' ').where((t) => t.isNotEmpty).toSet();
    final bestTokenHit = lex.forms
        .map((f) => f.split(' ').where((t) => t.isNotEmpty).toSet())
        .map((toks) => _jaccard(tokensU, toks))
        .fold(0.0, max);
    // Prefix boost
    final prefix = lex.forms.any((f) => _prefix(utter, f));
    var s = max(bestTokenHit, prefix ? 0.66 : 0.0);
    // Penalty for very short overlaps
    if (s < 0.5 && tokensU.length <= 2) s *= 0.9;
    return s;
  }

  bool _prefix(String u, String f) => u.startsWith(f) || f.startsWith(u);
  double _jaccard(Set<String> a, Set<String> b) =>
      a.isEmpty && b.isEmpty ? 1 : a.intersection(b).length / a.union(b).length;
}

class _Lex {
  final String value;
  final Set<String> forms;
  _Lex({required this.value, required this.forms});
}
