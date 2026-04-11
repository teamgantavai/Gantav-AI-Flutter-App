import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'services/app_state.dart';
import 'screens/home_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/auth_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }
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
          home: const _AppRouter(),
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
        // Still loading initial state
        if (appState.isLoading && !appState.isAuthenticated) {
          return const _SplashScreen();
        }

        // Not authenticated → onboarding
        if (!appState.isAuthenticated) {
          return const AuthScreen();
        }

        // Generating course (psychological hook — show progress)
        if (appState.isGeneratingCourse) {
          return const _GeneratingScreen();
        }

        // Main app
        return const AppShell();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 72, height: 72,
              child: Image.asset('assets/images/logo.png'),
            ),
            const SizedBox(height: 16),
            Text('Gantav AI',
              style: GoogleFonts.dmSans(
                fontSize: 24, fontWeight: FontWeight.w800,
                color: isDark ? AppColors.textLight : AppColors.textDark,
              )),
          ],
        ),
      ),
    );
  }
}

/// Shown while AI generates the course — psychological hook
class _GeneratingScreen extends StatefulWidget {
  const _GeneratingScreen();

  @override
  State<_GeneratingScreen> createState() => _GeneratingScreenState();
}

class _GeneratingScreenState extends State<_GeneratingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _progressCtrl;
  late Animation<double> _progressAnim;
  bool _showBackButton = false;
  bool _timedOut = false;

  final List<String> _steps = [
    'Analysing your dream...',
    'Searching YouTube for the best content...',
    'Curating top-rated videos...',
    'Structuring your learning modules...',
    'Building your personalised path...',
    'Almost ready! ✨',
  ];
  int _stepIdx = 0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _progressCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8));
    _progressAnim = Tween<double>(begin: 0, end: 0.92).animate(CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut));
    _progressCtrl.forward();

    // Show back button after 15 seconds
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted) setState(() => _showBackButton = true);
    });

    // Timeout after 90 seconds
    Future.delayed(const Duration(seconds: 90), () {
      if (mounted && !_timedOut) {
        setState(() => _timedOut = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Course generation is taking too long. Please try again.',
              style: GoogleFonts.dmSans()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        // Cancel generation
        context.read<AppState>().cancelGeneration();
      }
    });

    // Cycle through steps
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 1100));
      if (!mounted) return false;
      setState(() => _stepIdx = (_stepIdx + 1) % _steps.length);
      return true;
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dream = context.watch<AppState>().dream?.text ?? '';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated logo
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Transform.scale(
                  scale: 1.0 + _pulseCtrl.value * 0.06,
                  child: SizedBox(
                    width: 80, height: 80,
                    child: Image.asset('assets/images/logo.png'),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              Text('Building your path',
                style: GoogleFonts.dmSans(
                  fontSize: 28, fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.textLight : AppColors.textDark,
                  letterSpacing: -0.5,
                )),

              const SizedBox(height: 12),

              // Dream chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flag_outlined, color: AppColors.gold, size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(dream,
                        style: GoogleFonts.dmSans(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: AppColors.gold,
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // Progress bar
              AnimatedBuilder(
                animation: _progressAnim,
                builder: (_, __) {
                  return Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: LinearProgressIndicator(
                          value: _progressAnim.value,
                          minHeight: 6,
                          backgroundColor: isDark
                              ? AppColors.darkSurface2
                              : AppColors.lightSurface2,
                          valueColor: const AlwaysStoppedAnimation(AppColors.violet),
                        ),
                      ),
                      const SizedBox(height: 16),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: Text(
                          _steps[_stepIdx],
                          key: ValueKey(_stepIdx),
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            color: isDark ? AppColors.textLightSub : AppColors.textDarkSub,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 32),

              // Back / Cancel button — appears after delay
              AnimatedOpacity(
                opacity: _showBackButton ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: _showBackButton
                    ? TextButton.icon(
                        onPressed: () {
                          context.read<AppState>().cancelGeneration();
                        },
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: Text('Taking too long? Go back',
                          style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500)),
                        style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
                      )
                    : const SizedBox(),
              ),

              const SizedBox(height: 32),

              // Social proof
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ProofBadge(icon: Icons.people_outline, text: '10K+ learners'),
                  const SizedBox(width: 24),
                  _ProofBadge(icon: Icons.star_outline, text: '4.9 rating'),
                  const SizedBox(width: 24),
                  _ProofBadge(icon: Icons.play_circle_outline, text: 'YouTube powered'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProofBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ProofBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textMuted, size: 18),
        const SizedBox(height: 4),
        Text(text, style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

/// Main app shell with persistent header + bottom nav / side rail
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  static const _screens = [
    HomeScreen(),
    ExploreScreen(),
    ProgressScreen(),
    ProfileScreen(),
  ];

  static const _navItems = [
    _NavItem(Icons.home_rounded, Icons.home_outlined, 'Home'),
    _NavItem(Icons.explore_rounded, Icons.explore_outlined, 'Explore'),
    _NavItem(Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Progress'),
    _NavItem(Icons.person_rounded, Icons.person_outline, 'Profile'),
  ];

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
                _GantavHeader(isDark: isDark),
                Expanded(
                  child: IndexedStack(
                    index: appState.currentTabIndex,
                    children: _screens,
                  ),
                ),
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
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
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
            return GestureDetector(
              onTap: () => appState.setTabIndex(i),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 64,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      width: isActive ? 32 : 0,
                      height: 3,
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: AppColors.violet,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    Icon(
                      isActive ? item.activeIcon : item.icon,
                      size: 22,
                      color: isActive ? AppColors.violet : AppColors.textMuted,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        color: isActive ? AppColors.violet : AppColors.textMuted,
                      ),
                    ),
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

class _GantavHeader extends StatelessWidget {
  final bool isDark;
  const _GantavHeader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
      child: Row(
        children: [
          SizedBox(
            width: 32, height: 32,
            child: Image.asset('assets/images/logo.png'),
          ),
          const SizedBox(width: 10),
          Text('Gantav',
            style: GoogleFonts.dmSans(
              fontSize: 18, fontWeight: FontWeight.w800,
              color: isDark ? AppColors.textLight : AppColors.textDark,
            )),
          Text(' AI',
            style: GoogleFonts.dmSans(
              fontSize: 18, fontWeight: FontWeight.w300,
              color: AppColors.violetLight,
            )),
        ],
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
