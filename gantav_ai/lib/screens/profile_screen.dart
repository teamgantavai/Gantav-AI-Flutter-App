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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      context.read<AppState>().updateProfileImage(image.path);
    }
  }

  void _showEditProfileSheet(BuildContext context, AppState appState, bool isDark) {
    final nameController = TextEditingController(text: appState.user?.name ?? '');
    final handleController = TextEditingController(text: appState.user?.handle ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24.0, right: 24.0, top: 24.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit Profile',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                filled: true,
                fillColor: isDark ? const Color(0xFF1E212D) : const Color(0xFFF3F4F6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: handleController,
              decoration: InputDecoration(
                labelText: 'Handle',
                filled: true,
                fillColor: isDark ? const Color(0xFF1E212D) : const Color(0xFFF3F4F6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  appState.updateUserProfile(
                    name: nameController.text,
                    handle: handleController.text,
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.violet,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context, AppState appState, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.violet.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.settings_rounded, color: AppColors.violet, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  'Settings',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.edit_outlined, size: 18,
                  color: isDark ? AppColors.textLight : AppColors.textDark,
                ),
              ),
              title: Text('Edit Profile', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w500)),
              trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                Navigator.pop(ctx);
                _showEditProfileSheet(context, appState, isDark);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 18,
                  color: isDark ? AppColors.textLight : AppColors.textDark,
                ),
              ),
              title: Text('Toggle Theme', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w500)),
              trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                context.read<AppState>().toggleTheme();
                Navigator.pop(ctx);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
              ),
              title: Text('Sign Out', style: GoogleFonts.dmSans(
                fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.error)),
              contentPadding: EdgeInsets.zero,
              onTap: () async {
                Navigator.pop(ctx);
                await context.read<AppState>().signOut();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<AppState>(
      builder: (context, appState, _) {
        final user = appState.user;
        if (user == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.violet),
          );
        }

        return Stack(
          children: [
            // ─── Scrollable Content ─────────────────────────────
            RefreshIndicator(
              onRefresh: appState.refresh,
              color: AppColors.violet,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 48), // Space for the fixed settings button

                    // ─── Avatar ──────────────────────────────────────────
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: AppColors.violet.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.violet.withValues(alpha: 0.3),
                                width: 2,
                              ),
                              image: appState.profileImagePath != null
                                  ? DecorationImage(
                                      image: FileImage(File(appState.profileImagePath!)),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: appState.profileImagePath == null
                                ? Center(
                                    child: Text(
                                      user.initials,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.violet,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.violet,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      user.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'gantav.ai/u/${user.handle}',
                      style: GoogleFonts.dmMono(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ─── Gantav Score ────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: isDark ? 0.08 : 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.stars_rounded,
                                  color: AppColors.gold, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                'Gantav Score',
                                style: GoogleFonts.dmSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.gold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${user.gantavScore}',
                            style: GoogleFonts.dmMono(
                              fontSize: 40,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gold,
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Score breakdown
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _ScoreBreakdown(
                                icon: Icons.play_lesson_outlined,
                                value: '${user.lessonsCompleted}',
                                label: 'Lessons',
                              ),
                              Container(
                                width: 1,
                                height: 32,
                                color: AppColors.gold.withValues(alpha: 0.2),
                              ),
                              _ScoreBreakdown(
                                icon: Icons.quiz_outlined,
                                value: '${user.quizzesPassed}',
                                label: 'Quizzes',
                              ),
                              Container(
                                width: 1,
                                height: 32,
                                color: AppColors.gold.withValues(alpha: 0.2),
                              ),
                              _ScoreBreakdown(
                                icon: Icons.local_fire_department,
                                value: '${user.streakDays}',
                                label: 'Streak',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ─── Streak Bar ──────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
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
                          Row(
                            children: [
                              const Icon(Icons.local_fire_department,
                                  color: AppColors.teal, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '7-day streak',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(color: AppColors.teal),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          StreakBar(weekActivity: user.weekActivity),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ─── Active Paths ────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
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
                          Text(
                            'Active paths',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 14),
                          ...appState.activeCourses.map((course) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          course.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '${(course.progress * 100).round()}%',
                                        style: GoogleFonts.dmMono(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.progressColor(
                                              course.progress),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SimpleProgressBar(
                                      progress: course.progress, height: 6),
                                ],
                              ),
                            );
                          }),
                          if (appState.activeCourses.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'No active paths yet. Start one!',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ─── Share Profile Button ────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          SharePlus.instance.share(
                            ShareParams(
                              text: 'Check out my learning profile on Gantav AI! \nhttps://gantav.ai/u/${user.handle}',
                              subject: 'My Gantav AI Profile',
                            ),
                          );
                        },
                        icon: const Icon(Icons.share_outlined, size: 18),
                        label: Text(
                          'Share profile',
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.violet,
                          side: const BorderSide(color: AppColors.violet),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),

            // ─── Fixed Settings Gear ─────────────────────────────
            Positioned(
              top: 12,
              right: 16,
              child: GestureDetector(
                onTap: () => _showSettingsSheet(context, appState, isDark),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Icon(
                        Icons.settings_rounded,
                        size: 20,
                        color: isDark ? AppColors.textLight : AppColors.textDark,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScoreBreakdown extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _ScoreBreakdown({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.gold.withValues(alpha: 0.6), size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.dmMono(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.gold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
              ),
        ),
      ],
    );
  }
}
