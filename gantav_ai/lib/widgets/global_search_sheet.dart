import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/app_state.dart';
import '../models/models.dart';
import '../models/catalog_data.dart';
import '../models/trending_data.dart';
import '../screens/course_detail_screen.dart';
import 'daily_time_dialog.dart';

/// YouTube-style inline search overlay.
///
/// Opens from the header search icon. As the user types, matching
/// suggestions appear instantly, drawn from:
///   1. their own active/generated courses (highest priority),
///   2. curated trending topics (gradient chip preview),
///   3. catalog subcategories.
///
/// Tapping an existing course opens it; tapping a trending/catalog
/// item kicks off background generation — so search never forces
/// a full screen navigation away from where the user is.
Future<void> showGlobalSearch(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => const _GlobalSearchSheet(),
  );
}

class _GlobalSearchSheet extends StatefulWidget {
  const _GlobalSearchSheet();

  @override
  State<_GlobalSearchSheet> createState() => _GlobalSearchSheetState();
}

class _GlobalSearchSheetState extends State<_GlobalSearchSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Suggestion building ─────────────────────────────────────────────────

  List<_SearchHit> _buildHits(AppState app) {
    final q = _query.trim().toLowerCase();
    final hits = <_SearchHit>[];

    // 1) User's own courses
    for (final c in app.generatedCourses) {
      final title = c.title.replaceAll('\$dream', c.category);
      if (q.isEmpty || _match(title, q) || _match(c.category, q)) {
        hits.add(_SearchHit.myCourse(c, title));
      }
    }

    // 2) Trending (unless user already has a very-similar title)
    for (final t in TrendingData.courses) {
      if (q.isEmpty || _match(t.title, q) || _match(t.tagline, q)) {
        hits.add(_SearchHit.trending(t));
      }
    }

    // 3) Catalog subcategories
    for (final cat in CatalogData.categories) {
      for (final sub in cat.subCategories) {
        if (q.isEmpty || _match(sub.name, q) || _match(sub.description, q)) {
          hits.add(_SearchHit.subCategory(cat, sub));
        }
      }
    }

    // When the query is empty show a compact "Try these" list — the
    // user's courses first (up to 3), then top 4 trending. When the
    // user starts typing, show everything that matches, capped to keep
    // the sheet snappy.
    if (q.isEmpty) {
      final my = hits.where((h) => h.kind == _HitKind.myCourse).take(3);
      final trend = hits.where((h) => h.kind == _HitKind.trending).take(4);
      return [...my, ...trend];
    }
    return hits.take(20).toList();
  }

  bool _match(String haystack, String needle) =>
      haystack.toLowerCase().contains(needle);

  // ── Actions ────────────────────────────────────────────────────────────

  void _onTap(BuildContext context, _SearchHit hit) async {
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop(); // close sheet first

    switch (hit.kind) {
      case _HitKind.myCourse:
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CourseDetailScreen(course: hit.course!)));
        return;

      case _HitKind.trending:
      case _HitKind.subCategory:
        final trending = hit.trending;
        final prompt = trending != null
            ? app.pickTrendingPrompt(trending)
            : (hit.sub?.promptHint ?? '');
        if (prompt.isEmpty) return;
        final dailyMinutes = await showDailyTimeDialog(context);
        app.generateCourseInBackgroundFromCategory(
          prompt,
          dailyMinutes: dailyMinutes,
          allowCurated: trending == null,
        );
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Generating "${hit.label}"...',
                      style:
                          GoogleFonts.dmSans(color: Colors.white, fontSize: 13)),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            backgroundColor: AppColors.violet,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final app = context.watch<AppState>();
    final hits = _buildHits(app);

    return Padding(
      padding: EdgeInsets.only(top: 60, bottom: viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),

            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: GoogleFonts.dmSans(
                    fontSize: 15,
                    color: isDark ? AppColors.textLight : AppColors.textDark),
                textInputAction: TextInputAction.search,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search courses, topics, skills...',
                  hintStyle: TextStyle(
                      color: AppColors.textMuted.withValues(alpha: 0.7)),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.violet, size: 22),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 18, color: AppColors.textMuted),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                        )
                      : IconButton(
                          icon: const Icon(Icons.cancel_outlined,
                              size: 18, color: AppColors.textMuted),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                  filled: true,
                  fillColor: isDark
                      ? AppColors.darkSurface2
                      : AppColors.lightSurface2,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: AppColors.violet, width: 1.5),
                  ),
                ),
              ),
            ),

            // Section hint
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                _query.isEmpty ? 'Try these' : '${hits.length} result${hits.length == 1 ? '' : 's'}',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            // Results
            Flexible(
              child: hits.isEmpty
                  ? _EmptyState(isDark: isDark, query: _query)
                  : ListView.separated(
                      padding:
                          const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      itemCount: hits.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final hit = hits[index];
                        return _HitTile(
                          hit: hit,
                          isDark: isDark,
                          onTap: () => _onTap(context, hit),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data tags for hits ─────────────────────────────────────────────────────

enum _HitKind { myCourse, trending, subCategory }

class _SearchHit {
  final _HitKind kind;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color accent;

  final Course? course; // for myCourse
  final TrendingCourse? trending; // for trending
  final SubCategory? sub; // for subCategory
  final CourseCategory? cat; // for subCategory context

  _SearchHit._({
    required this.kind,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.accent,
    this.course,
    this.trending,
    this.sub,
    this.cat,
  });

  factory _SearchHit.myCourse(Course c, String title) => _SearchHit._(
        kind: _HitKind.myCourse,
        label: title,
        subtitle: 'Your course · ${c.category}',
        icon: Icons.bookmark_rounded,
        accent: AppColors.violet,
        course: c,
      );

  factory _SearchHit.trending(TrendingCourse t) => _SearchHit._(
        kind: _HitKind.trending,
        label: t.title,
        subtitle: t.tagline,
        icon: t.icon,
        accent: t.primary,
        trending: t,
      );

  factory _SearchHit.subCategory(CourseCategory cat, SubCategory sub) =>
      _SearchHit._(
        kind: _HitKind.subCategory,
        label: sub.name,
        subtitle: '${cat.name} · ${sub.description}',
        icon: cat.icon,
        accent: cat.color,
        sub: sub,
        cat: cat,
      );
}

// ── Tile widget ────────────────────────────────────────────────────────────

class _HitTile extends StatelessWidget {
  final _SearchHit hit;
  final bool isDark;
  final VoidCallback onTap;
  const _HitTile(
      {required this.hit, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tag = switch (hit.kind) {
      _HitKind.myCourse => 'Open',
      _HitKind.trending => 'Generate',
      _HitKind.subCategory => 'Generate',
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: hit.accent.withValues(alpha: 0.18)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: hit.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(hit.icon, size: 20, color: hit.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hit.label,
                          style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.textLight
                                  : AppColors.textDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(hit.subtitle,
                          style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textMuted,
                              height: 1.3),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: hit.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(tag,
                      style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: hit.accent,
                          letterSpacing: 0.3)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDark;
  final String query;
  const _EmptyState({required this.isDark, required this.query});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded,
              size: 48,
              color: AppColors.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text('No matches for "$query"',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textLightSub
                      : AppColors.textDarkSub)),
          const SizedBox(height: 6),
          Text('Try simpler keywords — or create a custom course from Explore.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                  fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
