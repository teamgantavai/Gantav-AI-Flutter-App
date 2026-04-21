import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/app_state.dart';
import '../widgets/widgets.dart';
import '../widgets/daily_time_dialog.dart';
import '../widgets/course_gen_dialog.dart';

import '../widgets/inline_ad_card.dart';
import 'course_detail_screen.dart';
import 'roadmap_screen.dart';
import 'coin_store_screen.dart';
import '../models/models.dart';
import '../models/trending_data.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  // coin-fly animation
  late AnimationController _coinCtrl;
  late Animation<double> _coinFlyAnim;
  late Animation<double> _coinFadeAnim;
  int _pendingCoins = 0;
  bool _showCoinBurst = false;

  // streak confetti / flame-pulse
  late AnimationController _streakCtrl;
  late Animation<double> _streakPulse;
  bool _showStreakBurst = false;
  int _burstStreak = 0;

  @override
  void initState() {
    super.initState();

    _coinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _coinFlyAnim = Tween<double>(begin: 0, end: -80).animate(
      CurvedAnimation(parent: _coinCtrl, curve: Curves.easeOut),
    );
    _coinFadeAnim = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _coinCtrl, curve: const Interval(0.5, 1.0)),
    );

    _streakCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _streakPulse = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _streakCtrl, curve: Curves.elasticOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenToAppState();
    });
  }

  void _listenToAppState() {
    final appState = context.read<AppState>();
    appState.addListener(_onAppStateChanged);
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    final appState = context.read<AppState>();

    final coinEvent = appState.coinEarnedEvent;
    if (coinEvent != null) {
      setState(() {
        _pendingCoins = coinEvent.coins;
        _showCoinBurst = true;
      });
      appState.clearCoinEarnedEvent();
      _coinCtrl.forward(from: 0).then((_) {
        if (mounted) setState(() => _showCoinBurst = false);
      });
    }

    final streakEvent = appState.streakBumpEvent;
    if (streakEvent != null) {
      setState(() {
        _burstStreak = streakEvent.newStreak;
        _showStreakBurst = true;
      });
      appState.clearStreakBumpEvent();
      _streakCtrl.forward(from: 0).then((_) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showStreakBurst = false);
        });
      });
    }
  }

  @override
  void dispose() {
    final appState = context.read<AppState>();
    appState.removeListener(_onAppStateChanged);
    _coinCtrl.dispose();
    _streakCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _generateTrending(BuildContext context, TrendingCourse course) async {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    
    final currentLangCode = appState.trendingCardLang(course);
    final initialLang = currentLangCode == 'hi' ? 'Hindi' : 'English';
    
    final selection = await showCourseGenDialog(context, initialLanguage: initialLang);
    if (selection == null) return;
    if (!mounted) return;
    
    appState.generateCourseInBackgroundFromCategory(
      appState.pickTrendingPrompt(course),
      dailyMinutes: selection.dailyMinutes == 0 ? null : selection.dailyMinutes,
      allowCurated: false,
      language: selection.language,
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

        final activeCourses = appState.activeCourses;
        final suggestedCourses = appState.suggestedCourses;
        final activeRoadmap = appState.activeRoadmap;
        final greeting = appState.greeting;

        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async => appState.refresh(),
              color: AppColors.violet,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  // ─── Greeting ───────────────────────────────────────
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

                  // ─── Roadmap Card ───────────────────────────────────
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

                  // ─── Score + Streak Row ─────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: Row(
                        children: [
                          // Coin chip — tapping opens the Coin Store
                          _CoinStatChip(
                            coins: user.coins,
                            showBurst: _showCoinBurst,
                            pendingCoins: _pendingCoins,
                            flyAnim: _coinFlyAnim,
                            fadeAnim: _coinFadeAnim,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const CoinStoreScreen()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _StreakStatChip(
                            streakDays: user.streakDays,
                            pulseAnim: _streakPulse,
                            showBurst: _showStreakBurst,
                            burstStreak: _burstStreak,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ─── Continue Learning ──────────────────────────────
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

                  // ─── Trending Now ───────────────────────────────────
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
                      height: 210,
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
                              currentLang: appState.trendingCardLang(course),
                              onTap: () => _generateTrending(context, course),
                              onLangToggle: (lang) =>
                                  appState.setTrendingCardLang(course, lang),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // ─── Suggested for you ──────────────────────────────
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
            ),

            // streak burst overlay
            if (_showStreakBurst)
              _StreakBurstOverlay(
                streak: _burstStreak,
                pulseAnim: _streakPulse,
              ),
          ],
        );
      },
    );
  }

  Widget _buildPortraitSuggestions(List<Course> courses) {
    const adEvery = 6;
    final slotCount = courses.length + (courses.length ~/ adEvery);
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= slotCount) return null;
          if ((index + 1) % (adEvery + 1) == 0) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: InlineAdCard(),
            );
          }
          final courseIdx = index - (index ~/ (adEvery + 1));
          if (courseIdx >= courses.length) return null;
          final course = courses[courseIdx];
          return RepaintBoundary(
            child: SuggestedCourseRow(
              course: course,
              onTap: () => _navigateToCourse(context, course),
            ),
          );
        },
        childCount: slotCount,
      ),
    );
  }

  Widget _buildLandscapeSuggestions(List<Course> courses) {
    final rowCount = (courses.length / 2).ceil();
    const adEveryRows = 3;
    final slotCount = rowCount + (rowCount ~/ adEveryRows);
    
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= slotCount) return null;
          
          if ((index + 1) % (adEveryRows + 1) == 0) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: InlineAdCard(),
            );
          }
          
          final rowIndex = index - (index ~/ (adEveryRows + 1));
          if (rowIndex >= rowCount) return null;
          
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
        childCount: slotCount,
      ),
    );
  }

  void _navigateToCourse(BuildContext context, dynamic course) {
    if (course is Course && course.id.startsWith('default_')) {
      context.read<AppState>().setTabIndex(1);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course)));
  }
}

