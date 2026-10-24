import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';

import 'features/translation/ocr_service.dart';
import 'features/translation/text_region.dart';
import 'features/translation/translation_service.dart';

Future<void> main() async {
  // Load .env file from parent directory
  await dotenv.load(fileName: '../.env');
  
  // Initialize services with API key from .env
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

// Initialize services with .env configuration
class AppServices {
  static OcrService? ocrService;
  static BackendTranslationService? translationService;

  static void initialize() {
    ocrService = GoogleMlKitOcrService();
    
    // Read backend URL from .env or use default
    // For physical device on same network: use your computer's IP
    // Example: http://192.168.1.100:8000
    final backendUrl = dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:8000';
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

  File? _selectedImage;
  String _sourceLanguage = 'Auto-detect';
  String _targetLanguage = 'Kannada';
  bool _isTranslating = false;
  OcrResult? _ocrResult;
  TranslationResult? _translationResult;
  String? _errorMessage;
  bool _showBoundingBoxes = false;

  @override
  void initState() {
    super.initState();
    _ocrService = widget.ocrService ?? GoogleMlKitOcrService();
    _translationService = widget.translationService;
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
        _ocrResult = null;
        _translationResult = null;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not select image: $error')),
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
        _isTranslating = false;
        _ocrResult = result;
      });

      if (result.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No text detected in this image. Try another frame.'),
          ),
        );
        return;
      }

      // Proceed with translation if service is available and target is not source
      if (_translationService != null && _targetLanguage != _sourceLanguage) {
        await _performTranslation(result.blocks);
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
          content: Text('Recognition failed: $error'),
        ),
      );
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
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: const Color(0xFF1D1D25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              clipBehavior: Clip.antiAlias,
              child: _selectedImage == null
                  ? InkWell(
                      onTap: _pickImage,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_search_rounded,
                            size: 54,
                            color: Color(0xFFAAA0FF),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Select a test image',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Choose a frame containing Hindi text',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    )
                  : Stack(
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
            if (_errorMessage != null) _buildErrorSection(_errorMessage!),
            if (_ocrResult != null) _buildResultsSection(_ocrResult!),
            if (_translationResult != null) _buildTranslationSection(_translationResult!),
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
