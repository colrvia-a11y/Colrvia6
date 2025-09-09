import 'package:color_canvas/firestore/firestore_data_schema.dart';

/// Tracks color history and navigation for individual color strips
class ColorStripHistory {
  final List<Paint> _history = [];
  int _currentIndex = -1;

  /// Gets the current paint in the history
  Paint? get current => _currentIndex >= 0 && _currentIndex < _history.length
      ? _history[_currentIndex]
      : null;

  /// Gets whether we can navigate backwards
  bool get canGoBack => _currentIndex > 0;

  /// Gets whether we can navigate forwards
  bool get canGoForward => _currentIndex < _history.length - 1;

  /// Gets the total number of colors in history
  int get length => _history.length;

  /// Gets whether this is the first color in the strip
  bool get isFirstColor => _currentIndex == 0;

  /// Adds a new paint to the history and makes it current
  void addPaint(Paint paint) {
    // If we're not at the end of history, remove everything after current
    if (_currentIndex < _history.length - 1) {
      _history.removeRange(_currentIndex + 1, _history.length);
    }

    // Add the new paint
    _history.add(paint);
    _currentIndex = _history.length - 1;

    // Limit history size to prevent memory issues
    const maxHistorySize = 50;
    if (_history.length > maxHistorySize) {
      _history.removeAt(0);
      _currentIndex = _history.length - 1;
    }
  }

  /// Navigates backwards in history
  Paint? goBack() {
    if (canGoBack) {
      _currentIndex--;
      return current;
    }
    return null;
  }

  /// Navigates forwards in history
  Paint? goForward() {
    if (canGoForward) {
      _currentIndex++;
      return current;
    }
    return null;
  }

  /// Sets the current paint without affecting history navigation
  /// Used when replacing colors externally
  void setCurrent(Paint paint) {
    if (_currentIndex >= 0 && _currentIndex < _history.length) {
      _history[_currentIndex] = paint;
    } else {
      addPaint(paint);
    }
  }

  /// Clears all history
  void clear() {
    _history.clear();
    _currentIndex = -1;
  }

  /// Gets a preview of the history for debugging
  List<String> getHistoryPreview() {
    return _history.asMap().entries.map((entry) {
      final marker = entry.key == _currentIndex ? '→' : ' ';
      return '$marker ${entry.value.name}';
    }).toList();
  }
}
