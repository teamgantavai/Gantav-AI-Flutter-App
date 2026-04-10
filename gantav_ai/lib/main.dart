import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'services/app_state.dart';
import 'screens/home_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/profile_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
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
          home: const AppShell(),
        );
      },
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
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final screenWidth = MediaQuery.of(context).size.width;
    final useRail = isLandscape && screenWidth > 600;

    return Consumer<AppState>(
      builder: (context, appState, _) {
        if (useRail) {
          return _buildWithRail(context, appState, isDark);
        }
        return _buildWithBottomNav(context, appState, isDark);
      },
    );
  }

  /// Standard portrait layout with bottom navigation
  Widget _buildWithBottomNav(
      BuildContext context, AppState appState, bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ──────────────────────────────────────────
            _GantavHeader(isDark: isDark),
            // ─── Content ─────────────────────────────────────────
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
  }

  /// Landscape layout with side rail navigation
  Widget _buildWithRail(
      BuildContext context, AppState appState, bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: Row(
          children: [
            // ─── Side Rail ──────────────────────────────────────
            _buildSideRail(context, appState, isDark),
            // ─── Content ────────────────────────────────────────
            Expanded(
              child: Column(
                children: [
                  _GantavHeader(isDark: isDark, compact: true),
                  Expanded(
                    child: IndexedStack(
                      index: appState.currentTabIndex,
                      children: _screens,
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

  Widget _buildSideRail(
      BuildContext context, AppState appState, bool isDark) {
    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          right: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Logo
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/images/logo.png',
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 24),
          // Nav items
          ..._navItems.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final isActive = appState.currentTabIndex == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => appState.setTabIndex(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.violet.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isActive ? item.activeIcon : item.icon,
                        size: 22,
                        color:
                            isActive ? AppColors.violet : AppColors.textMuted,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: GoogleFonts.dmSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: isActive
                              ? AppColors.violet
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBottomNav(
      BuildContext context, AppState appState, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 8),
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
                      width: isActive ? 48 : 0,
                      height: 3,
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: AppColors.violet,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    Icon(
                      isActive ? item.activeIcon : item.icon,
                      size: 24,
                      color:
                          isActive ? AppColors.violet : AppColors.textMuted,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w400,
                        color:
                            isActive ? AppColors.violet : AppColors.textMuted,
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

/// Gantav AI header with logo, title, and theme toggle
class _GantavHeader extends StatelessWidget {
  final bool isDark;
  final bool compact;

  const _GantavHeader({required this.isDark, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 20,
        compact ? 8 : 12,
        compact ? 12 : 16,
        compact ? 4 : 8,
      ),
      child: Row(
        children: [
          // Logo
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/logo.png',
              width: compact ? 28 : 32,
              height: compact ? 28 : 32,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(width: compact ? 8 : 10),
          Text(
            'Gantav AI',
            style: GoogleFonts.dmSans(
              fontSize: compact ? 16 : 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textLight : AppColors.textDark,
            ),
          ),
          const Spacer(),
          // Profile setting gear will go in the profile tab instead
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
