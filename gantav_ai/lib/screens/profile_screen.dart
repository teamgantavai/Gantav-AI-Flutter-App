import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/app_state.dart';
import '../widgets/widgets.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'roadmap_screen.dart';
import '../models/models.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
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
        if (user == null) return const Center(child: CircularProgressIndicator(color: AppColors.violet));

        return RefreshIndicator(
          onRefresh: appState.refresh,
          color: AppColors.violet,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // ── Hero Profile Header ──────────────────────────────
              SliverToBoxAdapter(
                child: _ProfileHero(
                  user: user,
                  appState: appState,
                  isDark: isDark,
                  onAvatarTap: _pickImage,
                  onSettingsTap: () => _showSettingsSheet(context, appState, isDark),
                ),
              ),

              // ── Stats Row ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: _StatsRow(user: user, isDark: isDark),
                ),
              ),

              // ── Tab Bar ──────────────────────────────────────────
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  tabController: _tabController,
                  isDark: isDark,
                ),
              ),

              // ── Tab Content ──────────────────────────────────────
              SliverFillRemaining(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ActivePathsTab(appState: appState, isDark: isDark),
                    _AchievementsTab(user: user, isDark: isDark),
                    _ActivityTab(user: user, isDark: isDark),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSettingsSheet(BuildContext context, AppState appState, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _SettingsSheet(appState: appState, isDark: isDark, onEditProfile: () {
        Navigator.pop(ctx);
        _showEditProfileSheet(context, appState, isDark);
      }),
    );
  }

  void _showEditProfileSheet(BuildContext context, AppState appState, bool isDark) {
    final nameCtrl = TextEditingController(text: appState.user?.name ?? '');
    final handleCtrl = TextEditingController(text: appState.user?.handle ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Profile', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
            const SizedBox(height: 16),
            TextField(controller: handleCtrl, decoration: const InputDecoration(labelText: 'Username', prefixText: '@')),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: () {
                  appState.updateUserProfile(name: nameCtrl.text, handle: handleCtrl.text);
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

// ── Profile Hero Widget ────────────────────────────────────────────────────

class _ProfileHero extends StatelessWidget {
  final dynamic user;
  final AppState appState;
  final bool isDark;
  final VoidCallback onAvatarTap;
  final VoidCallback onSettingsTap;

  const _ProfileHero({
    required this.user, required this.appState, required this.isDark,
    required this.onAvatarTap, required this.onSettingsTap,
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
              ? [AppColors.violet.withOpacity(0.15), AppColors.darkSurface]
              : [AppColors.violet.withOpacity(0.05), AppColors.lightSurface],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.violet.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Settings row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stars_rounded, color: AppColors.gold, size: 14),
                      const SizedBox(width: 5),
                      Text('${user.gantavScore} pts',
                        style: GoogleFonts.dmMono(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gold)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onSettingsTap,
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08)),
                    ),
                    child: Icon(Icons.settings_outlined, size: 18,
                      color: isDark ? AppColors.textLight : AppColors.textDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Avatar
            GestureDetector(
              onTap: onAvatarTap,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 84, height: 84,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.violet, AppColors.violetDark],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.violet.withOpacity(0.4), width: 3),
                      image: appState.profileImagePath != null
                          ? DecorationImage(image: FileImage(File(appState.profileImagePath!)), fit: BoxFit.cover)
                          : null,
                    ),
                    child: appState.profileImagePath == null
                        ? Center(
                            child: Text(user.initials,
                              style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                          )
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(color: AppColors.violet, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Text(user.name,
              style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800,
                color: isDark ? AppColors.textLight : AppColors.textDark)),
            const SizedBox(height: 2),
            Text('@${user.handle}',
              style: GoogleFonts.dmMono(fontSize: 13, color: AppColors.textMuted)),
            const SizedBox(height: 4),

            // Roadmap progress badge
            if (appState.activeRoadmap != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.violet.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppColors.violet.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.route_rounded, color: AppColors.violet, size: 12),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${(appState.activeRoadmap!.taskProgress * 100).round()}% • ${appState.activeRoadmap!.title}',
                        style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.violet),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Share button
            SizedBox(
              width: double.infinity, height: 42,
              child: OutlinedButton.icon(
                onPressed: () {
                  SharePlus.instance.share(ShareParams(
                    text: 'Check out my learning journey on Gantav AI! 🎯\nhttps://gantavai.com/u/${user.handle}',
                  ));
                },
                icon: const Icon(Icons.share_outlined, size: 16),
                label: Text('Share Profile', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.violet,
                  side: BorderSide(color: AppColors.violet.withOpacity(0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final dynamic user;
  final bool isDark;
  const _StatsRow({required this.user, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(value: '${user.lessonsCompleted}', label: 'Lessons', icon: Icons.play_lesson_outlined, color: AppColors.teal, isDark: isDark),
        const SizedBox(width: 10),
        _StatCard(value: '${user.quizzesPassed}', label: 'Quizzes', icon: Icons.quiz_outlined, color: AppColors.violet, isDark: isDark),
        const SizedBox(width: 10),
        _StatCard(value: '${user.streakDays}', label: 'Streak', icon: Icons.local_fire_department, color: AppColors.gold, isDark: isDark),
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
  const _StatCard({required this.value, required this.label, required this.icon, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.1 : 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: GoogleFonts.dmMono(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ── Tab Bar Delegate ──────────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  final bool isDark;
  const _TabBarDelegate({required this.tabController, required this.isDark});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: isDark ? AppColors.darkBg : AppColors.lightBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface2,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: tabController,
          indicator: BoxDecoration(color: AppColors.violet, borderRadius: BorderRadius.circular(10)),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
          indicatorPadding: const EdgeInsets.all(3),
          tabs: const [Tab(text: 'Roadmaps'), Tab(text: 'Achievements'), Tab(text: 'Activity')],
        ),
      ),
    );
  }

  @override double get maxExtent => 60;
  @override double get minExtent => 60;
  @override bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}

// ── Tab Contents ──────────────────────────────────────────────────────────

class _ActivePathsTab extends StatelessWidget {
  final AppState appState;
  final bool isDark;
  const _ActivePathsTab({required this.appState, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final roadmaps = appState.roadmaps;
    final courses = appState.activeCourses;

    if (roadmaps.isEmpty && courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route_outlined, color: AppColors.textMuted, size: 56),
            const SizedBox(height: 16),
            Text('No roadmaps yet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Complete onboarding to get your first roadmap',
              style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      physics: const BouncingScrollPhysics(),
      children: [
        // Roadmaps section
        if (roadmaps.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('My Roadmaps',
              style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textLight : AppColors.textDark)),
          ),
          ...roadmaps.map((roadmap) => GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => RoadmapScreen(roadmap: roadmap)),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.violet.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.route_rounded, size: 20, color: AppColors.violet),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(roadmap.title,
                              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.textLight : AppColors.textDark),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text('${roadmap.completedDays}/${roadmap.totalDays} days • ${roadmap.completedTasks}/${roadmap.totalTasks} tasks',
                              style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      Text('${(roadmap.taskProgress * 100).round()}%',
                        style: GoogleFonts.dmMono(fontSize: 14, fontWeight: FontWeight.w700,
                          color: AppColors.progressColor(roadmap.taskProgress))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SimpleProgressBar(progress: roadmap.taskProgress, height: 6),
                ],
              ),
            ),
          )),
        ],

        // Legacy courses section (kept for users who have them)
        if (courses.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Text('My Courses',
              style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textLight : AppColors.textDark)),
          ),
          ...courses.map((course) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(course.thumbnailUrl, width: 52, height: 40, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(width: 52, height: 40, color: AppColors.darkSurface2)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(course.title, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textLight : AppColors.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('${course.completedLessons}/${course.totalLessons} lessons',
                            style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    Text('${(course.progress * 100).round()}%',
                      style: GoogleFonts.dmMono(fontSize: 14, fontWeight: FontWeight.w700,
                        color: AppColors.progressColor(course.progress))),
                  ],
                ),
                const SizedBox(height: 10),
                SimpleProgressBar(progress: course.progress, height: 6),
              ],
            ),
          )),
        ],
      ],
    );
  }
}

