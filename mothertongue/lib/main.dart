
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MotherTongueApp());
}

class MotherTongueApp extends StatelessWidget {
  const MotherTongueApp({super.key});

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
      home: const TranslationHomePage(),
    );
  }
}

class TranslationHomePage extends StatefulWidget {
  const TranslationHomePage({super.key});

  @override
  State<TranslationHomePage> createState() => _TranslationHomePageState();
}

class _TranslationHomePageState extends State<TranslationHomePage> {
  final ImagePicker _imagePicker = ImagePicker();

  File? _selectedImage;
  String _sourceLanguage = 'Auto-detect';
  String _targetLanguage = 'Kannada';
  bool _isTranslating = false;

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (image == null || !mounted) return;

      setState(() {
        _selectedImage = File(image.path);
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

    setState(() => _isTranslating = true);

    // OCR and translation will be connected in the next implementation step.
    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    setState(() => _isTranslating = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Image loaded. Hindi OCR and Kannada translation are next.',
        ),
      ),
    );
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
                              setState(() => _selectedImage = null);
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
            const SizedBox(height: 16),
            const Text(
              'Development preview',
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
