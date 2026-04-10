import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/app_state.dart';
import '../widgets/widgets.dart';
import 'course_detail_screen.dart';
import 'dream_input_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _pulseTimer;

  @override
  void initState() {
    super.initState();
    // Auto-cycle pulse events every 5 seconds
    _pulseTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        context.read<AppState>().nextPulseEvent();
      }
    });
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
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
          onRefresh: appState.refresh,
          color: AppColors.violet,
          child: CustomScrollView(
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

              // ─── Dream Card ───────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _DreamCard(
                    dream: appState.dream,
                    onTap: () => _openDreamInput(context),
                    onChangeDream: () => _openDreamInput(context),
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

  void _openDreamInput(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await navigator.push<bool>(
      MaterialPageRoute(builder: (_) => const DreamInputScreen()),
    );
    // Result is true if user accepted a generated path
    if (result == true && mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Your learning path has been created! 🎉',
            style: GoogleFonts.dmSans(),
          ),
          backgroundColor: AppColors.darkSurface,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}

/// Dream card — shows current dream or prompts to set one
class _DreamCard extends StatelessWidget {
  final dynamic dream;
  final VoidCallback onTap;
  final VoidCallback onChangeDream;

  const _DreamCard({
    required this.dream,
    required this.onTap,
    required this.onChangeDream,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasDream = dream != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: hasDream
              ? LinearGradient(
                  colors: [
                    AppColors.violet.withValues(alpha: isDark ? 0.15 : 0.10),
                    AppColors.teal.withValues(alpha: isDark ? 0.08 : 0.05),
                  ],
                )
              : null,
          color: hasDream
              ? null
              : isDark
                  ? AppColors.darkSurface
                  : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasDream
                ? AppColors.violet.withValues(alpha: 0.2)
                : isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: hasDream
                    ? AppColors.violet.withValues(alpha: 0.15)
                    : isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                hasDream ? Icons.auto_awesome : Icons.flag_outlined,
                size: 20,
                color: hasDream ? AppColors.violet : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasDream ? 'Your Dream' : 'Set your dream',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: hasDream ? AppColors.violet : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasDream
                        ? dream.text
                        : 'Tell us what you want to become',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              hasDream ? Icons.edit_outlined : Icons.chevron_right,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
