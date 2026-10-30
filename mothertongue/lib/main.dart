import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mothertongue/features/translation/ocr_service.dart';
import 'package:mothertongue/features/translation/text_region.dart';
import 'package:mothertongue/features/translation/translation_service.dart';
import 'package:mothertongue/features/video/video_frame_capture_service.dart';

void main() {
  // Initialize services with hardcoded backend URL for mobile device
  AppServices.initialize();
  
  runApp(MotherTongueApp(
    ocrService: AppServices.ocrService,
    translationService: AppServices.translationService,
  ));
}

class MotherTongueApp extends StatelessWidget {
  final OcrService? ocrService;
  final BackendTranslationService? translationService;

  const MotherTongueApp({
    super.key,
    this.ocrService,
    this.translationService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MotherTongue',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6558E8),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF101014),
      ),
      home: TranslationHomePage(
        ocrService: ocrService,
        translationService: translationService,
      ),
    );
  }
}

// Initialize services with hardcoded configuration for mobile device
class AppServices {
  static OcrService? ocrService;
  static BackendTranslationService? translationService;

  static void initialize() {
    ocrService = GoogleMlKitOcrService();
    
    // Hardcoded backend URL for physical Android device on same network
    // Computer IP: 192.168.43.244
    // Backend port: 8000
    const backendUrl = 'http://192.168.43.244:8000';
    print('Using backend URL: $backendUrl');
    translationService = BackendTranslationService(baseUrl: backendUrl);
  }
}

class TranslationHomePage extends StatefulWidget {
  final OcrService? ocrService;
  final BackendTranslationService? translationService;

  const TranslationHomePage({
    super.key,
    this.ocrService,
    this.translationService,
  });

  @override
  State<TranslationHomePage> createState() => _TranslationHomePageState();
}

class _TranslationHomePageState extends State<TranslationHomePage> {
  final ImagePicker _imagePicker = ImagePicker();
  late final OcrService _ocrService;
  BackendTranslationService? _translationService;
  late final VideoFrameCaptureService _videoFrameCaptureService;

  File? _selectedImage;
  File? _selectedVideo;
  String _sourceLanguage = 'Auto-detect';
  String _targetLanguage = 'Kannada';
  bool _isTranslating = false;
  bool _isProcessingVideo = false;
  OcrResult? _ocrResult;
  TranslationResult? _translationResult;
  String? _errorMessage;
  bool _showBoundingBoxes = false;
  bool _isBackendConnected = false;
  String _connectionStatus = 'Checking...';
  
  // Video processing results
  double? _videoDuration;
  List<Map<String, dynamic>> _videoOcrResults = [];

  @override
  void initState() {
    super.initState();
    _ocrService = widget.ocrService ?? GoogleMlKitOcrService();
    _translationService = widget.translationService;
    _videoFrameCaptureService = NativeFrameCaptureService();
    
    // Check backend connection on startup
    _checkBackendConnection();
  }

  Future<void> _checkBackendConnection() async {
    if (_translationService == null) {
      setState(() {
        _isBackendConnected = false;
        _connectionStatus = 'Translation service not initialized';
      });
      return;
    }

    final isConnected = await _translationService!.checkConnection();
    setState(() {
      _isBackendConnected = isConnected;
      _connectionStatus = isConnected ? 'Connected' : 'Disconnected';
    });

    if (!isConnected) {
      print('WARNING: Backend is not reachable');
    }
  }

