import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/app_state.dart';
import '../services/error_handler.dart';
import '../models/models.dart';
import '../models/catalog_data.dart';
import '../widgets/widgets.dart';
import 'course_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  bool _showSubCategories = false;
  CourseCategory? _selectedCatalogCategory;

  final List<String> _categories = [
    'All',
    'Machine Learning',
    'Web Development',
    'Computer Science',
    'Mobile Development',
    'Cloud & DevOps',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  List<Course> _filteredCourses(List<Course> courses) {
    return courses.where((course) {
      final matchesSearch = _searchQuery.isEmpty ||
          course.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          course.category.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory =
          _selectedCategory == 'All' || course.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  Future<void> _generateCourseFromSubCategory(SubCategory sub) async {
    final appState = context.read<AppState>();

    // Show generating dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _GeneratingDialog(title: sub.name),
    );

    final course = await appState.generateCourseFromCategory(sub.promptHint);

    if (!mounted) return;
    Navigator.of(context).pop(); // Close dialog

    if (course != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course)),
      );
    } else {
      ErrorHandler.showError(context, 'Could not generate course. Please check your Gemini API key and try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<AppState>(
      builder: (context, appState, _) {
        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Explore', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text('Find your next learning path',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Tab bar: Courses | Categories
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface2,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.violet,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textMuted,
                  labelStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500),
                  indicatorPadding: const EdgeInsets.all(3),
                  tabs: const [
                    Tab(text: 'Courses'),
                    Tab(text: 'Categories'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCoursesTab(appState, isDark),
                  _buildCategoriesTab(isDark),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCoursesTab(AppState appState, bool isDark) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final screenWidth = MediaQuery.of(context).size.width;
    final useGrid = isLandscape || screenWidth > 700;
    final filtered = _filteredCourses(appState.courses);

    return RefreshIndicator(
      onRefresh: appState.refresh,
      color: AppColors.violet,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          // Search bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Search courses, topics...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          icon: const Icon(Icons.clear, color: AppColors.textMuted, size: 18),
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.violet),
                  ),
                ),
              ),
            ),
          ),

          // Category filter
          SliverToBoxAdapter(
            child: SizedBox(
              height: 52,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                physics: const BouncingScrollPhysics(),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = cat == _selectedCategory;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.violet : isDark ? AppColors.darkSurface : AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(100),
                          border: isSelected ? null : Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
                        ),
                        child: Text(cat, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppColors.textMuted)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Results count
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Text('${filtered.length} course${filtered.length != 1 ? 's' : ''} found',
                style: Theme.of(context).textTheme.bodySmall),
            ),
          ),

          // Course list
          if (filtered.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.search_off, color: AppColors.textMuted, size: 48),
                    const SizedBox(height: 14),
                    Text('No courses found', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('Try a different search or category', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            )
          else if (useGrid)
            _buildGrid(filtered)
          else
            _buildList(filtered),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildCategoriesTab(bool isDark) {
    if (_showSubCategories && _selectedCatalogCategory != null) {
      return _buildSubCategoryList(isDark);
    }
    return _buildCategoryGrid(isDark);
  }

  Widget _buildCategoryGrid(bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.4,
      ),
      itemCount: CatalogData.categories.length,
      itemBuilder: (context, index) {
        final cat = CatalogData.categories[index];
        return GestureDetector(
          onTap: () => setState(() {
            _selectedCatalogCategory = cat;
            _showSubCategories = true;
          }),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cat.color.withValues(alpha:0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: cat.color.withValues(alpha:0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: cat.color.withValues(alpha:0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(cat.icon, color: cat.color, size: 22),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cat.name, style: GoogleFonts.dmSans(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textLight : AppColors.textDark,
                    ), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('${cat.subCategories.length} paths',
                      style: GoogleFonts.dmSans(fontSize: 11, color: cat.color, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubCategoryList(bool isDark) {
    final cat = _selectedCatalogCategory!;

    return Column(
      children: [
        // Back + category header
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() {
                  _showSubCategories = false;
                  _selectedCatalogCategory = null;
                }),
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_back, size: 18, color: isDark ? AppColors.textLight : AppColors.textDark),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: cat.color.withValues(alpha:0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(cat.icon, color: cat.color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cat.name, style: Theme.of(context).textTheme.titleLarge),
                    Text('${cat.subCategories.length} learning paths available',
                      style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Sub-category list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            physics: const BouncingScrollPhysics(),
            itemCount: cat.subCategories.length,
            itemBuilder: (context, index) {
              final sub = cat.subCategories[index];
              return GestureDetector(
                onTap: () => _generateCourseFromSubCategory(sub),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: cat.color.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text('${index + 1}',
                            style: GoogleFonts.dmMono(fontSize: 16, fontWeight: FontWeight.w700, color: cat.color)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sub.name, style: GoogleFonts.dmSans(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textLight : AppColors.textDark,
                            )),
                            const SizedBox(height: 4),
                            Text(sub.description,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cat.color.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.auto_awesome, size: 16, color: cat.color),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildList(List<Course> filtered) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final course = filtered[index];
            return _ExploreCourseCard(
              course: course,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course)),
                );
              },
            );
          },
          childCount: filtered.length,
        ),
      ),
    );
  }

  Widget _buildGrid(List<Course> filtered) {
    final rowCount = (filtered.length / 2).ceil();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, rowIndex) {
            final i1 = rowIndex * 2;
            final i2 = i1 + 1;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ExploreCourseCard(
                    course: filtered[i1],
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => CourseDetailScreen(course: filtered[i1])),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 14),
                if (i2 < filtered.length)
                  Expanded(
                    child: _ExploreCourseCard(
                      course: filtered[i2],
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => CourseDetailScreen(course: filtered[i2])),
                        );
                      },
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
              ],
            );
          },
          childCount: rowCount,
        ),
      ),
    );
  }
}

/// Dialog shown while generating course from category
class _GeneratingDialog extends StatelessWidget {
  final String title;
  const _GeneratingDialog({required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: AppColors.violet.withValues(alpha:0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.auto_awesome, color: AppColors.violet, size: 28),
            ),
            const SizedBox(height: 20),
            Text('Generating Course', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Creating a $title learning path with AI...',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4)),
            const SizedBox(height: 24),
            const SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.violet),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExploreCourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback onTap;

  const _ExploreCourseCard({required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      course.thumbnailUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.darkSurface2,
                        child: const Center(child: Icon(Icons.play_circle_outline, color: AppColors.textMuted, size: 40)),
                      ),
                    ),
                    Positioned(
                      top: 10, right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, color: AppColors.gold, size: 14),
                            const SizedBox(width: 3),
                            Text(course.rating.toStringAsFixed(1),
                              style: GoogleFonts.dmMono(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.violet.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(course.category,
                            style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.violet),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.people_outline, color: AppColors.textMuted, size: 14),
                      const SizedBox(width: 4),
                      Text(_formatCount(course.learnerCount), style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(course.title, style: Theme.of(context).textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text(course.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.play_lesson_outlined, color: AppColors.textMuted, size: 14),
                      const SizedBox(width: 4),
                      Flexible(child: Text('${course.totalLessons} lessons', style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 14),
                      Icon(Icons.schedule_outlined, color: AppColors.textMuted, size: 14),
                      const SizedBox(width: 4),
                      Flexible(child: Text(course.estimatedTime, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  if (course.isInProgress) ...[
                    const SizedBox(height: 10),
                    SimpleProgressBar(progress: course.progress, height: 4),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }
}
