import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Selection result for the course generation dialog
class CourseSelection {
  final int dailyMinutes;
  final String language;

  CourseSelection({required this.dailyMinutes, required this.language});
}

/// A combined dialog that asks for both daily study time and content language.
/// This streamlines the "Trending Now" tap flow as requested by the user.
Future<CourseSelection?> showCourseGenDialog(BuildContext context, {String initialLanguage = 'English'}) async {
  return showModalBottomSheet<CourseSelection>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: true,
    builder: (_) => _CourseGenSheet(initialLanguage: initialLanguage),
  );
}

class _CourseGenSheet extends StatefulWidget {
  final String initialLanguage;
  const _CourseGenSheet({required this.initialLanguage});

  @override
  State<_CourseGenSheet> createState() => _CourseGenSheetState();
}

class _CourseGenSheetState extends State<_CourseGenSheet> {
  static const _presets = [15, 30, 45, 60, 90, 120];
  int _selectedMinutes = 30;
  late String _selectedLang;

  @override
  void initState() {
    super.initState();
    _selectedLang = widget.initialLanguage;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1B27) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              
              Text(
                'Personalize your path',
                style: GoogleFonts.dmSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.textDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),
              
              // Language Selection
              Text(
                'Content Language',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _LangOption(
                    label: '🇬🇧 English',
                    isSelected: _selectedLang == 'English',
                    onTap: () => setState(() => _selectedLang = 'English'),
                  ),
                  const SizedBox(width: 12),
                  _LangOption(
                    label: '🇮🇳 Hindi',
                    isSelected: _selectedLang == 'Hindi',
                    onTap: () => setState(() => _selectedLang = 'Hindi'),
                  ),
                ],
              ),
              
              const SizedBox(height: 28),
              
              // Daily Time Selection
              Text(
                'Daily Study Commitment',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _presets.map((m) {
                  final isSel = m == _selectedMinutes;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedMinutes = m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSel
                            ? AppColors.violet
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.04)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSel ? AppColors.violet : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        '$m min',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          color: isSel ? Colors.white : (isDark ? Colors.white : AppColors.textDark),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 32),
              
              // Primary Action
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(
                    CourseSelection(dailyMinutes: _selectedMinutes, language: _selectedLang)
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.violet,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Generate Course',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LangOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.violet.withValues(alpha: 0.1)
                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.violet : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppColors.violet : (isDark ? Colors.white70 : AppColors.textDark),
            ),
          ),
        ),
      ),
    );
  }
}
