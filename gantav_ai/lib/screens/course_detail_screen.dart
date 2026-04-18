import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/app_state.dart';
import '../services/certificate_service.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';
import 'certificate_screen.dart';
import 'lesson_player_screen.dart';

class CourseDetailScreen extends StatelessWidget {
  final Course course;

  const CourseDetailScreen({super.key, required this.course});

  String _getDisplayTitle(Course c) => c.title
      .replaceAll('\$dream', c.category)
      .replaceAll('Complete  Course', 'Complete ${c.category} Course');

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final activeCourse = appState.courses.firstWhere(
          (c) => c.id == course.id,
          orElse: () => course,
        );

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final isLandscape =
            MediaQuery.of(context).orientation == Orientation.landscape;
        final screenWidth = MediaQuery.of(context).size.width;
        final useWideLayout = isLandscape && screenWidth > 700;

        if (useWideLayout) {
          return _buildWideLayout(context, isDark, activeCourse);
        }
        return _buildNarrowLayout(context, isDark, activeCourse);
      },
    );
  }

  Widget _buildNarrowLayout(
      BuildContext context, bool isDark, Course currentCourse) {
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(context, isDark, currentCourse),
          _buildThumbnail(context, currentCourse),
          _buildCourseInfo(context, isDark, currentCourse),
          _buildModuleList(context, isDark, currentCourse),
          SliverToBoxAdapter(
            child: _buildCertifiedBadge(context, isDark, currentCourse),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      bottomNavigationBar: _buildBottomCTA(context, isDark, currentCourse),
    );
  }

  Widget _buildWideLayout(
      BuildContext context, bool isDark, Course currentCourse) {
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
                      _getDisplayTitle(currentCourse),
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
                          _buildThumbnailWidget(context, currentCourse),
                          const SizedBox(height: 16),
                          _buildInfoContent(context, isDark, currentCourse),
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
                          child: Text(
                            'Modules',
                            style:
                                Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: currentCourse.modules.length,
                            itemBuilder: (context, index) {
                              return _buildModuleCard(
                                  context,
                                  isDark,
                                  currentCourse.modules[index],
                                  index,
                                  currentCourse);
                            },
                          ),
                        ),
                        _buildCertifiedBadge(context, isDark, currentCourse),
                        _buildBottomCTA(context, isDark, currentCourse),
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

  SliverAppBar _buildAppBar(
      BuildContext context, bool isDark, Course currentCourse) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.08),
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
        _getDisplayTitle(currentCourse),
        style: Theme.of(context).textTheme.titleLarge,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  SliverToBoxAdapter _buildThumbnail(
      BuildContext context, Course currentCourse) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _buildThumbnailWidget(context, currentCourse),
      ),
    );
  }

  Widget _buildThumbnailWidget(
      BuildContext context, Course currentCourse) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              currentCourse.thumbnailUrl,
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
        ),
        if (currentCourse.isVerified)
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.5), width: 0.5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified,
                      color: AppColors.gold, size: 14),
                  const SizedBox(width: 6),
                  Text('GANTAV VERIFIED',
                      style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: AppColors.gold,
                          letterSpacing: 0.8)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  SliverToBoxAdapter _buildCourseInfo(
      BuildContext context, bool isDark, Course currentCourse) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoContent(context, isDark, currentCourse),
            Text('Modules', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoContent(
      BuildContext context, bool isDark, Course currentCourse) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (currentCourse.isVerified)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.verified, color: AppColors.gold, size: 16),
                const SizedBox(width: 6),
                Text('Hand-picked and curated by Gantav Team',
                    style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gold)),
              ],
            ),
          ),
        Text(
          _getDisplayTitle(currentCourse),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          currentCourse.description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
                height: 1.5,
              ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: currentCourse.isVerified
                    ? AppColors.gold.withValues(alpha: 0.12)
                    : AppColors.violet.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
                border: currentCourse.isVerified
                    ? Border.all(
                        color: AppColors.gold.withValues(alpha: 0.3),
                        width: 0.5)
                    : null,
              ),
              child: Text(
                currentCourse.isVerified
                    ? 'Gantav Verified'
                    : currentCourse.category,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: currentCourse.isVerified
                      ? AppColors.gold
                      : AppColors.violet,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (currentCourse.skills.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: currentCourse.skills.map((skill) {
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
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
                        color: isDark
                            ? AppColors.textLight
                            : AppColors.textDark,
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
                value: '${currentCourse.totalLessons}',
                label: 'lessons',
              ),
              Container(
                  width: 1,
                  height: 36,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.08)),
              _StatItem(
                icon: Icons.calendar_today_outlined,
                value: currentCourse.estimatedTime
                        .replaceAll(' weeks', '')
                        .isEmpty
                    ? '8'
                    : currentCourse.estimatedTime.replaceAll(' weeks', ''),
                label: 'weeks',
              ),
              Container(
                  width: 1,
                  height: 36,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.08)),
              _StatItem(
                icon: Icons.people_outline,
                value: _formatCount(currentCourse.learnerCount),
                label: 'learners',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (currentCourse.isInProgress) ...[
          SimpleProgressBar(
              progress: currentCourse.progress, height: 8),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '${currentCourse.completedLessons}/${currentCourse.totalLessons} lessons completed',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${(currentCourse.progress * 100).round()}%',
                style: GoogleFonts.dmMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.progressColor(currentCourse.progress),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _buildModuleCard(BuildContext context, bool isDark, Module module,
      int index, Course currentCourse) {
    bool isActuallyLocked = false;
    if (index > 0) {
      final prevModule = currentCourse.modules[index - 1];
      isActuallyLocked = prevModule.completedCount < prevModule.lessonCount;
    }

    return GestureDetector(
      onTap: isActuallyLocked
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Finish previous modules to unlock this!',
                      style: GoogleFonts.dmSans()),
                  backgroundColor: AppColors.violet,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          : () => _openModule(context, module, currentCourse),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isActuallyLocked ? 0.4 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: !module.isLocked
                  ? AppColors.violet.withValues(alpha: 0.2)
                  : isDark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isActuallyLocked
                      ? AppColors.textMuted.withValues(alpha: 0.1)
                      : AppColors.violet.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: isActuallyLocked
                      ? const Icon(Icons.lock_rounded,
                          size: 18, color: AppColors.textMuted)
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.title,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textLight
                            : AppColors.textDark,
                      ),
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
                      SimpleProgressBar(
                          progress: module.progress, height: 4),
                    ],
                  ],
                ),
              ),
              if (!module.isLocked)
                const Icon(Icons.chevron_right,
                    size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  SliverPadding _buildModuleList(
      BuildContext context, bool isDark, Course currentCourse) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= currentCourse.modules.length) return null;
            return _buildModuleCard(context, isDark,
                currentCourse.modules[index], index, currentCourse);
          },
          childCount: currentCourse.modules.length,
        ),
      ),
    );
  }

  /// Promo-style badge shown at the bottom of the modules list whenever the
  /// course is eligible for a Gantav AI certificate. Visible from the start
  /// (not only on completion) so learners know a certificate awaits them.
  Widget _buildCertifiedBadge(
      BuildContext context, bool isDark, Course currentCourse) {
    if (!CertificateService.isEligible(currentCourse.category)) {
      return const SizedBox.shrink();
    }
    final isComplete = currentCourse.totalLessons > 0 &&
        currentCourse.completedLessons >= currentCourse.totalLessons;
    final subtitle = isComplete
        ? 'All lessons complete — claim your certificate.'
        : 'Finish all lessons to unlock your verified certificate.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.gold.withValues(alpha: isDark ? 0.18 : 0.14),
              AppColors.violet.withValues(alpha: isDark ? 0.20 : 0.12),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.22),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.6),
                ),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: AppColors.gold,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Gantav Certified',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.goldLight
                              : AppColors.goldDark,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: isDark
                            ? AppColors.goldLight
                            : AppColors.goldDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: isDark
                          ? Colors.white70
                          : AppColors.textMuted,
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

  Widget _buildBottomCTA(
      BuildContext context, bool isDark, Course currentCourse) {
    // A course is complete when all lessons are watched
    final isComplete = currentCourse.totalLessons > 0 &&
        currentCourse.completedLessons >= currentCourse.totalLessons;

    // Certificate eligible: any completed course (not exam prep categories)
    final certEligible =
        isComplete && CertificateService.isEligible(currentCourse.category);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.lightBg,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: certEligible
          ? Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () =>
                          _startLearning(context, currentCourse),
                      child: Text(
                        'Review',
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _getCertificate(context, currentCourse),
                      icon: const Icon(
                          Icons.workspace_premium_rounded),
                      label: Text(
                        'Get Certificate',
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () =>
                    _startLearning(context, currentCourse),
                child: Text(
                  currentCourse.isInProgress
                      ? 'Continue learning'
                      : 'Start learning',
                  style: GoogleFonts.dmSans(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
    );
  }

  Future<void> _getCertificate(
      BuildContext context, Course currentCourse) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final appState = context.read<AppState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      ),
    );

    try {
      final user = appState.user ?? UserProfile.mock();
      final cert = await CertificateService.issueCertificate(
        course: currentCourse,
        user: user,
      );
      navigator.pop(); // close progress dialog
      navigator.push(
        MaterialPageRoute(
          builder: (_) => CertificateScreen(certificate: cert),
        ),
      );
    } catch (e) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Could not issue certificate: $e')),
      );
    }
  }

  void _openModule(
      BuildContext context, Module module, Course currentCourse) {
    if (module.lessons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lessons for "${module.title}" are loading...',
            style: GoogleFonts.dmSans(),
          ),
          backgroundColor: AppColors.darkSurface,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          course: currentCourse,
        ),
      ),
    );
  }

  void _startLearning(BuildContext context, Course currentCourse) {
    final module = currentCourse.modules.firstWhere(
      (m) =>
          m.completedCount < m.lessonCount && m.lessons.isNotEmpty,
      orElse: () => currentCourse.modules.first,
    );
    _openModule(context, module, currentCourse);
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

  const _StatItem(
      {required this.icon, required this.value, required this.label});

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
          style:
              Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
        ),
      ],
    );
  }
}