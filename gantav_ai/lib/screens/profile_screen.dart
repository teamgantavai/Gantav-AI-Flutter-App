import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/app_state.dart';
import '../widgets/widgets.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'course_detail_screen.dart';
import '../services/auth_service.dart';
import '../services/certificate_service.dart';
import 'admin_panel_screen.dart';
import 'certificate_screen.dart';
import 'verify_certificate_screen.dart';
import 'legal_screen.dart';
import '../models/models.dart';
import '../models/certificate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'coin_store_screen.dart';
import 'package:gantav_ai/services/share_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 4 tabs: Courses, Favorites, Certificates, Badges
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image =
        await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      context.read<AppState>().updateProfileImage(image.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<AppState>(
      builder: (context, appState, _) {
        final user = appState.user;
        if (user == null) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.violet));
        }

        return RefreshIndicator(
          onRefresh: appState.refresh,
          color: AppColors.violet,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: _ProfileHero(
                  user: user,
                  appState: appState,
                  isDark: isDark,
                  onAvatarTap: _pickImage,
                  onSettingsTap: () =>
                      _showSettingsSheet(context, appState, isDark),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: _StatsRow(user: user, isDark: isDark),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                    tabController: _tabController, isDark: isDark),
              ),
              SliverFillRemaining(
                hasScrollBody: true,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _GeneratedCoursesTab(
                        appState: appState, isDark: isDark),
                    _FavoritesTab(appState: appState, isDark: isDark),
                    _CertificatesTab(isDark: isDark, userId: user.id),
                    _AchievementsTab(user: user, isDark: isDark),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSettingsSheet(
      BuildContext context, AppState appState, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _SettingsSheet(
        appState: appState,
        isDark: isDark,
        onEditProfile: () {
          Navigator.pop(ctx);
          _showEditProfileSheet(context, appState, isDark);
        },
      ),
    );
  }

  void _showEditProfileSheet(
      BuildContext context, AppState appState, bool isDark) {
    final nameCtrl =
        TextEditingController(text: appState.user?.name ?? '');
    final handleCtrl =
        TextEditingController(text: appState.user?.handle ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          isDark ? AppColors.darkSurface : AppColors.lightSurface,
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
            Text('Edit Profile',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            TextField(
                controller: nameCtrl,
                decoration:
                    const InputDecoration(labelText: 'Full Name')),
            const SizedBox(height: 16),
            TextField(
                controller: handleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Username', prefixText: '@')),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  appState.updateUserProfile(
                      name: nameCtrl.text, handle: handleCtrl.text);
                  Navigator.pop(ctx);
                },
                child: const Text('Save Changes'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Profile Hero ────────────────────────────────────────────────────────────

class _ProfileHero extends StatelessWidget {
  final dynamic user;
  final AppState appState;
  final bool isDark;
  final VoidCallback onAvatarTap;
  final VoidCallback onSettingsTap;

  const _ProfileHero({
    required this.user,
    required this.appState,
    required this.isDark,
    required this.onAvatarTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.violet.withValues(alpha: 0.15),
                  AppColors.darkSurface
                ]
              : [
                  AppColors.violet.withValues(alpha: 0.05),
                  AppColors.lightSurface
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: AppColors.violet.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on_rounded,
                          color: AppColors.gold, size: 14),
                      const SizedBox(width: 5),
                      Text('${user.coins} coins',
                          style: GoogleFonts.dmMono(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gold)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onSettingsTap,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.08)),
                    ),
                    child: Icon(Icons.settings_outlined,
                        size: 18,
                        color: isDark
                            ? AppColors.textLight
                            : AppColors.textDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onAvatarTap,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [
                            AppColors.violet,
                            AppColors.violetDark
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.violet.withValues(alpha: 0.4),
                          width: 3),
                      image: appState.profileImagePath != null
                          ? DecorationImage(
                              image: FileImage(
                                  File(appState.profileImagePath!)),
                              fit: BoxFit.cover)
                          : null,
                    ),
                    child: appState.profileImagePath == null
                        ? Center(
                            child: Text(user.initials,
                                style: GoogleFonts.dmSans(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)))
                        : null,
                  ),
                  Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                          color: AppColors.violet,
                          shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 12)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(user.name,
                style: GoogleFonts.dmSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.textLight
                        : AppColors.textDark)),
            const SizedBox(height: 2),
            Text('@${user.handle}',
                style: GoogleFonts.dmMono(
                    fontSize: 13, color: AppColors.textMuted)),
            const SizedBox(height: 4),
            if (appState.activeRoadmap != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: AppColors.violet.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color:
                            AppColors.violet.withValues(alpha: 0.2))),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.route_rounded,
                        color: AppColors.violet, size: 12),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${(appState.activeRoadmap!.taskProgress * 100).round()}% • ${appState.activeRoadmap!.title}',
                        style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.violet),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: () {
                  SharePlus.instance.share(ShareParams(
                    text:
                        'Check out my learning journey on Gantav AI! 🎯',
                  ));
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.violet,
                  side: BorderSide(
                      color: AppColors.violet.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.zero,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.share_outlined, size: 16),
                    const SizedBox(width: 8),
                    Text('Share Profile',
                        style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─── Stats Row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final dynamic user;
  final bool isDark;
  const _StatsRow({required this.user, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
            value: '${user.lessonsCompleted}',
            label: 'Lessons',
            icon: Icons.play_lesson_outlined,
            color: AppColors.teal,
            isDark: isDark),
        const SizedBox(width: 10),
        _StatCard(
            value: '${user.quizzesPassed}',
            label: 'Quizzes',
            icon: Icons.quiz_outlined,
            color: AppColors.violet,
            isDark: isDark),
        const SizedBox(width: 10),
        _StatCard(
            value: '${user.streakDays}',
            label: 'Streak',
            icon: Icons.local_fire_department,
            color: AppColors.gold,
            isDark: isDark),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final bool isDark;
  const _StatCard(
      {required this.value,
      required this.label,
      required this.icon,
      required this.color,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.1 : 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: GoogleFonts.dmMono(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: color)),
            Text(label,
                style: GoogleFonts.dmSans(
                    fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ─── Tab Bar Delegate ─────────────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  final bool isDark;
  const _TabBarDelegate(
      {required this.tabController, required this.isDark});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: isDark ? AppColors.darkBg : AppColors.lightBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: tabController,
          isScrollable: false,
          indicator: BoxDecoration(
              color: AppColors.violet,
              borderRadius: BorderRadius.circular(10)),
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
            Tab(text: 'Favorites'),
            Tab(text: 'Certificates'),
            Tab(text: 'Badges'),
          ],
        ),
      ),
    );
  }

  @override
  double get maxExtent => 60;
  @override
  double get minExtent => 60;
  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) {
    return oldDelegate.isDark != isDark ||
           oldDelegate.tabController != tabController;
  }
}

