import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/app_state.dart';
import '../widgets/widgets.dart';
import 'lesson_player_screen.dart';

class QuizScreen extends StatefulWidget {
  final Lesson lesson;
  final Course course;
  final Module module;

  const QuizScreen({
    super.key,
    required this.lesson,
    required this.course,
    required this.module,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<QuizQuestion> _questions = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  int? _selectedAnswer;
  bool _answered = false;
  int _correctCount = 0;
  bool _quizComplete = false;

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    setState(() => _isLoading = true);

    String topic = widget.course.category;
    if (topic.length > 60 ||
        topic.toLowerCase().contains('with videos from')) {
      topic = widget.course.title;
    }

    final questions = await ApiService.fetchQuiz(
      widget.course.id,
      widget.lesson.id,
      lessonTitle: widget.lesson.title,
      courseTitle: widget.course.title,
      topic: topic,
    );

    if (!mounted) return;
    setState(() {
      _questions = questions;
      _isLoading = false;
    });
  }

  void _selectAnswer(int index) {
    if (_answered) return;
    setState(() {
      _selectedAnswer = index;
      _answered = true;
      if (index == _questions[_currentIndex].correctIndex) {
        _correctCount++;
      }
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = null;
        _answered = false;
      });
    } else {
      _finishQuiz();
    }
  }

