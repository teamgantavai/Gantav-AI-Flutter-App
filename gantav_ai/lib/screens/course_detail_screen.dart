import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';
import 'lesson_player_screen.dart';

class CourseDetailScreen extends StatelessWidget {
  final Course course;

  const CourseDetailScreen({super.key, required this.course});

  // Fix the course title - never show $dream
  String get _displayTitle => course.title
      .replaceAll('\$dream', course.category)
      .replaceAll('Complete  Course', 'Complete ${course.category} Course');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final screenWidth = MediaQuery.of(context).size.width;
    final useWideLayout = isLandscape && screenWidth > 700;

    if (useWideLayout) {
      return _buildWideLayout(context, isDark);
    }
    return _buildNarrowLayout(context, isDark);
  }

  Widget _buildNarrowLayout(BuildContext context, bool isDark) {
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(context, isDark),
          _buildThumbnail(context),
          _buildCourseInfo(context, isDark),
          _buildModuleList(context, isDark),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      bottomNavigationBar: _buildBottomCTA(context, isDark),
    );
  }

  Widget _buildWideLayout(BuildContext context, bool isDark) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.arrow_back,
                          size: 20,
                          color: isDark
                              ? AppColors.textLight
                              : AppColors.textDark),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _displayTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildThumbnailWidget(context),
                          const SizedBox(height: 16),
                          _buildInfoContent(context, isDark),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Row(
                            children: [
                              Text(
                                'Modules',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: course.modules.length,
                            itemBuilder: (context, index) {
                              return _buildModuleCard(context, isDark, course.modules[index], index);
                            },
                          ),
                        ),
                        _buildBottomCTA(context, isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, bool isDark) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      leading: IconButton(
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
            color: isDark ? AppColors.textLight : AppColors.textDark,
          ),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        _displayTitle,
        style: Theme.of(context).textTheme.titleLarge,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  SliverToBoxAdapter _buildThumbnail(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _buildThumbnailWidget(context),
      ),
    );
  }

  Widget _buildThumbnailWidget(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          course.thumbnailUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppColors.darkSurface2,
            child: const Center(
              child: Icon(Icons.play_circle_outline,
                  color: AppColors.textMuted, size: 56),
            ),
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildCourseInfo(BuildContext context, bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoContent(context, isDark),
            Text('Modules', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoContent(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _displayTitle,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          course.description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
                height: 1.5,
              ),
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.violet.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                course.category,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.violet,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.star_rounded, color: AppColors.gold, size: 18),
            const SizedBox(width: 4),
            Text(
              course.rating.toStringAsFixed(1),
              style: GoogleFonts.dmMono(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (course.skills.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: course.skills.map((skill) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  skill,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.textLight : AppColors.textDark,
                      ),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 18),

        // Stats row
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                icon: Icons.play_lesson_outlined,
                value: '${course.totalLessons}',
                label: 'lessons',
              ),
              Container(
                width: 1, height: 36,
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
              ),
              _StatItem(
                icon: Icons.calendar_today_outlined,
                value: course.estimatedTime.replaceAll(' weeks', '').isEmpty 
                    ? '8' 
                    : course.estimatedTime.replaceAll(' weeks', ''),
                label: 'weeks',
              ),
              Container(
                width: 1, height: 36,
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
              ),
              _StatItem(
                icon: Icons.people_outline,
                value: _formatCount(course.learnerCount),
                label: 'learners',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (course.isInProgress) ...[
          SimpleProgressBar(progress: course.progress, height: 8),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '${course.completedLessons}/${course.totalLessons} lessons completed',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${(course.progress * 100).round()}%',
                style: GoogleFonts.dmMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.progressColor(course.progress),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  /// Build a single module card with proper unique title/description display
  Widget _buildModuleCard(BuildContext context, bool isDark, Module module, int index) {
    return GestureDetector(
      onTap: module.isLocked ? null : () => _openModule(context, module),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: module.isLocked ? 0.5 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: !module.isLocked
                  ? AppColors.violet.withValues(alpha: 0.2)
                  : isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Row(
            children: [
              // Number or lock icon
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: module.isLocked
                      ? AppColors.textMuted.withValues(alpha: 0.1)
                      : AppColors.violet.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: module.isLocked
                      ? const Icon(Icons.lock_outline, size: 18, color: AppColors.textMuted)
                      : Text(
                          '${index + 1}',
                          style: GoogleFonts.dmMono(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.violet,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              // Module title + lesson count - use full text, no ellipsis on title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.title,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textLight : AppColors.textDark,
                      ),
                      // Allow up to 2 lines so text is fully visible
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${module.completedCount}/${module.lessonCount} lessons',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (!module.isLocked && module.progress > 0) ...[
                      const SizedBox(height: 8),
                      SimpleProgressBar(progress: module.progress, height: 4),
                    ],
                  ],
                ),
              ),
              if (!module.isLocked)
                const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  SliverPadding _buildModuleList(BuildContext context, bool isDark) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= course.modules.length) return null;
            return _buildModuleCard(context, isDark, course.modules[index], index);
          },
          childCount: course.modules.length,
        ),
      ),
    );
  }

  Widget _buildBottomCTA(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.lightBg,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () => _startLearning(context),
          child: Text(
            course.isInProgress ? 'Continue learning' : 'Start learning',
            style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  void _openModule(BuildContext context, Module module) {
    if (module.lessons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lessons for "${module.title}" are loading...',
            style: GoogleFonts.dmSans(),
          ),
          backgroundColor: AppColors.darkSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final nextLesson = module.lessons.firstWhere(
      (l) => !l.isCompleted,
      orElse: () => module.lessons.first,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LessonPlayerScreen(
          lesson: nextLesson,
          module: module,
          course: course,
        ),
      ),
    );
  }

  void _startLearning(BuildContext context) {
    final module = course.modules.firstWhere(
      (m) => !m.isLocked && m.lessons.isNotEmpty,
      orElse: () => course.modules.first,
    );
    _openModule(context, module);
  }

  static String _formatCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textMuted, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.dmMono(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
        ),
      ],
    );
  }
}