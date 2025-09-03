// lib/services/interview_engine.dart
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Types of prompts we render in the chat UI.
enum InterviewPromptType { singleSelect, multiSelect, freeText, yesNo }

@immutable
class InterviewPromptOption {
  final String value; // canonical enum-ish value stored in answers
  final String label; // human-readable label
  const InterviewPromptOption(this.value, this.label);
}

@immutable
class InterviewPrompt {
  final String id; // e.g. "roomType" or "existingElements.floorLook"
  final String title; // question copy
  final String? help; // short helper or example
  final InterviewPromptType type;
  final bool required;
  final List<InterviewPromptOption> options; // for select types
  final int? minItems;
  final int? maxItems;
  final bool isArray; // if answer is a list
  final String? dependsOn; // parent id used for branching visibility
  final bool Function(Map<String, dynamic> answers)? visibleIf; // runtime predicate

  const InterviewPrompt({
    required this.id,
    required this.title,
    this.help,
    required this.type,
    this.required = false,
    this.options = const [],
    this.minItems,
    this.maxItems,
    this.isArray = false,
    this.dependsOn,
    this.visibleIf,
  });
}

enum InterviewDepth { quick, full }

/// A minimal, schema-inspired engine that emits prompts in order and handles branching.
class InterviewEngine extends ChangeNotifier {
  InterviewEngine._(this._allPrompts);
  static InterviewEngine demo() => InterviewEngine._(_buildDemoPrompts());

  InterviewDepth _depth = InterviewDepth.quick;
  InterviewDepth get depth => _depth;
  void setDepth(InterviewDepth d) {
    _depth = d;
    _recomputeSequence();
    _index = _firstUnansweredIndex();
    notifyListeners();
  }

  /// In a future iteration, compile from full JSON Schema.
  /// For now, we create a curated list that maps 1:1 to the provided schema keys.
  final List<InterviewPrompt> _allPrompts;
  final List<String> _sequence = [];
  final Map<String, dynamic> _answers = {};
  int _index = 0;

  UnmodifiableMapView<String, dynamic> get answers => UnmodifiableMapView(_answers);
  int get index => _index;
  int get total => _sequence.length;
  double get progress => total == 0 ? 0 : (_index / total).clamp(0, 1);

  InterviewPrompt? get current =>
      (_index >= 0 && _index < _sequence.length)
          ? _allPrompts.firstWhere((p) => p.id == _sequence[_index])
          : null;

  /// Initialize (or reinitialize after loading answers)
  void start({Map<String, dynamic>? seedAnswers, InterviewDepth depth = InterviewDepth.quick}) {
    _answers.clear();
    if (seedAnswers != null) _answers.addAll(seedAnswers);
    _depth = depth;
    _recomputeSequence();
    _index = _firstUnansweredIndex();
    notifyListeners();
  }

  int _firstUnansweredIndex() {
    for (var i = 0; i < _sequence.length; i++) {
      if (!_answers.containsKey(_sequence[i]) ||
          (_answers[_sequence[i]] is List && (_answers[_sequence[i]] as List).isEmpty) ||
          (_answers[_sequence[i]] is String && (_answers[_sequence[i]] as String).trim().isEmpty)) {
        return i;
      }
    }
    return 0;
  }

  /// Build the prompt order given current answers (handles branching on roomType).
  void _recomputeSequence() {
    _sequence.clear();

    final quickCore = <String>[
      'roomType',
      'usage',
      'moodWords',
      'daytimeBrightness',
      'bulbColor',
      'boldDarkerSpot',
      'brandPreference',
    ];

    final fullExtras = <String>[
      'existingElements.floorLook',
      'existingElements.floorLookOtherNote',
      'existingElements.bigThingsToMatch',
      'existingElements.metals',
      'existingElements.mustStaySame',
      'colorComfort.overallVibe',
      'colorComfort.warmCoolFeel',
      'colorComfort.contrastLevel',
      'colorComfort.popColor',
      'finishes.wallsFinishPriority',
      'finishes.trimDoorsFinish',
      'finishes.specialNeeds',
      'guardrails.mustHaves',
      'guardrails.hardNos',
      'photos',
    ];

    final roomType = _answers['roomType'] as String?;
    final roomSpecific = _roomBranch(roomType);

    _sequence
      ..addAll(quickCore)
      ..addAll(roomSpecific);

    if (_depth == InterviewDepth.full) {
      _sequence.addAll(fullExtras);
    }

    _sequence.removeWhere((id) => !_isVisible(id));
  }