// ─── Certificates Tab ─────────────────────────────────────────────────────────

class _CertificatesTab extends StatefulWidget {
  final bool isDark;
  final String userId;
  const _CertificatesTab({required this.isDark, required this.userId});

  @override
  State<_CertificatesTab> createState() => _CertificatesTabState();
}

class _CertificatesTabState extends State<_CertificatesTab> {
  List<Certificate> _certificates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCertificates();
  }

  Future<void> _loadCertificates() async {
    final certificates = await CertificateService.getMyCertificates(userId: widget.userId);
    if (mounted) {
      setState(() {
        _certificates = certificates;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.violet));
    }

    if (_certificates.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.workspace_premium_outlined,
                    color: AppColors.gold, size: 32),
              ),
              const SizedBox(height: 16),
              Text('No certificates yet',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Complete a course to earn your certificate.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: _certificates.length,
      itemBuilder: (context, index) {
        final cert = _certificates[index];
        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => CertificateScreen(certificate: cert)),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  widget.isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.workspace_premium_rounded,
                      color: AppColors.gold, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cert.courseTitle,
                        style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: widget.isDark
                                ? AppColors.textLight
                                : AppColors.textDark),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(cert.courseCategory,
                                style: GoogleFonts.dmSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.gold)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(cert.issuedAt),
                            style: GoogleFonts.dmSans(
                                fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cert.verificationCode,
                        style: GoogleFonts.dmMono(
                            fontSize: 10,
                            color: AppColors.textMuted.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 18, color: AppColors.textMuted),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ─── Generated Courses Tab ─────────────────────────────────────────────────────

class _GeneratedCoursesTab extends StatelessWidget {
  final AppState appState;
  final bool isDark;
  const _GeneratedCoursesTab(
      {required this.appState, required this.isDark});

  @override
  Widget build(BuildContext context) {
    // Profile "My Courses" must show ONLY the user's own generated / enrolled
    // courses. Previously this used `appState.courses` which merges suggested
    // mock data with user content — the profile looked polluted.
    final courses = appState.generatedCourses;

    if (courses.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          alignment: Alignment.center,
          padding:
              const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    color: AppColors.violet.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.auto_awesome,
                    color: AppColors.violet, size: 32),
              ),
              const SizedBox(height: 16),
              Text('No courses yet',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Generate your first AI course from the Explore tab',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(height: 1.5)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => appState.setTabIndex(1),
                icon: const Icon(Icons.explore_outlined, size: 16),
                label: Text('Go to Explore',
                    style:
                        GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
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
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: courses.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Text(
                    '${courses.length} Course${courses.length != 1 ? 's' : ''}',
                    style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.textLight
                            : AppColors.textDark)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: AppColors.violet.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(100)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome,
                          size: 12, color: AppColors.violet),
                      const SizedBox(width: 4),
                      Text('AI Generated',
                          style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.violet)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final course = courses[index - 1];
        final displayTitle =
            course.title.replaceAll('\$dream', course.category);

        return GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CourseDetailScreen(course: course))),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurface
                  : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isDark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(16)),
                  child: SizedBox(
                    width: 90,
                    height: 75,
                    child: Image.network(
                      course.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.darkSurface2,
                        child: const Center(
                            child: Icon(Icons.play_circle_outline,
                                color: AppColors.textMuted, size: 28)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color:
                                  AppColors.violet.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(100)),
                          child: Text(course.category,
                              style: GoogleFonts.dmSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.violet),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(height: 4),
                        Text(displayTitle,
                            style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.textLight
                                    : AppColors.textDark),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.play_lesson_outlined,
                                size: 12, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text('${course.totalLessons} lessons',
                                style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    color: AppColors.textMuted)),
                          ],
                        ),
                        if (course.isInProgress) ...[
                          const SizedBox(height: 6),
                          SimpleProgressBar(
                              progress: course.progress, height: 3),
                        ],
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textMuted),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface,
                  onSelected: (value) {
                    switch (value) {
                      case 'save':
                        appState.toggleSaveCourse(course.id);
                        break;
                      case 'share':
                        SharePlus.instance.share(ShareParams(
                          text: 'Check out "${course.title}" on Gantav AI! 🎯\nhttps://gantavai.com/course/${course.id}',
                        ));
                        break;
                      case 'delete':
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: Text('Delete Course?', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
                            content: Text('This will permanently remove "${course.title}" from your library.',
                                style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textMuted)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  appState.deleteCourse(course.id);
                                },
                                child: const Text('Delete', style: TextStyle(color: AppColors.error)),
                              ),
                            ],
                          ),
                        );
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'save',
                      child: Row(children: [
                        Icon(appState.isCourseSaved(course.id) ? Icons.bookmark : Icons.bookmark_border,
                            size: 18, color: AppColors.violet),
                        const SizedBox(width: 10),
                        Text(appState.isCourseSaved(course.id) ? 'Unsave' : 'Save Course',
                            style: GoogleFonts.dmSans(fontSize: 13)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'share',
                      child: Row(children: [
                        const Icon(Icons.share_outlined, size: 18, color: AppColors.teal),
                        const SizedBox(width: 10),
                        Text('Share', style: GoogleFonts.dmSans(fontSize: 13)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                        const SizedBox(width: 10),
                        Text('Delete', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.error)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Achievements / Badges Tab ───────────────────────────────────────────────

class _AchievementsTab extends StatelessWidget {
  final dynamic user;
  final bool isDark;
  const _AchievementsTab({required this.user, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final ownedBadges = appState.ownedBadges;

    final achievements = [
      {
        'icon': Icons.rocket_launch_outlined,
        'title': 'First Step',
        'desc': 'Completed first lesson',
        'earned': user.lessonsCompleted > 0,
        'color': AppColors.violet
      },
      {
        'icon': Icons.local_fire_department,
        'title': '7 Day Streak',
        'desc': 'Learned 7 days in a row',
        'earned': user.streakDays >= 7,
        'color': AppColors.gold
      },
      {
        'icon': Icons.quiz_outlined,
        'title': 'Quiz Master',
        'desc': 'Passed 10 quizzes',
        'earned': user.quizzesPassed >= 10,
        'color': AppColors.teal
      },
      {
        'icon': Icons.verified_rounded,
        'title': 'Quick Learner',
        'desc': 'Finished 5 lessons in 1 day',
        'earned': user.lessonsCompleted >= 5, // Simplified logic
        'color': AppColors.violet
      },
      {
        'icon': Icons.star_rounded,
        'title': 'Perfect Score',
        'desc': 'Scored 100% on any quiz',
        'earned': user.quizzesPassed > 0, // Simplified logic
        'color': AppColors.gold
      },
      {
        'icon': Icons.school_outlined,
        'title': 'Scholar',
        'desc': 'Completed 25 lessons',
        'earned': user.lessonsCompleted >= 25,
        'color': AppColors.violet
      },
      {
        'icon': Icons.emoji_events_outlined,
        'title': 'Champion',
        'desc': 'Reached 1000 Gantav Score',
        'earned': user.gantavScore >= 1000,
        'color': AppColors.gold
      },
      {
        'icon': Icons.task_alt_rounded,
        'title': 'Course Finisher',
        'desc': 'Completed a full course',
        'earned': user.lessonsCompleted >= 10, // Simplified logic
        'color': AppColors.teal
      },
      {
        'icon': Icons.workspace_premium_outlined,
        'title': 'Certified',
        'desc': 'Earned first certificate',
        'earned': user.lessonsCompleted >= 10,
        'color': AppColors.gold,
      },
      {
        'icon': Icons.calendar_month_rounded,
        'title': 'Persistence',
        'desc': 'Learned for 30 total days',
        'earned': user.streakDays >= 30, // Simplified logic
        'color': AppColors.violet
      },
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      physics: const BouncingScrollPhysics(),
      children: [
        // ── Shop badges earned ──────────────────────────────────────
        if (ownedBadges.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Text(
                  'Shop Badges',
                  style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textLight : AppColors.textDark),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    '${ownedBadges.length} earned',
                    style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold),
                  ),
                ),
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 140,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.95),
            itemCount: ownedBadges.length,
            itemBuilder: (ctx, i) {
              final b = ownedBadges[i];
              return _ShareableBadgeCard(b: b, isDark: isDark);
            },
          ),
          const SizedBox(height: 24),
        ],

        // ── Achievement badges ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Achievements',
            style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textLight : AppColors.textDark),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2),
          itemCount: achievements.length,
          itemBuilder: (ctx, i) {
            final a = achievements[i];
            return _ShareableAchievementCard(a: a, isDark: isDark);
          },
        ),
      ],
    );
  }
}

