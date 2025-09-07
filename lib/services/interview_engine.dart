// lib/services/interview_engine.dart
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Input types we render in chat UI.
enum InterviewPromptType { singleSelect, multiSelect, freeText, yesNo }

enum InterviewDepth { quick, full }

@immutable
class InterviewPromptOption {
  final String value; // canonical value stored in answers
  final String label; // human label shown to user
  const InterviewPromptOption(this.value, this.label);
}

@immutable
class InterviewPrompt {
  final String id; // e.g. "roomType" or "existingElements.floorLook"
  final String title;
  final String? help;
  final InterviewPromptType type;
  final bool required;
  final List<InterviewPromptOption> options; // for selects
  final int? minItems;
  final int? maxItems;
  final bool isArray; // if the answer is a list
  final String? dependsOn; // optional parent id for visibility
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

class InterviewEngine extends ChangeNotifier {
  InterviewEngine._(this._allPrompts);
  factory InterviewEngine.fromPrompts(List<InterviewPrompt> prompts) => InterviewEngine._(prompts);
  static InterviewEngine demo() => InterviewEngine._(_buildDemoPrompts());

  final List<InterviewPrompt> _allPrompts;
  final List<String> _sequence = [];
  final Map<String, dynamic> _answers = {};
  int _index = 0;

  InterviewDepth _depth = InterviewDepth.quick;

  UnmodifiableMapView<String, dynamic> get answers => UnmodifiableMapView(_answers);
  int get index => _index;
  int get total => _sequence.length;
  double get progress => total == 0 ? 0 : (_index / total).clamp(0, 1);
  InterviewDepth get depth => _depth;

  InterviewPrompt? get current => (_index >= 0 && _index < _sequence.length)
      ? _allPrompts.firstWhere((p) => p.id == _sequence[_index])
      : null;

  List<InterviewPrompt> get visiblePrompts => _sequence
      .where((id) => _isVisible(id))
      .map((id) => _allPrompts.firstWhere(
            (p) => p.id == id,
            orElse: () => InterviewPrompt(
                id: id,
                title: id,
                type: InterviewPromptType.freeText),
          ))
      .toList();

