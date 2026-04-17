import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Prompts the user for daily study minutes. Returns the chosen minutes, or
/// null if dismissed. Used to size the generated roadmap against the user's
/// actual availability instead of a fixed "10-day" bucket.
Future<int?> showDailyTimeDialog(BuildContext context) async {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _DailyTimeSheet(),
  );
}

class _DailyTimeSheet extends StatefulWidget {
  const _DailyTimeSheet();

  @override
  State<_DailyTimeSheet> createState() => _DailyTimeSheetState();
}

class _DailyTimeSheetState extends State<_DailyTimeSheet> {
  static const _presets = [15, 30, 45, 60, 90, 120];
  int _selected = 30;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1B27) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              Text(
                'How much time per day?',
                style: GoogleFonts.dmSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your roadmap will be sized to fit this. You can change it later.',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _presets.map((m) {
                  final isSel = m == _selected;
                  return GestureDetector(
                    onTap: () => setState(() => _selected = m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSel
                            ? AppColors.violet
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.04)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSel
                              ? AppColors.violet
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        '$m min',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          color: isSel
                              ? Colors.white
                              : (isDark ? Colors.white : AppColors.textDark),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.violet,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Build my roadmap',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: Text(
                  'Skip — just create the course',
                  style: GoogleFonts.dmSans(
                    color: isDark ? Colors.white54 : AppColors.textMuted,
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
