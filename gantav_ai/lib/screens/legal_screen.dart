import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Which legal document to render. Shared screen chrome, different body.
enum LegalDocument { terms, privacy }

/// Generic legal/policy screen — used for both Terms & Conditions and Privacy
/// Policy so the two documents share a consistent chrome (app bar, scroll,
/// last-updated strip, contact footer). Both are mandatory for Play Store
/// publish; the app links to them from the Profile settings sheet and the
/// sign-up flow disclaimer.
///
/// Copy kept in-app (not fetched) so it works offline, and so Play Store
/// reviewers can inspect the exact text that ships in the APK. When we move
/// to a hosted version, swap `_termsBody` / `_privacyBody` for a WebView.
class LegalScreen extends StatelessWidget {
  final LegalDocument document;
  const LegalScreen({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTerms = document == LegalDocument.terms;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        elevation: 0,
        iconTheme: IconThemeData(
            color: isDark ? AppColors.textLight : AppColors.textDark),
        title: Text(
          isTerms ? 'Terms & Conditions' : 'Privacy Policy',
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.textLight : AppColors.textDark,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MetaStrip(isDark: isDark),
              const SizedBox(height: 20),
              ..._buildSections(isTerms ? _termsBody : _privacyBody, isDark),
              const SizedBox(height: 24),
              _ContactFooter(isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSections(
      List<_LegalSection> sections, bool isDark) {
    final widgets = <Widget>[];
    for (final s in sections) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(
          s.heading,
          style: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.textLight : AppColors.textDark,
            letterSpacing: -0.2,
          ),
        ),
      ));
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Text(
          s.body,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            height: 1.55,
            color: isDark ? AppColors.textLightSub : AppColors.textDarkSub,
          ),
        ),
      ));
    }
    return widgets;
  }
}

class _LegalSection {
  final String heading;
  final String body;
  const _LegalSection(this.heading, this.body);
}

class _MetaStrip extends StatelessWidget {
  final bool isDark;
  const _MetaStrip({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.violet.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.violet.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.violet, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Last updated: April 2026  •  Gantav AI, India',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textLightSub : AppColors.textDarkSub,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactFooter extends StatelessWidget {
  final bool isDark;
  const _ContactFooter({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Questions?',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textLight : AppColors.textDark,
              )),
          const SizedBox(height: 6),
          Text(
            'Reach out to teamgantavai@gmail.com and we will respond within 5 business days.',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              height: 1.5,
              color: isDark ? AppColors.textLightSub : AppColors.textDarkSub,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
// DOCUMENT BODIES
// Kept in-app so the Play Store APK is a self-contained legal artifact.
// Written plainly — MVP-grade but covers the policy bases that Google's
// review team checks for: data collection, third-party services, account
// termination, liability, governing law.
// ───────────────────────────────────────────────────────────────────────

const List<_LegalSection> _termsBody = [
  _LegalSection(
    '1. Acceptance of terms',
    'By creating an account or using Gantav AI ("the app"), you agree to these Terms & Conditions. If you do not agree, please uninstall the app and stop using our services.',
  ),
  _LegalSection(
    '2. Who can use the app',
    'You must be at least 13 years old to use Gantav AI. Users between 13 and 18 must have consent from a parent or legal guardian. You are responsible for any activity that happens under your account.',
  ),
  _LegalSection(
    '3. Your account',
    'You are responsible for keeping your email and password safe. Do not share your credentials. If you suspect unauthorized access, contact us immediately. We may suspend or terminate accounts that violate these terms.',
  ),
  _LegalSection(
    '4. Content and AI-generated material',
    'Gantav AI generates learning roadmaps, quizzes, and explanations using third-party AI models (Google Gemini and others). AI output can occasionally be inaccurate — use your own judgment, especially for academic or career-critical decisions. YouTube videos shown inside the app are the property of their respective channel owners; we only embed them, we do not claim ownership.',
  ),
  _LegalSection(
    '5. Acceptable use',
    'You agree not to: (a) reverse-engineer or scrape the app, (b) use the AI to generate illegal, harmful, or misleading content, (c) impersonate others, (d) upload copyrighted material you do not own, or (e) interfere with other users\' experience.',
  ),
  _LegalSection(
    '6. Virtual coins and certificates',
    'Coins earned inside the app have no monetary value and cannot be exchanged for real currency. Certificates of completion are issued for personal/portfolio use and do not constitute an accredited qualification.',
  ),
  _LegalSection(
    '7. Changes to the service',
    'We are an actively developed product. Features may change, be added, or be removed without prior notice. We will try to give advance notice for major breaking changes via in-app notifications.',
  ),
  _LegalSection(
    '8. Limitation of liability',
    'Gantav AI is provided "as is" without warranty. To the maximum extent permitted by law, we are not liable for any indirect, incidental, or consequential damages arising from your use of the app.',
  ),
  _LegalSection(
    '9. Termination',
    'You can delete your account at any time from the Profile screen. We may suspend or terminate accounts that violate these terms, with or without notice.',
  ),
  _LegalSection(
    '10. Governing law',
    'These terms are governed by the laws of India. Disputes will be handled exclusively by the courts located in Delhi, India.',
  ),
];

const List<_LegalSection> _privacyBody = [
  _LegalSection(
    '1. What we collect',
    'When you sign up we collect your name, email address, and a hashed password (via Firebase Authentication). As you use the app we also store your learning progress — completed lessons, quiz scores, streaks, coins, starred lessons, and generated course data. We do not collect your phone contacts, location, or SMS.',
  ),
  _LegalSection(
    '2. How we use your data',
    'Your data is used to: (a) let you sign in across devices, (b) save your progress and personalize your roadmap, (c) improve app features, (d) contact you about important updates. We do not sell your data to third parties.',
  ),
  _LegalSection(
    '3. Third-party services',
    'We use: Firebase Authentication and Firestore (Google) to store your account and progress; Google Gemini and similar AI APIs to generate course content and answer doubts; YouTube Data API (Google) to fetch video metadata. Each of these services has its own privacy policy, which you should also review.',
  ),
  _LegalSection(
    '4. Data retention',
    'Your account data is retained as long as your account is active. When you delete your account we remove your profile, progress, and generated courses from our servers within 30 days. Backup copies may persist for an additional 60 days before being permanently deleted.',
  ),
  _LegalSection(
    '5. Children\'s privacy',
    'Gantav AI is not directed at children under 13. If you believe we have collected data from a child under 13, please email us and we will delete it immediately.',
  ),
  _LegalSection(
    '6. Security',
    'We use industry-standard practices — HTTPS everywhere, Firebase security rules that restrict each user to their own data, and no storage of raw passwords. No system is 100% secure, but we take reasonable steps to protect you.',
  ),
  _LegalSection(
    '7. Your rights',
    'You can: view your profile data in-app, export your progress on request, correct any inaccurate information, and delete your account at any time. To exercise any of these rights, email teamgantavai@gmail.com.',
  ),
  _LegalSection(
    '8. Changes to this policy',
    'We may update this privacy policy from time to time. If we make material changes we will notify you via in-app notification or email. The "Last updated" date at the top of this page reflects the current version.',
  ),
  _LegalSection(
    '9. Contact',
    'For any privacy questions, data requests, or complaints, contact teamgantavai@gmail.com. We respond within 5 business days.',
  ),
];
