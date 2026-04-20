import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/app_state.dart';
import '../widgets/widgets.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  // Bug #1 fix: use a proper TabController so the toggle bar works correctly
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // Force rebuild so the active tab indicator updates
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<AppState>(
      builder: (context, appState, _) {
        final user = appState.user;

        return RefreshIndicator(
          onRefresh: appState.refresh,
          color: AppColors.violet,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track your learning journey',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textMuted,
                          ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // ─── Stats Row ────────────────────────────────────────
              // Bug #7 fix: Stats pulled live from appState.user which is
              // updated from Firestore on every refresh. No stale hardcoded values.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Row(
                  children: [
                    _OverviewStat(
                      value: '${user?.lessonsCompleted ?? 0}',
                      label: 'Lessons\ncompleted',
                      color: AppColors.teal,
                      icon: Icons.check_circle_outline,
                    ),
                    const SizedBox(width: 12),
                    _OverviewStat(
                      value: '${user?.quizzesPassed ?? 0}',
                      label: 'Quizzes\npassed',
                      color: AppColors.violet,
                      icon: Icons.quiz_outlined,
                    ),
                    const SizedBox(width: 12),
                    // Bug #7 fix: streak displayed correctly
                    _OverviewStat(
                      value: '${user?.streakDays ?? 0}',
                      label: 'Day\nstreak',
                      color: AppColors.gold,
                      icon: Icons.local_fire_department,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ─── Bug #1 Fix: Toggle bar using proper TabBar ────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurface2
                        : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    // Use tab indicator that fills the tab
                    indicator: BoxDecoration(
                      color: AppColors.violet,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textMuted,
                    labelStyle: GoogleFonts.dmSans(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    unselectedLabelStyle: GoogleFonts.dmSans(
                        fontSize: 13, fontWeight: FontWeight.w500),
                    indicatorPadding: const EdgeInsets.all(3),
                    tabs: const [
                      Tab(text: 'Roadmaps'),
                      Tab(text: 'Activity'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ─── Tab Content ──────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Course Progress
                    _buildCourseProgressTab(context, appState, isDark),
                    // Tab 2: Weekly Activity
                    _buildActivityTab(context, user, isDark),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCourseProgressTab(
      BuildContext context, AppState appState, bool isDark) {
    return RefreshIndicator(
      onRefresh: appState.refresh,
      color: AppColors.violet,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Roadmap progress if available
            if (appState.activeRoadmap != null) ...[
              Text('My Roadmap',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              _RoadmapProgressCard(
                roadmap: appState.activeRoadmap!,
                isDark: isDark,
              ),
              const SizedBox(height: 20),
            ],

            // Bug #9 fix: course title shown properly, not "$dream Course"
            if (appState.activeCourses.isNotEmpty) ...[
              Text('Course Progress',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 14),
              ...appState.activeCourses.map(
                (course) => _CourseProgressCard(course: course),
              ),
            ],

            if (appState.activeRoadmap == null && appState.activeCourses.isEmpty)
              _buildEmptyState(context, isDark),
          ],
        ),
      ),
    );
  }



  Widget _buildActivityTab(BuildContext context, dynamic user, bool isDark) {
    return SingleChildScrollView(
      physics:
          const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bug #7 fix: weekly activity updated from live user data
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This Week',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                StreakBar(
                  weekActivity:
                      user?.weekActivity ?? List.filled(7, false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Learning Stats',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          _StatTile(
            icon: Icons.play_lesson_outlined,
            label: 'Total Lessons',
            value: '${user?.lessonsCompleted ?? 0}',
            color: AppColors.teal,
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _StatTile(
            icon: Icons.quiz_outlined,
            label: 'Quizzes Passed',
            value: '${user?.quizzesPassed ?? 0}',
            color: AppColors.violet,
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _StatTile(
            icon: Icons.local_fire_department,
            label: 'Current Streak',
            value: '${user?.streakDays ?? 0} days',
            color: AppColors.gold,
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _StatTile(
            icon: Icons.monetization_on_rounded,
            label: 'Gantav Coins',
            value: '${user?.coins ?? 0}',
            color: AppColors.gold,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.school_outlined, color: AppColors.textMuted, size: 48),
          const SizedBox(height: 12),
          Text('No courses in progress',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Start a course to track your journey',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

// ── Roadmap Progress Card ──────────────────────────────────────────────────

class _RoadmapProgressCard extends StatelessWidget {
  final dynamic roadmap;
  final bool isDark;

  const _RoadmapProgressCard({required this.roadmap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.violet.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.violet.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route_rounded, color: AppColors.violet, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  roadmap.title,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textLight : AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${(roadmap.taskProgress * 100).round()}%',
                style: GoogleFonts.dmMono(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.violet,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SimpleProgressBar(progress: roadmap.taskProgress, height: 6),
          const SizedBox(height: 8),
          Text(
            '${roadmap.completedTasks}/${roadmap.totalTasks} tasks • Day ${roadmap.currentDayNumber}/${roadmap.totalDays}',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Stat Tile ─────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: isDark
                      ? AppColors.textLightSub
                      : AppColors.textDarkSub),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.dmMono(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Course Progress Card ───────────────────────────────────────────────────────

class _OverviewStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final IconData icon;

  const _OverviewStat({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.08 : 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.dmMono(
                  fontSize: 20, fontWeight: FontWeight.w700, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseProgressCard extends StatelessWidget {
  final dynamic course;
  const _CourseProgressCard({required this.course});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Bug #5 & #9 fix: Show actual course title, not "$dream Course" placeholder
    final displayTitle =
        (course.title as String).replaceAll('\$dream', course.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
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
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Image.network(
                    course.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.darkSurface2,
                      child: const Icon(Icons.play_circle_outline,
                          color: AppColors.textMuted, size: 22),
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
                      displayTitle, // Fixed title
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${course.completedLessons}/${course.totalLessons} lessons',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                '${(course.progress * 100).round()}%',
                style: GoogleFonts.dmMono(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.progressColor(course.progress),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SimpleProgressBar(progress: course.progress, height: 6),
        ],
      ),
    );
  }
}
