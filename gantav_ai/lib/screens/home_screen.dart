import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/app_state.dart';
import '../widgets/widgets.dart';
import '../widgets/daily_time_dialog.dart';
import 'course_detail_screen.dart';
import 'roadmap_screen.dart';
import 'exam_detail_screen.dart';
import '../models/models.dart';
import '../models/exam_models.dart';
import '../models/trending_data.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  // Hoisted once — the exam catalog is `static const`, no reason to
  // re-fetch it every build (the old code called the method twice per
  // SliverGrid rebuild, once for childCount and once per item).
  static final List<ExamCategory> _exams = ExamCategory.catalog();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _generateTrending(BuildContext context, TrendingCourse course) async {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final dailyMinutes = await showDailyTimeDialog(context);
    if (!mounted) return;
    appState.generateCourseInBackgroundFromCategory(
      appState.pickTrendingPrompt(course),
      dailyMinutes: dailyMinutes,
      allowCurated: false,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Generating "${course.title}"...',
                style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13)),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.violet,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Consumer<AppState>(
      builder: (context, appState, _) {
        if (appState.isLoading) return const HomeShimmer();

        final user = appState.user;
        if (user == null) return const SizedBox();

        // Hoist expensive getters once per build. These getters each
        // allocate a new list (dedup + filter) — calling them inside
        // itemBuilders multiplied that cost by N items before. See
        // AppState.activeCourses / suggestedCourses / courses.
        final activeCourses = appState.activeCourses;
        final suggestedCourses = appState.suggestedCourses;
        final activeRoadmap = appState.activeRoadmap;
        final greeting = appState.greeting;

        return RefreshIndicator(
          onRefresh: () async {
            await appState.refresh();
          },
          color: AppColors.violet,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // ─── Greeting ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$greeting, ${user.name.split(' ').first}',
                        style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 4),
                      Text('Your destination is waiting. Keep going.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ),

              // ─── Roadmap Card ───────────────────────────────────────
              if (activeRoadmap != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: RepaintBoundary(
                      child: _RoadmapCard(
                        roadmap: activeRoadmap,
                        todayDay: appState.todayRoadmapDay,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => RoadmapScreen(roadmap: activeRoadmap)),
                        ),
                      ),
                    ),
                  ),
                ),

              // ─── Score + Streak Row ─────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(
                    children: [
                      StatChip(icon: Icons.stars_rounded, label: 'Gantav Score', value: '${user.gantavScore}', color: AppColors.gold),
                      const SizedBox(width: 12),
                      StatChip(icon: Icons.local_fire_department, label: 'Day streak', value: '${user.streakDays}', color: AppColors.teal),
                    ],
                  ),
                ),
              ),

              // ─── Exam Prep Grid ─────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: SectionHeader(
                    title: 'Exam Preparation',
                    actionText: 'All exams',
                    onAction: () {},
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Text(
                    'Timed mock tests with AI-generated PYQ-style questions (2024–2026 pattern).',
                    style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted, height: 1.4),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isLandscape ? 4 : 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.95,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final exam = _exams[index];
                      return RepaintBoundary(
                        child: _ExamCard(
                          exam: exam,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ExamDetailScreen(exam: exam),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: _exams.length,
                  ),
                ),
              ),

              // ─── Continue Learning ──────────────────────────────────
              if (activeCourses.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: SectionHeader(
                      title: 'Continue learning',
                      actionText: 'See all',
                      onAction: () {},
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: isLandscape ? 300 : 360,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      physics: const BouncingScrollPhysics(),
                      itemCount: activeCourses.length,
                      itemBuilder: (context, index) {
                        final course = activeCourses[index];
                        return RepaintBoundary(
                          child: ActiveCourseCard(
                            course: course,
                            onTap: () => _navigateToCourse(context, course),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],

              // ─── Trending Now ───────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: SectionHeader(
                    title: 'Trending Now 🔥',
                    actionText: 'See all',
                    onAction: () => context.read<AppState>().setTabIndex(1),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 190,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    physics: const BouncingScrollPhysics(),
                    itemCount: TrendingData.courses.length,
                    itemBuilder: (context, index) {
                      final course = TrendingData.courses[index];
                      return RepaintBoundary(
                        child: _TrendingCourseCard(
                          course: course,
                          onTap: () => _generateTrending(context, course),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // ─── Suggested for you ──────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: SectionHeader(
                    title: 'Suggested for you',
                    actionText: 'Explore',
                    onAction: () => context.read<AppState>().setTabIndex(1),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: isLandscape
                    ? _buildLandscapeSuggestions(suggestedCourses)
                    : _buildPortraitSuggestions(suggestedCourses),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPortraitSuggestions(List<Course> courses) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= courses.length) return null;
          final course = courses[index];
          return RepaintBoundary(
            child: SuggestedCourseRow(
              course: course,
              onTap: () => _navigateToCourse(context, course),
            ),
          );
        },
        childCount: courses.length,
      ),
    );
  }

  Widget _buildLandscapeSuggestions(List<Course> courses) {
    final rowCount = (courses.length / 2).ceil();
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, rowIndex) {
          final i1 = rowIndex * 2;
          final i2 = i1 + 1;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (i1 < courses.length)
                Expanded(
                  child: RepaintBoundary(
                    child: SuggestedCourseRow(
                      course: courses[i1],
                      onTap: () => _navigateToCourse(context, courses[i1]),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              if (i2 < courses.length)
                Expanded(
                  child: RepaintBoundary(
                    child: SuggestedCourseRow(
                      course: courses[i2],
                      onTap: () => _navigateToCourse(context, courses[i2]),
                    ),
                  ),
                )
              else
                const Expanded(child: SizedBox()),
            ],
          );
        },
        childCount: rowCount,
      ),
    );
  }

  void _navigateToCourse(BuildContext context, dynamic course) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course)));
  }
}

