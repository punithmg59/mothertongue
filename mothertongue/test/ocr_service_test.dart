import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mothertongue/core/errors.dart';
import 'package:mothertongue/features/translation/ocr_service.dart';
import 'package:mothertongue/features/translation/text_region.dart';

void main() {
  group('TextRegion & OcrResult Model Tests', () {
    test('Empty OcrResult initializes correctly', () {
      final result = OcrResult.empty(language: 'Hindi');
      expect(result.isEmpty, isTrue);
      expect(result.isNotEmpty, isFalse);
      expect(result.blockCount, equals(0));
      expect(result.totalLines, equals(0));
      expect(result.fullText, isEmpty);
      expect(result.language, equals('Hindi'));
    });

    test('Non-empty OcrResult calculates metrics properly', () {
      const line1 = TextLineRegion(
        text: 'प्रकाश संश्लेषण',
        boundingBox: Rect.fromLTWH(10, 20, 100, 30),
      );
      const line2 = TextLineRegion(
        text: 'एक प्रक्रिया है',
        boundingBox: Rect.fromLTWH(10, 55, 120, 30),
      );
      const block = TextRegion(
        text: 'प्रकाश संश्लेषण\nएक प्रक्रिया है',
        boundingBox: Rect.fromLTWH(10, 20, 120, 65),
        lines: [line1, line2],
      );

      final result = OcrResult(
        fullText: 'प्रकाश संश्लेषण\nएक प्रक्रिया है',
        blocks: const [block],
        language: 'Hindi',
        processingDuration: const Duration(milliseconds: 140),
      );

      expect(result.isEmpty, isFalse);
      expect(result.isNotEmpty, isTrue);
      expect(result.blockCount, equals(1));
      expect(result.totalLines, equals(2));
      expect(result.fullText, contains('प्रकाश संश्लेषण'));
      expect(result.blocks.first.boundingBox.width, equals(120));
      expect(result.blocks.first.lines.length, equals(2));
    });
  });

  group('GoogleMlKitOcrService Error Handling', () {
    test('Throws ImageProcessingException when image file does not exist', () async {
      final ocrService = GoogleMlKitOcrService();
      final nonExistentFile = File('d:/non_existent_test_image_12345.jpg');

      expect(
        () => ocrService.recognizeText(nonExistentFile, language: 'Hindi'),
        throwsA(isA<ImageProcessingException>()),
      );

      await ocrService.dispose();
    });
  });
}