  @override
  void dispose() {
    _ocrService.dispose();
    _translationService?.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (image == null || !mounted) return;

      setState(() {
        _selectedImage = File(image.path);
        _selectedVideo = null;
        _ocrResult = null;
        _translationResult = null;
        _errorMessage = null;
        _videoDuration = null;
        _videoOcrResults = [];
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not select image: $error')),
      );
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
      );

      if (video == null || !mounted) return;

      setState(() {
        _selectedVideo = File(video.path);
        _selectedImage = null;
        _ocrResult = null;
        _translationResult = null;
        _errorMessage = null;
        _videoDuration = null;
        _videoOcrResults = [];
      });

      // Get video duration
      try {
        final duration = await _videoFrameCaptureService.getVideoDuration(video.path);
        if (mounted) {
          setState(() {
            _videoDuration = duration;
          });
        }
      } catch (e) {
        print('Warning: Could not get video duration: $e');
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not select video: $error')),
      );
    }
  }

  Future<void> _startTranslation() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select an image to start testing.'),
        ),
      );
      return;
    }

    setState(() {
      _isTranslating = true;
      _errorMessage = null;
      _ocrResult = null;
      _translationResult = null;
    });

    try {
      // Resolve language for OCR - default to Hindi for Auto-detect / Hindi
      final language = _sourceLanguage == 'Auto-detect' ? 'Hindi' : _sourceLanguage;
      final result = await _ocrService.recognizeText(
        _selectedImage!,
        language: language,
      );

      if (!mounted) return;

      setState(() {
        _ocrResult = result;
        _isTranslating = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isTranslating = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _processVideo() async {
    if (_selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a video to start processing.'),
        ),
      );
      return;
    }

    setState(() {
      _isProcessingVideo = true;
      _errorMessage = null;
      _videoOcrResults = [];
    });

    try {
      // Capture frames at 1 fps
      final config = FrameCaptureConfig.standard();
      final captureResult = await _videoFrameCaptureService.captureFrames(
        _selectedVideo!.path,
        config,
      );

      if (!mounted) return;

      print('Captured ${captureResult.frameCount} frames');

      // Process each frame with OCR
      final results = <Map<String, dynamic>>[];
      final language = _sourceLanguage == 'Auto-detect' ? 'Hindi' : _sourceLanguage;

      for (final frame in captureResult.frames) {
        try {
          // Save frame bytes to temporary file for OCR
          final tempDir = Directory('/data/user/0/com.example.mothertongue/cache/ocr_frames');
          if (!tempDir.existsSync()) {
            tempDir.createSync(recursive: true);
          }
          final tempFile = File('${tempDir.path}/frame_${frame.frameIndex}.png');
          await tempFile.writeAsBytes(frame.imageBytes);

          // Run OCR on the frame
          final ocrResult = await _ocrService.recognizeText(
            tempFile,
            language: language,
          );

          results.add({
            'timestamp': frame.timestamp,
            'frameIndex': frame.frameIndex,
            'text': ocrResult.fullText,
            'blockCount': ocrResult.blockCount,
            'hasText': ocrResult.isNotEmpty,
          });

          // Clean up temp file
          await tempFile.delete();
        } catch (e) {
          print('Warning: OCR failed for frame ${frame.frameIndex}: $e');
          results.add({
            'timestamp': frame.timestamp,
            'frameIndex': frame.frameIndex,
            'text': '',
            'blockCount': 0,
            'hasText': false,
            'error': e.toString(),
          });
        }
      }

      if (!mounted) return;

      setState(() {
        _videoOcrResults = results;
        _isProcessingVideo = false;
      });

      // Clean up captured frames
      await _videoFrameCaptureService.cleanup();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isProcessingVideo = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _performTranslation(List<TextRegion> textBlocks) async {
    if (_translationService == null) return;

    try {
      final sourceLang = _sourceLanguage == 'Auto-detect' ? 'Hindi' : _sourceLanguage;
      final result = await _translationService!.translate(
        textBlocks,
        sourceLanguage: sourceLang,
        targetLanguage: _targetLanguage,
      );

      if (!mounted) return;

      setState(() {
        _isTranslating = false;
        _translationResult = result;
      });

      if (result.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Translation returned no results.'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isTranslating = false;
        _errorMessage = error.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent.shade700,
          content: Text('Translation failed: $error'),
        ),
      );
    }
  }

  Widget _buildLanguageSelector({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            items: options
                .map(
                  (language) => DropdownMenuItem(
                    value: language,
                    child: Text(
                      language,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection(OcrResult result) {
    final languageLabel = result.language == 'Auto-detect' || result.language == 'Hindi'
        ? 'Hindi (Devanagari)'
        : result.language;

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1D25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6558E8).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.text_fields_rounded,
                    color: Color(0xFFAAA0FF),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Recognized $languageLabel',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              if (result.processingDuration > Duration.zero)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${result.processingDuration.inMilliseconds} ms',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (result.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amberAccent),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No Hindi text recognized in this image. Please ensure the frame is clear and contains visible text.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF141419),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'EXTRACTED TEXT (${result.blocks.length} blocks, ${result.totalLines} lines)',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white38,
                          letterSpacing: 0.5,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Copy text',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: result.fullText));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Recognized text copied to clipboard!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    result.fullText,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: Colors.white,
                      fontFamilyFallback: ['sans-serif'],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: _showBoundingBoxes,
                onExpansionChanged: (val) => setState(() => _showBoundingBoxes = val),
                title: Row(
                  children: [
                    const Icon(Icons.crop_free_rounded, size: 16, color: Color(0xFFAAA0FF)),
                    const SizedBox(width: 6),
                    Text(
                      'View Text Blocks & Bounding Boxes (${result.blocks.length})',
                      style: const TextStyle(fontSize: 13, color: Color(0xFFAAA0FF)),
                    ),
                  ],
                ),
                children: [
                  for (int i = 0; i < result.blocks.length; i++)
                    _buildBlockDetailItem(i + 1, result.blocks[i]),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Try Another Image'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslationSection(TranslationResult result) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.translate_rounded,
                    color: Color(0xFF81C784),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Translation: ${result.sourceLanguage} → ${result.targetLanguage}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              if (result.processingDuration > Duration.zero)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${result.processingDuration.inMilliseconds} ms',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TRANSLATED TEXT (${result.translatedBlocks.length} blocks)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white38,
                        letterSpacing: 0.5,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Copy translation',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: result.fullTranslatedText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Translation copied to clipboard!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SelectableText(
                  result.fullTranslatedText,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.white,
                    fontFamilyFallback: ['sans-serif'],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockDetailItem(int index, TextRegion block) {
    final rect = block.boundingBox;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Block #$index (${block.lines.length} lines)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
              Text(
                'x:${rect.left.toInt()} y:${rect.top.toInt()} w:${rect.width.toInt()} h:${rect.height.toInt()}',
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: Colors.white38,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            block.text,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorSection(String error) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.redAccent),
              SizedBox(width: 8),
              Text(
                'Recognition Error',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _startTranslation,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: _pickImage,
                child: const Text('Pick Another Image'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVideoOcrResultsSection() {
    final framesWithText = _videoOcrResults.where((r) => r['hasText'] == true).length;
    
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1D25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6558E8).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.play_circle_rounded,
                color: Color(0xFFAAA0FF),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Video OCR Results',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                '$framesWithText/${_videoOcrResults.length} frames with text',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _videoOcrResults.length,
              itemBuilder: (context, index) {
                final result = _videoOcrResults[index];
                final timestamp = result['timestamp'] as double;
                final hasText = result['hasText'] as bool;
                final text = result['text'] as String;
                final blockCount = result['blockCount'] as int;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: hasText 
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasText 
                          ? const Color(0xFF6558E8).withValues(alpha: 0.3)
                          : Colors.white10,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Frame ${result['frameIndex']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '@ ${timestamp.toStringAsFixed(1)}s',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white54,
                            ),
                          ),
                          const Spacer(),
                          if (blockCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6558E8).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$blockCount blocks',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFFAAA0FF),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (hasText && text.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          text,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else if (result.containsKey('error')) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Error: ${result['error']}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.redAccent,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 4),
                        const Text(
                          'No text detected',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white38,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickVideo,
            icon: const Icon(Icons.videocam),
            label: const Text('Select Another Video'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.translate_rounded),
            SizedBox(width: 10),
            Text(
              'MotherTongue',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          // Backend connection status indicator
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(
                  _isBackendConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: _isBackendConnected ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  _connectionStatus,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () {
                    _checkBackendConnection();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Checking backend connection...'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  tooltip: 'Reconnect to backend',
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Understand every frame.',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Translate visible text in educational videos '
              'into your language.',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image),
                    label: const Text('Select Image'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickVideo,
                    icon: const Icon(Icons.videocam),
                    label: const Text('Select Video'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: const Color(0xFF1D1D25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              clipBehavior: Clip.antiAlias,
              child: _selectedImage == null && _selectedVideo == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.perm_media_rounded,
                          size: 54,
                          color: Color(0xFFAAA0FF),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Select an image or video',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Images: Single frame OCR\nVideos: Frame-by-frame processing',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    )
                  : _selectedImage != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              _selectedImage!,
                              fit: BoxFit.contain,
                            ),
                            Positioned(
                              right: 10,
                              top: 10,
                              child: IconButton.filled(
                                onPressed: () {
                                  setState(() {
                                    _selectedImage = null;
                                    _ocrResult = null;
                                    _translationResult = null;
                                    _errorMessage = null;
                                  });
                                },
                                icon: const Icon(Icons.close),
                                tooltip: 'Remove image',
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.videocam_rounded,
                              size: 54,
                              color: Color(0xFFAAA0FF),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Video Selected',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_videoDuration != null)
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  'Duration: ${_videoDuration!.toStringAsFixed(1)}s',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                            const SizedBox(height: 6),
                            Text(
                              _selectedVideo!.path.split('/').last,
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () {
                                setState(() {
                                  _selectedVideo = null;
                                  _videoDuration = null;
                                  _videoOcrResults = [];
                                  _errorMessage = null;
                                });
                              },
                              icon: const Icon(Icons.close),
                              label: const Text('Remove'),
                            ),
                          ],
                        ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildLanguageSelector(
                  label: 'SOURCE LANGUAGE',
                  value: _sourceLanguage,
                  options: const [
                    'Auto-detect',
                    'Hindi',
                    'English',
                    'Japanese',
                    'Korean',
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _sourceLanguage = value);
                    }
                  },
                ),
                const SizedBox(width: 14),
                _buildLanguageSelector(
                  label: 'TRANSLATE INTO',
                  value: _targetLanguage,
                  options: const [
                    'Kannada',
                    'English',
                    'Hindi',
                    'Tamil',
                    'Telugu',
                    'Malayalam',
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _targetLanguage = value);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_selectedImage != null)
              FilledButton.icon(
                onPressed: _isTranslating ? null : _startTranslation,
                icon: _isTranslating
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.translate_rounded),
                label: Text(
                  _isTranslating ? 'Processing...' : 'Start Translation',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
              ),
            if (_selectedVideo != null)
              FilledButton.icon(
                onPressed: _isProcessingVideo ? null : _processVideo,
                icon: _isProcessingVideo
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_circle_rounded),
                label: Text(
                  _isProcessingVideo ? 'Processing Video...' : 'Process Video Frames',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: const Color(0xFF6558E8),
                ),
              ),
            if (_isTranslating) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Running on-device Devanagari OCR...',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ),
            ],
            if (_isProcessingVideo) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Extracting frames and running OCR...',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ),
            ],
            if (_errorMessage != null) _buildErrorSection(_errorMessage!),
            if (_ocrResult != null) _buildResultsSection(_ocrResult!),
            if (_translationResult != null) _buildTranslationSection(_translationResult!),
            if (_videoOcrResults.isNotEmpty) _buildVideoOcrResultsSection(),
            const SizedBox(height: 16),
            const Text(
              'Development preview • On-device Devanagari OCR',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
