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
    isDismissible: false, // Force explicit choice
    enableDrag: false,
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    icon: Icon(Icons.close, color: AppColors.textMuted, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'How much time per day?',
                style: GoogleFonts.dmSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.textDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your roadmap will be sized to fit this daily commitment.',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _presets.map((m) {
                  final isSel = m == _selected;
                  return GestureDetector(
                    onTap: () => setState(() => _selected = m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSel
                            ? AppColors.violet
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.04)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSel
                              ? AppColors.violet
                              : (isDark ? Colors.white10 : Colors.transparent),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        '$m min',
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                          color: isSel
                              ? Colors.white
                              : (isDark ? Colors.white : AppColors.textDark),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.violet,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Build my roadmap',
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

