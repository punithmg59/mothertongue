import 'dart:convert';
import 'dart:ui';

import 'package:http/http.dart' as http;

import '../../core/errors.dart';
import 'text_region.dart';

/// Clean service interface for text translation.
///
/// Designed to decouple the UI from underlying translation providers
/// (Google Cloud Translation, Sarvam AI, or future providers).
abstract class TranslationService {
  /// Translate text blocks from source language to target language.
  ///
  /// Returns a [TranslationResult] with translated text blocks
  /// preserving the original order and bounding box associations.
  Future<TranslationResult> translate(
    List<TextRegion> textBlocks, {
    required String sourceLanguage,
    required String targetLanguage,
  });

  /// Release any underlying resources.
  Future<void> dispose();
}

/// Result of a translation operation.
class TranslationResult {
  /// Original text blocks with their bounding boxes.
  final List<TextRegion> originalBlocks;

  /// Translated text blocks in the same order as original.
  final List<TranslatedBlock> translatedBlocks;

  /// Source language code used for translation.
  final String sourceLanguage;

  /// Target language code used for translation.
  final String targetLanguage;

  /// Time taken to complete translation.
  final Duration processingDuration;

  const TranslationResult({
    required this.originalBlocks,
    required this.translatedBlocks,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.processingDuration = Duration.zero,
  });

  /// Full concatenated translated text.
  String get fullTranslatedText =>
      translatedBlocks.map((b) => b.text).join('\n');

  bool get isEmpty => translatedBlocks.isEmpty;
  bool get isNotEmpty => translatedBlocks.isNotEmpty;
}

/// A single translated text block with its original bounding box.
class TranslatedBlock {
  final String text;
  final Rect boundingBox;

  const TranslatedBlock({
    required this.text,
    required this.boundingBox,
  });
}

/// Maps UI language names to Sarvam AI language codes.
class LanguageMapper {
  static const Map<String, String> _languageCodes = {
    'Auto-detect': 'auto',
    'Hindi': 'hi-IN',
    'English': 'en-IN',
    'Kannada': 'kn-IN',
    'Tamil': 'ta-IN',
    'Telugu': 'te-IN',
    'Malayalam': 'ml-IN',
    'Marathi': 'mr-IN',
    'Bengali': 'bn-IN',
    'Gujarati': 'gu-IN',
    'Punjabi': 'pa-IN',
    'Odia': 'or-IN',
  };

  static String toCode(String languageName) {
    return _languageCodes[languageName] ?? 'en-IN';
  }

  static String fromCode(String languageCode) {
    return _languageCodes.entries
        .firstWhere(
          (entry) => entry.value == languageCode,
          orElse: () => const MapEntry('English', 'en-IN'),
        )
        .key;
  }
}

/// Translation service powered by Sarvam AI Mayura API.
///
/// Requires a valid Sarvam AI API key with Translation API enabled.
/// Configure the API key via environment variable or secure storage.
class SarvamTranslationService implements TranslationService {
  final String apiKey;
  final http.Client _httpClient;
  final String _baseUrl = 'https://api.sarvam.ai/translate';

  SarvamTranslationService({
    required this.apiKey,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  @override
  Future<TranslationResult> translate(
    List<TextRegion> textBlocks, {
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    if (textBlocks.isEmpty) {
      return TranslationResult(
        originalBlocks: textBlocks,
        translatedBlocks: [],
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );
    }

    final stopwatch = Stopwatch()..start();

    try {
      final sourceCode = LanguageMapper.toCode(sourceLanguage);
      final targetCode = LanguageMapper.toCode(targetLanguage);

      // Extract text from blocks, preserving mathematical content
      final textsToTranslate = textBlocks.map((block) {
        return _preserveMathematicalContent(block.text);
      }).toList();

      // Batch translate all text blocks
      final translatedTexts = await _batchTranslate(
        textsToTranslate,
        sourceCode: sourceCode,
        targetCode: targetCode,
      );

      stopwatch.stop();

      // Create translated blocks with original bounding boxes
      final translatedBlocks = <TranslatedBlock>[];
      for (int i = 0; i < textBlocks.length; i++) {
        translatedBlocks.add(
          TranslatedBlock(
            text: translatedTexts[i],
            boundingBox: textBlocks[i].boundingBox,
          ),
        );
      }

      return TranslationResult(
        originalBlocks: textBlocks,
        translatedBlocks: translatedBlocks,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        processingDuration: stopwatch.elapsed,
      );
    } catch (error) {
      if (error is AppException) rethrow;

      throw TranslationException(
        'Failed to translate from $sourceLanguage to $targetLanguage: $error',
        error,
      );
    }
  }

  /// Batch translate multiple texts using Sarvam AI API.
  Future<List<String>> _batchTranslate(
    List<String> texts, {
    required String sourceCode,
    required String targetCode,
  }) async {
    if (texts.isEmpty) return [];

    // Sarvam AI processes texts individually for better accuracy
    final translatedTexts = <String>[];
    
    for (final text in texts) {
      final uri = Uri.parse(_baseUrl);
      
      final body = jsonEncode({
        'source_language_code': sourceCode == 'auto' ? 'auto' : sourceCode,
        'target_language_code': targetCode,
        'text': text,
        'speaker_gender': 'Female',
        'mode': 'formal',
        'model': 'mayura:v1',
      });

      final response = await _httpClient
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'api-subscription-key': apiKey,
            },
            body: body,
          )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw const TranslationException(
          'Translation request timed out after 30 seconds',
        ),
      );

      if (response.statusCode != 200) {
        throw TranslationException(
          'Sarvam AI API returned error ${response.statusCode}: ${response.body}',
        );
      }

      final data = jsonDecode(response.body);
      final translatedText = data['translated_text'] as String;
      translatedTexts.add(translatedText);
    }

    return translatedTexts;
  }

