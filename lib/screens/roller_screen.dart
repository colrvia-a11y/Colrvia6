import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show compute, kDebugMode;

import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/services/firebase_service.dart';
import 'package:color_canvas/utils/palette_generator.dart';
import 'package:color_canvas/utils/palette_isolate.dart';
import 'package:color_canvas/widgets/paint_column.dart';
import 'package:color_canvas/widgets/refine_sheet.dart';
import 'package:color_canvas/widgets/brand_filter_dialog.dart';
import 'package:color_canvas/widgets/save_palette_panel.dart';
import 'package:color_canvas/utils/color_utils.dart';
import 'package:color_canvas/data/sample_paints.dart';
import 'package:color_canvas/utils/debug_logger.dart';
import 'package:color_canvas/models/color_strip_history.dart';
// REGION: CODEX-ADD analytics-service-import
import 'package:color_canvas/services/analytics_service.dart';
// END REGION: CODEX-ADD analytics-service-import
// REGION: CODEX-ADD user-prefs-import
import 'package:color_canvas/services/user_prefs_service.dart';
// END REGION: CODEX-ADD user-prefs-import
import 'package:color_canvas/utils/palette_transforms.dart' as transforms;
import 'package:color_canvas/utils/lab.dart';
import 'package:color_canvas/services/project_service.dart';
import 'package:color_canvas/services/journey/journey_service.dart';

import 'package:color_canvas/models/fixed_elements.dart';
import 'package:color_canvas/services/accessibility_service.dart';
import 'package:color_canvas/services/fixed_element_service.dart';
import 'package:share_plus/share_plus.dart';

import '../services/roller_progress.dart';
import '../services/create_flow_progress.dart';

// Custom intents for keyboard navigation
class GoToPrevPageIntent extends Intent {
  const GoToPrevPageIntent();
}

class GoToNextPageIntent extends Intent {
  const GoToNextPageIntent();
}

enum ActiveTool { style, sort, adjust, count, save, share, temperature }

abstract class RollerScreenStatePublic extends State<RollerScreen> {
  int getPaletteSize();
  Paint? getPaintAtIndex(int index);
  void replacePaintAtIndex(int index, Paint paint);
  bool canAddNewColor();
  void addPaintToCurrentPalette(Paint paint);
}

class RollerScreen extends StatefulWidget {
  final String? projectId;
  final String? seedPaletteId;
  final List<String>? initialPaintIds;   // NEW
  final List<Paint>? initialPaints;      // NEW

  const RollerScreen({
    super.key,
    this.projectId,
    this.seedPaletteId,
    this.initialPaintIds,
    this.initialPaints,
  });

  @override
  State<RollerScreen> createState() => _RollerScreenState();
}

class _RollerScreenState extends RollerScreenStatePublic {
  List<Paint> _currentPalette = [];
  List<bool> _lockedStates = [];
  List<Paint> _availablePaints = [];
  List<Brand> _availableBrands = [];
  final Map<String, Paint> _paintById = {};
  Set<String> _selectedBrandIds = {};
  HarmonyMode _currentMode = HarmonyMode.neutral;
  bool _isLoading = true;
  bool _diversifyBrands = true;
  int _paletteSize = 5;
  bool _isRolling = false;
  List<FixedElement> _fixedElements = [];
  
  // Enhanced color history tracking for each strip
  final List<ColorStripHistory> _stripHistories = [];
  
  // TikTok-style vertical swipe feed
  final PageController _pageCtrl = PageController();
  final List<List<Paint>> _pages = <List<Paint>>[];
  int _visiblePage = 0;
  
  // Memory management (how many pages to keep in RAM at any time)
  static const int _retainWindow = 80; // tune 60–120 after profiling
  
  // Concurrency guard for page generation
  final Set<int> _generatingPages = <int>{};
  
  // First-time swipe hint
  bool _showSwipeHint = true;
  
  static const int _minPaletteSize = 1;
  
  // Adjust state variables
  double _hueShift = 0.0;  // -45..+45 degrees
  double _satScale = 1.0;  // 0.6..1.4 multiplier
  
  // Rolling request ID to drop stale results
  int _rollRequestId = 0;
  
  // Track original palette order before any LRV sorting (for stable ties)
  final Map<String, int> _originalIndexMap = {};
  
  // Tools dock state
  bool _toolsOpen = false;
  ActiveTool? _activeTool;
  
  // Track if user has manually applied brand filters
  final bool _hasAppliedFilters = false;
  
  // Track scheduled post-frame callbacks to prevent loops
  final Set<int> _scheduledCallbacks = {};

  // Track page generation attempts to prevent infinite loops
  final Map<int, int> _pageGenerationAttempts = {};
  static const int _maxPageGenerationAttempts = 3;

  // Track palette updates within a frame and pending callbacks that mutate it
  bool _paletteUpdatedThisFrame = false;
  final Set<int> _activePaletteCallbacks = {};
  int _nextPaletteCallbackId = 0;
  
  // Debug: Track setState calls to identify infinite loops
  int _setStateCount = 0;
  DateTime? _lastSetStateTime;

  // Throttled setState to prevent infinite loops
  void _safeSetState(VoidCallback callback, {String? details}) {
    if (!mounted) return;
    
    final now = DateTime.now();
    Debug.setState('RollerScreen', '_safeSetState', details: details);
    if (kDebugMode) {
      _setStateCount++;
      if (_lastSetStateTime != null && now.difference(_lastSetStateTime!).inMilliseconds < 16) {
        Debug.warning('RollerScreen', '_safeSetState', 'Rapid setState calls detected - count: $_setStateCount');
        if (_setStateCount > 100) {
          Debug.error('RollerScreen', '_safeSetState', 'Potential infinite setState loop detected! Skipping setState.');
          return;
        }
      }
      _lastSetStateTime = now;
      if (_setStateCount > 50 && now.difference(_lastSetStateTime!).inSeconds >= 1) {
        _setStateCount = 0;
      }
      if (_setStateCount % 50 == 0) {
        Debug.info('RollerScreen', '_safeSetState', 'setState count: $_setStateCount');
      }
    }
    setState(callback);
  }

