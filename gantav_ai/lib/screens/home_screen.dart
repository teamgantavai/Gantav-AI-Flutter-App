import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/app_state.dart';
import '../services/gemini_service.dart';
import '../services/recommendation_service.dart';
import '../widgets/widgets.dart';
import 'course_detail_screen.dart';
import 'roadmap_screen.dart';
import 'lesson_player_screen.dart';
import '../models/models.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  List<Map<String, String>> _recommendations = [];
  bool _loadingRecs = true;
  bool _loadingMoreRecs = false;
  int _recPage = 0;
  Timer? _pulseTimer;

  @override
  void initState() {
    super.initState();
    _pulseTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) context.read<AppState>().nextPulseEvent();
    });
    
    _scrollController.addListener(_onScroll);
    _loadRecommendations(reset: true);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 300) {
      _loadMoreRecommendations();
    }
  }

  Future<void> _loadRecommendations({bool reset = false}) async {
    if (reset) {
      if (mounted) setState(() { _loadingRecs = true; _recPage = 0; });
    }
    
    final appState = context.read<AppState>();
    final recs = await GeminiService.generateRecommendations(
      dream: appState.dream?.text,
      categories: appState.activeCourses.map((c) => c.category).toList(),
      page: _recPage,
    );
    
    if (mounted) {
      setState(() {
        if (reset) _recommendations = recs;
        else _recommendations.addAll(recs);
        _loadingRecs = false;
        _loadingMoreRecs = false;
      });
    }
  }

  Future<void> _loadMoreRecommendations() async {
    if (_loadingMoreRecs) return;
    if (mounted) setState(() { _loadingMoreRecs = true; _recPage++; });
    await _loadRecommendations(reset: false);
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Consumer<AppState>(
      builder: (context, appState, _) {
        if (appState.isLoading) {
          return const HomeShimmer();
        }

        final user = appState.user;
        if (user == null) return const SizedBox();

        return RefreshIndicator(
          onRefresh: () async {
            await appState.refresh();
            await _loadRecommendations();
          },
          color: AppColors.violet,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // ─── Greeting ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${appState.greeting}, ${user.name.split(' ').first}',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your destination is waiting. Keep going.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textMuted,
                            ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Roadmap Progress Card ─────────────────────────
              if (appState.activeRoadmap != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _RoadmapCard(
                      roadmap: appState.activeRoadmap!,
                      todayDay: appState.todayRoadmapDay,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RoadmapScreen(roadmap: appState.activeRoadmap!),
                        ),
                      ),
                    ),
                  ),
                ),

              // ─── Score + Streak Row ───────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(
                    children: [
                      StatChip(
                        icon: Icons.stars_rounded,
                        label: 'Gantav Score',
                        value: '${user.gantavScore}',
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: 12),
                      StatChip(
                        icon: Icons.local_fire_department,
                        label: 'Day streak',
                        value: '${user.streakDays}',
                        color: AppColors.teal,
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Social Pulse ─────────────────────────────────────
              if (appState.currentPulseEvent != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: PulseEventTile(
                        key: ValueKey(appState.currentPulseEvent!.id),
                        event: appState.currentPulseEvent!,
                      ),
                    ),
                  ),
                ),

              // ─── Continue Learning ────────────────────────────────
              if (appState.activeCourses.isNotEmpty) ...[
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
                      itemCount: appState.activeCourses.length,
                      itemBuilder: (context, index) {
                        final course = appState.activeCourses[index];
                        return ActiveCourseCard(
                          course: course,
                          onTap: () => _navigateToCourse(context, course),
                        );
                      },
                    ),
                  ),
                ),
              ],

              // ─── Today's Picks (Daily Recommendations) ────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: SectionHeader(
                    title: "Today's Picks 🔥",
                    actionText: 'Refresh',
                    onAction: () async {
                      setState(() => _loadingRecs = true);
                      // Clear cache to force refresh
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('recommendation_date');
                      await _loadRecommendations();
                    },
                  ),
                ),
              ),
              if (_loadingRecs)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.violet)),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _recommendations.length,
                      itemBuilder: (context, index) {
                        final rec = _recommendations[index];
                        return _RecommendationCard(rec: rec);
                      },
                    ),
                  ),
                ),

              // ─── Suggested for you ────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: SectionHeader(
                    title: 'Suggested for you',
                    actionText: 'Explore',
                    onAction: () {},
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: isLandscape
                    ? _buildLandscapeSuggestions(appState)
                    : _buildPortraitSuggestions(appState),
              ),

              // Bottom padding for nav bar
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPortraitSuggestions(AppState appState) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final courses = appState.suggestedCourses;
          if (index >= courses.length) return null;
          final course = courses[index];
          return SuggestedCourseRow(
            course: course,
            onTap: () => _navigateToCourse(context, course),
          );
        },
        childCount: appState.suggestedCourses.length,
      ),
    );
  }

  Widget _buildLandscapeSuggestions(AppState appState) {
    // 2-column grid in landscape
    final courses = appState.suggestedCourses;
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
                  child: SuggestedCourseRow(
                    course: courses[i1],
                    onTap: () => _navigateToCourse(context, courses[i1]),
                  ),
                ),
              const SizedBox(width: 12),
              if (i2 < courses.length)
                Expanded(
                  child: SuggestedCourseRow(
                    course: courses[i2],
                    onTap: () => _navigateToCourse(context, courses[i2]),
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CourseDetailScreen(course: course),
      ),
    );
  }

}

