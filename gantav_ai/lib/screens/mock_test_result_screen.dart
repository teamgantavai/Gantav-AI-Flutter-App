import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/exam_models.dart';
import '../theme/app_theme.dart';

/// Shows the final score, breakdown, and per-question review with correct answers + explanations.
class MockTestResultScreen extends StatelessWidget {
  final ExamCategory exam;
  final ExamSubject subject;
  final MockTest test;
  final MockAttempt attempt;
  final bool autoSubmitted;

  const MockTestResultScreen({
    super.key,
    required this.exam,
    required this.subject,
    required this.test,
    required this.attempt,
    this.autoSubmitted = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pct = (attempt.percentage * 100).round();
    final pctColor = pct >= 70 ? AppColors.success : (pct >= 40 ? AppColors.gold : AppColors.error);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ─── Score card ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: exam.gradient),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: exam.gradient.first.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(test.title,
                    style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('${exam.name} • ${subject.name}',
                    style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white.withValues(alpha: 0.75))),
                if (autoSubmitted) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('⏰ Auto-submitted (time up)',
                        style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$pct',
                        style: GoogleFonts.dmSans(fontSize: 56, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text('%',
                          style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        '${attempt.score.toStringAsFixed(2)} / ${attempt.maxScore.toStringAsFixed(0)}',
                        style: GoogleFonts.dmMono(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: attempt.percentage.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── Breakdown ────────────────────────────────────────────────
          Row(
            children: [
              _StatCard(label: 'Correct', value: attempt.correct, color: AppColors.success, icon: Icons.check_circle_rounded),
              _StatCard(label: 'Wrong', value: attempt.wrong, color: AppColors.error, icon: Icons.cancel_rounded),
              _StatCard(label: 'Skipped', value: attempt.unattempted, color: AppColors.textMuted, icon: Icons.remove_circle_outline_rounded),
            ],
          ),
          const SizedBox(height: 10),
          _TimeAccuracyCard(attempt: attempt, color: pctColor),
          const SizedBox(height: 24),

          // ─── Review header ────────────────────────────────────────────
          Text('Question-wise review',
              style: GoogleFonts.dmSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textLight : AppColors.textDark,
              )),
          const SizedBox(height: 10),

          for (int i = 0; i < test.questions.length; i++)
            _ReviewQuestionCard(
              index: i,
              question: test.questions[i],
              chosenIndex: attempt.answers[test.questions[i].id],
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  const _StatCard({required this.label, required this.value, required this.color, required this.icon});

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
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 8),
            Text('$value',
                style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _TimeAccuracyCard extends StatelessWidget {
  final MockAttempt attempt;
  final Color color;
  const _TimeAccuracyCard({required this.attempt, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mins = attempt.durationTakenSeconds ~/ 60;
    final secs = attempt.durationTakenSeconds % 60;
    final accuracyPct = (attempt.accuracy * 100).round();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, size: 18, color: AppColors.violet),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${mins}m ${secs}s',
                        style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? AppColors.textLight : AppColors.textDark)),
                    Text('Time taken', style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          Container(height: 32, width: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 18, color: color),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$accuracyPct%',
                          style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
                      Text('Accuracy', style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewQuestionCard extends StatelessWidget {
  final int index;
  final ExamQuestion question;
  final int? chosenIndex;
  const _ReviewQuestionCard({required this.index, required this.question, required this.chosenIndex});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCorrect = chosenIndex != null && chosenIndex == question.correctIndex;
    final isWrong = chosenIndex != null && chosenIndex != question.correctIndex;
    Color badgeColor = AppColors.textMuted;
    String badgeText = 'Skipped';
    if (isCorrect) {
      badgeColor = AppColors.success;
      badgeText = 'Correct';
    } else if (isWrong) {
      badgeColor = AppColors.error;
      badgeText = 'Wrong';
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: AppColors.violet.withValues(alpha: 0.15),
                child: Text('${index + 1}',
                    style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.violet)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(question.question,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textLight : AppColors.textDark,
                      height: 1.5,
                    )),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(badgeText,
                    style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: badgeColor)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < question.options.length; i++)
            _OptionRow(
              text: question.options[i],
              label: String.fromCharCode(65 + i),
              isCorrect: i == question.correctIndex,
              isChosen: i == chosenIndex,
            ),
          if (question.explanation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.violet.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, color: AppColors.violet, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      question.explanation,
                      style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final String text;
  final String label;
  final bool isCorrect;
  final bool isChosen;
  const _OptionRow({required this.text, required this.label, required this.isCorrect, required this.isChosen});

  @override
  Widget build(BuildContext context) {
    Color? bg;
    Color textColor = AppColors.textMuted;
    IconData? trailing;
    if (isCorrect) {
      bg = AppColors.success.withValues(alpha: 0.12);
      textColor = AppColors.success;
      trailing = Icons.check_circle_rounded;
    } else if (isChosen) {
      bg = AppColors.error.withValues(alpha: 0.12);
      textColor = AppColors.error;
      trailing = Icons.cancel_rounded;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Text('$label. ',
              style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: textColor)),
          Expanded(
            child: Text(text,
                style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500, color: textColor, height: 1.4)),
          ),
          if (trailing != null) Icon(trailing, size: 16, color: textColor),
        ],
      ),
    );
  }
}
