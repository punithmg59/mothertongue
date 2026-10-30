import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../../core/errors.dart';

/// Represents a single video frame with its timestamp.
class VideoFrame {
  /// The frame image as bytes.
  final Uint8List imageBytes;
  
  /// The timestamp in seconds from the start of the video.
  final double timestamp;
  
  /// Frame index (0-based).
  final int frameIndex;
  
  /// Original width of the frame.
  final int width;
  
  /// Original height of the frame.
  final int height;

  const VideoFrame({
    required this.imageBytes,
    required this.timestamp,
    required this.frameIndex,
    required this.width,
    required this.height,
  });
}

/// Configuration for frame capture.
class FrameCaptureConfig {
  /// Interval between frames in seconds.
  final double frameInterval;
  
  /// Maximum width for resized frames (0 = no resize).
  final int maxWidth;
  
  /// Maximum height for resized frames (0 = no resize).
  final int maxHeight;
  
  /// Image format for output frames.
  final String imageFormat;
  
  /// Temporary directory for extracted frames.
  final String? tempDir;

  const FrameCaptureConfig({
    this.frameInterval = 1.0, // 1 frame per second by default
    this.maxWidth = 0, // No resize by default
    this.maxHeight = 0, // No resize by default
    this.imageFormat = 'jpg',
    this.tempDir,
  });

  /// Creates a config for 1 fps capture without resizing.
  factory FrameCaptureConfig.standard() {
    return const FrameCaptureConfig(
      frameInterval: 1.0,
      maxWidth: 0,
      maxHeight: 0,
    );
  }

  /// Creates a config for resized frames to control memory.
  factory FrameCaptureConfig.resized({
    int maxWidth = 640,
    int maxHeight = 480,
  }) {
    return FrameCaptureConfig(
      frameInterval: 1.0,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }
}

/// Result of video frame capture operation.
class VideoFrameCaptureResult {
  /// List of captured frames.
  final List<VideoFrame> frames;
  
  /// Total duration of the video in seconds.
  final double duration;
  
  /// Number of frames captured.
  int get frameCount => frames.length;
  
  /// Whether any frames were captured.
  bool get hasFrames => frames.isNotEmpty;

  const VideoFrameCaptureResult({
    required this.frames,
    required this.duration,
  });
}

/// Service for capturing frames from video files using native Android API.
class NativeFrameCaptureService implements VideoFrameCaptureService {
  static const MethodChannel _channel = MethodChannel('com.example.mothertongue/video');
  String? _tempDir;
  
  @override
  Future<VideoFrameCaptureResult> captureFrames(
    String videoPath,
    FrameCaptureConfig config,
  ) async {
    try {
      _tempDir ??= await _getTempDirectory();
      
      final result = await _channel.invokeMethod('extractFrames', {
        'videoPath': videoPath,
        'outputDir': _tempDir,
        'intervalSeconds': config.frameInterval,
      });
      
      if (result == null) {
        throw VideoProcessingException('No response from native code');
      }
      
      if (result is Map && result['success'] == false) {
        throw VideoProcessingException(
          result['error'] ?? 'Unknown error during frame extraction',
        );
      }
      
      final duration = (result['duration'] as num?)?.toDouble() ?? 0.0;
      final framesData = result['frames'] as List<dynamic>?;
      
      if (framesData == null || framesData.isEmpty) {
        return const VideoFrameCaptureResult(frames: [], duration: 0);
      }
      
      final frames = <VideoFrame>[];
      
      for (final frameData in framesData) {
        final framePath = frameData['path'] as String;
        final timestamp = (frameData['timestamp'] as num?)?.toDouble() ?? 0.0;
        final frameIndex = frameData['frameIndex'] as int;
        final width = frameData['width'] as int;
        final height = frameData['height'] as int;
        
        final frameFile = File(framePath);
        if (!await frameFile.exists()) continue;
        
        final imageBytes = await frameFile.readAsBytes();
        final processedBytes = _resizeImageIfNeeded(
          imageBytes,
          config.maxWidth,
          config.maxHeight,
        );
        
        frames.add(VideoFrame(
          imageBytes: processedBytes,
          timestamp: timestamp,
          frameIndex: frameIndex,
          width: width,
          height: height,
        ));
        
        // Clean up frame file after processing
        await frameFile.delete();
      }
      
      return VideoFrameCaptureResult(
        frames: frames,
        duration: duration,
      );
    } on PlatformException catch (e) {
      throw VideoProcessingException(
        'Platform error during frame extraction: ${e.message}',
        e,
      );
    } catch (e) {
      throw VideoProcessingException(
        'Failed to capture frames: $e',
        e,
      );
    }
  }
  
  @override
  Future<double> getVideoDuration(String videoPath) async {
    try {
      final result = await _channel.invokeMethod('getVideoDuration', {
        'videoPath': videoPath,
      });
      
      if (result == null) {
        throw VideoProcessingException('No response from native code');
      }
      
      return (result as num).toDouble();
    } on PlatformException catch (e) {
      throw VideoProcessingException(
        'Platform error getting video duration: ${e.message}',
        e,
      );
    } catch (e) {
      throw VideoProcessingException(
        'Failed to get video duration: $e',
        e,
      );
    }
  }
  
  @override
  Future<void> cleanup() async {
    if (_tempDir != null) {
      final tempDir = Directory(_tempDir!);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      _tempDir = null;
    }
  }
  
  Future<String> _getTempDirectory() async {
    // Use Android-specific temp directory
    final tempDir = Directory('/data/user/0/com.example.mothertongue/cache/video_frames');
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }
    return tempDir.path;
  }
  
  Uint8List _resizeImageIfNeeded(
    Uint8List imageBytes,
    int maxWidth,
    int maxHeight,
  ) {
    if (maxWidth == 0 && maxHeight == 0) {
      return imageBytes;
    }
    
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;
      
      if (maxWidth > 0 && maxHeight > 0) {
        final resized = img.copyResize(
          image,
          width: maxWidth,
          height: maxHeight,
          maintainAspect: true,
        );
        return Uint8List.fromList(img.encodeJpg(resized));
      } else if (maxWidth > 0) {
        final resized = img.copyResize(
          image,
          width: maxWidth,
          maintainAspect: true,
        );
        return Uint8List.fromList(img.encodeJpg(resized));
      } else if (maxHeight > 0) {
        final resized = img.copyResize(
          image,
          height: maxHeight,
          maintainAspect: true,
        );
        return Uint8List.fromList(img.encodeJpg(resized));
      }
      
      return imageBytes;
    } catch (e) {
      // If resizing fails, return original bytes
      return imageBytes;
    }
  }
}

/// Abstract interface for video frame capture services.
abstract class VideoFrameCaptureService {
  /// Capture frames from a video file at specified intervals.
  Future<VideoFrameCaptureResult> captureFrames(
    String videoPath,
    FrameCaptureConfig config,
  );
  
  /// Get the duration of a video file in seconds.
  Future<double> getVideoDuration(String videoPath);
  
  /// Clean up temporary files and resources.
  Future<void> cleanup();
}