  void _markPaletteUpdated() {
    _paletteUpdatedThisFrame = true;
    _activePaletteCallbacks.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _paletteUpdatedThisFrame = false;
    });
  }

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.log('journey_step_view', {
      'step_id': JourneyService.instance.state.value?.currentStepId ?? 'roller.build',
    });
    AccessibilityService.instance
        .addListener(() => mounted ? setState(() {}) : null);
    AccessibilityService.instance.load();

    Debug.info('RollerScreen', 'initState', 'Component initializing');
    Debug.info('RollerScreen', 'initState', 'About to load paints');

    _loadPaints();

    if (widget.projectId != null) {
      UserPrefsService.setLastProject(widget.projectId!, 'roller');
      FixedElementService().listElements(widget.projectId!).then((els) {
        if (mounted) {
          setState(() => _fixedElements = els);
        }
      });
    }
  }
  

  void _onStepChanged(int step, int total) {
    CreateFlowProgress.instance.set('roller', step / total);
  }

  @override
  void dispose() {
    CreateFlowProgress.instance.clear('roller');
    RollerProgress.instance.value = 0.0;
    _pageCtrl.dispose();
    super.dispose();
  }

  void _safeJumpToPage(int page) {
    if (!mounted) return;
    if (_pageCtrl.hasClients) {
      _pageCtrl.jumpToPage(page);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageCtrl.hasClients) {
          _pageCtrl.jumpToPage(page);
        }
      });
    }
  }

  // LRV sorter that's stable on ties
  int _byLrvDescThenStable(Paint a, Paint b) {
    final la = a.computedLrv;
    final lb = b.computedLrv;
    final cmp = lb.compareTo(la);
    if (cmp != 0) return cmp;
    final aIndex = _originalIndexMap[a.id] ?? 0;
    final bIndex = _originalIndexMap[b.id] ?? 0;
    return aIndex.compareTo(bIndex);
  }

  // Always run pinned-LRV sort on unlocked subset
  List<Paint> _displayColorsForCurrentMode(List<Paint> base) {
    if (base.isEmpty) return base;

    _originalIndexMap.clear();
    for (int i = 0; i < base.length; i++) {
      _originalIndexMap[base[i].id] = i;
    }

    final result = List<Paint>.from(base);
    final List<int> unlockedIndices = <int>[];
    final List<Paint> unlockedPaints = <Paint>[];

    for (int i = 0; i < base.length; i++) {
      final isLocked = (i < _lockedStates.length) && _lockedStates[i];
      if (!isLocked) {
        unlockedIndices.add(i);
        unlockedPaints.add(base[i]);
      }
    }

    unlockedPaints.sort(_byLrvDescThenStable);

    for (int j = 0; j < unlockedIndices.length; j++) {
      result[unlockedIndices[j]] = unlockedPaints[j];
    }

    return result;
  }

  Future<void> _loadPaints() async {
    List<Paint> paints = [];
    List<Brand> brands = [];
    
    Debug.info('RollerScreen', '_loadPaints', 'Started');

    try {
      paints = await FirebaseService.getAllPaints();
      brands = await FirebaseService.getAllBrands();
      Debug.info('RollerScreen', '_loadPaints', 'Database loaded: ${paints.length} paints, ${brands.length} brands');
      if (paints.isEmpty) {
        Debug.warning('RollerScreen', '_loadPaints', 'No paints in DB; using samples');
        paints = await SamplePaints.getAllPaints();
        brands = await SamplePaints.getSampleBrands();
      }
    } catch (e) {
      Debug.error('RollerScreen', '_loadPaints', 'DB load error: $e; using samples');
      try {
        paints = await SamplePaints.getAllPaints();
        brands = await SamplePaints.getSampleBrands();
      } catch (sampleError) {
        Debug.error('RollerScreen', '_loadPaints', 'Sample load error: $sampleError');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to load paint data. Please try again later.')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
    }
    
    Debug.info('RollerScreen', '_loadPaints', 'Final loaded: ${paints.length} paints, ${brands.length} brands');

    _paintById.clear();
    for (final p in paints) {
      _paintById[p.id] = p;
    }

    setState(() {
      _availablePaints = paints;
      _availableBrands = brands;
      _selectedBrandIds = brands.map((b) => b.id).toSet();
      _lockedStates = List.filled(_paletteSize, false);
      _isLoading = false;
    });
    
    await _maybeSeedFromInitial();
  }

  Future<List<Paint>> _rollPaletteAsync(List<Paint?> anchors, [List<List<double>>? slotLrvHints]) async {
    final available = _getFilteredPaints()
        .map((p) => p.toJson()..['id'] = p.id)
        .toList();

    final anchorMaps = anchors
        .map((p) => p == null ? null : (p.toJson()..['id'] = p.id))
        .toList();

    final args = {
      'available': available,
      'anchors': anchorMaps,
      'modeIndex': _currentMode.index,
      'diversify': _diversifyBrands,
      'slotLrvHints': slotLrvHints,
      'fixedUndertones': _fixedElements.map((e) => e.undertone).toList(),
    };

    final resultMaps = await compute(rollPaletteInIsolate, args);
    return [for (final m in resultMaps) Paint.fromJson(m, m['id'] as String)];
  }

  void _rollPalette() async {
    if (_getFilteredPaints().isEmpty || _isRolling) return;

    HapticFeedback.lightImpact();
    setState(() => _isRolling = true);

    try {
      final anchors = List<Paint?>.filled(_paletteSize, null);
      for (int i = 0; i < _paletteSize && i < _lockedStates.length; i++) {
        if (_lockedStates[i] && i < _currentPalette.length) {
          anchors[i] = _currentPalette[i];
        }
      }

      final int requestId = ++_rollRequestId;
      List<Paint> rolled;
      
      try {
        rolled = await _rollPaletteAsync(anchors);
      } catch (e) {
        Debug.warning('RollerScreen', '_rollPalette', 'Async failed: $e; falling back to sync');
        rolled = PaletteGenerator.rollPalette(
          availablePaints: _getFilteredPaints(),
          anchors: anchors,
          mode: _currentMode,
          diversifyBrands: _diversifyBrands,
          fixedUndertones: _fixedElements.map((e) => e.undertone).toList(),
        );
      }
      
      if (!mounted || requestId != _rollRequestId) return;

      final adjusted = _applyAdjustments(rolled);
      final paletteForDisplay = _displayColorsForCurrentMode(adjusted.take(_paletteSize).toList());

      _safeSetState(() {
        _currentPalette = paletteForDisplay;
        _isRolling = false;
      });

      _ensureStripHistories();
      for (int i = 0; i < _currentPalette.length; i++) {
        final isLocked = i < _lockedStates.length ? _lockedStates[i] : false;
        if (!isLocked) {
          _stripHistories[i].addPaint(_currentPalette[i]);
        }
      }

      if (_visiblePage < _pages.length) {
        _pages[_visiblePage] = List<Paint>.from(_currentPalette);
      } else if (_pages.isEmpty) {
        _pages.add(List<Paint>.from(_currentPalette));
      }
      _markPaletteUpdated();
    } catch (e) {
      Debug.error('RollerScreen', '_rollPalette', 'Error: $e');
      if (mounted) {
        _safeSetState(() => _isRolling = false);
      }
    }
  }

  void _toggleLock(int index) {
    while (_lockedStates.length <= index) {
      _lockedStates.add(false);
    }

    HapticFeedback.selectionClick();

    setState(() {
      _lockedStates[index] = !_lockedStates[index];
      if (_visiblePage < _pages.length) {
        _pages[_visiblePage] = List<Paint>.from(_currentPalette);
      }
      if (_visiblePage < _pages.length - 1) {
        _pages.removeRange(_visiblePage + 1, _pages.length);
      }
    });

    _ensurePage(_visiblePage + 1);
  }

  void _ensureStripHistories() {
    while (_stripHistories.length < _paletteSize) {
      _stripHistories.add(ColorStripHistory());
    }
    if (_stripHistories.length > _paletteSize) {
      _stripHistories.removeRange(_paletteSize, _stripHistories.length);
    }
  }

  void _navigateStripForward(int index) {
    _ensureStripHistories();
    if (index >= _stripHistories.length) return;
    final history = _stripHistories[index];
    if (history.canGoForward) {
      final nextPaint = history.goForward();
      if (nextPaint != null) _updateStripColor(index, nextPaint);
    } else {
      _rollStripe(index);
    }
  }

  void _navigateStripBackward(int index) {
    _ensureStripHistories();
    if (index >= _stripHistories.length) return;
    final history = _stripHistories[index];
    if (history.canGoBack) {
      final prevPaint = history.goBack();
      if (prevPaint != null) _updateStripColor(index, prevPaint);
    } else {
      _rollStripe(index);
    }
  }

  void _updateStripColor(int index, Paint newPaint) {
    if (index >= _currentPalette.length) return;
    setState(() {
      _currentPalette[index] = newPaint;
    });
    if (_visiblePage < _pages.length) {
      _pages[_visiblePage] = List<Paint>.from(_currentPalette);
    }
    _markPaletteUpdated();
  }

  void _rollStripe(int index) {
    while (_lockedStates.length <= index) {
      _lockedStates.add(false);
    }
    if (_lockedStates[index] || _getFilteredPaints().isEmpty || _isRolling) return;
    HapticFeedback.lightImpact();
    setState(() => _isRolling = true);
    try {
      final anchors = List<Paint?>.filled(_paletteSize, null);
      for (int i = 0; i < _paletteSize && i < _currentPalette.length; i++) {
        if (i != index) anchors[i] = _currentPalette[i];
      }
      final rolled = PaletteGenerator.rollPalette(
        availablePaints: _getFilteredPaints(),
        anchors: anchors,
        mode: _currentMode,
        diversifyBrands: _diversifyBrands,
        fixedUndertones: _fixedElements.map((e) => e.undertone).toList(),
      );
      final adjusted = _applyAdjustments(rolled);
      setState(() {
        _currentPalette = adjusted.take(_paletteSize).toList();
        _isRolling = false;
      });
      _ensureStripHistories();
      if (index < _currentPalette.length && index < _stripHistories.length) {
        _stripHistories[index].addPaint(_currentPalette[index]);
      }
      if (_visiblePage < _pages.length) {
        _pages[_visiblePage] = List<Paint>.from(_currentPalette);
      }
      _markPaletteUpdated();
    } catch (e) {
      Debug.error('RollerScreen', '_rollStripe', 'Error: $e');
      if (mounted) setState(() => _isRolling = false);
    }
  }

  void _showRefineSheet(int index) {
    if (index >= _currentPalette.length) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => RefineSheet(
        paint: _currentPalette[index],
        availablePaints: _getFilteredPaints(),
        onPaintSelected: (newPaint) {
          setState(() {
            _currentPalette[index] = newPaint;
          });
          if (_visiblePage < _pages.length) {
            _pages[_visiblePage] = List<Paint>.from(_currentPalette);
          }
          _markPaletteUpdated();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _removeStripe(int index) {
    if (_paletteSize <= _minPaletteSize) return;
    HapticFeedback.lightImpact();
    setState(() {
      _paletteSize--;
      if (index < _currentPalette.length) _currentPalette.removeAt(index);
      if (index < _lockedStates.length) _lockedStates.removeAt(index);
    });
    if (_visiblePage < _pages.length) {
      _pages[_visiblePage] = List<Paint>.from(_currentPalette);
    }
    _markPaletteUpdated();
  }

  Future<void> _maybeSeedFromInitial() async {
    try {
      List<Paint> seeds = [];

      if (widget.initialPaints != null && widget.initialPaints!.isNotEmpty) {
        seeds = widget.initialPaints!;
      } else if (widget.initialPaintIds != null && widget.initialPaintIds!.isNotEmpty) {
        seeds = await FirebaseService.getPaintsByIds(widget.initialPaintIds!);
        final order = <String, int>{};
        for (var i = 0; i < widget.initialPaintIds!.length; i++) {
          order[widget.initialPaintIds![i]] = i;
        }
        seeds.sort((a, b) => (order[a.id] ?? 1 << 30).compareTo(order[b.id] ?? 1 << 30));
      }

      if (seeds.isEmpty) {
        if (_availablePaints.isNotEmpty) {
          _rollPalette();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _currentPalette.isNotEmpty && _pages.isEmpty) {
              _safeSetState(() {
                _pages.add(List<Paint>.from(_currentPalette));
              });
            }
          });
        }
        return;
      }

      final take = seeds.take(_paletteSize).toList();
      final sortedTake = _displayColorsForCurrentMode(take);

      _safeSetState(() {
        _currentPalette = sortedTake;
        _pages
          ..clear()
          ..add(List<Paint>.from(_currentPalette));
        _lockedStates = List<bool>.filled(_currentPalette.length, true);
      });
    } catch (e) {
      Debug.error('RollerScreen', '_maybeSeedFromInitial', 'Error: $e');
      if (_availablePaints.isNotEmpty) {
        _rollPalette();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _currentPalette.isNotEmpty && _pages.isEmpty) {
            _safeSetState(() {
              _pages.add(List<Paint>.from(_currentPalette));
            });
          }
        });
      }
    }
  }

  List<Paint> _getFilteredPaints() {
    if (_availablePaints.isEmpty) {
      Debug.warning('RollerScreen', '_getFilteredPaints', 'Available paints is empty');
      return [];
    }
    if (_selectedBrandIds.isEmpty || _selectedBrandIds.length == _availableBrands.length) {
      return _availablePaints;
    }
    final filtered = _availablePaints.where((p) => _selectedBrandIds.contains(p.brandId)).toList();
    Debug.info('RollerScreen', '_getFilteredPaints', 'Filtered ${_availablePaints.length} -> ${filtered.length}');
    return filtered;
  }
  
  List<Paint> _visiblePaletteSnapshot() {
    if (_visiblePage >= 0 && _visiblePage < _pages.length) {
      return List<Paint>.from(_pages[_visiblePage]);
    }
    return List<Paint>.from(_currentPalette);
  }

  void _closeDock() {
    _safeSetState(() {
      _toolsOpen = false;
      _activeTool = null;
    });
  }

  void _resizeLocksAndPaletteTo(int size) {
    if (_lockedStates.length > size) {
      _lockedStates = _lockedStates.take(size).toList();
    } else if (_lockedStates.length < size) {
      _lockedStates = [
        ..._lockedStates,
        ...List<bool>.filled(size - _lockedStates.length, false),
      ];
    }
    if (_currentPalette.length > size) {
      _currentPalette = _currentPalette.take(size).toList();
    }
    _ensureStripHistories();
  }

  Widget _buildToolPanel(ActiveTool tool) {
    switch (tool) {
      case ActiveTool.style:
        return _StylePanel(
          currentMode: _currentMode,
          diversifyBrands: _diversifyBrands,
          paletteSize: _paletteSize,
          onModeChanged: (mode) {
            _safeSetState(() => _currentMode = mode);
            _resetFeedToPageZero();
          },
          onDiversifyChanged: (value) {
            _safeSetState(() => _diversifyBrands = value);
            _resetFeedToPageZero();
          },
          onPaletteSizeChanged: (size) {
            _safeSetState(() {
              _paletteSize = size.clamp(1, 9);
              _resizeLocksAndPaletteTo(_paletteSize);
            });
            _resetFeedToPageZero();
          },
          onDone: _closeDock,
        );
      case ActiveTool.sort:
        return _BrandFilterPanelHost(
          availableBrands: _availableBrands,
          selectedBrandIds: _selectedBrandIds,
          onBrandsSelected: (brands) {
            _safeSetState(() => _selectedBrandIds = brands);
            _resetFeedToPageZero();
          },
          onDone: _closeDock,
        );
      case ActiveTool.adjust:
        return _AdjustPanelHost(
          hueShift: _hueShift,
          satScale: _satScale,
          onHueChanged: (value) {
            _safeSetState(() => _hueShift = value);
            Future.delayed(const Duration(milliseconds: 150), () {
              if (mounted) _rollPalette();
            });
          },
          onSatChanged: (value) {
            _safeSetState(() => _satScale = value);
            Future.delayed(const Duration(milliseconds: 150), () {
              if (mounted) _rollPalette();
            });
          },
          onReset: () {
            _safeSetState(() {
              _hueShift = 0.0;
              _satScale = 1.0;
            });
            _rollPalette();
          },
          onDone: _closeDock,
        );
      case ActiveTool.count:
        return _CountPanelHost(
          paletteSize: _paletteSize,
          onSizeChanged: (size) {
            _safeSetState(() {
              _paletteSize = size;
              _resizeLocksAndPaletteTo(_paletteSize);
              if (_visiblePage < _pages.length) {
                _pages[_visiblePage] = List<Paint>.from(_currentPalette);
              }
              if (_visiblePage < _pages.length - 1) {
                _pages.removeRange(_visiblePage + 1, _pages.length);
              }
            });
            _resetFeedToPageZero();
          },
          onDone: _closeDock,
        );
      case ActiveTool.save:
        return _SavePanelHost(
          projectId: widget.projectId,
          paints: _visiblePaletteSnapshot(),
          onSaved: _closeDock,
          onCancel: _closeDock,
        );
      case ActiveTool.share:
        return _SharePanelHost(
          onShare: () {
            _shareCurrentPalette();
            _closeDock();
          },
        );
      case ActiveTool.temperature:
        return const SizedBox.shrink();
    }
  }

  Paint _adjustPaint(Paint p, List<Paint> pool) {
    final l = p.lch[0];
    final c = (_satScale * p.lch[1]).clamp(0.0, 150.0);
    final h = (_hueShift + p.lch[2]) % 360.0;
    final targetLab = ColorUtils.lchToLab(l, c, h);
    return ColorUtils.nearestToTargetLab(targetLab, pool) ?? pool.first;
  }

  List<Paint> _applyAdjustments(List<Paint> palette) {
    final pool = _getFilteredPaints();
    if (pool.isEmpty) return palette;
    return [
      for (var i = 0; i < palette.length; i++)
        (_lockedStates.length > i && _lockedStates[i])
            ? palette[i]
            : _adjustPaint(palette[i], pool)
    ];
  }

  @override
  Widget build(BuildContext context) {
    Debug.build('RollerScreen', 'build', details: 'isLoading: $_isLoading, paletteSize: $_paletteSize, pagesCount: ${_pages.length}');
    
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Focus(
                  autofocus: true,
                  child: Shortcuts(
                    shortcuts: {
                      LogicalKeySet(LogicalKeyboardKey.arrowUp): const GoToPrevPageIntent(),
                      LogicalKeySet(LogicalKeyboardKey.arrowDown): const GoToNextPageIntent(),
                    },
                    child: Actions(
                      actions: {
                        GoToPrevPageIntent: CallbackAction<GoToPrevPageIntent>(onInvoke: (_) { _goToPrevPage(); return null; }),
                        GoToNextPageIntent: CallbackAction<GoToNextPageIntent>(onInvoke: (_) { _goToNextPage(); return null; }),
                      },
                      child: PageView.builder(
                        controller: _pageCtrl,
                        scrollDirection: Axis.vertical,
                        onPageChanged: _onPageChanged,
                        itemBuilder: (context, index) {
                          if (index >= _pages.length) {
                            if (!_generatingPages.contains(index) && !_scheduledCallbacks.contains(index)) {
                              _scheduledCallbacks.add(index);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _scheduledCallbacks.remove(index);
                                if (mounted && !_generatingPages.contains(index)) {
                                  _ensurePage(index);
                                }
                              });
                            }
                            return const Center(child: CircularProgressIndicator());
                          }
                          final palette = _pages[index];
                          return _buildPaletteView(palette);
                        },
                      ),
                    ),
                  ),
                ),
                if (_showSwipeHint)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(60),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Swipe ↑ for next palette',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ),
                if (_isRolling)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: Colors.black.withAlpha(10),
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                if (_toolsOpen)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => _safeSetState(() {
                        _toolsOpen = false;
                        _activeTool = null;
                      }),
                      behavior: HitTestBehavior.translucent,
                    ),
                  ),

                Positioned(
                  right: 12,
                  bottom: 24,
                  child: ToolsDock(
                    open: _toolsOpen,
                    activeTool: _activeTool,
                    onToggle: () {
                      HapticFeedback.selectionClick();
                      _safeSetState(() => _toolsOpen = !_toolsOpen);
                    },
                    onSelect: (t) {
                      _safeSetState(() {
                        if (t == null) {
                          _activeTool = null;
                          _toolsOpen = false;
                        } else {
                          _toolsOpen = true;
                          if (_activeTool == ActiveTool.temperature && t == ActiveTool.temperature) {
                          } else {
                            _activeTool = t;
                          }
                        }
                      });
                    },
                    items: [
                      DockItem(tool: ActiveTool.style, icon: Icons.auto_awesome, label: 'Style'),
                      DockItem(tool: ActiveTool.sort, icon: Icons.filter_list, label: 'Sort'),
                      DockItem(tool: ActiveTool.adjust, icon: Icons.tune, label: 'Adjust'),
                      DockItem(tool: ActiveTool.count, icon: Icons.grid_goldenratio, label: 'Count'),
                      DockItem(tool: ActiveTool.save, icon: Icons.bookmark_add_outlined, label: 'Save'),
                      DockItem(tool: ActiveTool.share, icon: Icons.ios_share_outlined, label: 'Share'),
                      DockItem(tool: ActiveTool.temperature, icon: Icons.thermostat, label: 'Temp'),
                    ],
                    panelBuilder: (tool) => _buildToolPanel(tool),
                    onTemperatureAction: (kind) {
                      _applyVariant(kind);
                      AnalyticsService.instance
                          .logEvent('temperature_action', {'kind': kind, 'size': _currentPalette.length});
                    },
                    onTemperatureBack: () {
                      _safeSetState(() {
                        _activeTool = null;
                        _toolsOpen = true;
                      });
                    },
                  ),
                ),
              ],
            ),
    );
  }

  void _resetFeedToPageZero() {
    _safeSetState(() {
      _pages.clear();
      _visiblePage = 0;
    });
    _rollPalette();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _currentPalette.isNotEmpty && _pages.isEmpty) {
        _safeSetState(() {
          _pages.add(List<Paint>.from(_currentPalette));
        });
      }
      _safeJumpToPage(0);
    });
  }

  void _onPageChanged(int i) {
    Debug.info('RollerScreen', '_onPageChanged', 'Page changed from $_visiblePage to $i');
    HapticFeedback.selectionClick();
    if (_visiblePage != i || _showSwipeHint) {
      _safeSetState(() {
        _visiblePage = i;
        _showSwipeHint = false;
        if (i < _pages.length) {
          final pageColors = _pages[i];
          final newPalette = _displayColorsForCurrentMode(pageColors);
          if (_currentPalette.length != newPalette.length || !_palettesEqual(_currentPalette, newPalette)) {
            _currentPalette = newPalette;
          }
        }
        if (_pages.length > 1) {
          _onStepChanged(i, _pages.length - 1);
        }
        RollerProgress.instance.value = (i / (_pages.length - 1)).clamp(0.0, 1.0);
      }, details: 'Page changed from $_visiblePage to $i');
    }
    if (i + 1 >= _pages.length) {
      _ensurePage(i + 1);
    }
  }

  void _applyVariant(String kind) {
    final ids = _currentPalette.map((p) => p.id).toList();
    if (ids.isEmpty) return;

    Lab labOf(String id) {
      final p = _paintById[id];
      if (p == null) return const Lab(0, 0, 0);
      return Lab(p.lab[0], p.lab[1], p.lab[2]);
    }

    String? nearestId(Lab lab) {
      final paints = _getFilteredPaints();
      final nearest = 
          ColorUtils.nearestByDeltaE([lab.l, lab.a, lab.b], paints);
      return nearest?.id;
    }

    List<String> newIds;
    switch (kind) {
      case 'brighter':
        newIds = transforms.brighter(ids, labOf, nearestId);
        break;
      case 'moodier':
        newIds = transforms.moodier(ids, labOf, nearestId);
        break;
      case 'warmer':
        newIds = transforms.warmer(ids, labOf, nearestId);
        break;
      case 'cooler':
        newIds = transforms.cooler(ids, labOf, nearestId);
        break;
      case 'cbFriendly':
        newIds = transforms.cbFriendlyVariant(ids, labOf, nearestId);
        break;
      case 'softer':
      default:
        newIds = transforms.softer(ids, labOf, nearestId);
        break;
    }

    for (int i = 0; i < newIds.length; i++) {
      if (i < _lockedStates.length && _lockedStates[i]) {
        newIds[i] = ids[i];
      } else if (!_paintById.containsKey(newIds[i])) {
        newIds[i] = ids[i];
      }
    }

    final newPalette = <Paint>[];
    for (int i = 0; i < newIds.length; i++) {
      final id = newIds[i];
      newPalette.add(_paintById[id] ?? _currentPalette[i]);
    }

    _ensureStripHistories();
    for (int i = 0; i < newPalette.length; i++) {
      final isLocked = i < _lockedStates.length ? _lockedStates[i] : false;
      if (!isLocked) {
        _stripHistories[i].addPaint(newPalette[i]);
      }
    }

    _safeSetState(() {
      _currentPalette = newPalette;
      if (_visiblePage < _pages.length) {
        _pages[_visiblePage] = List<Paint>.from(_currentPalette);
      }
    });
    _markPaletteUpdated();

    AnalyticsService.instance
        .logEvent('palette_variant_applied', {'kind': kind, 'size': newPalette.length});
    if (kind == 'cbFriendly') {
      AnalyticsService.instance
          .logEvent('cb_variant_applied', {'size': newPalette.length});
    }
    if (widget.projectId != null) {
      ProjectService.addPaletteHistory(widget.projectId!, kind, newIds);
    }
  }

  Future<void> _shareCurrentPalette() async {
    if (_currentPalette.isEmpty) return;

    final text = _currentPalette
        .map((p) => '${p.brandName} ${p.name} (${p.hex})')
        .join('\n');

    await SharePlus.instance.share(
      ShareParams(text: 'My Color Palette:\n$text', subject: 'My Color Palette'),
    );
  }

  bool _palettesEqual(List<Paint> a, List<Paint> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  void _goToPrevPage() {
    if (_visiblePage > 0) {
      _pageCtrl.previousPage(duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  void _goToNextPage() {
    _ensurePage(_visiblePage + 1);
    _pageCtrl.nextPage(duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  Widget _buildPaletteView(List<Paint> palette) {
    return Column(
      children: List.generate(_paletteSize, (i) {
        final paint = i < palette.length ? palette[i] : null;
        final isLocked = i < _lockedStates.length ? _lockedStates[i] : false;
        return Expanded(
          child: AnimatedPaintStripe(
            key: ValueKey(paint?.id ?? 'empty_$i'),
            paint: paint,
            previousPaint: null,
            isLocked: isLocked,
            isRolling: _isRolling,
            onTap: () => _toggleLock(i),
            onSwipeRight: () => _navigateStripForward(i),
            onSwipeLeft: () => _navigateStripBackward(i),
            onRefine: () => _showRefineSheet(i),
            onDelete: _paletteSize > 2 ? () => _removeStripe(i) : null,
          ),
        );
      }),
    );
  }

  Future<void> _ensurePage(int pageIndex) async {
    Debug.info('RollerScreen', '_ensurePage', 'Ensuring page $pageIndex (current pages: ${_pages.length})');
    if (pageIndex < 0) return;
    final attempts = _pageGenerationAttempts[pageIndex] ?? 0;
    if (attempts >= _maxPageGenerationAttempts) {
      Debug.error('RollerScreen', '_ensurePage', 'Too many attempts for page $pageIndex ($attempts). Aborting.');
      return;
    }
    _pageGenerationAttempts[pageIndex] = attempts + 1;

    final filtered = _getFilteredPaints();
    if (filtered.isEmpty) {
      Debug.warning('RollerScreen', '_ensurePage', 'No paints available after filtering');
      Debug.warning('RollerScreen', '_ensurePage', 'Available paints: ${_availablePaints.length}, Selected brands: ${_selectedBrandIds.length}');
      if (_hasAppliedFilters && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No paints match your filters.')),
            );
          }
        });
      }
      return;
    }

    if (pageIndex < _pages.length) {
      final existingPage = _pages[pageIndex];
      final sortedPage = _displayColorsForCurrentMode(existingPage);
      if (pageIndex == _visiblePage &&
          !_paletteUpdatedThisFrame &&
          !_palettesEqual(_currentPalette, sortedPage)) {
        Debug.postFrameCallback('RollerScreen', '_ensurePage', details: 'Updating existing page $pageIndex');
        final callbackId = ++_nextPaletteCallbackId;
        _activePaletteCallbacks.add(callbackId);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_activePaletteCallbacks.remove(callbackId)) return;
          if (mounted) {
            _safeSetState(() => _currentPalette = sortedPage, details: 'Updated existing page $pageIndex');
            _markPaletteUpdated();
          }
        });
      }
      return;
    }

    if (_generatingPages.contains(pageIndex) || _isRolling) {
      Debug.info('RollerScreen', '_ensurePage', 'Page $pageIndex already generating or rolling');
      return;
    }
    _generatingPages.add(pageIndex);
    Debug.info('RollerScreen', '_ensurePage', 'Generating page $pageIndex');

    try {
      if (_visiblePage < _pages.length) {
        _pages[_visiblePage] = List<Paint>.from(_currentPalette);
      }

      final List<Paint> base = (_visiblePage < _pages.length)
          ? List<Paint>.from(_pages[_visiblePage])
          : List<Paint>.from(_currentPalette);

      final anchors = List<Paint?>.generate(_paletteSize, (i) {
        final locked = i < _lockedStates.length && _lockedStates[i];
        return (locked && i < base.length) ? base[i] : null;
      });

      final rolled = await _rollPaletteAsync(anchors);
      final adjusted = _applyAdjustments(rolled);
      final newPage = _displayColorsForCurrentMode(adjusted.take(_paletteSize).toList());

      if (!mounted) return;
      Debug.postFrameCallback('RollerScreen', '_ensurePage', details: 'Adding generated page $pageIndex');
      final needsPaletteUpdate =
          pageIndex == _visiblePage && !_paletteUpdatedThisFrame && !_palettesEqual(_currentPalette, newPage);
      int? callbackId;
      if (needsPaletteUpdate) {
        callbackId = ++_nextPaletteCallbackId;
        _activePaletteCallbacks.add(callbackId);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (callbackId != null && !_activePaletteCallbacks.remove(callbackId)) return;
        if (!mounted) return;
        _safeSetState(() {
          if (pageIndex == _pages.length) {
            _pages.add(newPage);
          } else if (pageIndex < _pages.length) {
            _pages[pageIndex] = newPage;
          }
          if (needsPaletteUpdate) {
            _currentPalette = List<Paint>.from(newPage);
            _markPaletteUpdated();
          }
        }, details: 'Generated and added page $pageIndex');
      });
      _pageGenerationAttempts.remove(pageIndex);

      if (_pages.length > _retainWindow && _visiblePage > 10) {
        final keepFrom = (_visiblePage - 25).clamp(0, _pages.length - 1);
        if (keepFrom > 0) {
          _pages.removeRange(0, keepFrom);
          _visiblePage -= keepFrom;
          _safeJumpToPage(_visiblePage);
        }
      }
    } catch (e) {
      Debug.error('RollerScreen', '_ensurePage', 'Error generating page $pageIndex: $e');
    } finally {
      _generatingPages.remove(pageIndex);
      Debug.info('RollerScreen', '_ensurePage', 'Finished page $pageIndex');
    }
  }

  @override
  int getPaletteSize() => _paletteSize;

  @override
  Paint? getPaintAtIndex(int index) {
    if (index >= 0 && index < _currentPalette.length) {
      return _currentPalette[index];
    }
    return null;
  }

  @override
  void replacePaintAtIndex(int index, Paint paint) {
    if (index >= 0 && index < _currentPalette.length) {
      setState(() {
        _currentPalette[index] = paint;
      });
      if (_visiblePage < _pages.length) {
        _pages[_visiblePage] = List<Paint>.from(_currentPalette);
      }
      _markPaletteUpdated();
    }
  }

  @override
  bool canAddNewColor() {
    return _paletteSize < 9;
  }

  @override
  void addPaintToCurrentPalette(Paint paint) {
    if (!canAddNewColor()) return;
    _safeSetState(() {
      _paletteSize++;
      _currentPalette.add(paint);
      _lockedStates.add(false);
      if (_visiblePage < _pages.length) {
        _pages[_visiblePage] = List<Paint>.from(_currentPalette);
      }
    }, details: 'Added new paint: ${paint.name}, new palette size: $_paletteSize');
    _markPaletteUpdated();
  }
}

