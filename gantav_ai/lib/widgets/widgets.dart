import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

// ── Responsive Container ────────────────────────────────────────────────────
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final bool center;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 850, // Optimal reading/learning width
    this.center = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!center) return child;
    
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

// ── Simple Progress Bar ───────────────────────────────────────────────────────
class SimpleProgressBar extends StatelessWidget {
  final double progress;
  final double height;
  final Color? backgroundColor;

  const SimpleProgressBar({
    super.key,
    required this.progress,
    this.height = 6,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = backgroundColor ??
        (isDark ? AppColors.darkSurface2 : AppColors.lightSurface2);

    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: Stack(
            children: [
              Container(
                height: height, width: constraints.maxWidth,
                color: bgColor,
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                height: height,
                width: constraints.maxWidth * progress.clamp(0.0, 1.0),
                decoration: BoxDecoration(
                  color: AppColors.progressColor(progress),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Active Course Card ────────────────────────────────────────────────────────
class ActiveCourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback onTap;

  const ActiveCourseCard({super.key, required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pct = (course.progress * 100).round();

    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 240,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: SizedBox(
                      height: 130, width: double.infinity,
                      child: Image.network(
                        course.thumbnailUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.darkSurface2,
                          child: const Center(
                            child: Icon(Icons.play_circle_outline,
                              color: AppColors.textMuted, size: 36))),
                      ),
                    ),
                  ),
                  if (course.isVerified)
                    Positioned(
                      top: 10, left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha:0.75),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.gold.withValues(alpha:0.5), width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified, color: AppColors.gold, size: 12),
                            const SizedBox(width: 4),
                            Text('VERIFIED',
                              style: GoogleFonts.dmSans(
                                fontSize: 9, fontWeight: FontWeight.w900,
                                color: AppColors.gold, letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category
                      _CatPill(category: course.isVerified ? 'Gantav Verified' : course.category, isVerified: course.isVerified),
                      const SizedBox(height: 6),
                      // Title
                      Text(course.title,
                        style: GoogleFonts.dmSans(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.textLight : AppColors.textDark,
                          height: 1.3),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                      const Spacer(),
                      // Progress
                      SimpleProgressBar(progress: course.progress, height: 5),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${course.completedLessons}/${course.totalLessons} lessons',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: isDark ? AppColors.textLightSub : AppColors.textDarkSub)),
                          Text('$pct%',
                            style: GoogleFonts.dmMono(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: AppColors.progressColor(course.progress))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Continue button
                      Container(
                        width: double.infinity,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.violet.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Continue',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  color: AppColors.violet)),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_rounded,
                                size: 13, color: AppColors.violet),
                            ],
                          ),
                        ),
                      ),
                    ],
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

// ── Suggested Course Row ──────────────────────────────────────────────────────
class SuggestedCourseRow extends StatelessWidget {
  final Course course;
  final VoidCallback onTap;

  const SuggestedCourseRow({super.key, required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Row(
          children: [
            // Thumbnail
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 72, height: 56,
                    child: Image.network(
                      course.thumbnailUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.darkSurface2,
                        child: const Icon(Icons.play_circle_outline,
                          color: AppColors.textMuted, size: 24)),
                    ),
                  ),
                ),
                if (course.isVerified)
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                      child: const Icon(Icons.verified, color: AppColors.gold, size: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: _CatPill(category: course.isVerified ? 'Gantav Verified' : course.category, small: true, isVerified: course.isVerified)),
                      const SizedBox(width: 8),
                      const Icon(Icons.star_rounded, color: AppColors.gold, size: 12),
                      const SizedBox(width: 3),
                      Text(course.rating.toStringAsFixed(1),
                        style: GoogleFonts.dmMono(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: AppColors.gold)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(course.title,
                    style: GoogleFonts.dmSans(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textLight : AppColors.textDark,
                      height: 1.3),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('${course.totalLessons} lessons · ${course.estimatedTime}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: isDark ? AppColors.textLightSub : AppColors.textDarkSub)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right,
              color: AppColors.textMuted.withValues(alpha:0.5), size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Pulse Event Tile ──────────────────────────────────────────────────────────
class PulseEventTile extends StatefulWidget {
  final PulseEvent event;
  const PulseEventTile({super.key, required this.event});

  @override
  State<PulseEventTile> createState() => _PulseEventTileState();
}

class _PulseEventTileState extends State<PulseEventTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
        ..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          // Live dot
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                color: AppColors.liveRed.withValues(alpha:0.4 + _ctrl.value * 0.6),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.liveRed.withValues(alpha:_ctrl.value * 0.35),
                    blurRadius: 6, spreadRadius: 1),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              maxLines: 1, overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: isDark ? AppColors.textLight : AppColors.textDark),
                children: [
                  TextSpan(
                    text: widget.event.userName,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: ' ${widget.event.action} ',
                    style: TextStyle(
                      color: isDark ? AppColors.textLightSub : AppColors.textDarkSub)),
                  TextSpan(
                    text: widget.event.courseName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600, color: AppColors.violet)),
                  TextSpan(
                    text: ' · ${widget.event.timeAgo}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category Pill ─────────────────────────────────────────────────────────────
class _CatPill extends StatelessWidget {
  final String category;
  final bool small;
  final bool isVerified;
  const _CatPill({required this.category, this.small = false, this.isVerified = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 7 : 9,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: isVerified ? AppColors.gold.withValues(alpha:0.12) : AppColors.violet.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(100),
        border: isVerified ? Border.all(color: AppColors.gold.withValues(alpha:0.3), width: 0.5) : null,
      ),
      child: Text(category,
        style: GoogleFonts.dmSans(
          fontSize: small ? 10 : 11,
          fontWeight: FontWeight.w600,
          color: isVerified ? AppColors.gold : AppColors.violet),
        maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

// ── Home Shimmer ──────────────────────────────────────────────────────────────
class HomeShimmer extends StatefulWidget {
  const HomeShimmer({super.key});
  @override
  State<HomeShimmer> createState() => _HomeShimmerState();
}

class _HomeShimmerState extends State<HomeShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _Shimmer(width: 160, height: 28, isDark: isDark, ctrl: _ctrl),
            const SizedBox(height: 8),
            _Shimmer(width: 240, height: 18, isDark: isDark, ctrl: _ctrl),
            const SizedBox(height: 20),
            _Shimmer(width: double.infinity, height: 70, isDark: isDark, ctrl: _ctrl, radius: 16),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _Shimmer(height: 60, isDark: isDark, ctrl: _ctrl, radius: 14)),
              const SizedBox(width: 12),
              Expanded(child: _Shimmer(height: 60, isDark: isDark, ctrl: _ctrl, radius: 14)),
              const SizedBox(width: 12),
              Expanded(child: _Shimmer(height: 60, isDark: isDark, ctrl: _ctrl, radius: 14)),
            ]),
            const SizedBox(height: 24),
            _Shimmer(width: 180, height: 20, isDark: isDark, ctrl: _ctrl),
            const SizedBox(height: 14),
            _Shimmer(width: double.infinity, height: 72, isDark: isDark, ctrl: _ctrl, radius: 14),
            const SizedBox(height: 10),
            _Shimmer(width: double.infinity, height: 72, isDark: isDark, ctrl: _ctrl, radius: 14),
            const SizedBox(height: 10),
            _Shimmer(width: double.infinity, height: 72, isDark: isDark, ctrl: _ctrl, radius: 14),
          ],
        ),
      ),
    );
  }
}

class _Shimmer extends StatelessWidget {
  final double? width;
  final double height;
  final bool isDark;
  final AnimationController ctrl;
  final double radius;

  const _Shimmer({
    this.width,
    required this.height,
    required this.isDark,
    required this.ctrl,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) => ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            isDark ? Colors.white.withValues(alpha:0.06) : Colors.white.withValues(alpha:0.9),
            Colors.transparent,
          ],
          stops: [
            (ctrl.value - 0.3).clamp(0.0, 1.0),
            ctrl.value,
            (ctrl.value + 0.3).clamp(0.0, 1.0),
          ],
        ).createShader(bounds),
        blendMode: BlendMode.srcATop,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface2,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onAction;

  const SectionHeader({super.key, required this.title, this.actionText, this.onAction});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(title, 
              style: GoogleFonts.dmSans(
                fontSize: 17, fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textLight : AppColors.textDark),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          if (actionText != null)
            const SizedBox(width: 12),
          if (actionText != null)
            GestureDetector(
              onTap: onAction,
              child: Text(actionText!, style: GoogleFonts.dmSans(
                fontSize: 13, color: AppColors.violet, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

// ── Module Card ───────────────────────────────────────────────────────────────
class ModuleCard extends StatelessWidget {
  final Module module;
  final int index;
  final bool isLast;
  final VoidCallback? onTap;

  const ModuleCard({
    super.key,
    required this.module,
    required this.index,
    this.isLast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: module.isLocked ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: module.isLocked ? 0.45 : 1.0,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline
            Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: module.isLocked
                        ? AppColors.textMuted.withValues(alpha: 0.1)
                        : AppColors.violet.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: module.isLocked
                        ? const Icon(Icons.lock_outline,
                            size: 18, color: AppColors.textMuted)
                        : Text(
                            (index + 1).toString().padLeft(2, '0'),
                            style: GoogleFonts.dmMono(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.violet),
                          ),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 4,
                    height: 50,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            // Content Card
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.title,
                      style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textLight
                              : AppColors.textDark),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.play_circle_outline,
                            size: 14,
                            color: isDark
                                ? AppColors.textLightSub
                                : AppColors.textDarkSub),
                        const SizedBox(width: 4),
                        Text(
                          '${module.completedCount}/${module.lessonCount} lessons',
                          style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.textLightSub
                                  : AppColors.textDarkSub),
                        ),
                      ],
                    ),
                    if (!module.isLocked && module.progress > 0) ...[
                      const SizedBox(height: 12),
                      SimpleProgressBar(progress: module.progress, height: 6),
                    ],
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

// ── Streak Bar ────────────────────────────────────────────────────────────────
class StreakBar extends StatelessWidget {
  final List<bool> weekActivity;
  const StreakBar({super.key, required this.weekActivity});

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final active = i < weekActivity.length && weekActivity[i];
        return Column(
          children: [
            Text(_days[i],
              style: GoogleFonts.dmSans(
                fontSize: 11, fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textLightSub : AppColors.textDarkSub)),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: active
                    ? AppColors.teal.withValues(alpha:0.15)
                    : (isDark ? AppColors.darkSurface2 : AppColors.lightSurface2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active
                      ? AppColors.teal.withValues(alpha:0.35)
                      : Colors.transparent),
              ),
              child: active
                  ? const Center(child: Icon(Icons.check_rounded, color: AppColors.teal, size: 16))
                  : null,
            ),
          ],
        );
      }),
    );
  }
}

// ── Stat Chip (legacy compat) ─────────────────────────────────────────────────
class StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const StatChip({super.key, required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha:isDark ? 0.08 : 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha:0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                    style: GoogleFonts.dmSans( // Changed from dmMono for better fit
                      fontSize: 16, fontWeight: FontWeight.w700, color: color),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(label,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: isDark ? AppColors.textLightSub : AppColors.textDarkSub),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
