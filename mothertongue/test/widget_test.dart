import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mothertongue/core/errors.dart';
import 'package:mothertongue/features/translation/ocr_service.dart';
import 'package:mothertongue/features/translation/text_region.dart';
import 'package:mothertongue/main.dart';

class MockSuccessOcrService implements OcrService {
  @override
  Future<OcrResult> recognizeText(File imageFile, {String language = 'Hindi'}) async {
    return const OcrResult(
      fullText: 'नमस्ते दुनिया\nशिक्षा ही शक्ति है',
      blocks: [
        TextRegion(
          text: 'नमस्ते दुनिया',
          boundingBox: Rect.fromLTWH(20, 30, 200, 40),
          lines: [
            TextLineRegion(
              text: 'नमस्ते दुनिया',
              boundingBox: Rect.fromLTWH(20, 30, 200, 40),
            ),
          ],
        ),
      ],
      language: 'Hindi',
      processingDuration: Duration(milliseconds: 125),
    );
  }

  @override
  Future<void> dispose() async {}
}

class MockFailingOcrService implements OcrService {
  @override
  Future<OcrResult> recognizeText(File imageFile, {String language = 'Hindi'}) async {
    throw const OcrException('Native Devanagari recognition failed: Model initialization error');
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('MotherTongueApp renders home screen components properly', (WidgetTester tester) async {
    await tester.pumpWidget(const MotherTongueApp());

    expect(find.text('MotherTongue'), findsOneWidget);
    expect(find.text('Understand every frame.'), findsOneWidget);
    expect(find.text('Select a test image'), findsOneWidget);
    expect(find.text('Start Translation'), findsOneWidget);
    expect(find.text('SOURCE LANGUAGE'), findsOneWidget);
    expect(find.text('TRANSLATE INTO'), findsOneWidget);
  });

  testWidgets('Tapping Start Translation without image shows snackbar prompt', (WidgetTester tester) async {
    await tester.pumpWidget(const MotherTongueApp());

    await tester.tap(find.text('Start Translation'));
    await tester.pump();

    expect(find.text('Select an image to start testing.'), findsOneWidget);
  });
}
