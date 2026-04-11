import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get geminiApiKey {
    final key = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (key.isEmpty) {
      debugPrint('[Config] GEMINI_API_KEY not found in .env');
    }
    return key;
  }

  /// Using gemini-1.5-flash-latest — it's FREE and fast
  static const String geminiModel = 'gemini-1.5-flash-latest';
  static const String geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';
  
  static bool get isConfigured => geminiApiKey.isNotEmpty;
}
