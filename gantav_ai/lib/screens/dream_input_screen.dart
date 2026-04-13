import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/app_state.dart';
import '../services/api_config.dart';
import '../models/models.dart';

class DreamInputScreen extends StatefulWidget {
  const DreamInputScreen({super.key});

  @override
  State<DreamInputScreen> createState() => _DreamInputScreenState();
}

class _DreamInputScreenState extends State<DreamInputScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _langController = TextEditingController();
  final TextEditingController _teacherController = TextEditingController();
  String _timeCommitment = '1 Hour';
  
  bool _isGenerating = false;
  Course? _generatedCourse;
  String? _error;
  late AnimationController _shimmerController;

  final List<String> _suggestions = [
    'ML Engineer',
    'Full-Stack Developer',
    'Data Scientist',
    'Mobile App Developer',
    'Cloud Architect',
    'DevOps Engineer',
    'AI Researcher',
    'Cybersecurity Expert',
  ];

  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _topicController.dispose();
    _langController.dispose();
    _teacherController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.pop(context);
    }
  }

  void _generatePath() {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) return;
    
    final lang = _langController.text.trim().isNotEmpty ? _langController.text.trim() : 'English';
    final teacher = _teacherController.text.trim();
    final combinedPrompt = 'I want to learn: $topic.\\nLanguage: $lang.\\nTeacher preference: ${teacher.isNotEmpty ? teacher : 'Any top quality channel'}.\\nTime commitment: $_timeCommitment per day.';

    if (!ApiConfig.isConfigured) {
      setState(() => _error =
          'Please add your Gemini API key in lib/services/api_config.dart');
      return;
    }

    final appState = context.read<AppState>();
    appState.generateCourseInBackground(combinedPrompt, topic);
    Navigator.of(context).pop(true);
  }

  void _acceptPath() {
    // Legacy method, not used anymore if generated in background.
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
                        Icons.arrow_back,
                        size: 20,
                        color:
                            isDark ? AppColors.textLight : AppColors.textDark,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Generate Course',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                children: [
                  _buildTopicCard(isDark, isWide, screenWidth),
                  _buildLanguageCard(isDark, isWide, screenWidth),
                  _buildTeacherCard(isDark, isWide, screenWidth),
                  _buildTimeCard(isDark, isWide, screenWidth),
                ],
              ),
            ),

            // Navigation Bottom Bar
            if (_generatedCourse == null && _error == null)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _prevPage,
                      child: Text('Back',
                          style: GoogleFonts.dmSans(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600)),
                    ),
                    Row(
                      children: List.generate(4, (index) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? AppColors.violet
                                : AppColors.textMuted.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    _currentPage == 3
                        ? ElevatedButton(
                            onPressed: _isGenerating ||
                                    _topicController.text.trim().isEmpty
                                ? null
                                : _generatePath,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.violet,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isGenerating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('Generate'),
                          )
                        : ElevatedButton(
                            onPressed: _nextPage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.violet,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Next'),
                          ),
                  ],
                ),
              ),

                    // Error
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.error, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _error!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: AppColors.error, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

          ],
        ),
      ),
    );
  }

  Widget _buildCardBase(bool isDark, bool isWide, double screenWidth, List<Widget> children) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? screenWidth * 0.15 : 20,
        vertical: 24,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _buildTopicCard(bool isDark, bool isWide, double screenWidth) {
    return _buildCardBase(isDark, isWide, screenWidth, [
      Text('What do you want\nto learn?', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('Provide exactly what you want to learn. AI will curate the best YouTube videos for you.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
      const SizedBox(height: 24),
      TextField(
        controller: _topicController,
        style: Theme.of(context).textTheme.bodyLarge,
        textCapitalization: TextCapitalization.sentences,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'e.g., Complete Machine Learning',
          hintStyle: const TextStyle(color: AppColors.textMuted),
          filled: true,
          fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
      const SizedBox(height: 24),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _suggestions.map((s) {
          return GestureDetector(
            onTap: () {
              _topicController.text = s;
              setState(() {});
              _nextPage();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
              ),
              child: Text(s, style: GoogleFonts.dmSans(fontSize: 12, color: isDark ? AppColors.textLight : AppColors.textDark)),
            ),
          );
        }).toList(),
      ),
    ]);
  }

  Widget _buildLanguageCard(bool isDark, bool isWide, double screenWidth) {
    return _buildCardBase(isDark, isWide, screenWidth, [
      Text('Language Preference', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('In which language would you like to consume the content?',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
      const SizedBox(height: 24),
      TextField(
        controller: _langController,
        style: Theme.of(context).textTheme.bodyLarge,
        textCapitalization: TextCapitalization.sentences,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'e.g., English, Hindi',
          hintStyle: const TextStyle(color: AppColors.textMuted),
          filled: true,
          fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.all(16),
        ),
        onSubmitted: (_) => _nextPage(),
      ),
    ]);
  }

  Widget _buildTeacherCard(bool isDark, bool isWide, double screenWidth) {
    return _buildCardBase(isDark, isWide, screenWidth, [
      Text('Favorite Teacher\n(Optional)', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('Do you have a preferred channel or instructor?',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
      const SizedBox(height: 24),
      TextField(
        controller: _teacherController,
        style: Theme.of(context).textTheme.bodyLarge,
        textCapitalization: TextCapitalization.sentences,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'e.g., 3Blue1Brown, freeCodeCamp',
          hintStyle: const TextStyle(color: AppColors.textMuted),
          filled: true,
          fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.all(16),
        ),
        onSubmitted: (_) => _nextPage(),
      ),
    ]);
  }

  Widget _buildTimeCard(bool isDark, bool isWide, double screenWidth) {
    return _buildCardBase(isDark, isWide, screenWidth, [
      Text('Daily Time Commitment', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('How much time can you dedicate daily?',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBg : AppColors.lightBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _timeCommitment,
            isExpanded: true,
            dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            style: Theme.of(context).textTheme.bodyLarge,
            items: ['30 Mins', '1 Hour', '2 Hours', '3+ Hours'].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _timeCommitment = val);
            },
          ),
        ),
      ),
      if (_generatedCourse != null) ...[
         const SizedBox(height: 28),
         _GeneratedCoursePreview(
           course: _generatedCourse!,
           onAccept: _acceptPath,
           onRegenerate: _generatePath,
         ),
      ],
    ]);
  }
}

