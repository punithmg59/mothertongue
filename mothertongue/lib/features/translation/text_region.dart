import 'dart:ui';

/// Represents a single line within a recognized text region.
class TextLineRegion {
  final String text;
  final Rect boundingBox;

  const TextLineRegion({
    required this.text,
    required this.boundingBox,
  });

  @override
  String toString() => 'TextLineRegion(text: "$text", bounds: $boundingBox)';
}

/// Represents a detected block or region of text with spatial coordinates.
class TextRegion {
  final String text;
  final Rect boundingBox;
  final List<TextLineRegion> lines;
  final double? confidence;

  const TextRegion({
    required this.text,
    required this.boundingBox,
    this.lines = const [],
    this.confidence,
  });

  @override
  String toString() => 'TextRegion(text: "$text", bounds: $boundingBox, lines: ${lines.length})';
}

/// The structured result produced by an OCR engine.
class OcrResult {
  /// The concatenated full text extracted from the image.
  final String fullText;

  /// Structured blocks of text with spatial bounding boxes.
  final List<TextRegion> blocks;

  /// The target or detected language/script used for recognition.
  final String language;

  /// Time taken to process the image.
  final Duration processingDuration;

  const OcrResult({
    required this.fullText,
    required this.blocks,
    required this.language,
    this.processingDuration = Duration.zero,
  });

  /// Factory for an empty recognition result.
  factory OcrResult.empty({String language = 'Hindi'}) {
    return OcrResult(
      fullText: '',
      blocks: const [],
      language: language,
    );
  }

  bool get isEmpty => fullText.trim().isEmpty;
  bool get isNotEmpty => !isEmpty;
  int get blockCount => blocks.length;
  int get totalLines => blocks.fold(0, (count, block) => count + block.lines.length);

  @override
  String toString() =>
      'OcrResult(language: $language, blocks: ${blocks.length}, chars: ${fullText.length}, duration: ${processingDuration.inMilliseconds}ms)';
}
