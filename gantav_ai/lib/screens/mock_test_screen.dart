import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/exam_models.dart';
import '../services/exam_service.dart';
import '../theme/app_theme.dart';
import 'mock_test_result_screen.dart';

/// Real-exam-style timed mock test UI with:
/// - Top bar timer (HH:MM:SS) + auto-submit on 0
/// - Question palette (side drawer) showing answered / marked-for-review / skipped
/// - Save & Next, Clear, Mark for Review, Submit
/// - Negative marking applied on submit
/// - Confirms before leaving mid-test
class MockTestScreen extends StatefulWidget {
  final ExamCategory exam;
  final ExamSubject subject;
  final MockTest test;

  const MockTestScreen({
    super.key,
    required this.exam,
    required this.subject,
    required this.test,
  });

  @override
  State<MockTestScreen> createState() => _MockTestScreenState();
}

enum _QStatus { notVisited, answered, skipped, markedForReview, answeredMarked }

class _MockTestScreenState extends State<MockTestScreen> {
  late final DateTime _startedAt;
  late int _remainingSeconds;
  Timer? _timer;

  int _currentIndex = 0;
  late final Map<String, int?> _answers;       // questionId -> option index
  late final Map<String, _QStatus> _status;    // questionId -> status

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _remainingSeconds = widget.test.durationMinutes * 60;

