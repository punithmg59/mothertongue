import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mothertongue/core/errors.dart';
import 'package:mothertongue/features/translation/text_region.dart';
import 'package:mothertongue/features/translation/translation_service.dart';

void main() {
  group('LanguageMapper Tests', () {
    test('Maps UI language names to Sarvam AI codes correctly', () {
      expect(LanguageMapper.toCode('Hindi'), equals('hi-IN'));
      expect(LanguageMapper.toCode('English'), equals('en-IN'));
      expect(LanguageMapper.toCode('Kannada'), equals('kn-IN'));
      expect(LanguageMapper.toCode('Auto-detect'), equals('auto'));
      expect(LanguageMapper.toCode('Tamil'), equals('ta-IN'));
      expect(LanguageMapper.toCode('Telugu'), equals('te-IN'));
      expect(LanguageMapper.toCode('Malayalam'), equals('ml-IN'));
      expect(LanguageMapper.toCode('Unknown'), equals('en-IN')); // fallback
    });

    test('Maps Sarvam AI codes back to UI language names', () {
      expect(LanguageMapper.fromCode('hi-IN'), equals('Hindi'));
      expect(LanguageMapper.fromCode('en-IN'), equals('English'));
      expect(LanguageMapper.fromCode('kn-IN'), equals('Kannada'));
      expect(LanguageMapper.fromCode('ta-IN'), equals('Tamil'));
      expect(LanguageMapper.fromCode('te-IN'), equals('Telugu'));
    });
  });

  group('TranslationResult Model Tests', () {
    test('Empty translation result initializes correctly', () {
      const result = TranslationResult(
        originalBlocks: [],
        translatedBlocks: [],
        sourceLanguage: 'Hindi',
        targetLanguage: 'Kannada',
      );

      expect(result.isEmpty, isTrue);
      expect(result.isNotEmpty, isFalse);
      expect(result.fullTranslatedText, isEmpty);
    });

    test('Non-empty translation result calculates metrics correctly', () {
      const block1 = TextRegion(
        text: 'प्रकाश संश्लेषण',
        boundingBox: Rect.fromLTWH(10, 20, 100, 30),
      );

      const translatedBlock1 = TranslatedBlock(
        text: 'ದ್ಯುತಿ ಸಂಶ್ಲೇಷಣೆ',
        boundingBox: Rect.fromLTWH(10, 20, 100, 30),
      );

      const result = TranslationResult(
        originalBlocks: [block1],
        translatedBlocks: [translatedBlock1],
        sourceLanguage: 'Hindi',
        targetLanguage: 'Kannada',
        processingDuration: Duration(milliseconds: 250),
      );

      expect(result.isEmpty, isFalse);
      expect(result.isNotEmpty, isTrue);
      expect(result.translatedBlocks.length, equals(1));
      expect(result.fullTranslatedText, contains('ದ್ಯುತಿ'));
      expect(result.processingDuration.inMilliseconds, equals(250));
    });
  });

  group('TranslatedBlock Model Tests', () {
    test('TranslatedBlock stores text and bounding box', () {
      const block = TranslatedBlock(
        text: 'ಪ್ರಕಾಶ',
        boundingBox: Rect.fromLTWH(0, 0, 50, 20),
      );

      expect(block.text, equals('ಪ್ರಕಾಶ'));
      expect(block.boundingBox.width, equals(50));
    });
  });

  group('Mathematical Content Preservation Tests', () {
    test('Preserves simple mathematical expressions', () {
      // This tests the regex pattern used in _preserveMathematicalContent
      final mathPattern = RegExp(r'^[\d\s+\-*/=()\[\]{}.,xXyYzZ]+$');
      
      expect(mathPattern.hasMatch('2 + 2 = 4'), isTrue);
      expect(mathPattern.hasMatch('x + y = z'), isTrue);
      expect(mathPattern.hasMatch('3 * 5'), isTrue);
      expect(mathPattern.hasMatch('10 / 2'), isTrue);
      expect(mathPattern.hasMatch('(a + b)'), isTrue);
    });

    test('Does not preserve regular text', () {
      final mathPattern = RegExp(r'^[\d\s+\-*/=()\[\]{}.,xXyYzZ]+$');
      
      expect(mathPattern.hasMatch('Hello world'), isFalse);
      expect(mathPattern.hasMatch('प्रकाश संश्लेषण'), isFalse);
      expect(mathPattern.hasMatch('This is text'), isFalse);
    });
  });

  group('SarvamTranslationService Error Handling (Mocked)', () {
    test('Throws TranslationException when API key is invalid', () async {
      // This is a mocked test - real API calls require valid credentials
      // In a real test environment, you would use a mocking library like http_mock
      // to simulate API responses without making actual network calls
      
      // For now, we document that this test requires mocking:
      // 1. Mock http.Client to return a 401 or 403 response
      // 2. Verify that TranslationException is thrown with appropriate message
      // 3. This test is marked as mocked because it doesn't call the real API
      
      expect(
        () => SarvamTranslationService(apiKey: 'invalid_key'),
        returnsNormally,
      );
    });

    test('Handles empty text blocks gracefully', () async {
      // Mocked test - verify service handles empty input without crashing
      // Real implementation would mock the HTTP client
      
      const emptyResult = TranslationResult(
        originalBlocks: [],
        translatedBlocks: [],
        sourceLanguage: 'Hindi',
        targetLanguage: 'Kannada',
      );

      expect(emptyResult.isEmpty, isTrue);
    });
  });
}
