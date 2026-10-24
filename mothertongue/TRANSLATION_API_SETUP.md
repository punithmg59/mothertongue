# Translation API Setup Guide

## Overview

The MotherTongue app uses **Sarvam AI Mayura Translation API** for translating text between Indian languages. This document explains how to configure the API key securely.

## Required Credentials

To enable translation functionality, you need a **Sarvam AI API key**.

### Getting Your API Key

1. **Create a Sarvam AI Account**
   - Go to [Sarvam AI](https://www.sarvam.ai)
   - Sign up for an account

2. **Generate API Key**
   - Navigate to the API section in your dashboard
   - Click "Generate API Key"
   - Copy the generated API key

3. **Enable Translation API**
   - Ensure your account has access to the Translation API
   - Check your plan includes translation credits

## Configuration Options

### Option 1: .env File (Recommended)

The app uses a `.env` file to securely store your API key. This file is already added to `.gitignore` to prevent committing secrets.

1. **Create or edit the .env file** in the project root (d:\mothertongue):
   ```
   SARVAM_API_KEY=your_api_key_here
   ```

2. **The app automatically loads the .env file** on startup from `main.dart`:
   ```dart
   await dotenv.load(fileName: '../.env');
   ```

3. **No additional configuration needed** - the app reads the API key automatically.

### Option 2: Environment Variable (Alternative)

Set the `SARVAM_API_KEY` environment variable:

**Windows (PowerShell):**
```powershell
$env:SARVAM_API_KEY="your_api_key_here"
```

**Windows (Command Prompt):**
```cmd
set SARVAM_API_KEY=your_api_key_here
```

**Linux/Mac:**
```bash
export SARVAM_API_KEY="your_api_key_here"
```

### Option 3: Hardcoded (NOT Recommended for Production)

⚠️ **WARNING**: Never commit API keys to version control!

For testing purposes only, you can pass the API key directly when initializing the service:

```dart
final translationService = SarvamTranslationService(
  apiKey: 'your_api_key_here',
);
```

## Integrating the Translation Service

### In main.dart

The app is already configured to load the API key from `.env` file. The `AppServices` class handles initialization:

```dart
class AppServices {
  static void initialize() {
    ocrService = GoogleMlKitOcrService();
    
    final apiKey = dotenv.env['SARVAM_API_KEY'];
    if (apiKey != null && apiKey.isNotEmpty) {
      translationService = SarvamTranslationService(apiKey: apiKey);
    }
  }
}
```

No manual configuration in main.dart is needed when using the .env file.

### Running with API Key

When using the .env file, simply run the app normally:

**Flutter Run:**
```bash
flutter run
```

**Android Build:**
```bash
flutter build apk
```

The app will automatically load the API key from the `.env` file.

## Supported Language Pairs

The current implementation supports:

- **Hindi → Kannada** (hi-IN → kn-IN)
- **English → Kannada** (en-IN → kn-IN)
- **Auto-detect → Kannada** (auto → kn-IN)
- **Hindi → Tamil** (hi-IN → ta-IN)
- **English → Tamil** (en-IN → ta-IN)
- And more Indian languages (Telugu, Malayalam, Marathi, Bengali, Gujarati, Punjabi, Odia)

Additional languages can be added to the `LanguageMapper` class in `lib/features/translation/translation_service.dart`.

Sarvam AI supports direct translation between Indian languages without routing through English, preserving meaning and cultural context better.

## Cost Considerations

Sarvam AI Translation API pricing:
- Free trial included (no credit card required)
- Paid tier: ₹20 per 10,000 characters

Monitor your usage in the Sarvam AI dashboard to avoid unexpected charges.

Sarvam AI is optimized for Indian languages and may provide better quality translations for Indian language pairs compared to generic translation services.

## Security Best Practices

1. **Never commit API keys** to git or version control
2. **Use environment variables** for development
3. **Restrict API keys** to specific APIs and IP addresses in production
4. **Rotate API keys** periodically
5. **Use separate keys** for development and production environments
6. **Monitor usage** to detect unauthorized access

## Troubleshooting

### "Translation failed" Error

- Verify your API key is correct
- Check that your Sarvam AI account has translation credits
- Ensure your API key has access to the Translation API
- Check your internet connection

### "API key not valid" Error

- Verify the API key format from Sarvam AI dashboard
- Check that the API key hasn't expired
- Ensure the API key has the correct permissions

### No Translation Results

- Verify the source and target language codes are correct (e.g., hi-IN, kn-IN)
- Check that the language pair is supported by Sarvam AI
- Ensure the input text is not empty
- Check that you have sufficient translation credits

## Testing Without API Key

The app will work without the translation service configured:
- OCR functionality remains fully operational
- Only the translation step will be skipped
- Users can still view recognized text

To test without translation, simply don't provide the `translationService` parameter:

```dart
runApp(const MotherTongueApp()); // Translation disabled
```

## Future Enhancements

- Add support for more Indian languages (already supported by Sarvam AI)
- Implement different translation modes (formal, colloquial, code-mixed)
- Add offline translation capabilities
- Implement translation caching to reduce API calls
- Add support for numeral format conversion (Indic vs international digits)
- Add support for script preferences (native script vs Roman transliteration)