  void _finishQuiz() {
    final score = _correctCount / _questions.length;
    final passed = score >= 0.6;

    setState(() => _quizComplete = true);

    // Record per-course score (for certificate)
    context.read<AppState>().recordQuizScore(widget.course.id, score);

    // Record per-lesson quiz pass — THIS UNLOCKS THE NEXT LESSON
    if (passed) {
      context.read<AppState>().markLessonQuizPassed(widget.lesson.id);
      // Auto-navigate to next lesson after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _quizComplete) {
          _navigateToNextLesson();
        }
      });
    }
  }

  void _navigateToNextLesson() {
    Module? nextMod;
    Lesson? nextLes;
    bool foundCurrent = false;
    for (final m in widget.course.modules) {
      for (final l in m.lessons) {
        if (foundCurrent) {
          nextMod = m;
          nextLes = l;
          break;
        }
        if (l.id == widget.lesson.id) {
          foundCurrent = true;
        }
      }
      if (nextLes != null) break;
    }

    if (nextLes != null) {
      Navigator.of(context).pop(); // pop quiz
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LessonPlayerScreen(
            course: widget.course,
            module: nextMod!,
            lesson: nextLes!,
            autoPlay: true, // Auto-play the next lesson
          ),
        ),
      );
    } else {
      // End of course
      Navigator.of(context).pop();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 700;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: isDark ? AppColors.textLight : AppColors.textDark,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!_isLoading && !_quizComplete && _questions.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.violet.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        '${_currentIndex + 1}/${_questions.length}',
                        style: GoogleFonts.dmMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.violet,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            if (!_isLoading && !_quizComplete && _questions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SimpleProgressBar(
                  progress: (_currentIndex + 1) / _questions.length,
                  height: 4,
                ),
              ),

            Expanded(
              child: _isLoading
                  ? _buildLoadingState(isDark)
                  : _questions.isEmpty
                      ? _buildErrorState(isDark)
                      : _quizComplete
                          ? _buildResultScreen(isDark, isWide)
                          : _buildQuestionView(isDark, isWide),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.violet.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.auto_awesome,
                color: AppColors.violet, size: 28),
          ),
          const SizedBox(height: 16),
          Text('AI is creating your quiz...',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Generating questions about "${widget.lesson.title}"',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.violet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  color: Colors.orange, size: 32),
            ),
            const SizedBox(height: 16),
            Text('Quiz not available right now',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              'AI services are busy or offline. Check your connection and try again.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadQuiz,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('Retry',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.violet,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionView(bool isDark, bool isWide) {
    final q = _questions[_currentIndex];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isWide
            ? MediaQuery.of(context).size.width * 0.15
            : 20,
        vertical: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.violet.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, size: 11, color: AppColors.violet),
                const SizedBox(width: 4),
                Text('AI Generated',
                    style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.violet)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(q.question,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(height: 1.4)),
          const SizedBox(height: 24),

          ...q.options.asMap().entries.map((entry) {
            final idx = entry.key;
            final option = entry.value;
            final isSelected = _selectedAnswer == idx;
            final isCorrect = idx == q.correctIndex;
            final showCorrect = _answered && isCorrect;
            final showWrong = _answered && isSelected && !isCorrect;

            Color bgColor;
            Color borderColor;
            if (showCorrect) {
              bgColor = AppColors.success.withValues(alpha: 0.10);
              borderColor = AppColors.success.withValues(alpha: 0.4);
            } else if (showWrong) {
              bgColor = AppColors.error.withValues(alpha: 0.10);
              borderColor = AppColors.error.withValues(alpha: 0.4);
            } else if (isSelected) {
              bgColor = AppColors.violet.withValues(alpha: 0.08);
              borderColor = AppColors.violet.withValues(alpha: 0.3);
            } else {
              bgColor =
                  isDark ? AppColors.darkSurface : AppColors.lightSurface;
              borderColor = isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.06);
            }

            return GestureDetector(
              onTap: () => _selectAnswer(idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: showCorrect
                            ? AppColors.success.withValues(alpha: 0.2)
                            : showWrong
                                ? AppColors.error.withValues(alpha: 0.2)
                                : isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: showCorrect
                            ? const Icon(Icons.check, size: 16, color: AppColors.success)
                            : showWrong
                                ? const Icon(Icons.close, size: 16, color: AppColors.error)
                                : Text(
                                    String.fromCharCode(65 + idx),
                                    style: GoogleFonts.dmMono(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(option,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
            );
          }),

          if (_answered) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurface
                    : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _selectedAnswer == q.correctIndex
                            ? Icons.check_circle_outline
                            : Icons.info_outline,
                        size: 16,
                        color: _selectedAnswer == q.correctIndex
                            ? AppColors.success
                            : AppColors.gold,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _selectedAnswer == q.correctIndex
                            ? 'Correct!'
                            : 'Not quite',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _selectedAnswer == q.correctIndex
                              ? AppColors.success
                              : AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    q.explanation,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.5,
                          color: isDark
                              ? AppColors.textLight
                              : AppColors.textDark,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _nextQuestion,
                child: Text(
                  _currentIndex < _questions.length - 1
                      ? 'Next question'
                      : 'See results',
                  style: GoogleFonts.dmSans(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildResultScreen(bool isDark, bool isWide) {
    final score = _correctCount / _questions.length;
    final passed = score >= 0.6;
    final appState = context.watch<AppState>();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isWide
            ? MediaQuery.of(context).size.width * 0.15
            : 20,
        vertical: 32,
      ),
      child: Column(
        children: [
          // Score circle
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: passed
                  ? AppColors.success.withValues(alpha: 0.12)
                  : AppColors.error.withValues(alpha: 0.12),
              border: Border.all(
                color: passed
                    ? AppColors.success.withValues(alpha: 0.3)
                    : AppColors.error.withValues(alpha: 0.3),
                width: 3,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(score * 100).round()}%',
                    style: GoogleFonts.dmMono(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: passed ? AppColors.success : AppColors.error,
                    ),
                  ),
                  Text('$_correctCount/${_questions.length}',
                      style: GoogleFonts.dmMono(
                          fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            passed ? '🎉 Well done!' : '📚 Keep practicing!',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            passed
                ? 'You passed! The next lesson is now unlocked.'
                : 'Score 60% or higher to unlock the next lesson.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
            textAlign: TextAlign.center,
          ),

          // Coins earned
          if (passed) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text('+25 coins earned!',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFF59E0B),
                      )),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),

          // Actions
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                if (!passed) {
                  Navigator.of(context).pop();
                  return;
                }
                _navigateToNextLesson();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: passed ? AppColors.teal : AppColors.violet,
              ),
              child: Text(
                passed ? 'Continue to next lesson' : 'Back to lesson',
                style: GoogleFonts.dmSans(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!passed)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _currentIndex = 0;
                    _selectedAnswer = null;
                    _answered = false;
                    _correctCount = 0;
                    _quizComplete = false;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  side: BorderSide(
                      color: AppColors.textMuted.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text('Retry quiz',
                    style: GoogleFonts.dmSans(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }
}