    _answers = {for (final q in widget.test.questions) q.id: null};
    _status = {for (final q in widget.test.questions) q.id: _QStatus.notVisited};
    if (widget.test.questions.isNotEmpty) {
      _status[widget.test.questions[0].id] = _QStatus.skipped;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) {
        _submit(autoSubmit: true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  String get _timerText {
    final s = _remainingSeconds < 0 ? 0 : _remainingSeconds;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  Color get _timerColor {
    if (_remainingSeconds <= 60) return AppColors.error;
    if (_remainingSeconds <= 300) return AppColors.gold;
    return AppColors.teal;
  }

  ExamQuestion get _currentQ => widget.test.questions[_currentIndex];

  int get _answeredCount => _status.values
      .where((s) => s == _QStatus.answered || s == _QStatus.answeredMarked)
      .length;
  int get _markedCount =>
      _status.values.where((s) => s == _QStatus.markedForReview || s == _QStatus.answeredMarked).length;
  int get _skippedCount => _status.values.where((s) => s == _QStatus.skipped).length;
  int get _notVisitedCount => _status.values.where((s) => s == _QStatus.notVisited).length;

  void _pickOption(int index) {
    setState(() {
      _answers[_currentQ.id] = index;
      final existing = _status[_currentQ.id];
      _status[_currentQ.id] = (existing == _QStatus.markedForReview || existing == _QStatus.answeredMarked)
          ? _QStatus.answeredMarked
          : _QStatus.answered;
    });
  }

  void _clearResponse() {
    setState(() {
      _answers[_currentQ.id] = null;
      final existing = _status[_currentQ.id];
      _status[_currentQ.id] = (existing == _QStatus.markedForReview || existing == _QStatus.answeredMarked)
          ? _QStatus.markedForReview
          : _QStatus.skipped;
    });
  }

  void _markForReview() {
    setState(() {
      if (_answers[_currentQ.id] != null) {
        _status[_currentQ.id] = _QStatus.answeredMarked;
      } else {
        _status[_currentQ.id] = _QStatus.markedForReview;
      }
    });
    _goNext();
  }

  void _saveAndNext() {
    if (_answers[_currentQ.id] == null) {
      _status[_currentQ.id] = _QStatus.skipped;
    }
    _goNext();
  }

  void _goNext() {
    if (_currentIndex < widget.test.questions.length - 1) {
      setState(() {
        _currentIndex++;
        if (_status[_currentQ.id] == _QStatus.notVisited) {
          _status[_currentQ.id] = _QStatus.skipped;
        }
      });
    } else {
      _confirmSubmit();
    }
  }

  void _goTo(int index) {
    setState(() {
      _currentIndex = index;
      if (_status[_currentQ.id] == _QStatus.notVisited) {
        _status[_currentQ.id] = _QStatus.skipped;
      }
    });
    Navigator.of(context).maybePop();
  }

  Future<void> _confirmSubmit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Submit test?', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReviewLine(label: 'Answered', value: _answeredCount, color: AppColors.success),
            _ReviewLine(label: 'Skipped', value: _skippedCount, color: AppColors.gold),
            _ReviewLine(label: 'Marked for review', value: _markedCount, color: AppColors.violet),
            _ReviewLine(label: 'Not visited', value: _notVisitedCount, color: AppColors.textMuted),
            const SizedBox(height: 10),
            Text('This will finalize your attempt. You cannot change answers after submit.',
                style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted, height: 1.4)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Submit')),
        ],
      ),
    );
    if (ok == true) _submit();
  }

  Future<void> _submit({bool autoSubmit = false}) async {
    _timer?.cancel();
    // Capture the navigator before the async gap to avoid using a stale context.
    final navigator = Navigator.of(context);
    final attempt = ExamService.scoreAttempt(
      test: widget.test,
      answers: _answers,
      startedAt: _startedAt,
      submittedAt: DateTime.now(),
    );
    await ExamService.saveAttempt(attempt);
    if (!mounted) return;
    navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) => MockTestResultScreen(
          exam: widget.exam,
          subject: widget.subject,
          test: widget.test,
          attempt: attempt,
          autoSubmitted: autoSubmit,
        ),
      ),
    );
  }

  Future<bool> _confirmExit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Quit test?', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        content: const Text('Your progress will be lost. The test will NOT be submitted.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Quit')),
        ],
      ),
    );
    return ok == true;
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final q = _currentQ;
    final chosen = _answers[q.id];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final ok = await _confirmExit();
        if (ok && mounted) navigator.pop();
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        appBar: _buildAppBar(),
        endDrawer: _buildPalette(),
        body: SafeArea(
          child: Column(
            children: [
              _buildTopInfo(isDark),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Question ${_currentIndex + 1} of ${widget.test.questions.length}',
                            style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.5),
                          ),
                          const SizedBox(width: 8),
                          _SourceBadge(source: widget.test.source, topic: q.topic),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        q.question,
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textLight : AppColors.textDark,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 20),
                      for (int i = 0; i < q.options.length; i++)
                        _OptionTile(
                          label: String.fromCharCode(65 + i),
                          text: q.options[i],
                          selected: chosen == i,
                          onTap: () => _pickOption(i),
                        ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('+${q.marks.toStringAsFixed(2)}  /  −${q.negativeMarks.toStringAsFixed(2)}',
                              style: GoogleFonts.dmMono(fontSize: 11, color: AppColors.textMuted)),
                          TextButton.icon(
                            onPressed: _clearResponse,
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            label: const Text('Clear'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              _buildBottomBar(isDark),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: () async {
          final ok = await _confirmExit();
          if (ok && mounted) Navigator.of(context).pop();
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(widget.test.title, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
          Text('${widget.exam.name} • ${widget.subject.name}',
              style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
        ],
      ),
      actions: [
        Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.grid_view_rounded),
            tooltip: 'Question palette',
            onPressed: () => Scaffold.of(ctx).openEndDrawer(),
          ),
        ),
      ],
    );
  }

  Widget _buildTopInfo(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _timerColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _timerColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: _timerColor, size: 18),
          const SizedBox(width: 8),
          Text('Time left',
              style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(_timerText,
              style: GoogleFonts.dmMono(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _timerColor,
                letterSpacing: 1.2,
              )),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _markForReview,
              icon: const Icon(Icons.flag_outlined, size: 16),
              label: const Text('Review'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _saveAndNext,
              icon: Icon(
                _currentIndex == widget.test.questions.length - 1
                    ? Icons.check_rounded
                    : Icons.arrow_forward_rounded,
                size: 18,
              ),
              label: Text(_currentIndex == widget.test.questions.length - 1 ? 'Save & Submit' : 'Save & Next'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPalette() {
    return Drawer(
      width: 330,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
              child: Text('Question Palette',
                  style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _LegendDot(color: AppColors.success, label: 'Answered ($_answeredCount)'),
                  _LegendDot(color: AppColors.gold, label: 'Skipped ($_skippedCount)'),
                  _LegendDot(color: AppColors.violet, label: 'Marked ($_markedCount)'),
                  _LegendDot(color: AppColors.textMuted, label: 'Not visited ($_notVisitedCount)'),
                ],
              ),
            ),
            const Divider(height: 28),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemCount: widget.test.questions.length,
                itemBuilder: (context, i) {
                  final q = widget.test.questions[i];
                  final status = _status[q.id] ?? _QStatus.notVisited;
                  return _paletteCell(i, status);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                  onPressed: () {
                    Navigator.of(context).maybePop();
                    _confirmSubmit();
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('Submit Test'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paletteCell(int i, _QStatus status) {
    Color bg;
    Color fg = Colors.white;
    Widget? marker;
    switch (status) {
      case _QStatus.answered:
        bg = AppColors.success;
        break;
      case _QStatus.skipped:
        bg = AppColors.gold;
        break;
      case _QStatus.markedForReview:
        bg = AppColors.violet;
        break;
      case _QStatus.answeredMarked:
        bg = AppColors.violet;
        marker = const Positioned(
          right: 3, bottom: 3,
          child: Icon(Icons.check_circle, size: 12, color: AppColors.success),
        );
        break;
      case _QStatus.notVisited:
        bg = AppColors.darkSurface2;
        fg = AppColors.textLight;
        break;
    }
    final isCurrent = i == _currentIndex;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _goTo(i),
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
                border: isCurrent ? Border.all(color: AppColors.gold, width: 2) : null,
              ),
              alignment: Alignment.center,
              child: Text('${i + 1}',
                  style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
            ),
            if (marker != null) marker,
          ],
        ),
      ),
    );
  }
}

