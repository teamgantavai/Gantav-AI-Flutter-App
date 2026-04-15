import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/gemini_service.dart';
import '../services/api_config.dart';
import 'quiz_screen.dart';
import '../widgets/youtube_player_wrapper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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

class _LessonPlayerScreenState extends State<LessonPlayerScreen> {
  double _playbackSpeed = 1.0;
  bool _showAiChat = false;
  final List<double> _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

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

  final GlobalKey<AppYoutubePlayerState> _ytKey = GlobalKey();

  int get _currentLessonIndex =>
      widget.module.lessons.indexOf(widget.lesson) + 1;

  @override
  void initState() {
    super.initState();
    
    // Video player initializes itself using the wrapper now.
    
    // Video is now loaded via fromVideoId
    
    _loadInteractionState();
  }

  Future<void> _loadInteractionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'lesson_${widget.lesson.id}';
      final data = prefs.getString(key);
      if (data != null) {
        final map = jsonDecode(data) as Map<String, dynamic>;
        setState(() {
          _isLiked = map['liked'] ?? false;
          _isDisliked = map['disliked'] ?? false;
          _isStarred = map['starred'] ?? false;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveInteractionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'lesson_${widget.lesson.id}';
      await prefs.setString(key, jsonEncode({
        'liked': _isLiked,
        'disliked': _isDisliked,
        'starred': _isStarred,
      }));
    } catch (_) {}
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) _isDisliked = false;
    });
    _saveInteractionState();
    if (_isLiked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('👍 Liked this lesson!'), duration: Duration(seconds: 1), backgroundColor: AppColors.teal),
      );
    }
  }

  void _toggleDislike() {
    setState(() {
      _isDisliked = !_isDisliked;
      if (_isDisliked) _isLiked = false;
    });
    _saveInteractionState();
  }

  void _toggleStar() {
    setState(() {
      _isStarred = !_isStarred;
    });
    _saveInteractionState();
    if (_isStarred) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⭐ Added to favorites!'), duration: Duration(seconds: 1), backgroundColor: AppColors.gold),
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
    // controller is handled by the wrapper.
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
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
      // Allow rotation again after returning to portrait
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

  Future<void> _setPlaybackSpeed(double speed) async {
    setState(() => _playbackSpeed = speed);
    await _ytKey.currentState?.setPlaybackRate(speed);
  }

  Future<void> _sendMessage() async {
    String text = _chatController.text.trim();
    if (text.isEmpty || _isAiTyping) return;

    if (_includeTimestamp) {
      final time = (await _ytKey.currentState?.getCurrentTime() ?? 0.0).toInt();
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
    final screenWidth = MediaQuery.of(context).size.width;

    if (isLandscape) {
      return _buildLandscapeLayout(isDark, screenWidth);
    }
    return _buildPortraitLayout(isDark);
  }

  Widget _buildPortraitLayout(bool isDark) {
    if (_isFocusMode) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildVideoPlayer(),
              // Tap to exit focus mode
              GestureDetector(
                onTap: _toggleFocusMode,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Text('Tap to exit focus mode',
                    style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white54)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Video Section ─────────────────────────────────
            _buildVideoSection(isDark),

            // ─── Content or AI Chat ────────────────────────────
            Expanded(
              child: _showAiChat
                  ? _buildAiChatPanel(isDark)
                  : _buildContentPanel(isDark),
            ),
          ],
        ),
      ),
      // ─── Bottom CTA ──────────────────────────────────────
      bottomNavigationBar: _buildBottomBar(isDark),
    );
  }

  Widget _buildLandscapeLayout(bool isDark, double screenWidth) {
    // Landscape is always immersive Focus Mode
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
          // Exit Fullscreen Button
          Positioned(
            top: 20,
            left: 20,
            child: GestureDetector(
              onTap: () {
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.portraitUp,
                  DeviceOrientation.portraitDown,
                ]);
                // Allow rotation again after returning to portrait
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
                child: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// YouTube custom player wrapper
  Widget _buildVideoPlayer() {
    return AppYoutubePlayer(
      key: _ytKey,
      videoId: widget.lesson.youtubeVideoId,
      autoPlay: false,
    );
  }

  /// Video section with top bar, player, and interaction bar
  Widget _buildVideoSection(bool isDark, {bool showTopBar = true}) {
    return Column(
      children: [
        if (showTopBar)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 28),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '${widget.module.title} · $_currentLessonIndex/${widget.module.lessonCount}',
                    style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),

        // ─── YouTube iframe Player ───────────────────────────
        _buildVideoPlayer(),

        // ─── Interaction Bar ─────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    widget.lesson.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Like button
                  _InteractionButton(
                    icon: _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                    isActive: _isLiked,
                    activeColor: AppColors.violet,
                    onTap: _toggleLike,
                    tooltip: 'Like',
                  ),
                  // Dislike button
                  _InteractionButton(
                    icon: _isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                    isActive: _isDisliked,
                    activeColor: AppColors.error,
                    onTap: _toggleDislike,
                    tooltip: 'Dislike',
                  ),
                  // Star / Favorite button
                  _InteractionButton(
                    icon: _isStarred ? Icons.star : Icons.star_border,
                    isActive: _isStarred,
                    activeColor: AppColors.gold,
                    onTap: _toggleStar,
                    tooltip: 'Favorite',
                  ),
                  // Focus mode
                  _InteractionButton(
                    icon: _isFocusMode ? Icons.center_focus_strong : Icons.center_focus_weak,
                    isActive: _isFocusMode,
                    activeColor: AppColors.violet,
                    onTap: _toggleFocusMode,
                    tooltip: 'Focus mode',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Toggle between Content and AI Chat tabs
  Widget _buildContentToggle(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
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

  /// Content panel (lesson info, chapters, speed controls)
  Widget _buildContentPanel(bool isDark) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isLandscape) ...[
            const SizedBox(height: 14),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.violet.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(widget.course.category,
                    style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.violet)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(widget.course.title, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 10),

            _buildContentToggle(isDark),
            const SizedBox(height: 16),

            // Speed controls
            _buildSpeedControls(isDark),
            const SizedBox(height: 20),
          ] else ...[
            const SizedBox(height: 8),
            Text(widget.lesson.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
          ],

          // ─── Chapters ──────────────────────────────────────
          if (widget.lesson.chapters.isNotEmpty) ...[
            Text('Chapters', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ...widget.lesson.chapters.asMap().entries.map((entry) {
              final i = entry.key;
              final chapter = entry.value;
              return _ChapterTile(
                chapter: chapter,
                index: i,
                isActive: i == 0,
              );
            }),
            const SizedBox(height: 20),
          ],

          // ─── Up next ───────────────────────────────────────
          _buildUpNext(isDark),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  /// Speed control bar — actually calls setPlaybackRate now
  Widget _buildSpeedControls(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: _speeds.map((speed) {
          final isSelected = speed == _playbackSpeed;
          return Expanded(
            child: GestureDetector(
              onTap: () => _setPlaybackSpeed(speed),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.violet : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text('$speed×',
                    style: GoogleFonts.dmMono(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textMuted)),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Up next section
  Widget _buildUpNext(bool isDark) {
    final currentIdx = widget.module.lessons.indexOf(widget.lesson);
    final remaining = widget.module.lessons.skip(currentIdx + 1).take(3).toList();
    if (remaining.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Up next', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        ...remaining.map((lesson) {
          return GestureDetector(
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => LessonPlayerScreen(
                    lesson: lesson,
                    module: widget.module,
                    course: widget.course,
                  ),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 72, height: 42,
                      child: Image.network(
                        'https://img.youtube.com/vi/${lesson.youtubeVideoId}/0.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: AppColors.darkSurface2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lesson.title,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.textLight : AppColors.textDark,
                          ),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                        Text(lesson.duration,
                          style: GoogleFonts.dmMono(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  /// AI Chat panel — with back arrow header
  Widget _buildAiChatPanel(bool isDark) {
    return Column(
      children: [
        // ─── Back Arrow Header ──────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _showAiChat = false),
                icon: Icon(
                  Icons.arrow_back,
                  size: 20,
                  color: isDark ? AppColors.textLight : AppColors.textDark,
                ),
                tooltip: 'Back to content',
              ),
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: AppColors.violet.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome, color: AppColors.violet, size: 14),
              ),
              const SizedBox(width: 10),
              Text('AI Tutor',
                style: GoogleFonts.dmSans(
                  fontSize: 15, fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textLight : AppColors.textDark,
                )),
              const Spacer(),
              if (_chatMessages.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _chatMessages.clear()),
                  child: Text('Clear',
                    style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted)),
                ),
            ],
          ),
        ),

        Expanded(
          child: _chatMessages.isEmpty
              ? SingleChildScrollView(child: _buildChatEmptyState(isDark))
              : ListView.builder(
                  controller: _chatScrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  itemCount: _chatMessages.length + (_isAiTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _chatMessages.length && _isAiTyping) {
                      return _TypingIndicator(isDark: isDark);
                    }
                    return _ChatBubble(message: _chatMessages[index], isDark: isDark);
                  },
                ),
        ),

        // Input
        Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 4 : 4,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 4, 8, 14),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
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
                        onChanged: (val) => setState(() => _includeTimestamp = val ?? false),
                        activeColor: AppColors.violet,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    Text('Include video timestamp',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: TextField(
                          controller: _chatController,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Ask a doubt...',
                            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                            filled: true,
                            fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: _isAiTyping ? AppColors.textMuted.withValues(alpha: 0.3) : AppColors.violet,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 18),
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
    final isConfigured = ApiConfig.isConfigured;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppColors.violet.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.auto_awesome, color: AppColors.violet, size: 24),
          ),
          const SizedBox(height: 12),
          Text('AI Tutor', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            isConfigured
                ? 'Ask any doubt and get instant help.'
                : 'Add Gemini API key to enable AI.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
          if (isConfigured) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 6, runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                _SuggestionChip(
                  text: 'Key concepts',
                  onTap: () {
                    _chatController.text = 'Explain the key concepts in this lesson';
                    _sendMessage();
                  },
                ),
                _SuggestionChip(
                  text: 'Summary',
                  onTap: () {
                    _chatController.text = 'Give me a quick summary of this lesson';
                    _sendMessage();
                  },
                ),
                _SuggestionChip(
                  text: 'Example',
                  onTap: () {
                    _chatController.text = 'Show me a practical example related to this lesson';
                    _sendMessage();
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Bottom CTA bar
  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.lightBg,
        border: Border(
          top: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      child: SizedBox(
        width: double.infinity, height: 48,
        child: ElevatedButton(
          onPressed: () => _completeAndContinue(context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Complete & Continue',
                style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _completeAndContinue(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          lesson: widget.lesson,
          course: widget.course,
          module: widget.module,
        ),
      ),
    );
  }
}

// ─── Interaction Button Widget ──────────────────────────────────────────────

class _InteractionButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;
  final String tooltip;

  const _InteractionButton({
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              icon,
              key: ValueKey(isActive),
              size: 20,
              color: isActive ? activeColor : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Supporting Widgets ──────────────────────────────────────────────────────

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

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
              Icon(icon, size: 15, color: isActive ? Colors.white : AppColors.textMuted),
              const SizedBox(width: 6),
              Text(label,
                style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: isActive ? Colors.white : AppColors.textMuted)),
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

  const _ChapterTile({
    required this.chapter,
    required this.index,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.violet.withValues(alpha: 0.08)
            : isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(10),
        border: isActive
            ? Border.all(color: AppColors.violet.withValues(alpha: 0.2))
            : Border.all(color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.violet.withValues(alpha: 0.15)
                  : isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text('${index + 1}',
                style: GoogleFonts.dmMono(fontSize: 11, fontWeight: FontWeight.w600, color: isActive ? AppColors.violet : AppColors.textMuted)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(chapter.title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: isActive ? (isDark ? AppColors.textLight : AppColors.textDark) : AppColors.textMuted,
              )),
          ),
          Text(chapter.timestamp,
            style: GoogleFonts.dmMono(fontSize: 11, color: isActive ? AppColors.violet : AppColors.textMuted, fontWeight: FontWeight.w500)),
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
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: message.isUser
              ? AppColors.violet
              : isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: message.isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: message.isUser ? Radius.zero : const Radius.circular(16),
          ),
          border: message.isUser ? null : Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
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
                    Icon(Icons.auto_awesome, size: 12, color: AppColors.violet),
                    const SizedBox(width: 4),
                    Text('AI Tutor',
                      style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.violet)),
                  ],
                ),
              ),
            Text(message.text,
              style: GoogleFonts.dmSans(
                fontSize: 13, height: 1.5,
                color: message.isUser ? Colors.white : isDark ? AppColors.textLight : AppColors.textDark,
              )),
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
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
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
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: widget.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final offset = (_controller.value + i * 0.2) % 1.0;
                final opacity = (1 - (offset - 0.5).abs() * 2).clamp(0.3, 1.0);
                return Container(
                  width: 7, height: 7,
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
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.violet.withValues(alpha: 0.2)),
        ),
        child: Text(text,
          style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.violet)),
      ),
    );
  }
}
