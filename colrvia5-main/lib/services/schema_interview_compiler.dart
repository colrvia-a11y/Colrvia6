// lib/services/schema_interview_compiler.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:color_canvas/services/interview_engine.dart';

/// Compiles a (subset of) JSON Schema to List<InterviewPrompt>
/// Supported: object/string/array/boolean, enum, min/maxItems, uniqueItems,
/// nested properties, $defs (room branches), basic if/then required visibility.
class SchemaInterviewCompiler {
  final Map<String, dynamic> root;
  SchemaInterviewCompiler(this.root);

  static Future<SchemaInterviewCompiler> loadFromAsset(String path) async {
    final raw = await rootBundle.loadString(path);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return SchemaInterviewCompiler(json);
  }

  List<InterviewPrompt> compile() {
    final out = <InterviewPrompt>[];

    // 1) Top-level properties
    final props = (root['properties'] as Map?)?.cast<String, dynamic>() ?? {};
    final requiredTop = (root['required'] as List?)?.cast<String>() ?? const [];
    _compileObject('', props, requiredTop, out);

    // 2) Room branches under $defs (kitchen/bathroom/...)
    final defs = (root[r'$defs'] as Map?)?.cast<String, dynamic>() ?? {};
    final roomDefs = [
      'kitchen',
      'bathroom',
      'bedroom',
      'livingRoom',
      'diningRoom',
      'office',
      'kidsRoom',
      'laundryMudroom',
      'entryHall',
      'otherRoom'
    ];
    for (final r in roomDefs) {
      final def = (defs[r] as Map?)?.cast<String, dynamic>();
      if (def == null) continue;
      final rProps = (def['properties'] as Map?)?.cast<String, dynamic>() ?? {};
      final rReq = (def['required'] as List?)?.cast<String>() ?? const [];
      _compileObject('roomSpecific.', rProps, rReq, out);

      // Visibility rules from def.allOf
      final allOf = (def['allOf'] as List?)?.cast<dynamic>() ?? const [];
      final visRules = _extractVisibilityRules(allOf, scopePrefix: 'roomSpecific.');
      _applyVisibility(out, visRules);
    }

    // 3) Global conditional rules in root (e.g., floorLookOtherNote)
    final allOfRoot = (root['allOf'] as List?)?.cast<dynamic>() ?? const [];
    final rootVis = _extractVisibilityRules(allOfRoot);
    _applyVisibility(out, rootVis);

    return out;
  }

  void _compileObject(
    String prefix,
    Map<String, dynamic> props,
    List<String> required,
    List<InterviewPrompt> out,
  ) {
    for (final entry in props.entries) {
      final key = entry.key;
      final schema = (entry.value as Map).cast<String, dynamic>();
      final id = prefix.isEmpty ? key : '$prefix$key';

      final title = (schema['title'] as String?) ?? id;
      final desc = schema['description'] as String?;
      final type = schema['type'];

      final isRequired = required.contains(key);

      if (type == 'object') {
        final childProps = (schema['properties'] as Map?)?.cast<String, dynamic>() ?? {};
        final childReq = (schema['required'] as List?)?.cast<String>() ?? const [];
        _compileObject('$id.', childProps, childReq, out);
        continue;
      }

      if (type == 'string') {
        final enums = (schema['enum'] as List?)?.cast<String>();
        if (enums != null && enums.isNotEmpty) {
          out.add(InterviewPrompt(
            id: id,
            title: title,
            help: desc,
            type: InterviewPromptType.singleSelect,
            required: isRequired,
            options: enums.map((e) => InterviewPromptOption(e, _labelize(e))).toList(),
          ));
        } else {
          out.add(InterviewPrompt(
            id: id,
            title: title,
            help: desc,
            type: InterviewPromptType.freeText,
            required: isRequired,
          ));
        }
        continue;
      }

      if (type == 'boolean') {
        out.add(InterviewPrompt(
          id: id,
          title: title,
          help: desc,
          type: InterviewPromptType.yesNo,
          required: isRequired,
          options: const [
            InterviewPromptOption('yes', 'Yes'),
            InterviewPromptOption('no', 'No'),
          ],
        ));
        continue;
      }

      if (type == 'array') {
        final items = (schema['items'] as Map?)?.cast<String, dynamic>() ?? {};
        final itemType = items['type'];
        final itemEnums = (items['enum'] as List?)?.cast<String>();
        final minItems = schema['minItems'] as int?;
        final maxItems = schema['maxItems'] as int?;

        if (itemType == 'string' && itemEnums != null && itemEnums.isNotEmpty) {
          out.add(InterviewPrompt(
            id: id,
            title: title,
            help: desc,
            type: InterviewPromptType.multiSelect,
            isArray: true,
            required: isRequired,
            minItems: minItems,
            maxItems: maxItems,
            options: itemEnums.map((e) => InterviewPromptOption(e, _labelize(e))).toList(),
          ));
        } else {
          // Free-form list captured into chips; UI can render a text field → "Add" to chips.
          out.add(InterviewPrompt(
            id: id,
            title: title,
            help: desc,
            type: InterviewPromptType.multiSelect,
            isArray: true,
            required: isRequired,
            minItems: minItems,
            maxItems: maxItems,
            options: const [],
          ));
        }
        continue;
      }
    }
  }