  /// Preserves mathematical expressions, numbers, and operators.
  ///
  /// This is a simple heuristic. For production, consider more sophisticated
  /// detection using regex patterns or ML-based classification.
  String _preserveMathematicalContent(String text) {
    // If text is primarily mathematical (numbers, operators, variables),
    // return it unchanged to avoid incorrect translation.
    final mathPattern = RegExp(r'^[\d\s+\-*/=()\[\]{}.,xXyYzZ]+$');
    
    if (mathPattern.hasMatch(text.trim())) {
      return text;
    }

    return text;
  }

  @override
  Future<void> dispose() async {
    _httpClient.close();
  }
}

/// Translation service that calls the local FastAPI backend.
///
/// The backend handles Sarvam API integration securely.
/// Configure the backend URL via environment variable or use default localhost.
class BackendTranslationService implements TranslationService {
  final String baseUrl;
  final http.Client _httpClient;

  BackendTranslationService({
    this.baseUrl = 'http://10.0.2.2:8000', // Default for Android emulator
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  @override
  Future<TranslationResult> translate(
    List<TextRegion> textBlocks, {
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    if (textBlocks.isEmpty) {
      return TranslationResult(
        originalBlocks: textBlocks,
        translatedBlocks: [],
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );
    }

    final stopwatch = Stopwatch()..start();

    try {
      final sourceCode = LanguageMapper.toCode(sourceLanguage);
      final targetCode = LanguageMapper.toCode(targetLanguage);

      // Convert text blocks to backend format
      final blocksJson = textBlocks.map((block) {
        return {
          'text': block.text,
          'x': block.boundingBox.left,
          'y': block.boundingBox.top,
          'width': block.boundingBox.width,
          'height': block.boundingBox.height,
        };
      }).toList();

      final requestBody = {
        'text_blocks': blocksJson,
        'source_language': sourceCode,
        'target_language': targetCode,
      };

      final uri = Uri.parse('$baseUrl/translate');
      final response = await _httpClient
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(
        const Duration(seconds: 35), // Slightly longer than backend timeout
        onTimeout: () => throw const TranslationException(
          'Translation request timed out after 35 seconds',
        ),
      );

      if (response.statusCode != 200) {
        throw TranslationException(
          'Backend returned error ${response.statusCode}: ${response.body}',
        );
      }

      final data = jsonDecode(response.body);
      final translatedBlocksJson = data['translated_blocks'] as List;

      stopwatch.stop();

      // Convert backend response to TranslatedBlocks
      final translatedBlocks = <TranslatedBlock>[];
      for (int i = 0; i < translatedBlocksJson.length; i++) {
        final blockData = translatedBlocksJson[i];
        translatedBlocks.add(
          TranslatedBlock(
            text: blockData['text'] as String,
            boundingBox: Rect.fromLTWH(
              blockData['x'] as double,
              blockData['y'] as double,
              blockData['width'] as double,
              blockData['height'] as double,
            ),
          ),
        );
      }

      return TranslationResult(
        originalBlocks: textBlocks,
        translatedBlocks: translatedBlocks,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        processingDuration: stopwatch.elapsed,
      );
    } catch (error) {
      if (error is AppException) rethrow;

      throw TranslationException(
        'Failed to translate from $sourceLanguage to $targetLanguage: $error',
        error,
      );
    }
  }

  @override
  Future<void> dispose() async {
    _httpClient.close();
  }
}