  InterviewPrompt? byId(String id) {
    try {
      return _allPrompts.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  int indexOf(String id) => _sequence.indexOf(id);

  void jumpTo(String id) {
    final idx = indexOf(id);
    if (idx >= 0) {
      _index = idx;
      notifyListeners();
    }
  }

  bool isPromptVisible(String id) => _isVisible(id);

  void setDepth(InterviewDepth d) {
    _depth = d;
    _recomputeSequence();
    _index = _firstUnansweredIndex();
    notifyListeners();
  }

  void start({Map<String, dynamic>? seedAnswers, InterviewDepth depth = InterviewDepth.quick}) {
    _answers.clear();
    if (seedAnswers != null) _answers.addAll(seedAnswers);
    _depth = depth;
    _recomputeSequence();
    _index = _firstUnansweredIndex();
    notifyListeners();
  }

  void next() {
    if (_index < _sequence.length - 1) {
      _index += 1;
      while (_index < _sequence.length && !_isVisible(_sequence[_index])) {
        _index += 1; // fast-forward hidden prompts
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

  void setAnswer(String id, dynamic value) {
    if (value == null) {
      _answers.remove(id);
    } else if (value is List && value.isEmpty) {
      _answers.remove(id);
    } else {
      _answers[id] = value;
    }

    // Recompute order when branching inputs change
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

  /// Explicitly clear an answer (used by "Prefer not to answer").
  void clearAnswer(String id) {
    _answers.remove(id);
    notifyListeners();
  }

  // ---- internals ----

  int _firstUnansweredIndex() {
    for (var i = 0; i < _sequence.length; i++) {
      final key = _sequence[i];
      if (!_answers.containsKey(key)) return i;
      final val = _answers[key];
      if (val is String && val.trim().isEmpty) return i;
      if (val is List && val.isEmpty) return i;
    }
    return 0;
  }

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
        return [
          'roomSpecific.describeRoom',
        ];
      default:
        return [];
    }
  }

  bool _isVisible(String id) {
    final p = _allPrompts.firstWhere(
      (e) => e.id == id,
      orElse: () => InterviewPrompt(id: id, title: id, type: InterviewPromptType.freeText),
    );

    // conditional rules per schema
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

  // ---- prompts ----

  static List<InterviewPrompt> _buildDemoPrompts() {
    List<InterviewPromptOption> opt(List<String> vs) => vs.map((v) => InterviewPromptOption(v, _labelize(v))).toList();

    return [
      InterviewPrompt(
        id: 'roomType',
        title: 'Which room are we doing?',
        type: InterviewPromptType.singleSelect,
        required: true,
        options: opt(['kitchen','bathroom','bedroom','livingRoom','diningRoom','office','kidsRoom','laundryMudroom','entryHall','other']),
      ),
      InterviewPrompt(
        id: 'usage',
        title: 'Who uses this room most, and what do you do here?',
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
        options: opt(['calm','cozy','happy','fresh','focused','moody','bright']),
        required: true,
      ),
      InterviewPrompt(
        id: 'daytimeBrightness',
        title: 'How bright is it in the day?',
        type: InterviewPromptType.singleSelect,
        options: opt(['veryBright','kindaBright','dim']),
        required: true,
      ),
      InterviewPrompt(
        id: 'bulbColor',
        title: 'At night, what kind of bulbs?',
        type: InterviewPromptType.singleSelect,
        options: opt(['cozyYellow_2700K','neutral_3000_3500K','brightWhite_4000KPlus']),
        required: true,
      ),
      InterviewPrompt(
        id: 'boldDarkerSpot',
        title: 'Do you like a bold darker spot in this room?',
        type: InterviewPromptType.singleSelect,
        options: opt(['loveIt','maybe','noThanks']),
        required: true,
      ),
      InterviewPrompt(
        id: 'brandPreference',
        title: 'Pick one paint brand (or let us choose)',
        type: InterviewPromptType.singleSelect,
        options: opt(['SherwinWilliams','BenjaminMoore','Behr','pickForMe']),
        required: true,
      ),

      // ---- room-specific blocks (kitchen shown; others through visibility/branching) ----
      InterviewPrompt(
        id: 'roomSpecific.cabinets',
        title: 'Kitchen cabinets',
        type: InterviewPromptType.singleSelect,
        options: opt(['allNewColor','keepCurrentColor']),
      ),
      InterviewPrompt(
        id: 'roomSpecific.cabinetsCurrentColor',
        title: 'If keeping, what color are the cabinets now?',
        type: InterviewPromptType.freeText,
      ),
      InterviewPrompt(
        id: 'roomSpecific.island',
        title: 'Island',
        type: InterviewPromptType.singleSelect,
        options: opt(['noIsland','hasIsland_okDarker','hasIsland_keepLight']),
      ),
      InterviewPrompt(
        id: 'roomSpecific.countertopsDescription',
        title: 'Countertops look like…',
        help: 'plain white, creamy, speckled, gray veins, warm stone',
        type: InterviewPromptType.freeText,
      ),
      InterviewPrompt(
        id: 'roomSpecific.backsplash',
        title: 'Backsplash',
        type: InterviewPromptType.singleSelect,
        options: opt(['white','cream','color','pattern','none','describe']),
      ),
      InterviewPrompt(
        id: 'roomSpecific.backsplashDescribe',
        title: 'Tell us more about the backsplash',
        type: InterviewPromptType.freeText,
      ),
      InterviewPrompt(
        id: 'roomSpecific.appliances',
        title: 'Appliances',
        type: InterviewPromptType.singleSelect,
        options: opt(['stainless','black','white','mixed']),
      ),
      InterviewPrompt(
        id: 'roomSpecific.wallFeel',
        title: 'Walls should feel…',
        type: InterviewPromptType.singleSelect,
        options: opt(['lightAiry','aBitCozier']),
      ),
      InterviewPrompt(
        id: 'roomSpecific.darkerSpots',
        title: 'Good spots for a darker moment',
        type: InterviewPromptType.multiSelect,
        isArray: true,
        options: opt(['island','lowerCabinets','doors','none']),
      ),

      // Existing Elements
      InterviewPrompt(
        id: 'existingElements.floorLook',
        title: 'Floors look mostly…',
        type: InterviewPromptType.singleSelect,
        options: opt(['yellowGoldWood','orangeWood','redBrownWood','brownNeutral','grayBrown','tileOrStone','other']),
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
        options: opt(['countertops','backsplash','tile','bigFurniture','rug','curtains','builtIns','appliances','fireplace','none']),
      ),
      InterviewPrompt(
        id: 'existingElements.metals',
        title: 'If metal shows, what is it?',
        type: InterviewPromptType.singleSelect,
        options: opt(['black','silver','goldWarm','mixed','none']),
      ),
      InterviewPrompt(
        id: 'existingElements.mustStaySame',
        title: 'Anything that must stay the same color?',
        help: 'e.g., trim stays white; cabinets stay navy',
        type: InterviewPromptType.freeText,
      ),

      // Color Comfort
      InterviewPrompt(
        id: 'colorComfort.overallVibe',
        title: 'Overall vibe for color',
        type: InterviewPromptType.singleSelect,
        options: opt(['mostlySoftNeutrals', 'neutralsPlusGentleColors', 'confidentColorMoments']),
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
        options: opt(['verySoft','medium','crisp']),
      ),
      InterviewPrompt(
        id: 'colorComfort.popColor',
        title: 'Would you enjoy one small “pop” color?',
        type: InterviewPromptType.singleSelect,
        options: opt(['yes','maybe','no']),
      ),

      // Finishes
      InterviewPrompt(
        id: 'finishes.wallsFinishPriority',
        title: 'Walls — what matters most?',
        type: InterviewPromptType.singleSelect,
        options: opt(['easierToWipeClean','softerFlatterLook']),
      ),
      InterviewPrompt(
        id: 'finishes.trimDoorsFinish',
        title: 'Trim/doors finish',
        type: InterviewPromptType.singleSelect,
        options: opt(['aLittleShiny','softerShine']),
      ),
      InterviewPrompt(
        id: 'finishes.specialNeeds',
        title: 'Any special needs?',
        type: InterviewPromptType.multiSelect,
        isArray: true,
        options: opt(['kids','pets','steamyShowers','greaseHeavyCooking','rentalRules']),
      ),

      // Guardrails + Photos
      InterviewPrompt(
        id: 'guardrails.mustHaves',
        title: 'Must-haves (please include…) ',
        type: InterviewPromptType.multiSelect,
        isArray: true,
        options: const [], // free-form list via chips in UI
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
      .trim();
}
