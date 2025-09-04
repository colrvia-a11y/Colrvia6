import 'package:flutter_test/flutter_test.dart';
import 'package:color_canvas/models/color_strip_history.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';

void main() {
  group('ColorStripHistory Tests', () {
    late ColorStripHistory history;
    late Paint testPaint1;
    late Paint testPaint2;
    late Paint testPaint3;

    setUp(() {
      testPaint1 = Paint(
        id: 'test1',
        brandId: 'brand1',
        name: 'Test Paint 1',
        brandName: 'Test Brand',
        code: 'T001',
        hex: '#FF0000',
        rgb: [255, 0, 0],
        lab: [50.0, 70.0, 60.0],
        lch: [50.0, 90.0, 30.0],
      );

      testPaint2 = Paint(
        id: 'test2',
        brandId: 'brand2',
        name: 'Test Paint 2',
        brandName: 'Test Brand',
        code: 'T002',
        hex: '#00FF00',
        rgb: [0, 255, 0],
        lab: [85.0, -80.0, 80.0],
        lch: [85.0, 110.0, 135.0],
      );

      testPaint3 = Paint(
        id: 'test3',
        brandId: 'brand3',
        name: 'Test Paint 3',
        brandName: 'Test Brand',
        code: 'T003',
        hex: '#0000FF',
        rgb: [0, 0, 255],
        lab: [30.0, 70.0, -110.0],
        lch: [30.0, 130.0, 300.0],
      );

      history = ColorStripHistory();
    });

    test('should start empty', () {
      expect(history.current, isNull);
      expect(history.length, equals(0));
      expect(history.canGoBack, isFalse);
      expect(history.canGoForward, isFalse);
      expect(history.isFirstColor, isFalse);
    });

    test('should add paints correctly', () {
      history.addPaint(testPaint1);
      
      expect(history.current, equals(testPaint1));
      expect(history.length, equals(1));
      expect(history.canGoBack, isFalse);
      expect(history.canGoForward, isFalse);
      expect(history.isFirstColor, isTrue);
    });

    test('should navigate through history correctly', () {
      // Add multiple paints
      history.addPaint(testPaint1);
      history.addPaint(testPaint2);
      history.addPaint(testPaint3);
      
      expect(history.current, equals(testPaint3));
      expect(history.length, equals(3));
      expect(history.canGoBack, isTrue);
      expect(history.canGoForward, isFalse);
      
      // Navigate backward
      final prev = history.goBack();
      expect(prev, equals(testPaint2));
      expect(history.current, equals(testPaint2));
      expect(history.canGoBack, isTrue);
      expect(history.canGoForward, isTrue);
      
      // Navigate further back
      final first = history.goBack();
      expect(first, equals(testPaint1));
      expect(history.current, equals(testPaint1));
      expect(history.canGoBack, isFalse);
      expect(history.canGoForward, isTrue);
      expect(history.isFirstColor, isTrue);
      
      // Navigate forward
      final next = history.goForward();
      expect(next, equals(testPaint2));
      expect(history.current, equals(testPaint2));
    });

    test('should handle branching history correctly', () {
      // Create initial history
      history.addPaint(testPaint1);
      history.addPaint(testPaint2);
      
      // Go back and add new paint (should truncate future history)
      history.goBack();
      history.addPaint(testPaint3);
      
      expect(history.current, equals(testPaint3));
      expect(history.length, equals(2)); // Should have truncated
      expect(history.canGoForward, isFalse);
    });

    test('should respect history size limit', () {
      // Add more than the limit (50 colors)
      for (int i = 0; i < 55; i++) {
        final paint = Paint(
          id: 'test$i',
          brandId: 'brand$i',
          name: 'Test Paint $i',
          brandName: 'Test Brand',
          code: 'T$i',
          hex: '#FF0000',
          rgb: [255, 0, 0],
          lab: [50.0, 70.0, 60.0],
          lch: [50.0, 90.0, 30.0],
        );
        history.addPaint(paint);
      }
      
      expect(history.length, equals(50)); // Should be limited to 50
      expect(history.current?.name, equals('Test Paint 54')); // Most recent
    });

    test('should clear history correctly', () {
      history.addPaint(testPaint1);
      history.addPaint(testPaint2);
      
      history.clear();
      
      expect(history.current, isNull);
      expect(history.length, equals(0));
      expect(history.canGoBack, isFalse);
      expect(history.canGoForward, isFalse);
    });

    test('should set current paint correctly', () {
      history.addPaint(testPaint1);
      history.setCurrent(testPaint2);
      
      expect(history.current, equals(testPaint2));
      expect(history.length, equals(1)); // Should replace, not add
    });

    test('should provide helpful history preview', () {
      history.addPaint(testPaint1);
      history.addPaint(testPaint2);
      history.addPaint(testPaint3);
      history.goBack(); // Move to testPaint2
      
      final preview = history.getHistoryPreview();
      expect(preview.length, equals(3));
      expect(preview[1], contains('→')); // Current should be marked
      expect(preview[1], contains('Test Paint 2'));
    });
  });
}