  List<String> _roomBranch(String? roomType) {
    switch (roomType) {
      case 'kitchen':
        return [
          'roomSpecific.cabinets',
          'roomSpecific.cabinetsCurrentColor',
          'roomSpecific.island',
          'roomSpecific.countertopsDescription',
          'roomSpecific.backsplash',
          'roomSpecific.backsplashDescribe',
          'roomSpecific.appliances',
          'roomSpecific.wallFeel',
          'roomSpecific.darkerSpots',
        ];
      case 'bathroom':
        return [
          'roomSpecific.tileMainColor',
          'roomSpecific.tileColorWhich',
          'roomSpecific.vanityTop',
          'roomSpecific.showerSteamLevel',
          'roomSpecific.fixtureMetal',
          'roomSpecific.goal',
          'roomSpecific.darkerVanityOrDoor',
        ];
      case 'bedroom':
        return [
          'roomSpecific.sleepFeel',
          'roomSpecific.beddingColors',
          'roomSpecific.headboard',
          'roomSpecific.windowTreatments',
          'roomSpecific.darkerWallBehindBed',
        ];
      case 'livingRoom':
        return [
          'roomSpecific.sofaColor',
          'roomSpecific.rugMainColors',
          'roomSpecific.fireplace',
          'roomSpecific.fireplaceDetail',
          'roomSpecific.tvWall',
          'roomSpecific.builtInsOrDoorColor',
        ];
      case 'diningRoom':
        return [
          'roomSpecific.tableWoodTone',
          'roomSpecific.chairs',
          'roomSpecific.lightFixtureMetal',
          'roomSpecific.feeling',
          'roomSpecific.darkerBelowOrOneWall',
        ];
      case 'office':
        return [
          'roomSpecific.workMood',
          'roomSpecific.screenGlare',
          'roomSpecific.deeperLibraryWallsOk',
          'roomSpecific.colorBookshelvesOrBuiltIns',
        ];
      case 'kidsRoom':
        return [
          'roomSpecific.mood',
          'roomSpecific.mainFabricToyColors',
          'roomSpecific.superWipeableWalls',
          'roomSpecific.smallColorPopOk',
        ];
      case 'laundryMudroom':
        return [
          'roomSpecific.traffic',
          'roomSpecific.cabinetsShelving',
          'roomSpecific.cabinetsColor',
          'roomSpecific.hideDirtOrBrightClean',
          'roomSpecific.doorColorMomentOk',
        ];
      case 'entryHall':
        return [
          'roomSpecific.naturalLight',
          'roomSpecific.stairsBanister',
          'roomSpecific.woodTone',
          'roomSpecific.paintColor',
          'roomSpecific.feel',
          'roomSpecific.doorColorMoment',
        ];
      case 'other':
        return ['roomSpecific.describeRoom'];
      default:
        return [];
    }
  }

  bool _isVisible(String id) {
    final p = _allPrompts.firstWhere(
      (e) => e.id == id,
      orElse: () => InterviewPrompt(id: id, title: id, type: InterviewPromptType.freeText),
    );

    if (id == 'existingElements.floorLookOtherNote') {
      return _answers['existingElements.floorLook'] == 'other';
    }
    if (id == 'roomSpecific.cabinetsCurrentColor') {
      return _answers['roomSpecific.cabinets'] == 'keepCurrentColor';
    }
    if (id == 'roomSpecific.backsplashDescribe') {
      return _answers['roomSpecific.backsplash'] == 'describe';
    }
    if (id == 'roomSpecific.tileColorWhich') {
      return _answers['roomSpecific.tileMainColor'] == 'color';
    }
    if (id == 'roomSpecific.woodTone') {
      return _answers['roomSpecific.stairsBanister'] == 'wood';
    }
    if (id == 'roomSpecific.paintColor') {
      return _answers['roomSpecific.stairsBanister'] == 'painted';
    }

    if (p.visibleIf != null) return p.visibleIf!(answers);

    return true;
  }

