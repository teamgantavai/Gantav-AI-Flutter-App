import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/exam_models.dart';
import '../services/exam_service.dart';
import '../theme/app_theme.dart';

/// Bottom sheet that lets the user customise a mock test before starting:
/// topic chips, year range, difficulty. Returns a [MockTestFilters] or null
/// (null = cancelled / default test).
class MockTestSetupSheet extends StatefulWidget {
  final ExamCategory exam;
  final ExamSubject subject;

  const MockTestSetupSheet({
    super.key,
    required this.exam,
    required this.subject,
  });

  static Future<MockTestFilters?> show(
    BuildContext context, {
    required ExamCategory exam,
    required ExamSubject subject,
  }) {
    return showModalBottomSheet<MockTestFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MockTestSetupSheet(exam: exam, subject: subject),
    );
  }

  @override
  State<MockTestSetupSheet> createState() => _MockTestSetupSheetState();
}

class _MockTestSetupSheetState extends State<MockTestSetupSheet> {
  final Set<String> _selectedTopics = {};
  String? _difficulty; // null = any
  RangeValues _years = const RangeValues(2019, 2024);
  bool _useYears = false;

  // Common topic hints per subject family. Keeps the UI opinionated but safe:
  // they match the `topic` field in our bundled JSON.
  List<String> get _topicSuggestions {
    final sid = widget.subject.id;
    if (sid.endsWith('physics')) {
      return ['Kinematics', 'Thermodynamics', 'Optics', 'Electricity', 'Modern Physics'];
    }
    if (sid.endsWith('chemistry')) {
      return ['Organic', 'Inorganic', 'Physical', 'Equilibrium', 'Bonding'];
    }
    if (sid.endsWith('maths')) {
      return ['Calculus', 'Algebra', 'Trigonometry', 'Probability', 'Vectors'];
    }
    if (sid.endsWith('biology')) {
      return ['Genetics', 'Human Physiology', 'Botany', 'Cell', 'Ecology'];
    }
    if (sid.contains('reasoning')) {
      return ['Coding', 'Series', 'Syllogism', 'Direction', 'Blood Relations'];
    }
    if (sid.contains('quant')) {
      return ['Percentage', 'Time Work', 'Profit Loss', 'Averages', 'Ratio'];
    }
    if (sid.contains('english')) {
      return ['Grammar', 'Synonyms', 'Antonyms', 'Idioms', 'Spelling'];
    }
    if (sid.contains('polity')) {
      return ['Fundamental Rights', 'Parliament', 'Schedules', 'Federalism'];
    }
    if (sid.contains('history')) {
      return ['Ancient', 'Medieval', 'Modern', 'Freedom Struggle'];
    }
    if (sid.contains('geography')) {
      return ['Indian Geography', 'Climatology', 'World Geography', 'Agriculture'];
    }
    if (sid.contains('economy') || sid.contains('awareness')) {
      return ['Monetary Policy', 'Banking', 'Taxation', 'Inflation'];
    }
    if (sid.contains('current')) {
      return ['Schemes', 'Science & Tech', 'International Relations', 'Defence'];
    }
    if (sid.contains('computer')) {
      return ['Hardware', 'Memory', 'Networking', 'Security', 'MS Office'];
    }
    if (sid.contains('gk')) {
      return ['Geography', 'History', 'Polity', 'Science', 'Current Affairs'];
    }
    return ['General'];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark ? AppColors.textLight : AppColors.textDark;
    final accent = widget.exam.gradient.first;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Grab handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded, color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Customise mock test',
                        style: GoogleFonts.dmSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedTopics.clear();
                          _difficulty = null;
                          _useYears = false;
                          _years = const RangeValues(2019, 2024);
                        });
                      },
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    _sectionTitle('Topics', textColor,
                        subtitle: 'Pick any — leave empty for all'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _topicSuggestions.map((t) {
                        final selected = _selectedTopics.contains(t);
                        return FilterChip(
                          label: Text(t),
                          selected: selected,
                          selectedColor: accent.withValues(alpha: 0.2),
                          checkmarkColor: accent,
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                _selectedTopics.add(t);
                              } else {
                                _selectedTopics.remove(t);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('Difficulty', textColor),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        _diffChip('Any', null, accent, textColor),
                        _diffChip('Easy', 'easy', accent, textColor),
                        _diffChip('Medium', 'medium', accent, textColor),
                        _diffChip('Hard', 'hard', accent, textColor),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _sectionTitle('Year range', textColor),
                        ),
                        Switch(
                          value: _useYears,
                          activeColor: accent,
                          onChanged: (v) => setState(() => _useYears = v),
                        ),
                      ],
                    ),
                    if (_useYears) ...[
                      const SizedBox(height: 4),
                      RangeSlider(
                        values: _years,
                        min: 2010,
                        max: 2025,
                        divisions: 15,
                        activeColor: accent,
                        labels: RangeLabels(
                          _years.start.toInt().toString(),
                          _years.end.toInt().toString(),
                        ),
                        onChanged: (v) => setState(() => _years = v),
                      ),
                      Text(
                        '${_years.start.toInt()} – ${_years.end.toInt()}',
                        style: GoogleFonts.dmSans(
                          color: textColor.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                    ] else
                      Text(
                        'All years',
                        style: GoogleFonts.dmSans(
                          color: textColor.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
              // Bottom action bar
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(null),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Default test'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop(
                              MockTestFilters(
                                topics: _selectedTopics.toList(),
                                difficulty: _difficulty,
                                minYear: _useYears ? _years.start.toInt() : null,
                                maxYear: _useYears ? _years.end.toInt() : null,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Start custom mock'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String text, Color color, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: color.withValues(alpha: 0.6),
              ),
            ),
          ),
      ],
    );
  }

  Widget _diffChip(String label, String? value, Color accent, Color textColor) {
    final selected = _difficulty == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: accent.withValues(alpha: 0.2),
      onSelected: (_) => setState(() => _difficulty = value),
    );
  }
}