class _ShareableBadgeCard extends StatefulWidget {
  final dynamic b;
  final bool isDark;
  const _ShareableBadgeCard({required this.b, required this.isDark});

  @override
  State<_ShareableBadgeCard> createState() => _ShareableBadgeCardState();
}

class _ShareableBadgeCardState extends State<_ShareableBadgeCard> {
  final GlobalKey _cardKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final b = widget.b;
    final isDark = widget.isDark;

    return RepaintBoundary(
      key: _cardKey,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: b.color.withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: b.color.withValues(alpha: 0.35), width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(b.icon, color: b.color, size: 28),
                const SizedBox(height: 6),
                Text(b.title,
                    style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: b.color),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: () {
                ShareHelper.shareWidgetAsImage(
                  key: _cardKey,
                  text: 'Check out my "${b.title}" badge on Gantav AI! 🎯',
                  fileName: 'gantav_badge_${b.id}',
                );
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: b.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.share_rounded, color: b.color, size: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareableAchievementCard extends StatefulWidget {
  final Map<String, dynamic> a;
  final bool isDark;
  const _ShareableAchievementCard({required this.a, required this.isDark});

  @override
  State<_ShareableAchievementCard> createState() =>
      _ShareableAchievementCardState();
}

class _ShareableAchievementCardState extends State<_ShareableAchievementCard> {
  final GlobalKey _cardKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final a = widget.a;
    final isDark = widget.isDark;
    final earned = a['earned'] as bool;
    final color = a['color'] as Color;

    return RepaintBoundary(
      key: _cardKey,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: earned
                  ? color.withValues(alpha: isDark ? 0.12 : 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: earned
                      ? color.withValues(alpha: 0.3)
                      : isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(a['icon'] as IconData,
                    color: earned ? color : AppColors.textMuted, size: 28),
                const Spacer(),
                Text(a['title'] as String,
                    style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: earned
                            ? (isDark
                                ? AppColors.textLight
                                : AppColors.textDark)
                            : AppColors.textMuted)),
                Text(a['desc'] as String,
                    style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        height: 1.3)),
                if (!earned) ...[
                  const SizedBox(height: 6),
                  Text('Locked',
                      style: GoogleFonts.dmSans(
                          fontSize: 10,
                          color: AppColors.textMuted.withValues(alpha: 0.6)))
                ],
              ],
            ),
          ),
          if (earned)
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () {
                  ShareHelper.shareWidgetAsImage(
                    key: _cardKey,
                    text:
                        'I earned the "${a['title']}" achievement on Gantav AI! 🏆\n${a['desc']}',
                    fileName: 'gantav_achievement_${a['title']}',
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.share_rounded, color: color, size: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Settings Sheet ───────────────────────────────────────────────────────────

class _SettingsSheet extends StatelessWidget {
  final AppState appState;
  final bool isDark;
  final VoidCallback onEditProfile;
  const _SettingsSheet(
      {required this.appState,
      required this.isDark,
      required this.onEditProfile});

  @override
  Widget build(BuildContext context) {
    // Clean vertical settings list — iOS/Notion style. Responsive on any width
    // and orientation (uses ListView inside a constrained sheet).
    final items = <_SettingAction>[
      _SettingAction(
        icon: Icons.edit_outlined,
        title: 'Edit Profile',
        subtitle: 'Name, username, photo',
        color: AppColors.violet,
        onTap: onEditProfile,
      ),
      _SettingAction(
        icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        title: isDark ? 'Light Mode' : 'Dark Mode',
        subtitle: isDark ? 'Switch to bright theme' : 'Easier on the eyes',
        color: AppColors.gold,
        onTap: () {
          appState.toggleTheme();
          Navigator.pop(context);
        },
      ),
      if (AuthService.isAdmin)
        _SettingAction(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Admin Panel',
          subtitle: 'Manage content & PYQs',
          color: AppColors.violet,
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdminPanelScreen()));
          },
        ),
      _SettingAction(
        icon: Icons.storefront_rounded,
        title: 'Coin Store',
        subtitle: 'Spend coins on badges',
        color: const Color(0xFFF59E0B),
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CoinStoreScreen()),
          );
        },
      ),
      _SettingAction(
        icon: Icons.verified_outlined,
        title: 'Verify Certificate',
        subtitle: 'Check a certificate ID',
        color: AppColors.gold,
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const VerifyCertificateScreen(),
            ),
          );
        },
      ),
      _SettingAction(
        icon: Icons.help_outline_rounded,
        title: 'FAQs',
        subtitle: 'Frequently asked questions',
        color: AppColors.gold,
        onTap: () {
          Navigator.pop(context);
          _showFAQSheet(context, isDark);
        },
      ),
      _SettingAction(
        icon: Icons.alternate_email_rounded,
        title: 'Contact Us',
        subtitle: 'teamgantavai@gmail.com',
        color: AppColors.teal,
        onTap: () async {
          final Uri emailLaunchUri = Uri(
            scheme: 'mailto',
            path: 'teamgantavai@gmail.com',
            queryParameters: {
              'subject': 'Support Request - Gantav AI',
            },
          );
          if (await canLaunchUrl(emailLaunchUri)) {
            await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Could not open email app. Email: teamgantavai@gmail.com'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
      ),
      _SettingAction(
        icon: Icons.gavel_outlined,
        title: 'Terms & Conditions',
        subtitle: 'How to use Gantav AI',
        color: AppColors.violet,
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const LegalScreen(document: LegalDocument.terms),
            ),
          );
        },
      ),
      _SettingAction(
        icon: Icons.privacy_tip_outlined,
        title: 'Privacy Policy',
        subtitle: 'What we collect and why',
        color: AppColors.teal,
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const LegalScreen(document: LegalDocument.privacy),
            ),
          );
        },
      ),
      _SettingAction(
        icon: Icons.info_outline,
        title: 'About App',
        subtitle: 'Version 1.0.0 · Gantav AI',
        color: AppColors.textMuted,
        onTap: () {},
      ),
    ];

    final mq = MediaQuery.of(context);
    // Cap the sheet height so it scrolls instead of overflowing on short screens
    // or landscape orientation.
    final maxSheetHeight = mq.size.height * 0.8;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Settings',
                    style: GoogleFonts.dmSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textLight : AppColors.textDark,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 2),
                itemBuilder: (context, index) =>
                    _SettingsRow(action: items[index], isDark: isDark),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    Navigator.pop(context);
                    await appState.signOut();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.logout_rounded,
                              size: 18, color: AppColors.error),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Sign Out',
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _SettingAction({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
    this.subtitle = '',
  });
}