  void next() {
    if (_index < _sequence.length - 1) {
      _index += 1;
      while (_index < _sequence.length && !_isVisible(_sequence[_index])) {
        _index += 1;
      }
      notifyListeners();
    }
  }

  void back() {
    if (_index > 0) {
      _index -= 1;
      notifyListeners();
    }
  }

  /// Accepts a value or list value depending on prompt.
  void setAnswer(String id, dynamic value) {
    if (value is List && value.isEmpty) {
      _answers.remove(id);
    } else {
      _answers[id] = value;
    }

    if (id == 'roomType' || id.startsWith('roomSpecific.') || id.startsWith('existingElements.')) {
      final curId = current?.id;
      _recomputeSequence();
      if (curId != null) {
        final newIdx = _sequence.indexOf(curId);
        _index = newIdx >= 0 ? newIdx : _index.clamp(0, _sequence.length - 1);
      }
    }

    notifyListeners();
  }

  static List<InterviewPrompt> _buildDemoPrompts() {
    final opt = (List<String> vs) =>
        vs.map((v) => InterviewPromptOption(v, _labelize(v))).toList();

    return [
      InterviewPrompt(
        id: 'roomType',
        title: 'Which room are we doing?',
        type: InterviewPromptType.singleSelect,
        required: true,
        options: opt([
          'kitchen',
          'bathroom',
          'bedroom',
          'livingRoom',
          'diningRoom',
          'office',
          'kidsRoom',
          'laundryMudroom',
          'entryHall',
          'other'
        ]),
      ),
      InterviewPrompt(
        id: 'usage',
        title: 'Who uses this room most, and what do you do here? ',
        help: 'e.g., Family of four. We cook daily and hang at the island.',
        type: InterviewPromptType.freeText,
        required: true,
      ),
      InterviewPrompt(
        id: 'moodWords',
        title: 'Pick up to three mood words',
        help: 'calm, cozy, happy, fresh, focused, moody, bright…',
        type: InterviewPromptType.multiSelect,
        isArray: true,
        minItems: 1,
        maxItems: 3,
        options:
            opt(['calm', 'cozy', 'happy', 'fresh', 'focused', 'moody', 'bright']),
        required: true,
      ),
      InterviewPrompt(
        id: 'daytimeBrightness',
        title: 'How bright is it in the day?',
        type: InterviewPromptType.singleSelect,
        options: opt(['veryBright', 'kindaBright', 'dim']),
        required: true,
      ),
      InterviewPrompt(
        id: 'bulbColor',
        title: 'At night, what kind of bulbs?',
        type: InterviewPromptType.singleSelect,
        options: opt(['cozyYellow_2700K', 'neutral_3000_3500K', 'brightWhite_4000KPlus']),
        required: true,
      ),
      InterviewPrompt(
        id: 'boldDarkerSpot',
        title: 'Do you like a bold darker spot in this room?',
        type: InterviewPromptType.singleSelect,
        options: opt(['loveIt', 'maybe', 'noThanks']),
        required: true,
      ),
      InterviewPrompt(
        id: 'brandPreference',
        title: 'Pick one paint brand (or let us choose)',
        type: InterviewPromptType.singleSelect,
        options: opt(['SherwinWilliams', 'BenjaminMoore', 'Behr', 'pickForMe']),
        required: true,
      ),
      // Room-specific prompts are defined via _roomBranch
      InterviewPrompt(
        id: 'existingElements.floorLook',
        title: 'Floors look mostly…',
        type: InterviewPromptType.singleSelect,
        options: opt([
          'yellowGoldWood',
          'orangeWood',
          'redBrownWood',
          'brownNeutral',
          'grayBrown',
          'tileOrStone',
          'other'
        ]),
      ),
      InterviewPrompt(
        id: 'existingElements.floorLookOtherNote',
        title: 'If other, tell us',
        type: InterviewPromptType.freeText,
      ),
      InterviewPrompt(
        id: 'existingElements.bigThingsToMatch',
        title: 'Big things to match (pick all that apply)',
        type: InterviewPromptType.multiSelect,
        isArray: true,
        options: opt([
          'countertops',
          'backsplash',
          'tile',
          'bigFurniture',
          'rug',
          'curtains',
          'builtIns',
          'appliances',
          'fireplace',
          'none'
        ]),
      ),
      InterviewPrompt(
        id: 'existingElements.metals',
        title: 'If metal shows, what is it?',
        type: InterviewPromptType.singleSelect,
        options: opt(['black', 'silver', 'goldWarm', 'mixed', 'none']),
      ),
      InterviewPrompt(
        id: 'existingElements.mustStaySame',
        title: 'Anything that must stay the same color?',
        help: 'e.g., trim stays white; cabinets stay navy',
        type: InterviewPromptType.freeText,
      ),
      InterviewPrompt(
        id: 'colorComfort.overallVibe',
        title: 'Overall vibe for color',
        type: InterviewPromptType.singleSelect,
        options: opt([
          'mostlySoftNeutrals',
          'neutralsPlusGentleColors',
          'confidentColorMoments'
        ]),
      ),
      InterviewPrompt(
        id: 'colorComfort.warmCoolFeel',
        title: 'Warm vs cool feel',
        type: InterviewPromptType.singleSelect,
        options: opt(['warmer', 'cooler', 'inBetween']),
      ),
      InterviewPrompt(
        id: 'colorComfort.contrastLevel',
        title: 'Contrast level',
        type: InterviewPromptType.singleSelect,
        options: opt(['verySoft', 'medium', 'crisp']),
      ),
      InterviewPrompt(
        id: 'colorComfort.popColor',
        title: 'Would you enjoy one small “pop” color?',
        type: InterviewPromptType.singleSelect,
        options: opt(['yes', 'maybe', 'no']),
      ),
      InterviewPrompt(
        id: 'finishes.wallsFinishPriority',
        title: 'Walls — what matters most?',
        type: InterviewPromptType.singleSelect,
        options: opt(['easierToWipeClean', 'softerFlatterLook']),
      ),
      InterviewPrompt(
        id: 'finishes.trimDoorsFinish',
        title: 'Trim/doors finish',
        type: InterviewPromptType.singleSelect,
        options: opt(['aLittleShiny', 'softerShine']),
      ),
      InterviewPrompt(
        id: 'finishes.specialNeeds',
        title: 'Any special needs?',
        type: InterviewPromptType.multiSelect,
        isArray: true,
        options: opt(['kids', 'pets', 'steamyShowers', 'greaseHeavyCooking', 'rentalRules']),
      ),
      InterviewPrompt(
        id: 'guardrails.mustHaves',
        title: 'Must-haves (please include…) ',
        type: InterviewPromptType.multiSelect,
        isArray: true,
        options: const [],
      ),
      InterviewPrompt(
        id: 'guardrails.hardNos',
        title: 'Hard NOs (please avoid…)',
        type: InterviewPromptType.multiSelect,
        isArray: true,
        options: const [],
      ),
      InterviewPrompt(
        id: 'photos',
        title: 'Add 2–3 daytime links and 1 nighttime (optional)',
        type: InterviewPromptType.multiSelect,
        isArray: true,
        options: const [],
      ),
    ];
  }
}

String _labelize(String v) {
  return v
      .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .replaceAll('_', ' ')
      .replaceAll('Plus', '+')
      .replaceAll('kinda', 'kind of')
      .replaceAll('LRV', 'LRV')
      .trim();
}
