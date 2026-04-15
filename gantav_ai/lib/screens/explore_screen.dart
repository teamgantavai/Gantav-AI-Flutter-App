import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/app_state.dart';
import '../models/models.dart';
import '../models/catalog_data.dart';
import '../widgets/widgets.dart';
import 'course_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  bool _showSubCategories = false;
  CourseCategory? _selectedCatalogCategory;

  final ScrollController _scrollController = ScrollController();

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
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final appState = context.read<AppState>();
      if (!appState.isLoadingMore && !appState.isLoading) {
        appState.generateNextCourseBatch();
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _scrollController.dispose();
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

    // Start background generation immediately
    appState.generateCourseInBackgroundFromCategory(sub.promptHint);

    // Show brief toast
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Generating "${sub.name}" course in background...',
                style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.violet,
        duration: const Duration(seconds: 3),
      ),
    );

    // Go back to category list
    setState(() {
      _showSubCategories = false;
      _selectedCatalogCategory = null;
    });
  }

  void _showCustomCourseBuilder(BuildContext context) {
    String customGoal = '';
    String customTeacher = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What do you want to learn?',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              onChanged: (v) => customGoal = v,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g., Next.js for Beginners',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: (v) => customTeacher = v,
              decoration: InputDecoration(
                hintText: 'Preferred Teacher (Optional)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.violet,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  if (customGoal.isNotEmpty) {
                    final prompt =
                        '$customGoal ${customTeacher.isNotEmpty ? 'taught by $customTeacher' : ''}';
                    _generateCourseWithProfessionalUI(prompt);
                  }
                },
                child: const Text('Generate with AI'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _generateCourseWithProfessionalUI(String promptHint) async {
    final appState = context.read<AppState>();

    // Start background generation
    appState.generateCourseInBackgroundFromCategory(promptHint);

    // Show brief toast
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Generating course in background...',
                style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.violet,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<AppState>(
      builder: (context, appState, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Explore',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text('Find your next learning path',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Tab bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface2,
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
                  labelStyle: GoogleFonts.dmSans(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: GoogleFonts.dmSans(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  indicatorPadding: const EdgeInsets.all(3),
                  tabs: const [
                    Tab(text: 'Courses'),
                    Tab(text: 'Categories'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

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
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final screenWidth = MediaQuery.of(context).size.width;
    final useGrid = isLandscape || screenWidth > 700;
    final filtered = _filteredCourses(appState.courses);

    return RefreshIndicator(
      onRefresh: appState.refresh,
      color: AppColors.violet,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        slivers: [
          // Search bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: TextField(
                controller: _searchController,
                onChanged: (value) =>
                    setState(() => _searchQuery = value),
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Search courses, topics...',
                  prefixIcon: const Icon(Icons.search,
                      color: AppColors.textMuted, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          icon: const Icon(Icons.clear,
                              color: AppColors.textMuted, size: 18),
                        )
                      : null,
                  filled: true,
                  fillColor: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.06)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.06)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.violet),
                  ),
                ),
              ),
            ),
          ),

          // Custom Course Builder Button
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: InkWell(
                onTap: () => _showCustomCourseBuilder(context),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.violet, AppColors.teal],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.auto_awesome,
                            color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Create Custom Course',
                                style: GoogleFonts.dmSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                            Text('Tell AI exactly what you want to learn',
                                style: GoogleFonts.dmSans(
                                    fontSize: 13, color: Colors.white70)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios,
                          color: Colors.white, size: 16),
                    ],
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
                      onTap: () =>
                          setState(() => _selectedCategory = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.violet
                              : isDark
                                  ? AppColors.darkSurface
                                  : AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(100),
                          border: isSelected
                              ? null
                              : Border.all(
                                  color: isDark
                                      ? Colors.white
                                          .withValues(alpha: 0.08)
                                      : Colors.black
                                          .withValues(alpha: 0.08)),
                        ),
                        child: Text(cat,
                            style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textMuted)),
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
              child: Row(
                children: [
                  Text(
                      '${filtered.length} course${filtered.length != 1 ? 's' : ''} found',
                      style: Theme.of(context).textTheme.bodySmall),
                  const Spacer(),
                  if (filtered.isNotEmpty)
                    Text('Scroll for more ↓',
                        style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppColors.violet,
                            fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),

          // Course list/grid
          if (filtered.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    const Icon(Icons.search_off,
                        color: AppColors.textMuted, size: 48),
                    const SizedBox(height: 14),
                    Text('No courses found',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('Try a different search or category',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: appState.generateNextCourseBatch,
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: Text('Generate AI courses',
                          style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.violet,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (useGrid)
            _buildGrid(filtered)
          else
            _buildList(filtered),

          if (appState.isLoadingMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: AppColors.violet),
                    ),
                    const SizedBox(height: 10),
                    Text('Generating more courses with AI...',
                        style: GoogleFonts.dmSans(
                            fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ),

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

  /// Bug #4 fix: Category tiles are now smaller (childAspectRatio: 1.6 instead of 1.25)
  /// and use a compact horizontal layout
  Widget _buildCategoryGrid(bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.9, // Bug #4 fix: was 1.25, now tiles are much smaller
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cat.color.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cat.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(cat.icon, color: cat.color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        cat.name,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textLight
                              : AppColors.textDark,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${cat.subCategories.length} paths',
                        style: GoogleFonts.dmSans(
                            fontSize: 10,
                            color: cat.color,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
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
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_back,
                      size: 18,
                      color:
                          isDark ? AppColors.textLight : AppColors.textDark),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cat.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(cat.icon, color: cat.color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cat.name,
                        style: Theme.of(context).textTheme.titleLarge),
                    Text('${cat.subCategories.length} paths available',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
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
                    color: isDark
                        ? AppColors.darkSurface
                        : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: cat.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text('${index + 1}',
                              style: GoogleFonts.dmMono(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: cat.color)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sub.name,
                                style: GoogleFonts.dmSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.textLight
                                        : AppColors.textDark)),
                            const SizedBox(height: 4),
                            Text(sub.description,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(height: 1.4),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cat.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child:
                            Icon(Icons.auto_awesome, size: 16, color: cat.color),
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
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => CourseDetailScreen(course: course)),
              ),
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
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) =>
                              CourseDetailScreen(course: filtered[i1])),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                if (i2 < filtered.length)
                  Expanded(
                    child: _ExploreCourseCard(
                      course: filtered[i2],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                CourseDetailScreen(course: filtered[i2])),
                      ),
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

// Course generation now uses background processing with toast notifications

// ── Explore Course Card ────────────────────────────────────────────────────────

class _ExploreCourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback onTap;

  const _ExploreCourseCard({required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Bug #5 fix: Replace placeholder $dream in course title
    final displayTitle =
        (course.title).replaceAll('\$dream', course.category);

    // Bug #8 fix: All generated courses are personalized — don't show learner count
    // Only show learner count for mock/catalog courses that have a non-zero count
    final isPersonalized = course.learnerCount == 0 ||
        course.learnerCount == 154; // 154 is fallback marker from api_service
    final showLearnerCount = !isPersonalized && course.learnerCount > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      course.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.darkSurface2,
                        child: const Center(
                            child: Icon(Icons.play_circle_outline,
                                color: AppColors.textMuted, size: 40)),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                color: AppColors.gold, size: 14),
                            const SizedBox(width: 3),
                            Text(
                              course.rating.toStringAsFixed(1),
                              style: GoogleFonts.dmMono(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                            ),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                AppColors.violet.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            course.category,
                            style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.violet),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      // Bug #8 fix: only show learner count for non-personalized courses
                      if (showLearnerCount) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.people_outline,
                            color: AppColors.textMuted, size: 14),
                        const SizedBox(width: 4),
                        Text(_formatCount(course.learnerCount),
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Bug #5 fix: show corrected title
                  Text(displayTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text(
                    course.description,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.play_lesson_outlined,
                          color: AppColors.textMuted, size: 14),
                      const SizedBox(width: 4),
                      Flexible(
                          child: Text('${course.totalLessons} lessons',
                              style:
                                  Theme.of(context).textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 14),
                      const Icon(Icons.schedule_outlined,
                          color: AppColors.textMuted, size: 14),
                      const SizedBox(width: 4),
                      Flexible(
                          child: Text(course.estimatedTime,
                              style:
                                  Theme.of(context).textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis)),
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