/// Recommendation video card
class _RecommendationCard extends StatelessWidget {
  final Map<String, String> rec;
  const _RecommendationCard({required this.rec});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final videoId = rec['video_id'] ?? '';
    final thumbnailUrl = 'https://img.youtube.com/vi/$videoId/0.jpg';

    return GestureDetector(
      onTap: () {
        if (videoId.isEmpty) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LessonPlayerScreen(
              course: Course(
                id: 'rec_$videoId',
                title: 'Recommendation: ${rec['category'] ?? 'Pick'}',
                description: 'A recommended video based on your interests.',
                category: rec['category'] ?? '',
                thumbnailUrl: thumbnailUrl,
              ),
              module: const Module(
                id: 'mod_rec',
                title: 'Recommendations',
                lessonCount: 1,
              ),
              lesson: Lesson(
                id: 'les_rec_$videoId',
                title: rec['title'] ?? 'Video',
                duration: rec['duration'] ?? '',
                youtubeVideoId: videoId,
              ),
            ),
          ),
        );
      },
      child: Container(
        width: 240,
        margin: const EdgeInsets.only(right: 14, top: 8, bottom: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
                  height: 110,
                  width: 240,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => CachedNetworkImage(
                    imageUrl: 'https://img.youtube.com/vi/$videoId/0.jpg',
                    height: 110,
                    width: 240,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      height: 110, width: 240,
                      color: AppColors.darkSurface2,
                      child: const Icon(Icons.play_circle_outline, color: AppColors.textMuted, size: 32),
                    ),
                  ),
                ),
                // Duration badge
                Positioned(
                  bottom: 6, right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(rec['duration'] ?? '',
                      style: GoogleFonts.dmMono(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
                // Category badge
                Positioned(
                  top: 6, left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.violet.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(rec['category'] ?? '',
                      style: GoogleFonts.dmSans(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          // Info
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rec['title'] ?? '',
                  style: GoogleFonts.dmSans(
                    fontSize: 12, fontWeight: FontWeight.w600, height: 1.3,
                    color: isDark ? AppColors.textLight : AppColors.textDark,
                  ),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(rec['channel'] ?? '',
                  style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}

/// Roadmap progress card — replaces DreamCard on the home screen
class _RoadmapCard extends StatelessWidget {
  final Roadmap roadmap;
  final RoadmapDay? todayDay;
  final VoidCallback onTap;

  const _RoadmapCard({
    required this.roadmap,
    required this.todayDay,
    required this.onTap,
  });

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
            colors: [
              AppColors.violet.withValues(alpha: isDark ? 0.15 : 0.10),
              AppColors.teal.withValues(alpha: isDark ? 0.08 : 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.violet.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.violet.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.route_rounded, size: 20, color: AppColors.violet),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('My Roadmap',
                        style: GoogleFonts.dmSans(
                          fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.violet)),
                      const SizedBox(height: 2),
                      Text(roadmap.title,
                        style: GoogleFonts.dmSans(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textLight : AppColors.textDark),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Text('$pct%',
                  style: GoogleFonts.dmMono(
                    fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.violet)),
              ],
            ),
            const SizedBox(height: 12),
            // Progress bar
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
            // Today's task status
            Row(
              children: [
                Icon(
                  allDoneToday ? Icons.check_circle : Icons.today_outlined,
                  size: 14,
                  color: allDoneToday ? AppColors.teal : AppColors.gold,
                ),
                const SizedBox(width: 6),
                Text(
                  allDoneToday
                      ? 'Today\'s tasks complete! 🎉'
                      : 'Today: $todayDone/$todayTotal tasks done',
                  style: GoogleFonts.dmSans(
                    fontSize: 12, fontWeight: FontWeight.w500,
                    color: allDoneToday ? AppColors.teal : AppColors.textMuted),
                ),
                const Spacer(),
                Text('Day ${roadmap.currentDayNumber}/${roadmap.totalDays}',
                  style: GoogleFonts.dmMono(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
