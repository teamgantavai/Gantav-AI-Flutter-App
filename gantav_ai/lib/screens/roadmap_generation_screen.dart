import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/app_state.dart';

/// Animated loading screen shown while AI generates the roadmap
class RoadmapGenerationScreen extends StatefulWidget {
  const RoadmapGenerationScreen({super.key});

  @override
  State<RoadmapGenerationScreen> createState() => _RoadmapGenerationScreenState();
}

class _RoadmapGenerationScreenState extends State<RoadmapGenerationScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _progressCtrl;
  late Animation<double> _progressAnim;
  bool _showBackButton = false;
  bool _timedOut = false;

  final List<String> _steps = [
    'Analysing your preferences...',
    'Matching your learning style...',
    'Designing day-by-day curriculum...',
    'Adding tasks and exercises...',
    'Finding the best resources...',
    'Wrapping up your roadmap... ✨',
  ];
  int _stepIdx = 0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
        ..repeat(reverse: true);
    _progressCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 10));
    _progressAnim = Tween<double>(begin: 0, end: 0.90).animate(
        CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut));
    _progressCtrl.forward();

    // Show back button after 20 seconds
    Future.delayed(const Duration(seconds: 20), () {
      if (mounted) setState(() => _showBackButton = true);
    });

    // Timeout after 120 seconds
    Future.delayed(const Duration(seconds: 120), () {
      if (mounted && !_timedOut) {
        setState(() => _timedOut = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Roadmap generation is taking too long. Please try again.',
              style: GoogleFonts.dmSans()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        context.read<AppState>().cancelGeneration();
      }
    });

    // Cycle through steps
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 1300));
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
    final appState = context.watch<AppState>();
    final prefs = appState.preferences;

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
                  child: Container(
                    width: 88, height: 88,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.violet.withValues(alpha: _pulseCtrl.value * 0.15),
                          blurRadius: 30,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Image.asset('assets/images/logo.png'),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              Text('Creating your roadmap',
                style: GoogleFonts.dmSans(
                  fontSize: 26, fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.textLight : AppColors.textDark,
                  letterSpacing: -0.5,
                )),

              const SizedBox(height: 14),

              // Preferences chips
              if (prefs != null)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _PrefChip(
                      icon: Icons.translate_rounded,
                      text: prefs.language == 'hi' ? 'हिन्दी' : 'English',
                      color: AppColors.violet,
                    ),
                    _PrefChip(
                      icon: Icons.flag_outlined,
                      text: prefs.learningGoal,
                      color: AppColors.gold,
                    ),
                    _PrefChip(
                      icon: Icons.timer_outlined,
                      text: '${prefs.dailyStudyMinutes} min/day',
                      color: AppColors.teal,
                    ),
                    if (prefs.preferredTeacher != null && prefs.preferredTeacher!.isNotEmpty)
                      _PrefChip(
                        icon: Icons.person_outline,
                        text: prefs.preferredTeacher!,
                        color: AppColors.violetLight,
                      ),
                  ],
                ),

              const SizedBox(height: 40),

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
                          backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
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
                            fontSize: 14,
                            color: isDark ? AppColors.textLightSub : AppColors.textDarkSub,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 36),

              // Back / Cancel button
              AnimatedOpacity(
                opacity: _showBackButton ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: _showBackButton
                    ? TextButton.icon(
                        onPressed: () => context.read<AppState>().cancelGeneration(),
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: Text('Taking too long? Go back',
                          style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500)),
                        style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
                      )
                    : const SizedBox(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrefChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _PrefChip({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text,
              style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: color),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
