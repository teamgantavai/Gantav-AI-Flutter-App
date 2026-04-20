import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:gantav_ai/theme/app_theme.dart';
import 'package:gantav_ai/services/app_state.dart';
import 'package:gantav_ai/screens/home_screen.dart';
import 'package:gantav_ai/screens/explore_screen.dart';
import 'package:gantav_ai/screens/progress_screen.dart';
import 'package:gantav_ai/screens/profile_screen.dart';
import 'package:gantav_ai/screens/auth_screen.dart';
import 'package:gantav_ai/screens/onboarding_screen.dart';
import 'package:gantav_ai/screens/roadmap_generation_screen.dart';
import 'package:gantav_ai/screens/course_detail_screen.dart';
import 'package:gantav_ai/screens/splash_screen.dart';
import 'package:gantav_ai/screens/roadmap_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gantav_ai/firebase_options.dart';
import 'package:gantav_ai/widgets/connectivity_wrapper.dart';
import 'package:gantav_ai/widgets/global_search_sheet.dart';
import 'package:gantav_ai/services/api_config.dart';
import 'package:gantav_ai/services/ads_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:gantav_ai/services/notification_service.dart';
import 'package:gantav_ai/widgets/widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  ApiConfig.printStatus();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Firebase Analytics — enabled on all platforms
    final analytics = FirebaseAnalytics.instance;
    await analytics.setAnalyticsCollectionEnabled(true);
    debugPrint('[Firebase] Analytics initialized');

    // Firebase Crashlytics — only on mobile (not supported on web)
    if (!kIsWeb) {
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      // Pass all uncaught asynchronous errors to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      debugPrint('[Firebase] Crashlytics initialized');
    }
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }
  
  // Initialize notifications
  await NotificationService.init();

  // Fire-and-forget AdMob init so startup isn't blocked on Google's SDK
  // handshake. If it fails, ads skip silently (see AdsService.init).
  AdsService.init();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: const GantavAIApp(),
    ),
  );
}

class GantavAIApp extends StatelessWidget {
  const GantavAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return MaterialApp(
          title: 'Gantav AI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: appState.themeMode,
          home: ConnectivityWrapper(child: const _AppRouter()),
        );
      },
    );
  }
}

class _AppRouter extends StatelessWidget {
  const _AppRouter();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        if (appState.isInitialLoading) {
          return const SplashScreen();
        }
        if (appState.authStatus == AuthStatus.needsOnboarding) {
          return const OnboardingScreen();
        }
        if (appState.isGeneratingRoadmap) {
          return const RoadmapGenerationScreen();
        }
        if (appState.isAuthenticated) {
          // Note: background course generation is shown as a persistent
          // banner inside AppShell (see _GenerationBanner) instead of a
          // fullscreen block, so the rest of the app stays usable.
          return const AppShell();
        }
        return const AuthScreen();
      },
    );
  }
}