class _StyleOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  
  const _StyleOptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: selected ? Theme.of(context).colorScheme.onPrimaryContainer : null,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: selected
                            ? Theme.of(context).colorScheme.onPrimaryContainer.withAlpha((255 * 0.7).round())
                            : Theme.of(context).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DockItem {
  final ActiveTool tool;
  final IconData icon;
  final String label;
  DockItem({required this.tool, required this.icon, required this.label});
}

class ToolsDock extends StatefulWidget {
  final bool open;
  final ActiveTool? activeTool;
  final VoidCallback onToggle;
  final Function(ActiveTool?) onSelect;
  final List<DockItem> items;
  final Widget Function(ActiveTool) panelBuilder;

  final ValueChanged<String>? onTemperatureAction;
  final VoidCallback? onTemperatureBack;

  const ToolsDock({
    super.key,
    required this.open,
    required this.activeTool,
    required this.onToggle,
    required this.onSelect,
    required this.items,
    required this.panelBuilder,
    this.onTemperatureAction,
    this.onTemperatureBack,
  });

  @override
  State<ToolsDock> createState() => _ToolsDockState();
}

class _ToolsDockState extends State<ToolsDock> with TickerProviderStateMixin {
  late AnimationController _dockController;
  late AnimationController _panelController;
  late Animation<double> _panelProgress;
  final double _dockWidthPx = 72.0;