class _GeneratedCoursePreview extends StatelessWidget {
  final Course course;
  final VoidCallback onAccept;
  final VoidCallback onRegenerate;

  const _GeneratedCoursePreview({
    required this.course,
    required this.onAccept,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.violet.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.violet.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: AppColors.violet, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI-Generated Path',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.violet,
                      ),
                    ),
                    Text(
                      course.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            course.description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  height: 1.5,
                  color: AppColors.textMuted,
                ),
          ),
          const SizedBox(height: 14),

          // Stats
          Row(
            children: [
              _MiniStat(
                  icon: Icons.play_lesson_outlined,
                  text: '${course.totalLessons} lessons'),
              const SizedBox(width: 16),
              _MiniStat(
                  icon: Icons.schedule_outlined,
                  text: course.estimatedTime),
              const SizedBox(width: 16),
              _MiniStat(
                  icon: Icons.layers_outlined,
                  text: '${course.modules.length} modules'),
            ],
          ),
          const SizedBox(height: 14),

          // Skills
          if (course.skills.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: course.skills.map((skill) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    skill,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 14),

          // Modules preview
          ...course.modules.take(4).map((module) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: module.isLocked
                          ? AppColors.textMuted.withValues(alpha: 0.2)
                          : AppColors.violet.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: module.isLocked
                          ? const Icon(Icons.lock_outline,
                              size: 12, color: AppColors.textMuted)
                          : Text(
                              '${course.modules.indexOf(module) + 1}',
                              style: GoogleFonts.dmMono(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.violet,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      module.title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.textLight
                                : AppColors.textDark,
                            fontWeight: FontWeight.w500,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${module.lessonCount} lessons',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onRegenerate,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side:
                        BorderSide(color: AppColors.textMuted.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.refresh, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Regenerate',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Start this path',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniStat({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