class _SettingsRow extends StatelessWidget {
  final _SettingAction action;
  final bool isDark;
  const _SettingsRow({required this.action, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? AppColors.textLight : AppColors.textDark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(action.icon, size: 20, color: action.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      action.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    if (action.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        action.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textMuted.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Favorites Tab ──────────────────────────────────────────────────────

class _FavoritesTab extends StatelessWidget {
  final AppState appState;
  final bool isDark;
  const _FavoritesTab({required this.appState, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final favorites = appState.favoriteCourses;
    final starredLessons = appState.starredLessons;

    if (favorites.isEmpty && starredLessons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite_border,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text('No favorites yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Saved courses and starred videos will appear here.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      physics: const BouncingScrollPhysics(),
      children: [
        if (favorites.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 8),
            child: Text('Saved Courses',
                style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textLight
                        : AppColors.textDark)),
          ),
          ...favorites.map((c) =>
              _CourseListTile(course: c, isDark: isDark)),
        ],
        if (starredLessons.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 16),
            child: Text('Starred Videos',
                style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textLight
                        : AppColors.textDark)),
          ),
          ...starredLessons.map((l) =>
              _LessonListTile(lesson: l, isDark: isDark)),
        ],
      ],
    );
  }
}

class _LessonListTile extends StatelessWidget {
  final Lesson lesson;
  final bool isDark;
  const _LessonListTile({required this.lesson, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color:
                isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              'https://img.youtube.com/vi/${lesson.youtubeVideoId}/0.jpg',
              width: 100,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                  color: AppColors.darkSurface2, width: 100, height: 60),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lesson.title,
                    style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(lesson.duration,
                    style: GoogleFonts.dmMono(
                        color: AppColors.violet,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseListTile extends StatelessWidget {
  final Course course;
  final bool isDark;
  const _CourseListTile({required this.course, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CourseDetailScreen(course: course))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color:
                  isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                course.thumbnailUrl,
                width: 80,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 80,
                  height: 60,
                  color: AppColors.darkSurface2,
                  child: const Center(
                      child: Icon(Icons.play_circle_outline,
                          color: AppColors.textMuted, size: 24)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      course.title
                          .replaceAll('\$dream', course.category),
                      style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  Text(course.category,
                      style: GoogleFonts.dmSans(
                          color: AppColors.violet,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textMuted),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface,
              onSelected: (value) {
                switch (value) {
                  case 'save':
                    appState.toggleSaveCourse(course.id);
                    break;
                  case 'share':
                    SharePlus.instance.share(ShareParams(
                      text: 'Check out "${course.title}" on Gantav AI! 🎯\nhttps://gantavai.com/course/${course.id}',
                    ));
                    break;
                  case 'delete':
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text('Delete Course?', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
                        content: Text('This will permanently remove "${course.title}" from your library.',
                            style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textMuted)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              appState.deleteCourse(course.id);
                            },
                            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
                          ),
                        ],
                      ),
                    );
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'save',
                  child: Row(children: [
                    Icon(appState.isCourseSaved(course.id) ? Icons.bookmark : Icons.bookmark_border,
                        size: 18, color: AppColors.violet),
                    const SizedBox(width: 10),
                    Text(appState.isCourseSaved(course.id) ? 'Unsave' : 'Save Course',
                        style: GoogleFonts.dmSans(fontSize: 13)),
                  ]),
                ),
                PopupMenuItem(
                  value: 'share',
                  child: Row(children: [
                    const Icon(Icons.share_outlined, size: 18, color: AppColors.teal),
                    const SizedBox(width: 10),
                    Text('Share', style: GoogleFonts.dmSans(fontSize: 13)),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                    const SizedBox(width: 10),
                    Text('Delete', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.error)),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _showFAQSheet(BuildContext context, bool isDark) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (_, controller) => _FAQView(controller: controller, isDark: isDark),
    ),
  );
}


class _FAQView extends StatelessWidget {
  final ScrollController controller;
  final bool isDark;

  const _FAQView({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {
        'q': 'How do I generate a course?',
        'a': 'Simply enter any topic you want to learn in the search bar on the Home screen. Gantav AI will analyze YouTube content and generate a structured roadmap with lessons and quizzes for you.'
      },
      {
        'q': 'Is Gantav AI free to use?',
        'a': 'Yes! You can generate up to 5 courses for free. You can delete old courses to free up slots for new topics.'
      },
      {
        'q': 'How do I earn certificates?',
        'a': 'Complete all lessons in a course and pass the associated quizzes with a score of 60% or higher to unlock your Gantav Verified certificate.'
      },
      {
        'q': 'Can I learn on multiple devices?',
        'a': 'Absolutely. Your progress is synced to your Google account, allowing you to pick up exactly where you left off on any device.'
      },
      {
        'q': 'What are "Flips"?',
        'a': 'If you don\'t like the video selected for a lesson, you can "Flip" it. Gantav AI will search for an alternative high-quality video for that specific topic.'
      },
    ];

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.textMuted.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Text(
                'Frequently Asked Questions',
                style: GoogleFonts.dmSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textLight : AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: controller,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: faqs.length,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: ExpansionTile(
                  shape: const RoundedRectangleBorder(side: BorderSide.none),
                  collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                  title: Text(
                    faqs[index]['q']!,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textLight : AppColors.textDark,
                    ),
                  ),
                  iconColor: AppColors.violet,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(
                        faqs[index]['a']!,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          height: 1.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}