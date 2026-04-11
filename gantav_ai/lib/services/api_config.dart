/// Gantav AI — API Configuration
///
/// Paste your Gemini API key below. Get one free at:
/// https://aistudio.google.com/apikey
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  /// Gemini model to use — flash for speed
  static const String geminiModel = 'gemini-2.0-flash';

  /// Gemini API base URL
  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Whether the API key is configured
  static bool get isConfigured => geminiApiKey.isNotEmpty;
}