  // --- Visibility extraction from allOf if/then blocks ---

  /// Returns list of (targetId, dependsOnId, constValue)
  List<_VisRule> _extractVisibilityRules(List<dynamic> allOf, {String scopePrefix = ''}) {
    final rules = <_VisRule>[];
    for (final raw in allOf) {
      final block = (raw as Map?)?.cast<String, dynamic>() ?? const {};
      if (block.isEmpty) continue;

      final ifPart = (block['if'] as Map?)?.cast<String, dynamic>();
      final thenPart = (block['then'] as Map?)?.cast<String, dynamic>();
      if (ifPart == null || thenPart == null) continue;

      final conditions = <Map<String, dynamic>>[];
      _collectConstConditions(ifPart, '', conditions);
      if (conditions.isEmpty) continue;

      final requiredTargets = <String>[];
      _collectRequiredTargets(thenPart, '', requiredTargets);

      // Pair each condition with each required target
      for (final c in conditions) {
        final condPath = scopePrefix + (c['path'] as String);
        final condVal = c['const'];
        for (final t in requiredTargets) {
          final targetId = scopePrefix + t;
          rules.add(_VisRule(targetId: targetId, dependsOn: condPath, equalsValue: condVal));
        }
      }
    }
    return rules;
  }

  void _collectConstConditions(Map<String, dynamic> node, String prefix, List<Map<String, dynamic>> out) {
    if (node.containsKey('const')) {
      out.add({'path': prefix, 'const': node['const']});
      return;
    }
    final props = (node['properties'] as Map?)?.cast<String, dynamic>() ?? {};
    for (final e in props.entries) {
      final sub = (e.value as Map).cast<String, dynamic>();
      final next = prefix.isEmpty ? e.key : '$prefix.${e.key}';
      _collectConstConditions(sub, next, out);
    }
  }

  void _collectRequiredTargets(Map<String, dynamic> node, String prefix, List<String> out) {
    final req = (node['required'] as List?)?.cast<String>() ?? const [];
    for (final r in req) {
      out.add(prefix.isEmpty ? r : '$prefix.$r');
    }
    final props = (node['properties'] as Map?)?.cast<String, dynamic>() ?? {};
    for (final e in props.entries) {
      final sub = (e.value as Map).cast<String, dynamic>();
      final next = prefix.isEmpty ? e.key : '$prefix.${e.key}';
      _collectRequiredTargets(sub, next, out);
    }
  }

  void _applyVisibility(List<InterviewPrompt> prompts, List<_VisRule> rules) {
    final byId = {for (final p in prompts) p.id: p};
    for (final r in rules) {
      final p = byId[r.targetId];
      if (p == null) continue;
      final orig = p.visibleIf;
      final visible = (Map<String, dynamic> a) {
        final v = a[r.dependsOn];
        final hit = v == r.equalsValue;
        if (orig != null) {
          return hit && orig(a);
        }
        return hit;
      };
      // Replace with a new prompt instance carrying visibleIf
      byId[r.targetId] = InterviewPrompt(
        id: p.id,
        title: p.title,
        help: p.help,
        type: p.type,
        required: p.required,
        options: p.options,
        minItems: p.minItems,
        maxItems: p.maxItems,
        isArray: p.isArray,
        dependsOn: r.dependsOn,
        visibleIf: visible,
      );
    }

    // Rebuild ordered list in place
    prompts
      ..clear()
      ..addAll(byId.values);
  }
}

class _VisRule {
  final String targetId;
  final String dependsOn;
  final dynamic equalsValue;
  _VisRule({required this.targetId, required this.dependsOn, required this.equalsValue});
}

String _labelize(String v) {
  return v
      .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .replaceAll('_', ' ')
      .replaceAll('Plus', '+')
      .replaceAll('kinda', 'kind of')
      .trim();
}

