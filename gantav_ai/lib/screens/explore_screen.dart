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
      final title = course.title.replaceAll('\$dream', course.category);
      final matchesSearch = _searchQuery.isEmpty ||
          title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          course.category.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory =
          _selectedCategory == 'All' || course.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  Future<void> _generateCourseFromSubCategory(SubCategory sub) async {
    final appState = context.read<AppState>();
    appState.generateCourseInBackgroundFromCategory(sub.promptHint);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(child: Text('Generating "${sub.name}" course...', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13))),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.violet,
        duration: const Duration(seconds: 3),
      ),
    );

    setState(() { _showSubCategories = false; _selectedCatalogCategory = null; });
  }

  void _showCustomCourseBuilder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CustomCourseBuilderSheet(
        isDark: isDark,
        onGenerate: (courseName, language, channel) {
          Navigator.pop(ctx);
          final prompt = [
            courseName,
            if (language.isNotEmpty) 'in $language language',
            if (channel.isNotEmpty) 'taught by $channel or similar channel',
          ].join(' ');
          context.read<AppState>().generateCourseInBackgroundFromCategory(prompt);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Creating "$courseName" course...', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13))),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: AppColors.violet,
              duration: const Duration(seconds: 4),
            ),
          );
        },
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
                  indicator: BoxDecoration(color: AppColors.violet, borderRadius: BorderRadius.circular(10)),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textMuted,
                  labelStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500),
                  indicatorPadding: const EdgeInsets.all(3),
                  tabs: const [Tab(text: 'Courses'), Tab(text: 'Categories')],
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
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final screenWidth = MediaQuery.of(context).size.width;
    final useGrid = isLandscape || screenWidth > 700;
    final filtered = _filteredCourses(appState.courses);

    return RefreshIndicator(
      onRefresh: appState.refresh,
      color: AppColors.violet,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
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
                          onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); },
                          icon: const Icon(Icons.clear, color: AppColors.textMuted, size: 18))
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

          // ─── Professional Custom Course Builder Banner ──────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: GestureDetector(
                onTap: () => _showCustomCourseBuilder(context),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.violet, Color(0xFF9C5BDB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: AppColors.violet.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Create Custom Course', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                            const SizedBox(height: 2),
                            Text('Tell AI exactly what you want to learn', style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white70)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                      ),
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

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Row(
                children: [
                  Text('${filtered.length} course${filtered.length != 1 ? 's' : ''} found',
                    style: Theme.of(context).textTheme.bodySmall),
                  const Spacer(),
                  if (filtered.isNotEmpty)
                    Text('Scroll for more ↓', style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.violet, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),

          if (filtered.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    const Icon(Icons.search_off, color: AppColors.textMuted, size: 48),
                    const SizedBox(height: 14),
                    Text('No courses found', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('Try a different search or category', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: appState.generateNextCourseBatch,
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: Text('Generate AI courses', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.violet,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.violet)),
                    const SizedBox(height: 10),
                    Text('Generating more courses with AI...', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted)),
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
    if (_showSubCategories && _selectedCatalogCategory != null) return _buildSubCategoryList(isDark);
    return _buildCategoryGrid(isDark);
  }

  Widget _buildCategoryGrid(bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.9,
      ),
      itemCount: CatalogData.categories.length,
      itemBuilder: (context, index) {
        final cat = CatalogData.categories[index];
        return GestureDetector(
          onTap: () => setState(() { _selectedCatalogCategory = cat; _showSubCategories = true; }),
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
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: cat.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(cat.icon, color: cat.color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(cat.name, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? AppColors.textLight : AppColors.textDark), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('${cat.subCategories.length} paths', style: GoogleFonts.dmSans(fontSize: 10, color: cat.color, fontWeight: FontWeight.w600)),
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
                onPressed: () => setState(() { _showSubCategories = false; _selectedCatalogCategory = null; }),
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
              Container(width: 36, height: 36, decoration: BoxDecoration(color: cat.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(cat.icon, color: cat.color, size: 18)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cat.name, style: Theme.of(context).textTheme.titleLarge),
                    Text('${cat.subCategories.length} paths available', style: Theme.of(context).textTheme.bodySmall),
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
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: cat.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                        child: Center(child: Text('${index + 1}', style: GoogleFonts.dmMono(fontSize: 16, fontWeight: FontWeight.w700, color: cat.color))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sub.name, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? AppColors.textLight : AppColors.textDark)),
                            const SizedBox(height: 4),
                            Text(sub.description, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: cat.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
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
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course))),
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
                Expanded(child: _ExploreCourseCard(course: filtered[i1], onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseDetailScreen(course: filtered[i1]))))),
                const SizedBox(width: 14),
                if (i2 < filtered.length)
                  Expanded(child: _ExploreCourseCard(course: filtered[i2], onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseDetailScreen(course: filtered[i2])))))
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

// ─── Professional Custom Course Builder Sheet ─────────────────────────────────

class _CustomCourseBuilderSheet extends StatefulWidget {
  final bool isDark;
  final void Function(String courseName, String language, String channel) onGenerate;

  const _CustomCourseBuilderSheet({required this.isDark, required this.onGenerate});

  @override
  State<_CustomCourseBuilderSheet> createState() => _CustomCourseBuilderSheetState();
}

class _CustomCourseBuilderSheetState extends State<_CustomCourseBuilderSheet> {
  final _courseNameCtrl = TextEditingController();
  final _channelCtrl = TextEditingController();
  String _selectedLanguage = 'English';
  int _currentStep = 0;

