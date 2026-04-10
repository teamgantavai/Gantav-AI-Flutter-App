import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/gemini_service.dart';
import '../services/api_config.dart';
import 'quiz_screen.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

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

  late YoutubePlayerController _youtubeController;

  int get _currentLessonIndex =>
      widget.module.lessons.indexOf(widget.lesson) + 1;

  bool _lessonCompletedEventFired = false;

  @override
  void initState() {
    super.initState();
    _youtubeController = YoutubePlayerController(
      initialVideoId: widget.lesson.youtubeVideoId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        hideControls: true,
      ),
    );
    _youtubeController.addListener(_onPlayerStateChange);
  }

  void _onPlayerStateChange() {
    if (_lessonCompletedEventFired) return;
    
    final position = _youtubeController.value.position;
    final duration = _youtubeController.metadata.duration;
    
    if (duration.inMilliseconds > 0 && position.inMilliseconds >= duration.inMilliseconds * 0.8) {
      _lessonCompletedEventFired = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lesson completed! XP awarded.'),
            duration: Duration(seconds: 3),
            backgroundColor: AppColors.teal,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _youtubeController.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    String text = _chatController.text.trim();
    if (text.isEmpty || _isAiTyping) return;

    if (_includeTimestamp) {
      final time = _youtubeController.value.position.inSeconds;
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
              _buildVideoSection(isDark),
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
            // ─── Video Section (YouTube-style) ─────────────────────
            _buildVideoSection(isDark),

            // ─── Content or AI Chat ─────────────────────────────────
            Expanded(
              child: _showAiChat
                  ? _buildAiChatPanel(isDark)
                  : _buildContentPanel(isDark),
            ),
          ],
        ),
      ),
      // ─── Bottom CTA ────────────────────────────────────────────
      bottomNavigationBar: _buildBottomBar(isDark),
    );
  }

  Widget _buildLandscapeLayout(bool isDark, double screenWidth) {
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: Row(
          children: [
            // Left: Video
            SizedBox(
              width: screenWidth * 0.55,
              child: Column(
                children: [
                  _buildVideoSection(isDark, showTopBar: true),
                  // Speed controls below video in landscape
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: _buildSpeedControls(isDark),
                  ),
                  const Spacer(),
                  _buildBottomBar(isDark),
                ],
              ),
            ),
            // Right: Content / Chat
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    // Tab toggle
                    _buildContentToggle(isDark),
                    Expanded(
                      child: _showAiChat
                          ? _buildAiChatPanel(isDark)
                          : _buildContentPanel(isDark),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// YouTube-style video thumbnail with controls
  Widget _buildVideoSection(bool isDark, {bool showTopBar = true}) {
    return Column(
      children: [
        if (showTopBar)
          // ─── Top bar ─────────────────────────────────────────
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '${widget.module.title} · $_currentLessonIndex/${widget.module.lessonCount}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // ─── Video Player ─────────────────────────────────────
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 0),
            child: Stack(
              children: [
                YoutubePlayer(
                  controller: _youtubeController,
                ),
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      if (_youtubeController.value.isPlaying) {
                        _youtubeController.pause();
                      } else {
                        _youtubeController.play();
                      }
                    },
                    child: Center(
                      child: ValueListenableBuilder<YoutubePlayerValue>(
                        valueListenable: _youtubeController,
                        builder: (context, value, _) {
                          return Icon(
                            value.isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 64,
                            color: Colors.white.withValues(alpha: value.isPlaying ? 0.0 : 0.8),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                // Simple Progress Bar
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: ValueListenableBuilder<YoutubePlayerValue>(
                    valueListenable: _youtubeController,
                    builder: (context, value, _) {
                      final pos = value.position.inMilliseconds.toDouble();
                      final dur = _youtubeController.metadata.duration.inMilliseconds.toDouble();
                      final val = (dur > 0) ? (pos / dur).clamp(0.0, 1.0) : 0.0;
                      return LinearProgressIndicator(
                        value: val,
                        minHeight: 3,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.violet),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // ─── Interaction Bar ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.lesson.title,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.thumb_up_outlined, size: 20),
                    onPressed: () {},
                    color: AppColors.textMuted,
                  ),
                  IconButton(
                    icon: const Icon(Icons.thumb_down_outlined, size: 20),
                    onPressed: () {},
                    color: AppColors.textMuted,
                  ),
                  IconButton(
                    icon: const Icon(Icons.star_border, size: 20),
                    onPressed: () {},
                    color: AppColors.textMuted,
                  ),
                  IconButton(
                    icon: Icon(_isFocusMode ? Icons.center_focus_strong : Icons.center_focus_weak, size: 20),
                    onPressed: () {
                      setState(() {
                         _isFocusMode = !_isFocusMode;
                      });
                    },
                    color: _isFocusMode ? AppColors.violet : AppColors.textMuted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Toggle between Content and AI Chat tabs in portrait
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
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isLandscape) ...[
            const SizedBox(height: 14),

            // Lesson title (YouTube style)
            Text(
              widget.lesson.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
            ),
            const SizedBox(height: 6),

            // Course info row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.violet.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    widget.course.category,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.violet,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.course.title,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Content / AI Chat toggle
            _buildContentToggle(isDark),
            const SizedBox(height: 16),

            // Speed controls
            _buildSpeedControls(isDark),
            const SizedBox(height: 20),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              widget.lesson.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
          ],

          // ─── Chapters ───────────────────────────────────────
          if (widget.lesson.chapters.isNotEmpty) ...[
            Text(
              'Chapters',
              style: Theme.of(context).textTheme.titleMedium,
            ),
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

  /// Speed control bar
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
              onTap: () => setState(() => _playbackSpeed = speed),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.violet
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '$speed×',
                    style: GoogleFonts.dmMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Up next section showing other lessons in this module
  Widget _buildUpNext(bool isDark) {
    final currentIdx = widget.module.lessons.indexOf(widget.lesson);
    final remaining = widget.module.lessons
        .skip(currentIdx + 1)
        .take(3)
        .toList();
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
                color: isDark
                    ? AppColors.darkSurface
                    : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.04),
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 72,
                      height: 42,
                      child: Image.network(
                        'https://img.youtube.com/vi/${lesson.youtubeVideoId}/mqdefault.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: AppColors.darkSurface2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson.title,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? AppColors.textLight
                                    : AppColors.textDark,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          lesson.duration,
                          style: GoogleFonts.dmMono(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
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

  /// AI Chat panel — Gemini powered doubt resolution
  Widget _buildAiChatPanel(bool isDark) {
    return Column(
      children: [
        // Chat messages
        Expanded(
          child: _chatMessages.isEmpty
              ? _buildChatEmptyState(isDark)
              : ListView.builder(
                  controller: _chatScrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  itemCount:
                      _chatMessages.length + (_isAiTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _chatMessages.length && _isAiTyping) {
                      return _TypingIndicator(isDark: isDark);
                    }
                    return _ChatBubble(
                      message: _chatMessages[index],
                      isDark: isDark,
                    );
                  },
                ),
        ),

        // Input
        // Input Content
        Container(
          padding: const EdgeInsets.fromLTRB(14, 4, 8, 14),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Checkbox(
                    value: _includeTimestamp,
                    onChanged: (val) {
                      setState(() {
                        _includeTimestamp = val ?? false;
                      });
                    },
                    activeColor: AppColors.violet,
                    visualDensity: VisualDensity.compact,
                  ),
                  Text(
                    'Include video timestamp',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatController,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Ask a doubt about this lesson...',
                        hintStyle:
                            const TextStyle(color: AppColors.textMuted, fontSize: 13),
                        filled: true,
                        fillColor: isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _isAiTyping
                        ? AppColors.textMuted.withValues(alpha: 0.3)
                        : AppColors.violet,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  ],
);
  }

  Widget _buildChatEmptyState(bool isDark) {
    final isConfigured = ApiConfig.isConfigured;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.violet.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.auto_awesome,
                  color: AppColors.violet, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              'AI Tutor',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              isConfigured
                  ? 'Ask any doubt about "${widget.lesson.title}" and get instant help.'
                  : 'Add your Gemini API key in api_config.dart to enable AI features.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    height: 1.5,
                  ),
            ),
            if (isConfigured) ...[
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _SuggestionChip(
                    text: 'Explain the key concepts',
                    onTap: () {
                      _chatController.text =
                          'Explain the key concepts in this lesson';
                      _sendMessage();
                    },
                  ),
                  _SuggestionChip(
                    text: 'Give me a quick summary',
                    onTap: () {
                      _chatController.text =
                          'Give me a quick summary of this lesson';
                      _sendMessage();
                    },
                  ),
                  _SuggestionChip(
                    text: 'Show me an example',
                    onTap: () {
                      _chatController.text =
                          'Show me a practical example related to this lesson';
                      _sendMessage();
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
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
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: () => _completeAndContinue(context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Complete & Continue',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
              Icon(icon,
                  size: 15,
                  color: isActive ? Colors.white : AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : AppColors.textMuted,
                ),
              ),
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
            : isDark
                ? AppColors.darkSurface
                : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(10),
        border: isActive
            ? Border.all(color: AppColors.violet.withValues(alpha: 0.2))
            : Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.04),
              ),
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
              child: Text(
                '${index + 1}',
                style: GoogleFonts.dmMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isActive ? AppColors.violet : AppColors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              chapter.title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isActive
                        ? (isDark ? AppColors.textLight : AppColors.textDark)
                        : AppColors.textMuted,
                  ),
            ),
          ),
          Text(
            chapter.timestamp,
            style: GoogleFonts.dmMono(
              fontSize: 11,
              color: isActive ? AppColors.violet : AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
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
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: message.isUser
              ? AppColors.violet
              : isDark
                  ? AppColors.darkSurface
                  : AppColors.lightSurface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft:
                message.isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight:
                message.isUser ? Radius.zero : const Radius.circular(16),
          ),
          border: message.isUser
              ? null
              : Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.06),
                ),
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
                    Icon(Icons.auto_awesome,
                        size: 12, color: AppColors.violet),
                    const SizedBox(width: 4),
                    Text(
                      'AI Tutor',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.violet,
                      ),
                    ),
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
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
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
          color: widget.isDark
              ? AppColors.darkSurface
              : AppColors.lightSurface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
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
          border: Border.all(
            color: AppColors.violet.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          text,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.violet,
          ),
        ),
      ),
    );
  }
}
