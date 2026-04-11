import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supported AI providers — ordered by preference
enum AIProvider { gemini, groq, openRouter }

/// Type of AI tasks to allow load distribution
enum AITask { recommendations, courseGeneration, chat }

/// Centralized configuration for all AI providers.
class ApiConfig {
  // ... existing getters ...
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String geminiModel = 'gemini-2.0-flash';
  static const String geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  static String get groqApiKey => dotenv.env['GROQ_API_KEY'] ?? '';
  static const String groqModel = 'llama-3.3-70b-versatile';
  static const String groqBaseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  static String get openRouterApiKey => dotenv.env['OPENROUTER_API_KEY'] ?? '';
  static const String openRouterModel = 'mistralai/mistral-small-3.1-24b-instruct:free';
  static const String openRouterBaseUrl = 'https://openrouter.ai/api/v1/chat/completions';

  // YouTube API integration
  static String get youtubeApiKey => dotenv.env['YOUTUBE_API_KEY'] ?? '';
  static bool get hasYoutube => youtubeApiKey.isNotEmpty;

  // ── Smart Distribution ──────────────────────────────────────────────────

  /// Picks the primary provider for a specific task to avoid overloading one API
  static AIProvider? primaryProvider(AITask task) {
    switch (task) {
      case AITask.recommendations:
        // Use OpenRouter or Groq for recommendations (Gemini free is too slow/limited)
        if (hasOpenRouter) return AIProvider.openRouter;
        if (hasGroq) return AIProvider.groq;
        return hasGemini ? AIProvider.gemini : null;

      case AITask.chat:
        // Use Groq for chat (fastest)
        if (hasGroq) return AIProvider.groq;
        if (hasOpenRouter) return AIProvider.openRouter;
        return hasGemini ? AIProvider.gemini : null;

      case AITask.courseGeneration:
        // Use Gemini for heavy JSON logic, but fall back to Groq if possible
        if (hasGemini) return AIProvider.gemini;
        if (hasGroq) return AIProvider.groq;
        return hasOpenRouter ? AIProvider.openRouter : null;
    }
  }

  /// Convenience getters for the smart engine
  static AIProvider? get bestForJson => primaryProvider(AITask.courseGeneration);
  static AIProvider? get bestForChat => primaryProvider(AITask.chat);

  static bool get hasGemini => geminiApiKey.isNotEmpty;
  static bool get hasGroq => groqApiKey.isNotEmpty;
  static bool get hasOpenRouter => openRouterApiKey.isNotEmpty;
  static bool get isConfigured => hasGemini || hasGroq || hasOpenRouter;

  /// Returns the next provider in the fallback chain
  static AIProvider? fallbackAfter(AIProvider current) {
    final order = [AIProvider.gemini, AIProvider.groq, AIProvider.openRouter];
    final currentIndex = order.indexOf(current);
    
    for (int i = 1; i < order.length; i++) {
        final nextIndex = (currentIndex + i) % order.length;
        final next = order[nextIndex];
        if (_isAvailable(next)) return next;
    }
    return null;
  }

  static bool _isAvailable(AIProvider provider) {
    switch (provider) {
      case AIProvider.gemini: return hasGemini;
      case AIProvider.groq: return hasGroq;
      case AIProvider.openRouter: return hasOpenRouter;
    }
  }

  /// Returns fallback order based on the current primary
  static List<AIProvider> getFallbackChain(AIProvider primary) {
    final chain = <AIProvider>[primary];
    if (primary != AIProvider.gemini && hasGemini) chain.add(AIProvider.gemini);
    if (primary != AIProvider.groq && hasGroq) chain.add(AIProvider.groq);
    if (primary != AIProvider.openRouter && hasOpenRouter) chain.add(AIProvider.openRouter);
    return chain;
  }

  static void printStatus() {
    debugPrint('┌─── API Configuration Status ───────────────────');
    debugPrint('│ Gemini:     ${hasGemini ? "✓ configured" : "✗ no key"}');
    debugPrint('│ Groq:       ${hasGroq ? "✓ configured" : "✗ no key"}');
    debugPrint('│ OpenRouter: ${hasOpenRouter ? "✓ configured" : "✗ no key"}');
    debugPrint('│ YouTube:    ${hasYoutube ? "✓ configured" : "✗ no key"}');
    debugPrint('│ Best JSON:  ${bestForJson?.name ?? "none"}');
    debugPrint('│ Best Chat:  ${bestForChat?.name ?? "none"}');
    debugPrint('└────────────────────────────────────────────────');
  }
}
