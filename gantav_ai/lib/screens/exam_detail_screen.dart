import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/exam_models.dart';
import '../services/exam_service.dart';
import '../theme/app_theme.dart';
import 'subject_detail_screen.dart';

/// Shows the subjects under a selected exam category and the user's recent attempts.
/// Tap a subject → start a fresh AI-generated mock test.
class ExamDetailScreen extends StatefulWidget {
  final ExamCategory exam;
  const ExamDetailScreen({super.key, required this.exam});

  @override
  State<ExamDetailScreen> createState() => _ExamDetailScreenState();
}

class _ExamDetailScreenState extends State<ExamDetailScreen> {
  List<MockAttempt> _attempts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAttempts();
  }

  Future<void> _loadAttempts() async {
    final list = await ExamService.loadAttempts(examId: widget.exam.id);
    if (mounted) {
      setState(() {
        _attempts = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            stretch: true,
            backgroundColor: widget.exam.gradient.first,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.exam.name,
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.white),
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
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      right: -30,
                      bottom: -40,
                      child: Icon(widget.exam.icon, size: 240, color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    Positioned(
                      left: 20,
                      bottom: 60,
                      right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.exam.tagline,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.exam.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.85),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Stats row ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  _MiniStat(label: 'Subjects', value: '${widget.exam.subjects.length}', icon: Icons.menu_book_rounded),
                  _MiniStat(label: 'Mock tests', value: '${widget.exam.mockTestCount}+', icon: Icons.assignment_rounded),
                  _MiniStat(label: 'Your attempts', value: _loading ? '—' : '${_attempts.length}', icon: Icons.history_rounded),
                ],
              ),
            ),
          ),

          // ─── Subjects ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
              child: Row(
                children: [
                  Text(
                    'Subjects',
                    style: GoogleFonts.dmSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textLight : AppColors.textDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.violet.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Tap to start mock test',
                      style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.violet, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final subject = widget.exam.subjects[i];
                  return _SubjectTile(
                    subject: subject,
                    gradient: widget.exam.gradient,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubjectDetailScreen(
                          exam: widget.exam,
                          subject: subject,
                        ),
                      ),
                    ).then((_) => _loadAttempts()),
                  );
                },
                childCount: widget.exam.subjects.length,
              ),
            ),
          ),

          // ─── Recent attempts ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
              child: Text(
                'Your recent attempts',
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textLight : AppColors.textDark,
                ),
              ),
            ),
          ),
          if (_loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.violet)),
              ),
            )
          else if (_attempts.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.textMuted, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No attempts yet. Pick a subject above to start your first mock test.',
                          style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted, height: 1.4),
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
                  (context, i) => _AttemptTile(attempt: _attempts[i]),
                  childCount: _attempts.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

}

// ─── Small widgets ───────────────────────────────────────────────────────────

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _MiniStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: AppColors.violet),
            const SizedBox(height: 8),
            Text(value,
                style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? AppColors.textLight : AppColors.textDark)),
            Text(label, style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _SubjectTile extends StatelessWidget {
  final ExamSubject subject;
  final List<Color> gradient;
  final VoidCallback onTap;
  const _SubjectTile({required this.subject, required this.gradient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(subject.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subject.name,
                        style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? AppColors.textLight : AppColors.textDark)),
                    const SizedBox(height: 2),
                    Text('${subject.topicCount} topics • 25 Q · 30 min',
                        style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.violet,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Start',
                        style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
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

class _AttemptTile extends StatelessWidget {
  final MockAttempt attempt;
  const _AttemptTile({required this.attempt});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: pctColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text('$pct%',
                style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w800, color: pctColor)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(attempt.testTitle,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? AppColors.textLight : AppColors.textDark)),
                const SizedBox(height: 4),
                Text(
                  '${attempt.correct} correct · ${attempt.wrong} wrong · ${attempt.unattempted} skipped',
                  style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Text(
            _relativeTime(attempt.submittedAt),
            style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.textMuted),
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