// ─── Trending Course Card (Seekho-style) ─────────────────────────────────────

class _TrendingCourseCard extends StatelessWidget {
  final TrendingCourse course;
  final VoidCallback onTap;
  const _TrendingCourseCard({required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14, top: 8, bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            width: 230,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [course.primary, course.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: course.primary.withValues(alpha: 0.30),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(course.icon, color: Colors.white, size: 22),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          course.badge,
                          style: GoogleFonts.dmSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.title,
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        course.tagline,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.88),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.play_circle_fill_rounded,
                              size: 14, color: Colors.white.withValues(alpha: 0.9)),
                          const SizedBox(width: 5),
                          Text(
                            'Tap to generate',
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Roadmap Card ─────────────────────────────────────────────────────────────

class _RoadmapCard extends StatelessWidget {
  final Roadmap roadmap;
  final RoadmapDay? todayDay;
  final VoidCallback onTap;

  const _RoadmapCard({required this.roadmap, required this.todayDay, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pct = (roadmap.taskProgress * 100).round();
    final todayDone = todayDay?.completedTaskCount ?? 0;
    final todayTotal = todayDay?.tasks.length ?? 0;
    final allDoneToday = todayDay?.allTasksCompleted ?? false;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.violet.withValues(alpha: isDark ? 0.15 : 0.10), AppColors.teal.withValues(alpha: isDark ? 0.08 : 0.05)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.violet.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.violet.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.route_rounded, size: 20, color: AppColors.violet),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('My Roadmap', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.violet)),
                      const SizedBox(height: 2),
                      Text(roadmap.title, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? AppColors.textLight : AppColors.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Text('$pct%', style: GoogleFonts.dmMono(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.violet)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: roadmap.taskProgress,
                minHeight: 5,
                backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                valueColor: const AlwaysStoppedAnimation(AppColors.violet),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(allDoneToday ? Icons.check_circle : Icons.today_outlined, size: 14, color: allDoneToday ? AppColors.teal : AppColors.gold),
                const SizedBox(width: 6),
                Text(
                  allDoneToday ? "Today's tasks complete! 🎉" : 'Today: $todayDone/$todayTotal tasks done',
                  style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500, color: allDoneToday ? AppColors.teal : AppColors.textMuted),
                ),
                const Spacer(),
                Text('Day ${roadmap.currentDayNumber}/${roadmap.totalDays}', style: GoogleFonts.dmMono(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Exam Card ───────────────────────────────────────────────────────────────

class _ExamCard extends StatelessWidget {
  final ExamCategory exam;
  final VoidCallback onTap;
  const _ExamCard({required this.exam, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: exam.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: exam.gradient.first.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top row: icon + difficulty badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(exam.icon, color: Colors.white, size: 18),
                    ),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          exam.difficulty,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Middle: name + tagline (flexes to avoid overflow)
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        exam.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        exam.tagline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                // Bottom stats row — each stat in Flexible so they shrink gracefully
                Row(
                  children: [
                    Icon(Icons.menu_book_rounded, size: 11, color: Colors.white.withValues(alpha: 0.8)),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        '${exam.subjects.length} subjects',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.assignment_rounded, size: 11, color: Colors.white.withValues(alpha: 0.8)),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        '${exam.mockTestCount}+ tests',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}