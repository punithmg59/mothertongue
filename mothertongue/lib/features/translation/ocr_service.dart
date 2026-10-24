import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../core/errors.dart';
import 'text_region.dart';

/// Clean service interface for Optical Character Recognition.
///
/// Designed to decouple the UI from underlying OCR engines (Google ML Kit Devanagari,
/// Tesseract, Bhashini, or future Indian language OCR engines).
abstract class OcrService {
  /// Recognize text from an image file for the given [language].
  ///
  /// For Hindi, implementations must utilize a dedicated Devanagari script model.
  Future<OcrResult> recognizeText(File imageFile, {String language = 'Hindi'});

  /// Release any underlying native engine resources.
  Future<void> dispose();
}

/// On-device OCR service powered by Google ML Kit's specialized script recognition models.
///
/// Note: To recognize Hindi, standard Latin ML Kit models cannot be used.
/// This service explicitly instantiates [TextRecognitionScript.devanagiri] backed by
/// the native `com.google.mlkit:text-recognition-devanagari` Android dependency.
class GoogleMlKitOcrService implements OcrService {
  final Map<TextRecognitionScript, TextRecognizer> _recognizers = {};

  /// Resolves the ML Kit script for the requested language.
  TextRecognitionScript _scriptForLanguage(String language) {
    switch (language.toLowerCase()) {
      case 'hindi':
      case 'devanagari':
      case 'auto-detect':
        // Primary script for Hindi educational text
        return TextRecognitionScript.devanagiri;
      case 'japanese':
        return TextRecognitionScript.japanese;
      case 'korean':
        return TextRecognitionScript.korean;
      case 'chinese':
        return TextRecognitionScript.chinese;
      case 'english':
      default:
        return TextRecognitionScript.latin;
    }
  }

  /// Retrieves or creates an instance of [TextRecognizer] for the requested [script].
  TextRecognizer _getRecognizer(TextRecognitionScript script) {
    return _recognizers.putIfAbsent(
      script,
      () => TextRecognizer(script: script),
    );
  }

  @override
  Future<OcrResult> recognizeText(
    File imageFile, {
    String language = 'Hindi',
  }) async {
    if (!imageFile.existsSync()) {
      throw ImageProcessingException(
        'Selected image file not found on device: ${imageFile.path}',
      );
    }

    final stopwatch = Stopwatch()..start();
    final script = _scriptForLanguage(language);
    final recognizer = _getRecognizer(script);

    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await recognizer.processImage(inputImage);
      stopwatch.stop();

      final blocks = <TextRegion>[];
      for (final block in recognizedText.blocks) {
        final lines = <TextLineRegion>[];
        for (final line in block.lines) {
          lines.add(
            TextLineRegion(
              text: line.text,
              boundingBox: line.boundingBox,
            ),
          );
        }

        blocks.add(
          TextRegion(
            text: block.text,
            boundingBox: block.boundingBox,
            lines: lines,
          ),
        );
      }

      return OcrResult(
        fullText: recognizedText.text,
        blocks: blocks,
        language: language,
        processingDuration: stopwatch.elapsed,
      );
    } catch (error) {
      if (error is AppException) rethrow;

      throw OcrException(
        'Failed to extract $language text from image: $error',
        error,
      );
    }
  }

  @override
  Future<void> dispose() async {
    for (final recognizer in _recognizers.values) {
      try {
        await recognizer.close();
      } catch (_) {
        // Suppress errors during shutdown
      }
    }
    _recognizers.clear();
  }
}
