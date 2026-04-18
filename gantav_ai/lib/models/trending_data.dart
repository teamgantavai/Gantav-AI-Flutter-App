import 'package:flutter/material.dart';

/// Seekho-style attractive course cards shown in the Home "Trending Now"
/// section and the Explore Categories grid. Each card is a ready-to-generate
/// course: tapping it runs the same course generation pipeline as a
/// subcategory, using [promptHint] as the topic.
///
/// Titles are written in the voice that actually converts for Indian exam/
/// career audiences — "How to become a YouTuber", "Earn money as a student"
/// — instead of dry taxonomy labels.
class TrendingCourse {
  final String id;
  final String title;
  final String tagline; // one-line value prop shown on the card
  final String promptHint; // passed into course generation pipeline
  final IconData icon;
  final Color primary; // gradient start
  final Color secondary; // gradient end
  final String badge; // e.g. "Trending", "Hot", "New"

  const TrendingCourse({
    required this.id,
    required this.title,
    required this.tagline,
    required this.promptHint,
    required this.icon,
    required this.primary,
    required this.secondary,
    this.badge = 'Trending',
  });
}

class TrendingData {
  /// Curated high-intent topics that map to real Indian student / young-adult
  /// aspirations. Keep this list short and conversion-optimised.
  static const List<TrendingCourse> courses = [
    TrendingCourse(
      id: 't_youtuber',
      title: 'How to become a YouTuber',
      tagline: 'Channel setup, content strategy, monetisation & first 1K subs',
      promptHint:
          'Complete course on becoming a successful YouTuber — channel setup, niche selection, video editing, SEO, thumbnails, monetisation, and growth strategy for Indian creators',
      icon: Icons.smart_display_rounded,
      primary: Color(0xFFEF4444),
      secondary: Color(0xFFEC4899),
      badge: 'Hot',
    ),
    TrendingCourse(
      id: 't_earn_student',
      title: 'Earn money as a student',
      tagline: 'Freelancing, content, tutoring — realistic side-income paths',
      promptHint:
          'Complete course on how Indian students can earn money online — freelancing, content creation, affiliate marketing, online tutoring, and side-income skills that actually pay',
      icon: Icons.currency_rupee_rounded,
      primary: Color(0xFF10B981),
      secondary: Color(0xFF059669),
      badge: 'Trending',
    ),
    TrendingCourse(
      id: 't_govt_id',
      title: 'Govt ID & documents guide',
      tagline: 'Aadhaar, PAN, Passport, voter card — step-by-step for 2026',
      promptHint:
          'Complete step-by-step guide to apply for Indian government IDs and documents — Aadhaar, PAN card, Passport, Voter ID, Driving Licence, and how to fix common errors',
      icon: Icons.badge_rounded,
      primary: Color(0xFF6366F1),
      secondary: Color(0xFF8B5CF6),
      badge: 'Useful',
    ),
    TrendingCourse(
      id: 't_freelancing',
      title: 'Freelancing from home',
      tagline: 'Fiverr, Upwork, cold emails & your first paying client',
      promptHint:
          'Complete freelancing course — how to start on Fiverr and Upwork, pick a skill, write proposals, handle clients, and earn in dollars from India',
      icon: Icons.laptop_mac_rounded,
      primary: Color(0xFF0EA5E9),
      secondary: Color(0xFF2563EB),
      badge: 'Trending',
    ),
    TrendingCourse(
      id: 't_instagram',
      title: 'Grow on Instagram in 2026',
      tagline: 'Reels, algorithm hacks, niches that actually blow up',
      promptHint:
          'Complete Instagram growth course for 2026 — reels strategy, algorithm understanding, content pillars, hashtag and caption writing, monetisation for creators in India',
      icon: Icons.camera_alt_rounded,
      primary: Color(0xFFF59E0B),
      secondary: Color(0xFFEC4899),
      badge: 'Hot',
    ),
    TrendingCourse(
      id: 't_stock_market',
      title: 'Stock market for beginners',
      tagline: 'Demat, fundamentals, charting & your first safe trade',
      promptHint:
          'Complete beginner-friendly stock market course for Indian investors — Demat account opening, fundamental analysis, technical charting basics, risk management, and long-term investing',
      icon: Icons.trending_up_rounded,
      primary: Color(0xFF14B8A6),
      secondary: Color(0xFF0EA5E9),
      badge: 'Trending',
    ),
    TrendingCourse(
      id: 't_ielts',
      title: 'Crack IELTS / Spoken English',
      tagline: 'Speaking confidence, writing tricks & band 7+ strategies',
      promptHint:
          'Complete IELTS and spoken English course for Indian students — listening, reading, writing and speaking modules, grammar, confidence building, and band 7+ strategies',
      icon: Icons.record_voice_over_rounded,
      primary: Color(0xFF8B5CF6),
      secondary: Color(0xFF6366F1),
      badge: 'New',
    ),
    TrendingCourse(
      id: 't_ai_tools',
      title: 'Use AI like a pro',
      tagline: 'ChatGPT, Midjourney, Gemini — real workflows that save hours',
      promptHint:
          'Complete AI tools mastery course — how to use ChatGPT, Gemini, Claude, Midjourney, and image/video AI tools for productivity, content, and study workflows',
      icon: Icons.auto_awesome_rounded,
      primary: Color(0xFFE879F9),
      secondary: Color(0xFF8B5CF6),
      badge: 'Trending',
    ),
  ];
}
