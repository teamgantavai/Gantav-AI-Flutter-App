import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supported AI providers
enum AIProvider { gemini, groq, openRouter, huggingFace }

/// Type of AI tasks — used for smart provider routing
enum AITask { recommendations, courseGeneration, chat, quiz }

/// Centralized configuration for all AI providers.
class ApiConfig {
  // ── Gemini ────────────────────────────────────────────────────────────────
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  /// Optional secondary Gemini key used for "low-priority" tasks — doubt AI
  /// chat and quiz generation — so the primary key's quota stays reserved
  /// for course generation. Falls back to the primary key when unset.
  static String get geminiApiKey2 => dotenv.env['GEMINI_API_KEY_2'] ?? '';
  static bool get hasGeminiSecondary => geminiApiKey2.isNotEmpty;

  /// Returns the most appropriate Gemini key for the given [task].
  /// Doubt (chat) and quiz go to the secondary key when present; course
  /// generation and everything else use the primary key.
  static String geminiKeyForTask(AITask task) {
    if (!hasGeminiSecondary) return geminiApiKey;
    switch (task) {
      case AITask.chat:
      case AITask.quiz:
        return geminiApiKey2;
      case AITask.courseGeneration:
      case AITask.recommendations:
        return geminiApiKey;
    }
  }

  static const String geminiModel = 'gemini-2.5-flash-lite';
  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  // ── Groq ──────────────────────────────────────────────────────────────────
  static String get groqApiKey => dotenv.env['GROQ_API_KEY'] ?? '';
  static const String groqModel = 'llama-3.3-70b-versatile';
  static const String groqBaseUrl =
      'https://api.groq.com/openai/v1/chat/completions';

  // ── OpenRouter ────────────────────────────────────────────────────────────
  static String get openRouterApiKey => dotenv.env['OPENROUTER_API_KEY'] ?? '';
  static const String openRouterModel =
      'meta-llama/llama-3.3-70b-instruct:free';
  static const String openRouterBaseUrl =
      'https://openrouter.ai/api/v1/chat/completions';

  // ── HuggingFace (Free Tier) ───────────────────────────────────────────────
  static String get huggingFaceApiKey =>
      dotenv.env['HUGGINGFACE_API_KEY'] ?? '';
  // Using Mistral-7B-Instruct — free and capable
  static const String huggingFaceModel =
      'mistralai/Mistral-7B-Instruct-v0.3';
  static const String huggingFaceBaseUrl =
      'https://api-inference.huggingface.co/models/mistralai/Mistral-7B-Instruct-v0.3';

  // ── YouTube ───────────────────────────────────────────────────────────────
  static String get youtubeApiKey => dotenv.env['YOUTUBE_API_KEY'] ?? '';
  static String get youtubeApiKey2 => dotenv.env['YOUTUBE_API_KEY_2'] ?? '';
  static String get youtubeApiKey3 => dotenv.env['YOUTUBE_API_KEY_3'] ?? '';
  static bool get hasYoutube => youtubeApiKey.isNotEmpty;
  static bool get hasYoutube2 => youtubeApiKey2.isNotEmpty;
  static bool get hasYoutube3 => youtubeApiKey3.isNotEmpty;

  // ── Availability checks ───────────────────────────────────────────────────
  static bool get hasGemini => geminiApiKey.isNotEmpty;
  static bool get hasGroq => groqApiKey.isNotEmpty;
  static bool get hasOpenRouter => openRouterApiKey.isNotEmpty;
  static bool get hasHuggingFace => huggingFaceApiKey.isNotEmpty;
  static bool get isConfigured =>
      hasGemini || hasGroq || hasOpenRouter || hasHuggingFace;

  // ── Legacy compatibility ──────────────────────────────────────────────────

  static AIProvider? primaryProvider(AITask task) {
    switch (task) {
      case AITask.recommendations:
        if (hasOpenRouter) return AIProvider.openRouter;
        if (hasGroq) return AIProvider.groq;
        if (hasHuggingFace) return AIProvider.huggingFace;
        return hasGemini ? AIProvider.gemini : null;

      case AITask.chat:
        if (hasGroq) return AIProvider.groq;
        if (hasHuggingFace) return AIProvider.huggingFace;
        if (hasOpenRouter) return AIProvider.openRouter;
        return hasGemini ? AIProvider.gemini : null;

      case AITask.courseGeneration:
      case AITask.quiz:
        if (hasGemini) return AIProvider.gemini;
        if (hasGroq) return AIProvider.groq;
        if (hasOpenRouter) return AIProvider.openRouter;
        return hasHuggingFace ? AIProvider.huggingFace : null;
    }
  }

  static AIProvider? get bestForJson => primaryProvider(AITask.courseGeneration);
  static AIProvider? get bestForChat => primaryProvider(AITask.chat);

  static bool _isAvailable(AIProvider provider) {
    switch (provider) {
      case AIProvider.gemini:
        return hasGemini;
      case AIProvider.groq:
        return hasGroq;
      case AIProvider.openRouter:
        return hasOpenRouter;
      case AIProvider.huggingFace:
        return hasHuggingFace;
    }
  }

  static AIProvider? fallbackAfter(AIProvider current) {
    final order = [
      AIProvider.gemini,
      AIProvider.groq,
      AIProvider.openRouter,
      AIProvider.huggingFace,
    ];
    final currentIndex = order.indexOf(current);

    for (int i = 1; i < order.length; i++) {
      final nextIndex = (currentIndex + i) % order.length;
      final next = order[nextIndex];
      if (_isAvailable(next) && next != current) return next;
    }
    return null;
  }

  static void printStatus() {
    debugPrint('┌─── API Configuration Status ───────────────────────');
    debugPrint('│ Gemini:       ${hasGemini ? "✓ configured" : "✗ no key"}');
    debugPrint('│ Gemini (2nd): ${hasGeminiSecondary ? "✓ configured (doubt/quiz)" : "✗ no key"}');
    debugPrint('│ Groq:         ${hasGroq ? "✓ configured" : "✗ no key"}');
    debugPrint('│ OpenRouter:   ${hasOpenRouter ? "✓ configured" : "✗ no key"}');
    debugPrint('│ HuggingFace:  ${hasHuggingFace ? "✓ configured (free)" : "✗ no key"}');
    debugPrint('│ YouTube:      ${hasYoutube ? "✓ configured" : "✗ no key"}');
    debugPrint('│ YouTube (2nd):${hasYoutube2 ? " ✓ configured (fallback)" : " ✗ no key"}');
    debugPrint('│ YouTube (3rd):${hasYoutube3 ? " ✓ configured (fallback)" : " ✗ no key"}');
    debugPrint('│ Best JSON:    ${bestForJson?.name ?? "none"}');
    debugPrint('│ Best Chat:    ${bestForChat?.name ?? "none"}');
    debugPrint('│ Configured:   $isConfigured');
    debugPrint('└────────────────────────────────────────────────────');
  }
}