// ─── Sub widgets ────────────────────────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  final String label;
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const _OptionTile({required this.label, required this.text, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.violet.withValues(alpha: 0.12)
                : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.violet : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: selected ? AppColors.violet : AppColors.darkSurface2,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text(label,
                    style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: isDark ? AppColors.textLight : AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
      ],
    );
  }
}

/// Tiny pill that tells the learner *why* they should trust this question —
/// "Real PYQ" when it came from the curated dataset, "Online PYQ" when it
/// was sourced via grounded search, "AI pattern" for LLM-generated ones.
class _SourceBadge extends StatelessWidget {
  final String source;
  final String topic;
  const _SourceBadge({required this.source, required this.topic});

  ({String label, Color color, IconData icon}) _style() {
    switch (source) {
      case 'pyq-dataset':
        return (label: 'Real PYQ', color: AppColors.success, icon: Icons.verified_rounded);
      case 'pyq-dataset+ai':
        return (label: 'Real PYQ + AI', color: AppColors.teal, icon: Icons.verified_outlined);
      case 'online-pyq':
        return (label: 'Online PYQ', color: AppColors.violet, icon: Icons.travel_explore_rounded);
      case 'offline-fallback':
        return (label: 'Offline', color: AppColors.textMuted, icon: Icons.cloud_off_rounded);
      default:
        return (label: 'AI pattern', color: AppColors.gold, icon: Icons.auto_awesome_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 10, color: s.color),
          const SizedBox(width: 4),
          Text(
            topic.isNotEmpty ? '${s.label} · $topic' : s.label,
            style: GoogleFonts.dmSans(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: s.color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewLine extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _ReviewLine({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500))),
          Text('$value', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