  final List<String> _courseNameSuggestions = [
    'Complete Python for Beginners',
    'Full-Stack Web Development',
    'Machine Learning Fundamentals',
    'Flutter Mobile App Development',
    'Data Science with Python',
    'React & Node.js Bootcamp',
    'DevOps & Cloud Engineering',
    'UI/UX Design Masterclass',
    'Cybersecurity Essentials',
    'Game Development with Unity',
  ];

  final List<Map<String, String>> _languageOptions = [
    {'label': '🇬🇧 English', 'value': 'English'},
    {'label': '🇮🇳 Hindi', 'value': 'Hindi'},
    {'label': '🇪🇸 Spanish', 'value': 'Spanish'},
    {'label': '🇫🇷 French', 'value': 'French'},
    {'label': '🇩🇪 German', 'value': 'German'},
  ];

  final List<String> _channelSuggestions = [
    'freeCodeCamp',
    'Traversy Media',
    'Fireship',
    '3Blue1Brown',
    'The Net Ninja',
    'CodeWithHarry',
    'Apna College',
    'Programming with Mosh',
    'TechWithTim',
    'CS50',
  ];

  @override
  void dispose() {
    _courseNameCtrl.dispose();
    _channelCtrl.dispose();
    super.dispose();
  }

  bool get _canGenerate => _courseNameCtrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(100),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: AppColors.violet.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.auto_awesome, color: AppColors.violet, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Create Custom Course', style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w700, color: isDark ? AppColors.textLight : AppColors.textDark)),
                      Text('AI will curate the best YouTube videos', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),

            // Content
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Step 1: Course Name ──────────────────────────
                  _buildSectionLabel('What do you want to learn? *', Icons.school_outlined, AppColors.violet),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _courseNameCtrl,
                    autofocus: true,
                    style: GoogleFonts.dmSans(fontSize: 15, color: isDark ? AppColors.textLight : AppColors.textDark),
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'e.g., Complete Python for Beginners',
                      hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.7)),
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.violet, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      suffixIcon: _courseNameCtrl.text.isNotEmpty
                          ? IconButton(onPressed: () => setState(() => _courseNameCtrl.clear()), icon: const Icon(Icons.clear, size: 18, color: AppColors.textMuted))
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Quick suggestions
                  Text('Quick picks:', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.3)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: _courseNameSuggestions.map((s) {
                      return GestureDetector(
                        onTap: () => setState(() => _courseNameCtrl.text = s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _courseNameCtrl.text == s ? AppColors.violet.withValues(alpha: 0.12) : isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: _courseNameCtrl.text == s ? AppColors.violet.withValues(alpha: 0.4) : isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
                          ),
                          child: Text(s, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w500, color: _courseNameCtrl.text == s ? AppColors.violet : AppColors.textMuted)),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // ─── Step 2: Language ─────────────────────────────
                  _buildSectionLabel('Content Language', Icons.translate_rounded, AppColors.teal),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _languageOptions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final opt = _languageOptions[index];
                        final isSelected = _selectedLanguage == opt['value'];
                        return GestureDetector(
                          onTap: () => setState(() => _selectedLanguage = opt['value']!),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.teal.withValues(alpha: 0.12) : isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: isSelected ? AppColors.teal.withValues(alpha: 0.4) : Colors.transparent),
                            ),
                            child: Text(opt['label']!, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? AppColors.teal : AppColors.textMuted)),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ─── Step 3: Channel (Optional) ───────────────────
                  _buildSectionLabel('Preferred Channel (Optional)', Icons.play_circle_outline, AppColors.gold),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _channelCtrl,
                    style: GoogleFonts.dmSans(fontSize: 14, color: isDark ? AppColors.textLight : AppColors.textDark),
                    decoration: InputDecoration(
                      hintText: 'e.g., freeCodeCamp, Traversy Media...',
                      hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.7), fontSize: 13),
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.gold, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: _channelSuggestions.map((c) {
                      return GestureDetector(
                        onTap: () => setState(() => _channelCtrl.text = c),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _channelCtrl.text == c ? AppColors.gold.withValues(alpha: 0.12) : isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: _channelCtrl.text == c ? AppColors.gold.withValues(alpha: 0.4) : isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
                          ),
                          child: Text(c, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w500, color: _channelCtrl.text == c ? AppColors.gold : AppColors.textMuted)),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),

            // ─── Generate Button ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _canGenerate
                      ? () => widget.onGenerate(
                          _courseNameCtrl.text.trim(),
                          _selectedLanguage,
                          _channelCtrl.text.trim(),
                        )
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.violet,
                    disabledBackgroundColor: AppColors.violet.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome, size: 18),
                      const SizedBox(width: 8),
                      Text('Generate Course with AI', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: widget.isDark ? AppColors.textLightSub : AppColors.textDarkSub)),
      ],
    );
  }
}

// ─── Explore Course Card ────────────────────────────────────────────────────

class _ExploreCourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback onTap;

  const _ExploreCourseCard({required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Fix $dream placeholder
    final displayTitle = course.title.replaceAll('\$dream', course.category);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                        child: const Center(child: Icon(Icons.play_circle_outline, color: AppColors.textMuted, size: 40)),
                      ),
                    ),
                    Positioned(
                      top: 10, right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, color: AppColors.gold, size: 14),
                            const SizedBox(width: 3),
                            Text(course.rating.toStringAsFixed(1), style: GoogleFonts.dmMono(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
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
                  // Category pill — NO learner count
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.violet.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(100)),
                    child: Text(course.category, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.violet), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(height: 10),
                  // Fixed title — no $dream
                  Text(displayTitle, style: Theme.of(context).textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text(course.description, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.play_lesson_outlined, color: AppColors.textMuted, size: 14),
                      const SizedBox(width: 4),
                      Flexible(child: Text('${course.totalLessons} lessons', style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 14),
                      const Icon(Icons.schedule_outlined, color: AppColors.textMuted, size: 14),
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
}