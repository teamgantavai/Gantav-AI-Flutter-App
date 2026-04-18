import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/exam_models.dart';
import '../services/exam_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mock_test_setup_sheet.dart';
import 'mock_test_screen.dart';

/// Detail screen for a single [ExamSubject]: shows subject info and a CTA to start a mock test.
/// NOTE: Video section intentionally removed — exam prep uses AI-generated PYQ tests only.
class SubjectDetailScreen extends StatefulWidget {
  final ExamCategory exam;
  final ExamSubject subject;

  const SubjectDetailScreen({
    super.key,
    required this.exam,
    required this.subject,
  });

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  List<MockAttempt> _recentAttempts = [];
  bool _loadingAttempts = true;
  bool _generatingTest = false;

  @override
  void initState() {
    super.initState();
    _loadRecentAttempts();
  }

  Future<void> _loadRecentAttempts() async {
    final attempts = await ExamService.loadAttempts(
      examId: widget.exam.id,
      subjectId: widget.subject.id,
    );
    if (mounted) {
      setState(() {
        _recentAttempts = attempts.take(5).toList();
        _loadingAttempts = false;
      });
    }
  }

  Future<void> _startCustomMockTest() async {
    final filters = await MockTestSetupSheet.show(
      context,
      exam: widget.exam,
      subject: widget.subject,
    );
    if (filters == null) return;
    if (!mounted) return;
    await _startMockTest(filters: filters);
  }

  Future<void> _startMockTest({MockTestFilters? filters}) async {
    if (_generatingTest) return;
    setState(() => _generatingTest = true);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final test = await ExamService.generateMockTest(
        exam: widget.exam,
        subject: widget.subject,
        filters: filters,
      );

      if (!mounted) return;
      setState(() => _generatingTest = false);

      navigator.push(
        MaterialPageRoute(
          builder: (_) => MockTestScreen(
            exam: widget.exam,
            subject: widget.subject,
            test: test,
          ),
        ),
      ).then((_) => _loadRecentAttempts());
    } catch (e) {
      if (!mounted) return;
      setState(() => _generatingTest = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to build test: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: CustomScrollView(
        slivers: [
          _buildHero(),
          // ─── Subject Info Cards ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  _InfoCard(
                    icon: Icons.menu_book_rounded,
                    label: 'Topics',
                    value: '${widget.subject.topicCount}',
                    color: widget.exam.gradient.first,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 12),
                  _InfoCard(
                    icon: Icons.quiz_rounded,
                    label: 'Questions',
                    value: '25',
                    color: widget.exam.gradient.last,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 12),
                  _InfoCard(
                    icon: Icons.timer_rounded,
                    label: 'Duration',
                    value: '30m',
                    color: AppColors.violet,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),

          // ─── Mock Test CTA ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                children: [
                  _MockTestCta(
                    exam: widget.exam,
                    subject: widget.subject,
                    isGenerating: _generatingTest,
                    onStart: _startMockTest,
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _generatingTest ? null : _startCustomMockTest,
                      icon: Icon(Icons.tune_rounded,
                          size: 18, color: widget.exam.gradient.first),
                      label: Text(
                        'Customise (topic / year / difficulty)',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: widget.exam.gradient.first,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Test Format Info ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: _TestFormatCard(isDark: isDark, exam: widget.exam),
            ),
          ),

          // ─── Recent Attempts ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
              child: Text(
                'Your recent attempts',
                style: GoogleFonts.dmSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textLight : AppColors.textDark,
                ),
              ),
            ),
          ),

          if (_loadingAttempts)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.violet),
                ),
              ),
            )
          else if (_recentAttempts.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: AppColors.textMuted, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No attempts yet. Start your first mock test above!',
                          style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: AppColors.textMuted,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _AttemptTile(
                    attempt: _recentAttempts[i],
                    isDark: isDark,
                  ),
                  childCount: _recentAttempts.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: widget.exam.gradient.first,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.subject.name,
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.exam.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                bottom: -30,
                child: Icon(
                  widget.subject.icon,
                  size: 200,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 80, 20, 60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.exam.name.toUpperCase(),
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.subject.topicCount} topics covered',
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Info Card ────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.textLight : AppColors.textDark,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Mock Test CTA ────────────────────────────────────────────────────────────

class _MockTestCta extends StatelessWidget {
  final ExamCategory exam;
  final ExamSubject subject;
  final bool isGenerating;
  final VoidCallback onStart;

  const _MockTestCta({
    required this.exam,
    required this.subject,
    required this.isGenerating,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: exam.gradient),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: exam.gradient.first.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.assignment_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Start Mock Test',
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '25 AI-generated PYQ-style questions • 30 min • Negative marking',
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: isGenerating ? null : onStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: isGenerating
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: exam.gradient.first,
                        ),
                      )
                    : Text(
                        'Begin',
                        style: GoogleFonts.dmSans(
                          color: exam.gradient.first,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Test Format Card ─────────────────────────────────────────────────────────

class _TestFormatCard extends StatelessWidget {
  final bool isDark;
  final ExamCategory exam;

  const _TestFormatCard({required this.isDark, required this.exam});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.violet.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.info_outline_rounded,
                    size: 18, color: AppColors.violet),
              ),
              const SizedBox(width: 12),
              Text(
                'Test Format',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textLight : AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _FormatRow(
              icon: Icons.quiz_outlined,
              text: '25 MCQ questions per test',
              isDark: isDark),
          _FormatRow(
              icon: Icons.timer_outlined,
              text: '30 minutes total duration',
              isDark: isDark),
          _FormatRow(
              icon: Icons.check_circle_outline,
              text: '+1 mark for correct answer',
              isDark: isDark,
              color: AppColors.success),
          _FormatRow(
              icon: Icons.cancel_outlined,
              text: '-0.25 for wrong answer (negative marking)',
              isDark: isDark,
              color: AppColors.error),
          _FormatRow(
              icon: Icons.auto_awesome_outlined,
              text: 'AI-generated PYQ-style (2024–2026 pattern)',
              isDark: isDark,
              color: AppColors.violet),
        ],
      ),
    );
  }
}

class _FormatRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;
  final Color? color;

  const _FormatRow({
    required this.icon,
    required this.text,
    required this.isDark,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: color ?? AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: isDark ? AppColors.textLightSub : AppColors.textDarkSub,
                  height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Attempt Tile ─────────────────────────────────────────────────────────────

class _AttemptTile extends StatelessWidget {
  final MockAttempt attempt;
  final bool isDark;

  const _AttemptTile({required this.attempt, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final pct = (attempt.percentage * 100).round();
    final pctColor = pct >= 70
        ? AppColors.success
        : (pct >= 40 ? AppColors.gold : AppColors.error);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: pctColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              '$pct%',
              style: GoogleFonts.dmSans(
                  fontSize: 14, fontWeight: FontWeight.w800, color: pctColor),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attempt.testTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textLight : AppColors.textDark),
                ),
                const SizedBox(height: 4),
                Text(
                  '${attempt.correct} correct · ${attempt.wrong} wrong · ${attempt.unattempted} skipped',
                  style: GoogleFonts.dmSans(
                      fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Text(
            _relativeTime(attempt.submittedAt),
            style:
                GoogleFonts.dmSans(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}