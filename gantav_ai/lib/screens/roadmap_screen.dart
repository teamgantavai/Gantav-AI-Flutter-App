import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';
import '../services/app_state.dart';
import '../models/onboarding_models.dart';

/// Displays the AI-generated learning roadmap with day-by-day timeline, 
/// task completion tracking, and share functionality.
class RoadmapScreen extends StatefulWidget {
  final Roadmap roadmap;
  const RoadmapScreen({super.key, required this.roadmap});

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  final GlobalKey _shareKey = GlobalKey();
  final ScrollController _scrollCtrl = ScrollController();
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    
    // Scroll to current day after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentDay();
    });
  }

  void _scrollToCurrentDay() {
    final currentDay = widget.roadmap.currentDayNumber;
    // Approximate scroll position (each day card ~200px)
    final targetScroll = (currentDay - 1) * 200.0;
    if (_scrollCtrl.hasClients && targetScroll > 0) {
      _scrollCtrl.animateTo(
        targetScroll.clamp(0, _scrollCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _shareAsImage() async {
    setState(() => _isSharing = true);
    try {
      final boundary = _shareKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/gantav_roadmap.png');
      await file.writeAsBytes(pngBytes);

      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        text: '🎯 My learning roadmap on Gantav AI!\n${widget.roadmap.title}\n\nhttps://gantavai.com',
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roadmap = widget.roadmap;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            _buildAppBar(isDark, roadmap),

            // ── Content ─────────────────────────────────────────────
            Expanded(
              child: RepaintBoundary(
                key: _shareKey,
                child: Container(
                  color: isDark ? AppColors.darkBg : AppColors.lightBg,
                  child: CustomScrollView(
                    controller: _scrollCtrl,
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // Progress overview card
                      SliverToBoxAdapter(
                        child: _buildProgressCard(isDark, roadmap),
                      ),

                      // Today's tasks highlight
                      SliverToBoxAdapter(
                        child: _buildTodayCard(isDark, roadmap),
                      ),

                      // Timeline
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                          child: Text('Roadmap Timeline',
                            style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.textLight : AppColors.textDark)),
                        ),
                      ),

                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildTimelineDay(isDark, roadmap, roadmap.days[index], index),
                            childCount: roadmap.days.length,
                          ),
                        ),
                      ),

                      // Watermark for sharing
                      SliverToBoxAdapter(
                        child: _buildWatermark(isDark),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  ),
                ),
              ),
            ),

            // ── Bottom bar with share/save ───────────────────────────
            _buildBottomBar(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark, Roadmap roadmap) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_back, size: 18,
                color: isDark ? AppColors.textLight : AppColors.textDark),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(roadmap.title,
                  style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textLight : AppColors.textDark),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${roadmap.totalDays} days · ${roadmap.language == 'hi' ? 'हिन्दी' : 'English'}',
                  style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(bool isDark, Roadmap roadmap) {
    final pct = (roadmap.taskProgress * 100).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.violet.withValues(alpha: isDark ? 0.15 : 0.08),
              AppColors.teal.withValues(alpha: isDark ? 0.08 : 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.violet.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Overall Progress',
                      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                    const SizedBox(height: 4),
                    Text('$pct%',
                      style: GoogleFonts.dmMono(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.violet)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${roadmap.completedTasks}/${roadmap.totalTasks}',
                      style: GoogleFonts.dmMono(fontSize: 16, fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textLight : AppColors.textDark)),
                    Text('tasks done',
                      style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(height: 8),
                    Text('Day ${roadmap.currentDayNumber}/${roadmap.totalDays}',
                      style: GoogleFonts.dmMono(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.teal)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Animated progress bar
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: roadmap.taskProgress),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) => ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                  valueColor: const AlwaysStoppedAnimation(AppColors.violet),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayCard(bool isDark, Roadmap roadmap) {
    final today = roadmap.todayDay;
    if (today == null) return const SizedBox();

    final allDone = today.allTasksCompleted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: allDone
              ? AppColors.teal.withValues(alpha: 0.1)
              : AppColors.gold.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: allDone
                ? AppColors.teal.withValues(alpha: 0.3)
                : AppColors.gold.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: allDone
                    ? AppColors.teal.withValues(alpha: 0.15)
                    : AppColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                allDone ? Icons.check_circle_outline : Icons.today_outlined,
                color: allDone ? AppColors.teal : AppColors.gold, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(allDone ? 'Today\'s tasks complete! 🎉' : 'Today\'s Tasks',
                    style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700,
                      color: allDone ? AppColors.teal : AppColors.gold)),
                  Text('${today.completedTaskCount}/${today.tasks.length} tasks · ${today.topic}',
                    style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineDay(bool isDark, Roadmap roadmap, RoadmapDay day, int index) {
    final isCurrentDay = day.dayNumber == roadmap.currentDayNumber;
    final isPast = day.dayNumber < roadmap.currentDayNumber;
    final isCompleted = day.isCompleted;
    final isLast = index == roadmap.days.length - 1;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline column (dot + line)
          SizedBox(
            width: 40,
            child: Column(
              children: [
                const SizedBox(height: 4),
                // Dot
                if (isCurrentDay)
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) => Container(
                      width: 18, height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.violet,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.violet.withValues(alpha: _pulseCtrl.value * 0.4),
                            blurRadius: 10, spreadRadius: 2),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.play_arrow_rounded, size: 10, color: Colors.white)),
                    ),
                  )
                else
                  Container(
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                      color: isCompleted ? AppColors.teal : (isPast ? AppColors.textMuted : AppColors.darkSurface2),
                      shape: BoxShape.circle,
                      border: isCompleted ? null : Border.all(
                        color: isPast ? AppColors.textMuted : AppColors.darkBorder, width: 2),
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check, size: 10, color: Colors.white)
                        : null,
                  ),
                // Line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: isCompleted
                          ? AppColors.teal.withValues(alpha: 0.4)
                          : isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
              ],
            ),
          ),

          // Day card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isCurrentDay
                    ? AppColors.violet.withValues(alpha: 0.06)
                    : isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCurrentDay
                      ? AppColors.violet.withValues(alpha: 0.3)
                      : isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Day ${day.dayNumber}',
                        style: GoogleFonts.dmMono(fontSize: 12, fontWeight: FontWeight.w700,
                          color: isCurrentDay ? AppColors.violet : AppColors.textMuted)),
                      if (isCurrentDay) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.violet.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text('TODAY', style: GoogleFonts.dmMono(
                            fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.violet)),
                        ),
                      ],
                      const Spacer(),
                      Text('${day.totalDurationMinutes} min',
                        style: GoogleFonts.dmMono(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(day.topic,
                    style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textLight : AppColors.textDark)),
                  if (day.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(day.description,
                      style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted, height: 1.4),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],

                  // Tasks (expandable)
                  if (day.tasks.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...day.tasks.map((task) => _buildTaskRow(isDark, roadmap, day, task)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskRow(bool isDark, Roadmap roadmap, RoadmapDay day, RoadmapTask task) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          context.read<AppState>().toggleTaskComplete(roadmap.id, day.dayNumber, task.id);
          setState(() {});
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: task.isCompleted
                ? AppColors.teal.withValues(alpha: 0.08)
                : isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: task.isCompleted
                  ? AppColors.teal.withValues(alpha: 0.2)
                  : Colors.transparent),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: task.isCompleted ? AppColors.teal : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: task.isCompleted ? AppColors.teal : AppColors.textMuted,
                    width: 2),
                ),
                child: task.isCompleted
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(task.title,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: task.isCompleted ? FontWeight.w400 : FontWeight.w500,
                    color: task.isCompleted
                        ? AppColors.textMuted
                        : isDark ? AppColors.textLight : AppColors.textDark,
                    decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Text('${task.durationMinutes}m',
                style: GoogleFonts.dmMono(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWatermark(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 16, height: 16, child: Image.asset('assets/images/logo.png')),
          const SizedBox(width: 6),
          Text('Gantav AI',
            style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600,
              color: AppColors.textMuted.withValues(alpha: 0.4))),
          Text(' · gantavai.com',
            style: GoogleFonts.dmSans(fontSize: 11,
              color: AppColors.textMuted.withValues(alpha: 0.3))),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(top: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
      ),
      child: Row(
        children: [
          // Share button
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _isSharing ? null : _shareAsImage,
                icon: _isSharing
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.violet))
                    : const Icon(Icons.share_outlined, size: 18),
                label: Text(_isSharing ? 'Exporting...' : 'Share Roadmap',
                  style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.violet,
                  side: BorderSide(color: AppColors.violet.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