// ─── App Shell ────────────────────────────────────────────────────────────────

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _screens = [HomeScreen(), ExploreScreen(), ProgressScreen(), ProfileScreen()];

  static const _navItems = [
    _NavItem(Icons.home_rounded, Icons.home_outlined, 'Home'),
    _NavItem(Icons.explore_rounded, Icons.explore_outlined, 'Explore'),
    _NavItem(Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Progress'),
    _NavItem(Icons.person_rounded, Icons.person_outline, 'Profile'),
  ];

  AppState? _appState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _appState = context.read<AppState>();
      _appState?.addListener(_onStateChange);
    });
  }

  @override
  void dispose() {
    _appState?.removeListener(_onStateChange);
    _appState = null;
    super.dispose();
  }

  void _onStateChange() {
    if (!mounted || _appState == null) return;
    if (_appState!.notificationMessage != null) {
      final msg = _appState!.notificationMessage!;
      final completedCourse = _appState!.lastCompletedCourse;
      _appState!.clearNotification();

      final isSuccess = msg.startsWith('Success:');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg.replaceFirst('Success: ', '').replaceFirst('Error: ', ''), style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13)),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: isSuccess ? AppColors.teal : AppColors.violet,
          duration: Duration(seconds: isSuccess ? 6 : 3),
          action: (isSuccess && completedCourse != null)
              ? SnackBarAction(
                  label: 'View Course',
                  textColor: Colors.white,
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseDetailScreen(course: completedCourse))),
                )
              : null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
          body: SafeArea(
            child: Column(
              children: [
                _GantavHeader(isDark: isDark, appState: appState),
                Expanded(
                  child: IndexedStack(
                    index: appState.currentTabIndex,
                    children: _screens,
                  ),
                ),
                if (appState.isGeneratingCourse)
                  _GenerationBanner(isDark: isDark, appState: appState),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomNav(context, appState, isDark),
        );
      },
    );
  }

  Widget _buildBottomNav(BuildContext context, AppState appState, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
      ),
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: _navItems.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final isActive = appState.currentTabIndex == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => appState.setTabIndex(i),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      width: isActive ? 32 : 0,
                      height: 3,
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(color: AppColors.violet, borderRadius: BorderRadius.circular(100)),
                    ),
                    Icon(isActive ? item.activeIcon : item.icon, size: 22, color: isActive ? AppColors.violet : AppColors.textMuted),
                    const SizedBox(height: 4),
                    Text(item.label,
                      style: GoogleFonts.dmSans(fontSize: 11, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400, color: isActive ? AppColors.violet : AppColors.textMuted),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Header with working notification bell ────────────────────────────────────

class _GantavHeader extends StatelessWidget {
  final bool isDark;
  final AppState appState;
  const _GantavHeader({required this.isDark, required this.appState});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
      child: Row(
        children: [
          SizedBox(width: 32, height: 32, child: Image.asset('assets/images/logo.png')),
          const SizedBox(width: 10),
          Text('Gantav', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? AppColors.textLight : AppColors.textDark)),
          Text(' AI', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w300, color: AppColors.violetLight)),
          const Spacer(),
          // Notification bell — now opens notification panel
          GestureDetector(
            onTap: () => _showNotificationPanel(context, isDark),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.notifications_outlined, size: 20, color: isDark ? AppColors.textLightSub : AppColors.textDarkSub),
                  // Notification dot if there's a pending message
                  if (appState.notificationMessage != null)
                    Positioned(
                      top: 6, right: 6,
                      child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Search button — opens inline YouTube-style suggestion sheet
          GestureDetector(
            onTap: () => showGlobalSearch(context),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.search_rounded, size: 20, color: isDark ? AppColors.textLightSub : AppColors.textDarkSub),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotificationPanel(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _NotificationPanel(isDark: isDark),
    );
  }
}

class _NotificationPanel extends StatelessWidget {
  final bool isDark;
  const _NotificationPanel({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final roadmap = appState.activeRoadmap;
    final todayDay = appState.todayRoadmapDay;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.textMuted.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(100))),
          ),
          const SizedBox(height: 20),
          Text('Notifications', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? AppColors.textLight : AppColors.textDark)),
          const SizedBox(height: 16),

          // Today's roadmap tasks notification
          if (todayDay != null && !todayDay.allTasksCompleted)
            _NotifTile(
              icon: Icons.today_outlined,
              iconColor: AppColors.gold,
              title: "Today's Tasks Pending",
              subtitle: '${todayDay.completedTaskCount}/${todayDay.tasks.length} tasks done in ${todayDay.topic}',
              isDark: isDark,
              onTap: roadmap != null ? () { Navigator.pop(context); Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoadmapScreen(roadmap: roadmap))); } : null,
            ),

          if (todayDay != null && todayDay.allTasksCompleted)
            _NotifTile(
              icon: Icons.check_circle_outline,
              iconColor: AppColors.teal,
              title: "Today's Tasks Complete! 🎉",
              subtitle: 'Great work! Keep your streak going tomorrow.',
              isDark: isDark,
            ),

          // Streak notification
          if (appState.user != null && appState.user!.streakDays > 0)
            _NotifTile(
              icon: Icons.local_fire_department,
              iconColor: AppColors.error,
              title: '${appState.user!.streakDays}-Day Streak! 🔥',
              subtitle: 'Keep learning daily to maintain your streak.',
              isDark: isDark,
            ),

          // Course ready notification
          if (appState.lastCompletedCourse != null)
            _NotifTile(
              icon: Icons.auto_awesome,
              iconColor: AppColors.violet,
              title: 'New Course Ready!',
              subtitle: '"${appState.lastCompletedCourse!.title.replaceAll('\$dream', appState.lastCompletedCourse!.category)}" is ready to explore.',
              isDark: isDark,
              onTap: () { Navigator.pop(context); Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseDetailScreen(course: appState.lastCompletedCourse!))); },
            ),

          // Empty state
          if (todayDay == null && appState.user?.streakDays == 0 && appState.lastCompletedCourse == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(Icons.notifications_none_outlined, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    Text('No notifications yet', style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textMuted)),
                    const SizedBox(height: 4),
                    Text('Start your learning journey to get updates.', textAlign: TextAlign.center, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted.withValues(alpha: 0.6))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback? onTap;

  const _NotifTile({required this.icon, required this.iconColor, required this.title, required this.subtitle, required this.isDark, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: iconColor.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.textLight : AppColors.textDark)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (onTap != null) Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData activeIcon;
  final IconData icon;
  final String label;
  const _NavItem(this.activeIcon, this.icon, this.label);
}

// ─── Persistent background-generation banner ─────────────────────────────────
// Shown above the bottom nav while a course is being generated in the
// background. The rest of the app stays interactive — the user sees that
// work is in flight rather than facing a full-screen block.

class _GenerationBanner extends StatelessWidget {
  final bool isDark;
  final AppState appState;
  const _GenerationBanner({required this.isDark, required this.appState});

  @override
  Widget build(BuildContext context) {
    final dream = appState.dream?.text;
    final subtitle = (dream != null && dream.isNotEmpty)
        ? 'Building your course — "$dream"'
        : 'Curating videos & structuring lessons…';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.violet.withValues(alpha: isDark ? 0.22 : 0.14),
            AppColors.violet.withValues(alpha: isDark ? 0.10 : 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.violet.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation(AppColors.violet),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Generating course…',
                  style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.violet,
                      letterSpacing: 0.2),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.textLightSub : AppColors.textDarkSub,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: appState.cancelGeneration,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.close_rounded,
                  size: 18,
                  color: isDark ? AppColors.textLightSub : AppColors.textDarkSub),
            ),
          ),
        ],
      ),
    );
  }
}