  @override
  void initState() {
    super.initState();
    final reduce = AccessibilityService.instance.reduceMotion;
    _dockController = AnimationController(
      duration: Duration(milliseconds: reduce ? 0 : 220),
      vsync: this,
    );
    _panelController = AnimationController(
      duration: Duration(milliseconds: reduce ? 0 : 220),
      vsync: this,
    );
    _panelProgress = CurvedAnimation(
      parent: _panelController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(ToolsDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != oldWidget.open) {
      if (widget.open) {
        _dockController.forward();
      } else {
        _dockController.reverse();
        _panelController.reverse();
      }
    }
    if (widget.activeTool != oldWidget.activeTool) {
      if (widget.activeTool != null && widget.activeTool != ActiveTool.temperature) {
        _panelController.forward();
      } else {
        _panelController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _dockController.dispose();
    _panelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedBuilder(
          animation: _panelProgress,
          builder: (context, child) {
            final size = MediaQuery.of(context).size;

            const double rightMargin = 12.0;
            const double gapBetween = 12.0;
            final double available = size.width - rightMargin - gapBetween - _dockWidthPx;
            final double targetWidth = available <= 0 ? 0 : available.clamp(0.0, 320.0);
            final double panelWidth = _panelProgress.value * targetWidth;
            if (panelWidth <= 1) return const SizedBox.shrink();

            final panelHeight = (size.height * 0.8).clamp(200.0, size.height);
            // Avoid building complex panel content until there is enough width to lay out
            // tiles with trailing controls (e.g., Switch) without ListTile assertions.
            const double minContentWidth = 220.0;
            return Container(
              width: panelWidth,
              height: panelHeight,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: (widget.activeTool != null && widget.activeTool != ActiveTool.temperature && panelWidth >= minContentWidth)
                  ? widget.panelBuilder(widget.activeTool!)
                  : null,
            );
          },
        ),
        
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: !widget.open
              ? _ToolsCollapsed(
                  key: const ValueKey('collapsed'),
                  onTap: widget.onToggle,
                  onMeasured: null,
                )
              : (widget.activeTool == ActiveTool.temperature
                  ? _TemperatureRail(
                      key: const ValueKey('tempRail'),
                      width: _dockWidthPx,
                      onAction: widget.onTemperatureAction,
                      onBack: widget.onTemperatureBack,
                    )
                  : _RailItem(
                      key: const ValueKey('expanded'),
                      items: widget.items,
                      activeTool: widget.activeTool,
                      onSelect: (t) {
                        if (t == null && widget.activeTool == ActiveTool.temperature) {
                          return;
                        }
                        widget.onSelect(t);
                      },
                      onMeasured: null,
                    )),
        ),
      ],
    );
  }
}