// ─── Coin stat chip ───────────────────────────────────────────────────────────

class _CoinStatChip extends StatelessWidget {
  final int coins;
  final bool showBurst;
  final int pendingCoins;
  final Animation<double> flyAnim;
  final Animation<double> fadeAnim;
  final VoidCallback onTap; // ← new

  const _CoinStatChip({
    required this.coins,
    required this.showBurst,
    required this.pendingCoins,
    required this.flyAnim,
    required this.fadeAnim,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── tappable chip ──────────────────────────────────────────
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Ink(
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.08 : 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      const Text('🪙', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$coins',
                                style: GoogleFonts.dmSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFF59E0B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text('Coins',
                                style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppColors.textLightSub
                                        : AppColors.textDarkSub),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      // small store icon hint
                      Icon(Icons.storefront_rounded,
                          size: 14,
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.6)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ── flying coin burst label ────────────────────────────────
          if (showBurst)
            Positioned(
              top: 0,
              left: 20,
              child: AnimatedBuilder(
                animation: flyAnim,
                builder: (_, __) => Transform.translate(
                  offset: Offset(0, flyAnim.value),
                  child: Opacity(
                    opacity: fadeAnim.value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF59E0B)
                                .withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Text('+$pendingCoins 🪙',
                          style: GoogleFonts.dmSans(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Streak stat chip ─────────────────────────────────────────────────────────

class _StreakStatChip extends StatelessWidget {
  final int streakDays;
  final Animation<double> pulseAnim;
  final bool showBurst;
  final int burstStreak;

  const _StreakStatChip({
    required this.streakDays,
    required this.pulseAnim,
    required this.showBurst,
    required this.burstStreak,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: AnimatedBuilder(
        animation: pulseAnim,
        builder: (_, child) => Transform.scale(
          scale: showBurst ? pulseAnim.value : 1.0,
          child: child,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.teal.withValues(alpha: isDark ? 0.08 : 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: showBurst
                  ? AppColors.teal.withValues(alpha: 0.5)
                  : AppColors.teal.withValues(alpha: 0.15),
              width: showBurst ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.local_fire_department,
                  color: AppColors.teal, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$streakDays',
                        style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.teal),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text('Day streak',
                        style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.textLightSub
                                : AppColors.textDarkSub),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Streak burst overlay ─────────────────────────────────────────────────────

class _StreakBurstOverlay extends StatelessWidget {
  final int streak;
  final Animation<double> pulseAnim;
  const _StreakBurstOverlay({required this.streak, required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 120,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedBuilder(
          animation: pulseAnim,
          builder: (_, __) => Transform.scale(
            scale: pulseAnim.value,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.teal,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.teal.withValues(alpha: 0.45),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Text('$streak-day streak!',
                      style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Trending Course Card ─────────────────────────────────────────────────────

class _TrendingCourseCard extends StatelessWidget {
  final TrendingCourse course;
  final String currentLang;
  final VoidCallback onTap;
  final void Function(String lang) onLangToggle;

  const _TrendingCourseCard({
    required this.course,
    required this.currentLang,
    required this.onTap,
    required this.onLangToggle,
  });

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
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(course.icon, color: Colors.white, size: 20),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () =>
                            onLangToggle(currentLang == 'en' ? 'hi' : 'en'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                currentLang == 'hi' ? '🇮🇳' : '🇬🇧',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                currentLang == 'hi' ? 'HI' : 'EN',
                                style: GoogleFonts.dmSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(course.badge,
                            style: GoogleFonts.dmSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.4)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    course.title,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.2,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    course.tagline,
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.play_circle_fill_rounded,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.9)),
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

  const _RoadmapCard(
      {required this.roadmap, required this.todayDay, required this.onTap});

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
              AppColors.teal.withValues(alpha: isDark ? 0.08 : 0.05)
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: AppColors.violet.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: AppColors.violet.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.route_rounded,
                      size: 20, color: AppColors.violet),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('My Roadmap',
                          style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.violet)),
                      const SizedBox(height: 2),
                      Text(roadmap.title,
                          style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.textLight
                                  : AppColors.textDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Text('$pct%',
                    style: GoogleFonts.dmMono(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.violet)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: roadmap.taskProgress,
                minHeight: 5,
                backgroundColor: isDark
                    ? AppColors.darkSurface2
                    : AppColors.lightSurface2,
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.violet),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                    allDoneToday
                        ? Icons.check_circle
                        : Icons.today_outlined,
                    size: 14,
                    color:
                        allDoneToday ? AppColors.teal : AppColors.gold),
                const SizedBox(width: 6),
                Text(
                  allDoneToday
                      ? "Today's tasks complete! 🎉"
                      : 'Today: $todayDone/$todayTotal tasks done',
                  style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: allDoneToday
                          ? AppColors.teal
                          : AppColors.textMuted),
                ),
                const Spacer(),
                Text('Day ${roadmap.currentDayNumber}/${roadmap.totalDays}',
                    style: GoogleFonts.dmMono(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}