class _AchievementsTab extends StatelessWidget {
  final dynamic user;
  final bool isDark;
  const _AchievementsTab({required this.user, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final achievements = [
      {'icon': Icons.rocket_launch_outlined, 'title': 'First Step', 'desc': 'Completed first lesson', 'earned': user.lessonsCompleted > 0, 'color': AppColors.violet},
      {'icon': Icons.local_fire_department, 'title': '7 Day Streak', 'desc': 'Learned 7 days in a row', 'earned': user.streakDays >= 7, 'color': AppColors.gold},
      {'icon': Icons.quiz_outlined, 'title': 'Quiz Master', 'desc': 'Passed 10 quizzes', 'earned': user.quizzesPassed >= 10, 'color': AppColors.teal},
      {'icon': Icons.school_outlined, 'title': 'Scholar', 'desc': 'Completed 25 lessons', 'earned': user.lessonsCompleted >= 25, 'color': AppColors.violet},
      {'icon': Icons.emoji_events_outlined, 'title': 'Champion', 'desc': 'Reached 1000 Gantav Score', 'earned': user.gantavScore >= 1000, 'color': AppColors.gold},
    ];

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.1,
      ),
      itemCount: achievements.length,
      itemBuilder: (ctx, i) {
        final a = achievements[i];
        final earned = a['earned'] as bool;
        final color = a['color'] as Color;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: earned
                ? color.withOpacity(isDark ? 0.12 : 0.08)
                : isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: earned ? color.withOpacity(0.3) : isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(a['icon'] as IconData, color: earned ? color : AppColors.textMuted, size: 28),
              const Spacer(),
              Text(a['title'] as String, style: GoogleFonts.dmSans(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: earned ? (isDark ? AppColors.textLight : AppColors.textDark) : AppColors.textMuted)),
              Text(a['desc'] as String, style: GoogleFonts.dmSans(
                fontSize: 11, color: AppColors.textMuted, height: 1.3)),
              if (!earned) ...[
                const SizedBox(height: 6),
                Text('Locked', style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.textMuted.withOpacity(0.6))),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ActivityTab extends StatelessWidget {
  final dynamic user;
  final bool isDark;
  const _ActivityTab({required this.user, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This Week', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          StreakBar(weekActivity: user.weekActivity),
          const SizedBox(height: 24),
          Text('Learning Stats', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _StatRow(label: 'Total lessons', value: '${user.lessonsCompleted}', isDark: isDark),
          _StatRow(label: 'Quizzes passed', value: '${user.quizzesPassed}', isDark: isDark),
          _StatRow(label: 'Current streak', value: '${user.streakDays} days', isDark: isDark),
          _StatRow(label: 'Gantav Score', value: '${user.gantavScore}', isDark: isDark),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  const _StatRow({required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.dmSans(fontSize: 14, color: isDark ? AppColors.textLightSub : AppColors.textDarkSub)),
          Text(value, style: GoogleFonts.dmMono(fontSize: 14, fontWeight: FontWeight.w700,
            color: isDark ? AppColors.textLight : AppColors.textDark)),
        ],
      ),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  final AppState appState;
  final bool isDark;
  final VoidCallback onEditProfile;
  const _SettingsSheet({required this.appState, required this.isDark, required this.onEditProfile});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.textMuted.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text('Settings', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          _SettingsTile(icon: Icons.edit_outlined, title: 'Edit Profile', onTap: onEditProfile, isDark: isDark),
          _SettingsTile(icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            title: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onTap: () { appState.toggleTheme(); Navigator.pop(context); }, isDark: isDark),
          _SettingsTile(icon: Icons.notifications_outlined, title: 'Notifications', onTap: () {}, isDark: isDark),
          _SettingsTile(icon: Icons.help_outline, title: 'Help & Support', onTap: () {}, isDark: isDark),
          const SizedBox(height: 8),
          _SettingsTile(icon: Icons.logout_rounded, title: 'Sign Out', isDestructive: true,
            onTap: () async { Navigator.pop(context); await appState.signOut(); }, isDark: isDark),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool isDark;
  const _SettingsTile({required this.icon, required this.title, required this.onTap, this.isDestructive = false, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.error : (isDark ? AppColors.textLight : AppColors.textDark);
    return ListTile(
      leading: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: isDestructive ? AppColors.error.withOpacity(0.1) : isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(title, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w500, color: color)),
      trailing: isDestructive ? null : const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
    );
  }
}
