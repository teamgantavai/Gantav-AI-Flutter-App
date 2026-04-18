import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../models/exam_models.dart';
import '../services/admin_service.dart';
import '../services/pyq_service.dart';
import '../services/youtube_api_service.dart';
import '../theme/app_theme.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _categoryController = TextEditingController();
  final _skillsController = TextEditingController();
  final _youtubeLinksController = TextEditingController();
  final _moduleNameController = TextEditingController();
  String _selectedLanguage = 'English';

  bool _isLoading = false;
  List<Module> _parsedModules = [];
  List<Course> _verifiedCourses = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCourses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _categoryController.dispose();
    _skillsController.dispose();
    _youtubeLinksController.dispose();
    _moduleNameController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    setState(() => _isLoading = true);
    final courses = await AdminService.getAllVerifiedCourses();
    setState(() {
      _verifiedCourses = courses;
      _isLoading = false;
    });
  }

  Future<void> _parseLinks() async {
    final lines = _youtubeLinksController.text.split('\n');
    List<Lesson> currentLessons = [];
    
    setState(() => _isLoading = true);

    try {
      for (var line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        final videoId = _extractVideoId(trimmed);
        if (videoId != null) {
          // Automatic fetching
          final details = await YouTubeApiService.fetchVideoDetails(videoId);
          currentLessons.add(Lesson(
            id: 'l_${DateTime.now().microsecondsSinceEpoch}_${currentLessons.length}',
            title: details?.title ?? 'Video ${currentLessons.length + 1}',
            description: details?.title ?? '', // Using title as default description if empty
            youtubeVideoId: videoId,
            duration: details?.durationText ?? '12:00',
          ));
        }
      }

      if (currentLessons.isNotEmpty) {
        final moduleTitle = _moduleNameController.text.trim().isEmpty 
            ? 'Section ${_parsedModules.length + 1}' 
            : _moduleNameController.text.trim();

        setState(() {
          _parsedModules.add(Module(
            id: 'm_${DateTime.now().microsecondsSinceEpoch}',
            title: moduleTitle,
            lessonCount: currentLessons.length,
            lessons: List.from(currentLessons),
          ));
          _youtubeLinksController.clear();
          _moduleNameController.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid YouTube links found.')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String? _extractVideoId(String url) {
    if (url.contains('youtu.be/')) {
      return url.split('youtu.be/').last.split('?').first;
    }
    if (url.contains('youtube.com/live/')) {
      return url.split('youtube.com/live/').last.split('?').first;
    }
    RegExp regExp = RegExp(
        r'^.*((youtu.be\/)|(v\/)|(\/u\/\w\/)|(embed\/)|(watch\?))\??v?=?([^#&?]*).*');
    var match = regExp.firstMatch(url);
    if (match != null && match.group(7)!.length == 11) {
      return match.group(7);
    }
    return null;
  }

  void _saveCourse() async {
    if (!_formKey.currentState!.validate() || _parsedModules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill all fields and parse at least one module')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      int totalLessons = 0;
      for (var m in _parsedModules) {
        totalLessons += m.lessonCount;
      }

      final course = Course(
        id: 'vc_${DateTime.now().millisecondsSinceEpoch}',
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        category: _categoryController.text.trim(),
        language: _selectedLanguage,
        thumbnailUrl:
            'https://img.youtube.com/vi/${_parsedModules.first.lessons.first.youtubeVideoId}/maxresdefault.jpg',
        skills: _skillsController.text.split(',').map((s) => s.trim()).toList(),
        modules: List.from(_parsedModules),
        totalLessons: totalLessons,
        isVerified: true,
      );

      await AdminService.saveVerifiedCourse(course);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Course saved as Gantav Verified!')),
        );
        _titleController.clear();
        _descController.clear();
        _youtubeLinksController.clear();
        _skillsController.clear();
        _categoryController.clear();
        setState(() => _parsedModules = []);
        _loadCourses();
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCourse(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Course?'),
        content: const Text('This will remove it from the verified library.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      await AdminService.deleteVerifiedCourse(id);
      await _loadCourses();
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Course deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text('Admin Panel',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.violet,
          labelColor: AppColors.violet,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Create'),
            Tab(text: 'Manage'),
            Tab(text: 'PYQ Bank'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCreateIndexTab(isDark),
          _buildManageTab(isDark),
          const _PyqImportTab(),
        ],
      ),
    );
  }

  Widget _buildCreateIndexTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Course Details'),
            const SizedBox(height: 16),
            _buildTextField(_titleController, 'Course Title',
                'e.g. Master Video Editing'),
            const SizedBox(height: 12),
            _buildTextField(_descController, 'Description',
                'What will users learn?',
                maxLines: 3),
            const SizedBox(height: 12),
            _buildTextField(_categoryController, 'Category',
                'e.g. Video Editing'),
            const SizedBox(height: 12),
            _buildLanguageDropdown(isDark),
            const SizedBox(height: 12),
            _buildTextField(_skillsController, 'Skills (comma separated)',
                'e.g. Premiere Pro, Storytelling'),

            const SizedBox(height: 32),
            _buildSectionTitle('Module Construction'),
            const SizedBox(height: 16),
            _buildTextField(_moduleNameController, 'Module Name', 'e.g. Basics of Premiere Pro'),
            const SizedBox(height: 12),
            _buildTextField(_youtubeLinksController, 'Links for this Module (One per line)',
                'Paste YouTube video links here...',
                maxLines: 5),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _parseLinks,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Module to Course'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.violet,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),

            if (_parsedModules.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSectionTitle('Parsed Structure (${_parsedModules.length} Modules)'),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _parsedModules.length,
                itemBuilder: (context, index) {
                  final module = _parsedModules[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface2 : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.violet,
                        radius: 12,
                        child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                        title: Text(module.title, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold)),
                        subtitle: Text('${module.lessonCount} videos', style: const TextStyle(fontSize: 11)),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                          onPressed: () => setState(() => _parsedModules.removeAt(index)),
                        ),
                        children: module.lessons.map((lesson) => ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network('https://img.youtube.com/vi/${lesson.youtubeVideoId}/default.jpg', width: 40),
                          ),
                          title: TextFormField(
                            initialValue: lesson.title,
                            onChanged: (val) {
                              // We can update the lesson title in memory if needed
                              // For simplicity in this UI, we'll just allow display for now
                            },
                            style: const TextStyle(fontSize: 12),
                            decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                          ),
                          subtitle: Text(lesson.youtubeVideoId, style: const TextStyle(fontSize: 10)),
                          dense: true,
                        )).toList(),
                      ),
                  );
                },
              ),
            ],

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveCourse,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Publish Course',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildManageTab(bool isDark) {
    if (_isLoading && _verifiedCourses.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.violet));
    }

    if (_verifiedCourses.isEmpty) {
       return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_books_outlined, size: 64, color: AppColors.textMuted.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('No verified courses yet', style: GoogleFonts.dmSans(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCourses,
      color: AppColors.violet,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _verifiedCourses.length,
        itemBuilder: (context, index) {
          final course = _verifiedCourses[index];
          return _CourseManageCard(
            course: course, 
            isDark: isDark,
            onDelete: () => _deleteCourse(course.id),
          );
        },
      ),
    );
  }



  Widget _buildLanguageDropdown(bool isDark) {
    return DropdownButtonFormField<String>(
      value: _selectedLanguage,
      dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
      style: GoogleFonts.dmSans(color: isDark ? Colors.white : Colors.black, fontSize: 14),
      decoration: InputDecoration(
        labelText: 'Course Language',
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      items: ['English', 'Hindi'].map((lang) => DropdownMenuItem(value: lang, child: Text(lang))).toList(),
      onChanged: (val) {
        if (val != null) setState(() => _selectedLanguage = val);
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: AppColors.violet,
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      String hint,
      {int maxLines = 1}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.dmSans(color: isDark ? Colors.white : Colors.black, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : Colors.grey[100],
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
         contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
    );
  }
}

class _CourseManageCard extends StatefulWidget {
  final Course course;
  final bool isDark;
  final VoidCallback onDelete;

  const _CourseManageCard({
    required this.course,
    required this.isDark,
    required this.onDelete,
  });

  @override
  State<_CourseManageCard> createState() => _CourseManageCardState();
}

class _CourseManageCardState extends State<_CourseManageCard> {
  bool _isExpanded = false;
  Map<String, YouTubeVideoStats> _videoStats = {};
  bool _isLoadingStats = false;

  Future<void> _fetchStats() async {
    if (_videoStats.isNotEmpty) return;
    setState(() => _isLoadingStats = true);
    
    try {
      for (var module in widget.course.modules) {
        for (var lesson in module.lessons) {
          final stats = await YouTubeApiService.fetchVideoDetails(lesson.youtubeVideoId);
          if (stats != null) {
            _videoStats[lesson.youtubeVideoId] = stats;
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final isDark = widget.isDark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(course.thumbnailUrl, width: 80, height: 60, fit: BoxFit.cover),
            ),
            title: Text(course.title, style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course.category, style: GoogleFonts.dmSans(color: AppColors.violet, fontSize: 11, fontWeight: FontWeight.bold)),
                Text('${course.totalLessons} lessons • ${course.language}', style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                ),
                Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textMuted),
              ],
            ),
            onTap: () {
              setState(() => _isExpanded = !_isExpanded);
              if (_isExpanded) _fetchStats();
            },
          ),
          if (_isExpanded) ...[
            const Divider(height: 1),
            if (_isLoadingStats)
              const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2))
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Video Statistics', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.violet)),
                    const SizedBox(height: 12),
                    ...course.modules.expand((m) => m.lessons).map((lesson) {
                      final stats = _videoStats[lesson.youtubeVideoId];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(lesson.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildMiniStat(Icons.visibility_outlined, stats?.viewCount.toString() ?? 'N/A'),
                                _buildMiniStat(Icons.thumb_up_outlined, stats?.likeCount.toString() ?? 'N/A'),
                                _buildMiniStat(Icons.comment_outlined, stats?.commentCount.toString() ?? 'N/A'),
                                _buildMiniStat(Icons.analytics_outlined, '${stats?.engagementRatio ?? 0}%'),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(value, style: GoogleFonts.dmMono(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PYQ Bank Import Tab
//
// Lists every (exam, subject) pair from the catalog. Each row shows a button
// that reads the bundled `assets/pyq/{exam}_{subject}.json` asset, validates
// it, and mirrors the questions to `pyq_bank/{exam}_{subject}` in Firestore
// so other installs pick them up without a new APK build.

class _PyqImportTab extends StatefulWidget {
  const _PyqImportTab();

  @override
  State<_PyqImportTab> createState() => _PyqImportTabState();
}

class _PyqImportTabState extends State<_PyqImportTab> {
  final Map<String, _ImportRowState> _rowState = {};

  String _key(String examId, String subjectId) => '${examId}_$subjectId';

  Future<void> _importOne(ExamCategory exam, ExamSubject subject) async {
    final k = _key(exam.id, subject.id);
    setState(() => _rowState[k] = _ImportRowState.loading());
    final written = await PyqService.importAssetToFirestore(
      exam: exam,
      subject: subject,
    );
    if (!mounted) return;
    setState(() {
      _rowState[k] = written > 0
          ? _ImportRowState.ok(written)
          : written == 0
              ? _ImportRowState.empty()
              : _ImportRowState.err();
    });
  }

  Future<void> _importAll() async {
    for (final exam in ExamCategory.catalog()) {
      for (final subject in exam.subjects) {
        await _importOne(exam, subject);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final exams = ExamCategory.catalog();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.violet.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.violet.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.violet, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reads bundled assets/pyq/{exam}_{subject}.json and mirrors them to Firestore pyq_bank/. Missing files are expected — import only what you have.',
                    style: GoogleFonts.dmSans(fontSize: 12, color: isDark ? Colors.white70 : AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _importAll,
              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
              label: const Text('Import all bundled banks'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.violet,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ...exams.map((exam) => _examSection(exam, isDark)),
        ],
      ),
    );
  }

  Widget _examSection(ExamCategory exam, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Row(
            children: [
              Icon(exam.icon, size: 18, color: AppColors.violet),
              const SizedBox(width: 8),
              Text(
                '${exam.name} · ${exam.tagline}',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
        ...exam.subjects.map((subject) {
          final k = _key(exam.id, subject.id);
          final st = _rowState[k];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(subject.icon, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.name,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        'assets/pyq/${exam.id}_${subject.id}.json',
                        style: GoogleFonts.dmMono(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (st != null) _statusChip(st),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: st?.isLoading == true
                      ? null
                      : () => _importOne(exam, subject),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.violet,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: st?.isLoading == true
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.violet,
                          ),
                        )
                      : const Text('Import'),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _statusChip(_ImportRowState st) {
    if (st.isLoading) return const SizedBox.shrink();
    final color = st.isError
        ? AppColors.error
        : st.wrote == 0
            ? AppColors.textMuted
            : AppColors.success;
    final label = st.isError
        ? 'Err'
        : st.wrote == 0
            ? 'No asset'
            : '${st.wrote} Qs';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmMono(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ImportRowState {
  final bool isLoading;
  final bool isError;
  final int wrote;
  const _ImportRowState._({required this.isLoading, required this.isError, required this.wrote});
  factory _ImportRowState.loading() => const _ImportRowState._(isLoading: true, isError: false, wrote: 0);
  factory _ImportRowState.ok(int n) => _ImportRowState._(isLoading: false, isError: false, wrote: n);
  factory _ImportRowState.empty() => const _ImportRowState._(isLoading: false, isError: false, wrote: 0);
  factory _ImportRowState.err() => const _ImportRowState._(isLoading: false, isError: true, wrote: 0);
}
