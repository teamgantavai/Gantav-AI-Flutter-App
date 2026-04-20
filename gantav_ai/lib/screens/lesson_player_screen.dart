import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/gemini_service.dart';
import 'quiz_screen.dart';
import '../widgets/youtube_player_wrapper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import 'course_detail_screen.dart';
import 'dart:convert';
import '../widgets/widgets.dart';

class LessonPlayerScreen extends StatefulWidget {
  final Lesson lesson;
  final Module module;
  final Course course;

  const LessonPlayerScreen({
    super.key,
    required this.lesson,
    required this.module,
    required this.course,
  });

  @override
  State<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends State<LessonPlayerScreen>
    with TickerProviderStateMixin {
  bool _showAiChat = false;

  // AI Chat state
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final List<ChatMessage> _chatMessages = [];
  bool _isAiTyping = false;
  bool _includeTimestamp = false;
  bool _isFocusMode = false;

  // Interaction states
  bool _isLiked = false;
  bool _isDisliked = false;
  bool _isStarred = false;
  bool _isCompleted = false;
  int _likeCount = 0;

  // 12D.1 — coin badge animation
  late AnimationController _coinBadgeCtrl;
  late Animation<double> _coinBadgeScale;

  final GlobalKey<AppYoutubePlayerState> _ytKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadInteractionState();

    // 12D.1 — coin badge animation controller
    _coinBadgeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _coinBadgeScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _coinBadgeCtrl, curve: Curves.elasticOut),
    );
  }

  Future<void> _loadInteractionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'lesson_${widget.lesson.id}';
      final data = prefs.getString(key);
      if (data != null) {
        final map = jsonDecode(data) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _isLiked = map['liked'] ?? false;
            _isDisliked = map['disliked'] ?? false;
            _isStarred = map['starred'] ?? false;
            _isCompleted = map['completed'] ?? false;
            _likeCount = map['like_count'] ?? 0;
          });
        }
      }
      if (mounted) {
        final appState = context.read<AppState>();
        final starredInAppState = appState.isLessonStarred(widget.lesson.id);
        if (starredInAppState != _isStarred) {
          setState(() => _isStarred = starredInAppState);
        }
      }
    } catch (_) {}
  }

  Future<void> _saveInteractionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'lesson_${widget.lesson.id}';
      await prefs.setString(
          key,
          jsonEncode({
            'liked': _isLiked,
            'disliked': _isDisliked,
            'starred': _isStarred,
            'completed': _isCompleted,
            'like_count': _likeCount,
          }));
    } catch (_) {}
  }

  void _toggleLike() {
    setState(() {
      if (_isLiked) {
        _isLiked = false;
        _likeCount = (_likeCount - 1).clamp(0, 99999);
      } else {
        _isLiked = true;
        _likeCount++;
        if (_isDisliked) _isDisliked = false;
      }
    });
    _saveInteractionState();
  }

  void _toggleDislike() {
    setState(() {
      _isDisliked = !_isDisliked;
      if (_isDisliked && _isLiked) {
        _isLiked = false;
        _likeCount = (_likeCount - 1).clamp(0, 99999);
      }
    });
    _saveInteractionState();
  }

  void _toggleStar() {
    setState(() => _isStarred = !_isStarred);
    _saveInteractionState();
    context.read<AppState>().toggleStarredLesson(widget.lesson.id);
    if (_isStarred) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⭐ Saved to favorites!', style: GoogleFonts.dmSans()),
          duration: const Duration(seconds: 1),
          backgroundColor: AppColors.gold,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _chatController.dispose();
    _chatScrollController.dispose();
    _coinBadgeCtrl.dispose();
    super.dispose();
  }

  void _handleFlipCourse(BuildContext context) async {
    final appState = context.read<AppState>();
    final flipsLeft = appState.flipsRemaining(widget.course.id);
    
    if (flipsLeft <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No flips remaining for this course.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Flip Course?'),
        content: Text(
          'This will find new videos from a different YouTube channel for the same topic. '
          'You have $flipsLeft flips remaining for this course.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Flip'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: AppColors.violet),
        ),
      );
      
      // Delete old course later? Or `flipCourse` handles it?
      // `flipCourse` replaces the course structure. So just call it.
      final newCourse = await appState.flipCourse(widget.course.id);
      
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        if (newCourse != null) {
          // Replace current route with the new course
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => CourseDetailScreen(course: newCourse),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not flip course. Please try again.')),
          );
        }
      }
    }
  }

  void _toggleFocusMode() {
    setState(() => _isFocusMode = !_isFocusMode);
    if (_isFocusMode) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_isFocusMode) {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        }
      });
    }
  }


  Future<void> _sendMessage() async {
    String text = _chatController.text.trim();
    if (text.isEmpty || _isAiTyping) return;

    if (_includeTimestamp) {
      final time =
          (await _ytKey.currentState?.getCurrentTime() ?? 0.0).toInt();
      final minutes = (time / 60).floor();
      final seconds = (time % 60).floor().toString().padLeft(2, '0');
      text = '[At $minutes:$seconds]: $text';
    }

    setState(() {
      _chatMessages.add(ChatMessage(
        id: 'msg_${_chatMessages.length}',
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _chatController.clear();
      _isAiTyping = true;
    });

    _scrollToBottom();

    final response = await GeminiService.askDoubt(
      question: text,
      lessonTitle: widget.lesson.title,
      courseTitle: widget.course.title,
      history: _chatMessages,
    );

    if (!mounted) return;

    setState(() {
      _chatMessages.add(ChatMessage(
        id: 'msg_${_chatMessages.length}',
        text: response,
        isUser: false,
        timestamp: DateTime.now(),
      ));
      _isAiTyping = false;
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      return _buildLandscapeLayout(isDark);
    }
    return _buildPortraitLayout(isDark);
  }

  Widget _buildPortraitLayout(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(isDark),
            _buildVideoPlayer(),
            Expanded(
              child: _showAiChat
                  ? _buildAiChatPanel(isDark)
                  : _buildContentPanel(isDark),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(isDark),
    );
  }

  Widget _buildLandscapeLayout(bool isDark) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: _buildVideoPlayer(),
            ),
          ),
          Positioned(
            top: 20,
            left: 20,
            child: GestureDetector(
              onTap: () {
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                SystemChrome.setPreferredOrientations(
                    [DeviceOrientation.portraitUp]);
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) {
                    SystemChrome.setPreferredOrientations([
                      DeviceOrientation.portraitUp,
                      DeviceOrientation.portraitDown,
                      DeviceOrientation.landscapeLeft,
                      DeviceOrientation.landscapeRight,
                    ]);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.fullscreen_exit,
                    color: Colors.white, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.keyboard_arrow_down, size: 28),
          ),
          Expanded(
            child: Text(
              widget.lesson.title,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textLight : AppColors.textDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 12D.1 — coin value chip in top bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🪙', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 4),
                Text('+${widget.lesson.coinValue}',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFF59E0B),
                  )),
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () => _ytKey.currentState?.showSettingsSheet(),
            icon: Icon(Icons.settings_rounded,
                size: 20,
                color: isDark ? Colors.white54 : Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return SizedBox(
      width: double.infinity,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        // 12D.7 — AppYoutubePlayer key is set so _ytKey.currentState is
        // always valid; the mobile implementation handles 10s double-tap
        // seek and long-press 2× speed natively inside the player widget.
        child: AppYoutubePlayer(
          key: _ytKey,
          videoId: widget.lesson.youtubeVideoId,
          autoPlay: false,
          onVideoEnd: () {
            if (!_isCompleted) {
              setState(() => _isCompleted = true);
              _saveInteractionState();
              context.read<AppState>().markLessonAsCompleted(
                    widget.course.id,
                    widget.module.id,
                    widget.lesson.id,
                  );

              // 12D.1 — show coin badge briefly after video ends
              _coinBadgeCtrl.forward(from: 0).then((_) {
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) _coinBadgeCtrl.reverse();
                });
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '✅ +${widget.lesson.coinValue} coins! Take the quiz to continue.',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                  ),
                  backgroundColor: AppColors.teal,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildContentPanel(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildYouTubeInfoBlock(isDark),
          _buildContentToggle(isDark),

          // Chapters
          if (widget.lesson.chapters.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text('Chapters',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: widget.lesson.chapters
                    .asMap()
                    .entries
                    .map((entry) => _ChapterTile(
                          chapter: entry.value,
                          index: entry.key,
                          isActive: entry.key == 0,
                        ))
                    .toList(),
              ),
            ),
          ],

          // Up next
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildUpNext(isDark),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildYouTubeInfoBlock(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.lesson.title,
            style: GoogleFonts.dmSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: isDark ? AppColors.textLight : AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.violet.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  widget.course.category,
                  style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.violet),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.course.title
                      .replaceAll('\$dream', widget.course.category),
                  style: GoogleFonts.dmSans(
                      fontSize: 12, color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _LikePill(
                  isLiked: _isLiked,
                  likeCount: _likeCount,
                  onLike: _toggleLike,
                  onDislike: _toggleDislike,
                  isDisliked: _isDisliked,
                  isDark: isDark,
                ),
                const SizedBox(width: 10),
                if (!widget.course.isVerified) ...[
                  _ActionPill(
                    icon: Icons.refresh,
                    label: 'Flip',
                    isActive: false,
                    activeColor: AppColors.violet,
                    onTap: () => _handleFlipCourse(context),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 10),
                ],
                _ActionPill(
                  icon: _isStarred ? Icons.bookmark : Icons.bookmark_outline,
                  label: _isStarred ? 'Saved' : 'Save',
                  isActive: _isStarred,
                  activeColor: AppColors.gold,
                  onTap: _toggleStar,
                  isDark: isDark,
                ),
                const SizedBox(width: 10),
                _ActionPill(
                  icon: Icons.crop_free_rounded,
                  label: 'Focus',
                  isActive: _isFocusMode,
                  activeColor: AppColors.violet,
                  onTap: _toggleFocusMode,
                  isDark: isDark,
                ),
                const SizedBox(width: 16),
                // 12D.1 — coin badge for completed lesson
                if (_isCompleted)
                ScaleTransition(
                  scale: _coinBadgeScale,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🪙', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text('+${widget.lesson.coinValue} earned',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFF59E0B),
                          )),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          ),
          const SizedBox(height: 10),
          Divider(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.07)),
        ],
      ),
    );
  }

  Widget _buildContentToggle(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _TabButton(
            label: 'Content',
            icon: Icons.list_alt_rounded,
            isActive: !_showAiChat,
            onTap: () => setState(() => _showAiChat = false),
          ),
          _TabButton(
            label: 'AI Tutor',
            icon: Icons.auto_awesome,
            isActive: _showAiChat,
            onTap: () => setState(() => _showAiChat = true),
          ),
        ],
      ),
    );
  }

  Widget _buildUpNext(bool isDark) {
    final currentIdx = widget.module.lessons.indexOf(widget.lesson);
    final remaining =
        widget.module.lessons.skip(currentIdx + 1).take(3).toList();
    if (remaining.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 10),
          child: Text('Up next',
              style: Theme.of(context).textTheme.titleMedium),
        ),
        ...remaining.map((lesson) {
          final isLocked = !_isCompleted && !lesson.isCompleted;
          return GestureDetector(
            onTap: () {
              if (isLocked) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '🔒 Complete the current video first!',
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                    ),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
                return;
              }
              Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => LessonPlayerScreen(
                    lesson: lesson,
                    module: widget.module,
                    course: widget.course,
                  ),
                  transitionDuration: const Duration(milliseconds: 300),
                  transitionsBuilder: (_, animation, __, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                ),
              );
            },
            child: Opacity(
              opacity: isLocked ? 0.6 : 1.0,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.black.withValues(alpha: 0.04)),
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 72,
                            height: 42,
                            child: Image.network(
                              'https://img.youtube.com/vi/${lesson.youtubeVideoId}/0.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(color: AppColors.darkSurface2),
                            ),
                          ),
                        ),
                        if (isLocked)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.lock, color: Colors.white, size: 18),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lesson.title,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? AppColors.textLight
                                      : AppColors.textDark,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Text(
                                lesson.duration,
                                style: GoogleFonts.dmMono(
                                    fontSize: 11, color: AppColors.textMuted),
                              ),
                              const SizedBox(width: 6),
                              // 12D.1 — show coin value on up-next lessons
                              Text('🪙 ${lesson.coinValue}',
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  color: const Color(0xFFF59E0B),
                                  fontWeight: FontWeight.w600,
                                )),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isLocked ? Icons.lock_outline : Icons.play_circle_outline,
                      size: 20,
                      color: isLocked ? AppColors.textMuted : AppColors.violet,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAiChatPanel(bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.06)),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _showAiChat = false),
                icon: Icon(Icons.arrow_back,
                    size: 20,
                    color:
                        isDark ? AppColors.textLight : AppColors.textDark),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.violet.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: AppColors.violet, size: 14),
              ),
              const SizedBox(width: 10),
              Text('AI Tutor',
                  style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textLight
                          : AppColors.textDark)),
              const Spacer(),
              if (_chatMessages.isNotEmpty)
                TextButton(
                  onPressed: () =>
                      setState(() => _chatMessages.clear()),
                  child: Text('Clear',
                      style: GoogleFonts.dmSans(
                          fontSize: 12, color: AppColors.textMuted)),
                ),
            ],
          ),
        ),
        Expanded(
          child: _chatMessages.isEmpty
              ? _buildChatEmptyState(isDark)
              : ListView.builder(
                  controller: _chatScrollController,
                  physics: const BouncingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  itemCount:
                      _chatMessages.length + (_isAiTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _chatMessages.length && _isAiTyping) {
                      return _TypingIndicator(isDark: isDark);
                    }
                    return _ChatBubble(
                        message: _chatMessages[index], isDark: isDark);
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 8, 14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.06)),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    SizedBox(
                      height: 32,
                      child: Checkbox(
                        value: _includeTimestamp,
                        onChanged: (val) =>
                            setState(() => _includeTimestamp = val ?? false),
                        activeColor: AppColors.violet,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    Text('Include video timestamp',
                        style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.white70
                                : Colors.black87)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: TextField(
                          controller: _chatController,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontSize: 13),
                          textCapitalization:
                              TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Ask a doubt...',
                            hintStyle: const TextStyle(
                                color: AppColors.textMuted, fontSize: 13),
                            filled: true,
                            fillColor: isDark
                                ? AppColors.darkSurface
                                : AppColors.lightSurface,
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 0),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _isAiTyping
                              ? AppColors.textMuted.withValues(alpha: 0.3)
                              : AppColors.violet,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_upward_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.violet.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.auto_awesome,
                  color: AppColors.violet, size: 24),
            ),
            const SizedBox(height: 12),
            Text('AI Tutor',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Ask any doubt about this lesson.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontSize: 12)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                _SuggestionChip(
                    text: 'Key concepts',
                    onTap: () {
                      _chatController.text =
                          'Explain the key concepts in this lesson';
                      _sendMessage();
                    }),
                _SuggestionChip(
                    text: 'Summary',
                    onTap: () {
                      _chatController.text =
                          'Give me a quick summary of this lesson';
                      _sendMessage();
                    }),
                _SuggestionChip(
                    text: 'Example',
                    onTap: () {
                      _chatController.text =
                          'Show me a practical example related to this lesson';
                      _sendMessage();
                    }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.lightBg,
        border: Border(
            top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06))),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: () {
            if (!_isCompleted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '⚠️ Watch the full video to unlock the quiz!',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                  ),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
              return;
            }
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => QuizScreen(
                  lesson: widget.lesson,
                  course: widget.course,
                  module: widget.module,
                ),
              ),
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isCompleted
                    ? Icons.quiz_rounded
                    : Icons.lock_outline_rounded,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                _isCompleted ? 'Take Quiz & Continue' : 'Complete Video First',
                style: GoogleFonts.dmSans(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Reusable sub-widgets ─────────────────────────────────────────────────────

class _LikePill extends StatelessWidget {
  final bool isLiked;
  final bool isDisliked;
  final int likeCount;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final bool isDark;

  const _LikePill({
    required this.isLiked,
    required this.isDisliked,
    required this.likeCount,
    required this.onLike,
    required this.onDislike,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onLike,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isLiked
                    ? AppColors.violet.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(100)),
              ),
              child: Row(
                children: [
                  Icon(
                    isLiked
                        ? Icons.thumb_up_rounded
                        : Icons.thumb_up_outlined,
                    size: 18,
                    color: isLiked ? AppColors.violet : AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          Container(
              width: 1,
              height: 20,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.1)),
          GestureDetector(
            onTap: onDislike,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDisliked
                    ? AppColors.error.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius:
                    const BorderRadius.horizontal(right: Radius.circular(100)),
              ),
              child: Icon(
                isDisliked
                    ? Icons.thumb_down_rounded
                    : Icons.thumb_down_outlined,
                size: 18,
                color: isDisliked ? AppColors.error : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;
  final bool isDark;

  const _ActionPill({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.15)
              : isDark
                  ? AppColors.darkSurface2
                  : AppColors.lightSurface2,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isActive
                ? activeColor.withValues(alpha: 0.3)
                : isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: isActive ? activeColor : AppColors.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? activeColor : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton(
      {required this.label,
      required this.icon,
      required this.isActive,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppColors.violet : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: isActive ? Colors.white : AppColors.textMuted),
              const SizedBox(width: 6),
              Text(label,
                  style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  final Chapter chapter;
  final int index;
  final bool isActive;

  const _ChapterTile(
      {required this.chapter, required this.index, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.violet.withValues(alpha: 0.08)
            : isDark
                ? AppColors.darkSurface
                : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(10),
        border: isActive
            ? Border.all(color: AppColors.violet.withValues(alpha: 0.2))
            : Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.violet.withValues(alpha: 0.15)
                  : isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text('${index + 1}',
                  style: GoogleFonts.dmMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? AppColors.violet
                          : AppColors.textMuted)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(chapter.title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isActive
                          ? (isDark ? AppColors.textLight : AppColors.textDark)
                          : AppColors.textMuted,
                    )),
          ),
          Text(chapter.timestamp,
              style: GoogleFonts.dmMono(
                  fontSize: 11,
                  color: isActive ? AppColors.violet : AppColors.textMuted,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;
  const _ChatBubble({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: message.isUser
              ? AppColors.violet
              : isDark
                  ? AppColors.darkSurface
                  : AppColors.lightSurface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: message.isUser
                ? const Radius.circular(16)
                : Radius.zero,
            bottomRight: message.isUser
                ? Radius.zero
                : const Radius.circular(16),
          ),
          border: message.isUser
              ? null
              : Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!message.isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome,
                        size: 12, color: AppColors.violet),
                    const SizedBox(width: 4),
                    Text('AI Tutor',
                        style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.violet)),
                  ],
                ),
              ),
            Text(
              message.text,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                height: 1.5,
                color: message.isUser
                    ? Colors.white
                    : isDark
                        ? AppColors.textLight
                        : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  final bool isDark;
  const _TypingIndicator({required this.isDark});
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: widget.isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16)),
          border: Border.all(
              color: widget.isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.06)),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final offset = (_controller.value + i * 0.2) % 1.0;
                final opacity =
                    (1 - (offset - 0.5).abs() * 2).clamp(0.3, 1.0);
                return Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: AppColors.violet.withValues(alpha: opacity),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _SuggestionChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.violet.withValues(alpha: 0.2)),
        ),
        child: Text(text,
            style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.violet)),
      ),
    );
  }
}