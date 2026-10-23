/// Base exception for application errors
abstract class AppException implements Exception {
  final String message;
  final Object? cause;

  const AppException(this.message, [this.cause]);

  @override
  String toString() => message;
}

/// Exception thrown when OCR processing fails
class OcrException extends AppException {
  const OcrException(super.message, [super.cause]);
}

/// Exception thrown when an image file is invalid or missing
class ImageProcessingException extends AppException {
  const ImageProcessingException(super.message, [super.cause]);
}