class _ToolsCollapsed extends StatelessWidget {
  final VoidCallback onTap;
  final ValueChanged<double>? onMeasured;
  const _ToolsCollapsed({super.key, required this.onTap, this.onMeasured});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const StadiumBorder(),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, color: Colors.black, size: 20),
              SizedBox(width: 8),
              Text('Tools', style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final List<DockItem> items;
  final ActiveTool? activeTool;
  final Function(ActiveTool?) onSelect;
  final ValueChanged<double>? onMeasured;

  const _RailItem({
    super.key,
    required this.items,
    required this.activeTool,
    required this.onSelect,
    this.onMeasured,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const StadiumBorder(),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: items.map((item) => _buildRailButton(item)).toList(),
        ),
      ),
    );
  }

  Widget _buildRailButton(DockItem item) {
    final isActive = activeTool == item.tool;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          if (item.tool == ActiveTool.temperature) {
            onSelect(item.tool);
          } else {
            onSelect(isActive ? null : item.tool);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: isActive
              ? BoxDecoration(
                  color: Colors.black.withAlpha(5),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: Column(
            children: [
              Icon(item.icon, color: Colors.black, size: 22),
              const SizedBox(height: 4),
              Text(item.label, style: const TextStyle(color: Colors.black, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemperatureRail extends StatelessWidget {
  final double width;
  final ValueChanged<String>? onAction;
  final VoidCallback? onBack;

  const _TemperatureRail({
    super.key,
    required this.width,
    required this.onAction,
    required this.onBack,
  });

  Widget _btn(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Tooltip(
        message: label,
        waitDuration: const Duration(milliseconds: 300),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              children: [
                Icon(icon, color: Colors.black, size: 22),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(color: Colors.black, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(BuildContext context, {required IconData icon, required String label, required String kind}) {
    return _btn(context, icon: icon, label: label, onTap: () => onAction?.call(kind));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const StadiumBorder(),
      elevation: 6,
      child: ConstrainedBox(
        constraints: BoxConstraints.tightFor(width: width),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _btn(
                context,
                icon: Icons.arrow_back_ios_new_rounded,
                label: 'Back',
                onTap: onBack ?? () {},
              ),
              _actionBtn(context, icon: Icons.tonality,               label: 'Softer',   kind: 'softer'),
              _actionBtn(context, icon: Icons.brightness_5,           label: 'Brighter', kind: 'brighter'),
              _actionBtn(context, icon: Icons.dark_mode_outlined,     label: 'Moodier',  kind: 'moodier'),
              _actionBtn(context, icon: Icons.local_fire_department,  label: 'Warmer',   kind: 'warmer'),
              _actionBtn(context, icon: Icons.ac_unit,                label: 'Cooler',   kind: 'cooler'),
            ],
          ),
        ),
      ),
    );
  }
}

class _StylePanel extends StatelessWidget {
  final HarmonyMode currentMode;
  final bool diversifyBrands;
  final int paletteSize;
  final Function(HarmonyMode) onModeChanged;
  final Function(bool) onDiversifyChanged;
  final Function(int) onPaletteSizeChanged;
  final VoidCallback onDone;

  const _StylePanel({
    required this.currentMode,
    required this.diversifyBrands,
    required this.paletteSize,
    required this.onModeChanged,
    required this.onDiversifyChanged,
    required this.onPaletteSizeChanged,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Harmony Style', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          
          _StyleOptionTile(
            title: 'Designer',
            subtitle: 'Curated combinations',
            selected: currentMode == HarmonyMode.designer,
            onTap: () => onModeChanged(HarmonyMode.designer),
          ),
          _StyleOptionTile(
            title: 'Neutral',
            subtitle: 'Muted & balanced tones',
            selected: currentMode == HarmonyMode.neutral,
            onTap: () => onModeChanged(HarmonyMode.neutral),
          ),
          _StyleOptionTile(
            title: 'Analogous',
            subtitle: 'Similar hue neighbors',
            selected: currentMode == HarmonyMode.analogous,
            onTap: () => onModeChanged(HarmonyMode.analogous),
          ),
          _StyleOptionTile(
            title: 'Complementary',
            subtitle: 'Opposite color wheel',
            selected: currentMode == HarmonyMode.complementary,
            onTap: () => onModeChanged(HarmonyMode.complementary),
          ),
          _StyleOptionTile(
            title: 'Triad',
            subtitle: 'Three evenly spaced',
            selected: currentMode == HarmonyMode.triad,
            onTap: () => onModeChanged(HarmonyMode.triad),
          ),
          
          if (currentMode == HarmonyMode.designer) ...[
            const SizedBox(height: 24),
            Text('Palette Size', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Choose the number of colors (1–9)', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(9, (i) {
                final size = i + 1;
                final isSelected = paletteSize == size;
                return FilterChip(
                  label: Text(size.toString()),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) onPaletteSizeChanged(size);
                  },
                );
              }),
            ),
          ],
          
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Diversify brands'),
                      const SizedBox(height: 2),
                      Text(
                        'Mix different paint brands',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: diversifyBrands,
                  onChanged: onDiversifyChanged,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onDone,
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandFilterPanelHost extends StatelessWidget {
  final List<Brand> availableBrands;
  final Set<String> selectedBrandIds;
  final Function(Set<String>) onBrandsSelected;
  final VoidCallback onDone;

  const _BrandFilterPanelHost({
    required this.availableBrands,
    required this.selectedBrandIds,
    required this.onBrandsSelected,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return BrandFilterPanel(
      availableBrands: availableBrands,
      selectedBrandIds: selectedBrandIds,
      onBrandsSelected: onBrandsSelected,
      onDone: onDone,
    );
  }
}

class _AdjustPanelHost extends StatelessWidget {
  final double hueShift;
  final double satScale;
  final Function(double) onHueChanged;
  final Function(double) onSatChanged;
  final VoidCallback onReset;
  final VoidCallback onDone;

  const _AdjustPanelHost({
    required this.hueShift,
    required this.satScale,
    required this.onHueChanged,
    required this.onSatChanged,
    required this.onReset,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Adjust Colors', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text('Hue Shift: ${hueShift.round()}°'),
          Slider(
            value: hueShift,
            min: -45,
            max: 45,
            divisions: 90,
            onChanged: onHueChanged,
          ),
          const SizedBox(height: 8),
          Text('Saturation: ${(satScale * 100).round()}%'),
          Slider(
            value: satScale,
            min: 0.6,
            max: 1.4,
            divisions: 40,
            onChanged: onSatChanged,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReset,
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: onDone,
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountPanelHost extends StatelessWidget {
  final int paletteSize;
  final Function(int) onSizeChanged;
  final VoidCallback onDone;

  const _CountPanelHost({
    required this.paletteSize,
    required this.onSizeChanged,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Palette Size', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: List.generate(9, (i) {
              final size = i + 1;
              return ChoiceChip(
                label: Text('$size'),
                selected: paletteSize == size,
                onSelected: (_) {
                  onSizeChanged(size);
                  onDone();
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _SharePanelHost extends StatelessWidget {
  final VoidCallback onShare;

  const _SharePanelHost({required this.onShare});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text('Share Palette', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.share),
              label: const Text('Share Now'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavePanelHost extends StatelessWidget {
  final String? projectId;
  final List<Paint> paints;
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  const _SavePanelHost({
    this.projectId,
    required this.paints,
    required this.onSaved,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (paints.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.palette_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Roll a palette first.', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
    }
    
    return SavePalettePanel(
      projectId: projectId,
      paints: paints,
      onSaved: onSaved,
      onCancel: onCancel,
    );
  }
}
