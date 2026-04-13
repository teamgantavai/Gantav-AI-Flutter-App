import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/app_state.dart';
import '../models/onboarding_models.dart';

/// Modern 4-step poll-based onboarding screen
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _currentStep = 0;

  // Selections
  String _selectedLanguage = '';
  String _selectedGoal = '';
  final TextEditingController _teacherCtrl = TextEditingController();
  int _selectedMinutes = 0;

  // Animation
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  final List<String> _goals = [
    'Prepare for exams',
    'Learn coding',
    'Improve skills',
    'Build projects',
    'Learn a specific subject',
  ];

  final List<IconData> _goalIcons = [
    Icons.school_outlined,
    Icons.code_rounded,
    Icons.trending_up_rounded,
    Icons.build_circle_outlined,
    Icons.menu_book_outlined,
  ];

  final List<Map<String, dynamic>> _timeOptions = [
    {'minutes': 15, 'label': '15 min', 'icon': Icons.timer_outlined, 'desc': 'Quick daily session'},
    {'minutes': 20, 'label': '20 min', 'icon': Icons.timer_outlined, 'desc': 'Short and focused'},
    {'minutes': 30, 'label': '30 min', 'icon': Icons.timer, 'desc': 'Balanced pace'},
    {'minutes': 45, 'label': '45 min', 'icon': Icons.hourglass_bottom, 'desc': 'Steady progress'},
    {'minutes': 60, 'label': '1 hour', 'icon': Icons.hourglass_full, 'desc': 'Deep learning'},
    {'minutes': 120, 'label': '2 hours', 'icon': Icons.rocket_launch_outlined, 'desc': 'Intensive mode'},
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _teacherCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  bool get _canProceed {
    switch (_currentStep) {
      case 0: return _selectedLanguage.isNotEmpty;
      case 1: return _selectedGoal.isNotEmpty;
      case 2: return true; // Optional step
      case 3: return _selectedMinutes > 0;
      default: return false;
    }
  }

  void _goNext() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _pageCtrl.animateToPage(_currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic);
    } else {
      _submitOnboarding();
    }
  }

  void _goBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageCtrl.animateToPage(_currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic);
    }
  }

  Future<void> _submitOnboarding() async {
    final prefs = UserPreferences(
      language: _selectedLanguage,
      learningGoal: _selectedGoal,
      preferredTeacher: _teacherCtrl.text.trim().isEmpty ? null : _teacherCtrl.text.trim(),
      dailyStudyMinutes: _selectedMinutes,
      createdAt: DateTime.now(),
    );

    await context.read<AppState>().completeOnboarding(prefs);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              // ── Header with progress ──────────────────────────────
              _buildHeader(isDark),

              // ── Page content ──────────────────────────────────────
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildLanguageStep(isDark),
                    _buildGoalStep(isDark),
                    _buildTeacherStep(isDark),
                    _buildTimeStep(isDark),
                  ],
                ),
              ),

              // ── Bottom navigation ─────────────────────────────────
              _buildBottomBar(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        children: [
          // Logo + step counter
          Row(
            children: [
              SizedBox(width: 28, height: 28, child: Image.asset('assets/images/logo.png')),
              const SizedBox(width: 8),
              Text('Gantav', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800,
                color: isDark ? AppColors.textLight : AppColors.textDark)),
              Text(' AI', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w300, color: AppColors.violetLight)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.violet.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text('${_currentStep + 1} / 4',
                  style: GoogleFonts.dmMono(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.violet)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (_currentStep + 1) / 4),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 4,
                backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                valueColor: const AlwaysStoppedAnimation(AppColors.violet),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 1: Language Selection
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLanguageStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepIcon(Icons.translate_rounded, AppColors.violet),
          const SizedBox(height: 20),
          Text('Choose your language',
            style: GoogleFonts.dmSans(fontSize: 26, fontWeight: FontWeight.w800,
              color: isDark ? AppColors.textLight : AppColors.textDark, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text('Your courses and AI tutor will use this language',
            style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textMuted, height: 1.5)),
          const SizedBox(height: 32),
          _LanguageCard(
            flag: '🇬🇧',
            title: 'English',
            subtitle: 'International courses & content',
            isSelected: _selectedLanguage == 'en',
            onTap: () => setState(() => _selectedLanguage = 'en'),
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          _LanguageCard(
            flag: '🇮🇳',
            title: 'हिन्दी',
            subtitle: 'Hindi medium courses & content',
            isSelected: _selectedLanguage == 'hi',
            onTap: () => setState(() => _selectedLanguage = 'hi'),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 2: Learning Goal
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildGoalStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepIcon(Icons.flag_rounded, AppColors.gold),
          const SizedBox(height: 20),
          Text('What do you want to do?',
            style: GoogleFonts.dmSans(fontSize: 26, fontWeight: FontWeight.w800,
              color: isDark ? AppColors.textLight : AppColors.textDark, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text('We\'ll personalize your roadmap based on this',
            style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textMuted, height: 1.5)),
          const SizedBox(height: 28),
          ...List.generate(_goals.length, (i) {
            final isSelected = _selectedGoal == _goals[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => setState(() => _selectedGoal = _goals[i]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.violet.withValues(alpha: 0.12)
                        : isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.violet.withValues(alpha: 0.5)
                          : isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.violet.withValues(alpha: 0.15)
                              : isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_goalIcons[i], size: 20,
                          color: isSelected ? AppColors.violet : AppColors.textMuted),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(_goals[i],
                          style: GoogleFonts.dmSans(
                            fontSize: 15, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? AppColors.violet
                                : isDark ? AppColors.textLight : AppColors.textDark)),
                      ),
                      if (isSelected)
                        Container(
                          width: 24, height: 24,
                          decoration: const BoxDecoration(
                            color: AppColors.violet, shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, size: 14, color: Colors.white),
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

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 3: Preferred Teacher (Optional)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTeacherStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepIcon(Icons.person_search_rounded, AppColors.teal),
          const SizedBox(height: 20),
          Text('Any favourite teacher?',
            style: GoogleFonts.dmSans(fontSize: 26, fontWeight: FontWeight.w800,
              color: isDark ? AppColors.textLight : AppColors.textDark, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text('We\'ll try to include their content in your roadmap',
            style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textMuted, height: 1.5)),
          const SizedBox(height: 28),
          TextField(
            controller: _teacherCtrl,
            style: GoogleFonts.dmSans(fontSize: 15,
              color: isDark ? AppColors.textLight : AppColors.textDark),
            decoration: InputDecoration(
              hintText: 'e.g. CodeWithHarry, freeCodeCamp...',
              prefixIcon: const Icon(Icons.play_circle_outline, color: AppColors.textMuted),
              filled: true,
              fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.violet, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Popular suggestions
          Text('Popular channels',
            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'freeCodeCamp', 'CodeWithHarry', 'Traversy Media', 'Fireship',
              'TechWithTim', '3Blue1Brown', 'Khan Academy', 'Apna College',
            ].map((name) => GestureDetector(
              onTap: () => setState(() => _teacherCtrl.text = name),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _teacherCtrl.text == name
                      ? AppColors.teal.withValues(alpha: 0.12)
                      : isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: _teacherCtrl.text == name
                        ? AppColors.teal.withValues(alpha: 0.4)
                        : isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Text(name,
                  style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500,
                    color: _teacherCtrl.text == name ? AppColors.teal : AppColors.textMuted)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 24),
          // Skip hint
          Center(
            child: Text('This step is optional — you can skip it',
              style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted.withValues(alpha: 0.6))),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 4: Daily Study Time
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTimeStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepIcon(Icons.schedule_rounded, AppColors.gold),
          const SizedBox(height: 20),
          Text('Daily study time?',
            style: GoogleFonts.dmSans(fontSize: 26, fontWeight: FontWeight.w800,
              color: isDark ? AppColors.textLight : AppColors.textDark, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text('How much time can you dedicate each day?',
            style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textMuted, height: 1.5)),
          const SizedBox(height: 28),
          ...List.generate(_timeOptions.length, (i) {
            final opt = _timeOptions[i];
            final isSelected = _selectedMinutes == opt['minutes'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => setState(() => _selectedMinutes = opt['minutes'] as int),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.gold.withValues(alpha: 0.1)
                        : isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.gold.withValues(alpha: 0.5)
                          : isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(opt['icon'] as IconData, size: 20,
                        color: isSelected ? AppColors.gold : AppColors.textMuted),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(opt['label'] as String,
                              style: GoogleFonts.dmSans(
                                fontSize: 15, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.gold
                                    : isDark ? AppColors.textLight : AppColors.textDark)),
                            Text(opt['desc'] as String,
                              style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Container(
                          width: 24, height: 24,
                          decoration: const BoxDecoration(
                            color: AppColors.gold, shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, size: 14, color: Colors.white),
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

  // ═══════════════════════════════════════════════════════════════════════════
  // BOTTOM BAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.lightBg,
        border: Border(top: BorderSide(
          color: isDark ? AppColors.darkBorder.withValues(alpha: 0.3) : AppColors.lightBorder.withValues(alpha: 0.3),
        )),
      ),
      child: Row(
        children: [
          // Back button
          if (_currentStep > 0)
            GestureDetector(
              onTap: _goBack,
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Icon(Icons.arrow_back_rounded, size: 20,
                  color: isDark ? AppColors.textLight : AppColors.textDark),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),

          // Next / Submit button
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 52,
              child: ElevatedButton(
                onPressed: _canProceed ? _goNext : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canProceed ? AppColors.violet : AppColors.textMuted.withValues(alpha: 0.2),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                  disabledForegroundColor: AppColors.textMuted,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _currentStep == 3 ? 'Generate My Roadmap' : _currentStep == 2 ? 'Skip / Next' : 'Next',
                      style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    Icon(_currentStep == 3 ? Icons.auto_awesome : Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepIcon(IconData icon, Color color) {
    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: color, size: 26),
    );
  }
}

// ── Language Card ────────────────────────────────────────────────────────────

class _LanguageCard extends StatelessWidget {
  final String flag;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _LanguageCard({
    required this.flag, required this.title, required this.subtitle,
    required this.isSelected, required this.onTap, required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.violet.withValues(alpha: 0.1)
              : isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.violet.withValues(alpha: 0.5)
                : isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.violet.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ] : null,
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 36)),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                    style: GoogleFonts.dmSans(
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppColors.violet
                          : isDark ? AppColors.textLight : AppColors.textDark)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                    style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textMuted)),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 28, height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.violet, shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 16, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}
