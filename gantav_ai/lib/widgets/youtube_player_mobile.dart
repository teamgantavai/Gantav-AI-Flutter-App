import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

class AppYoutubePlayer extends StatefulWidget {
  final String videoId;
  final bool autoPlay;
  final void Function(double speed)? onSpeedChanged;
  final VoidCallback? onVideoEnd;

  const AppYoutubePlayer({
    super.key,
    required this.videoId,
    this.autoPlay = false,
    this.onSpeedChanged,
    this.onVideoEnd,
  });

  @override
  State<AppYoutubePlayer> createState() => AppYoutubePlayerState();
}

class AppYoutubePlayerState extends State<AppYoutubePlayer> with SingleTickerProviderStateMixin {
  late YoutubePlayerController _controller;
  bool _isReady = false;

  // Settings
  double _currentSpeed = 1.0;
  String _currentQuality = 'Auto';
  bool _captionsEnabled = false;

  // Gesture States
  bool _isLongPressing = false;
  bool _showPlayPauseOverlay = false;

  // Double Tap Seek Animation
  bool _showSeekForward = false;
  bool _showSeekBackward = false;
  int _seekAmount = 10;

  Timer? _overlayTimer;
  Timer? _seekTimer;

  late AnimationController _playPauseController;
  late Animation<double> _playPauseScaleAnimation;

  static const List<double> _speedOptions = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
  static const List<String> _qualityOptions = ['Auto', '1080p', '720p', '480p', '360p', '240p'];

  String _getSafeVideoId(String input) {
    if (input.isEmpty) return '';
    if (input.contains('youtube.com/watch?v=')) {
      return Uri.tryParse(input)?.queryParameters['v'] ?? input;
    }
    if (input.contains('youtu.be/')) {
      final parts = input.split('youtu.be/');
      if (parts.length > 1) return parts[1].split('?')[0];
    }
    return input.length == 11 ? input : '';
  }

  @override
  void initState() {
    super.initState();

    _playPauseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _playPauseScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _playPauseController, curve: Curves.easeOut),
    );

    final safeId = _getSafeVideoId(widget.videoId);
    _controller = YoutubePlayerController(
      initialVideoId: safeId.isNotEmpty ? safeId : 'dQw4w9WgXcQ',
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        enableCaption: false,
        forceHD: false,
        hideControls: false,
        hideThumbnail: false,
        useHybridComposition: true,
      ),
    )..addListener(_onControllerUpdate);

    _loadCachedSettings();
  }

  void _onControllerUpdate() {
    if (_controller.value.isReady && !_isReady) {
      setState(() => _isReady = true);
      if (_currentSpeed != 1.0) _controller.setPlaybackRate(_currentSpeed);
    }
    if (_controller.value.playerState == PlayerState.ended) {
      widget.onVideoEnd?.call();
    }
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    _seekTimer?.cancel();
    _playPauseController.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ================== SETTINGS ==================
  Future<void> _loadCachedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('player_settings');
      if (json != null) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _currentSpeed = (data['speed'] ?? 1.0).toDouble();
            _currentQuality = data['quality'] ?? 'Auto';
            _captionsEnabled = data['captions'] ?? false;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _saveCachedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('player_settings', jsonEncode({
        'speed': _currentSpeed,
        'quality': _currentQuality,
        'captions': _captionsEnabled,
      }));
    } catch (_) {}
  }

  void setPlaybackRate(double rate) {
    _controller.setPlaybackRate(rate);
    setState(() => _currentSpeed = rate);
    _saveCachedSettings();
    widget.onSpeedChanged?.call(rate);
  }

  // ================== GESTURES ==================
  void _togglePlayPause() {
    final isPlaying = _controller.value.isPlaying;

    if (isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }

    setState(() => _showPlayPauseOverlay = true);
    _playPauseController.forward().then((_) => _playPauseController.reverse());

    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _showPlayPauseOverlay = false);
    });

    HapticFeedback.lightImpact();
  }

  void _handleDoubleTap(TapDownDetails details) {
    final width = MediaQuery.of(context).size.width;
    final isRightSide = details.globalPosition.dx > width / 2;

    if (isRightSide) {
      _seekRelative(10);
      setState(() {
        _showSeekForward = true;
        _seekAmount = 10;
      });
    } else {
      _seekRelative(-10);
      setState(() {
        _showSeekBackward = true;
        _seekAmount = 10;
      });
    }

    HapticFeedback.mediumImpact();

    _seekTimer?.cancel();
    _seekTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _showSeekForward = false;
          _showSeekBackward = false;
        });
      }
    });
  }

  void _seekRelative(int seconds) {
    final current = _controller.value.position.inSeconds.toDouble();
    final duration = _controller.metadata.duration.inSeconds.toDouble();
    final newPos = (current + seconds).clamp(0.0, duration);
    _controller.seekTo(Duration(seconds: newPos.toInt()));
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    if (_currentSpeed != 2.0) {
      setPlaybackRate(2.0);
    }
    setState(() => _isLongPressing = true);
    HapticFeedback.heavyImpact();
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    if (_currentSpeed == 2.0) {
      setPlaybackRate(1.0); // Return to normal
    }
    setState(() => _isLongPressing = false);
  }

  // ================== BUILD ==================
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlayPause,
      onDoubleTapDown: _handleDoubleTap,
      onLongPressStart: _handleLongPressStart,
      onLongPressEnd: _handleLongPressEnd,
      child: Stack(
        fit: StackFit.expand,
        children: [
          YoutubePlayer(
            controller: _controller,
            showVideoProgressIndicator: true,
            progressIndicatorColor: const Color(0xFF6D5BDB),
            progressColors: const ProgressBarColors(
              playedColor: Color(0xFF6D5BDB),
              handleColor: Color(0xFF6D5BDB),
              bufferedColor: Colors.white30,
              backgroundColor: Colors.white12,
            ),
            onReady: () {
              setState(() => _isReady = true);
              if (_currentSpeed != 1.0) _controller.setPlaybackRate(_currentSpeed);
            },
            bottomActions: [
              CurrentPosition(),
              const Expanded(child: ProgressBar(isExpanded: true)),
              RemainingDuration(),
              if (_currentSpeed != 1.0)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('${_currentSpeed}x', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              const FullScreenButton(),
            ],
          ),

          // ================== DOUBLE TAP SEEK ANIMATION ==================
          if (_showSeekForward)
            _buildSeekAnimation(true),
          if (_showSeekBackward)
            _buildSeekAnimation(false),

          // ================== PLAY / PAUSE OVERLAY ==================
          if (_showPlayPauseOverlay)
            Center(
              child: ScaleTransition(
                scale: _playPauseScaleAnimation,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 72,
                  ),
                ),
              ),
            ),

          // ================== LONG PRESS 2X INDICATOR ==================
          if (_isLongPressing)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C6AFF).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C6AFF).withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.speed_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 6),
                    Text(
                      '2×',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSeekAnimation(bool isForward) {
    return Positioned(
      left: isForward ? null : 40,
      right: isForward ? 40 : null,
      top: MediaQuery.of(context).size.height * 0.35,
      child: AnimatedOpacity(
        opacity: (isForward ? _showSeekForward : _showSeekBackward) ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isForward ? Icons.forward_10_rounded : Icons.replay_10_rounded,
                color: Colors.white,
                size: 42,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${isForward ? '+' : ''}$_seekAmount s',
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Keep your existing showSettingsSheet() method unchanged
  void showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SettingsSheet(
        currentSpeed: _currentSpeed,
        currentQuality: _currentQuality,
        captionsEnabled: _captionsEnabled,
        onSpeedChanged: (speed) {
          setPlaybackRate(speed);
          Navigator.pop(ctx);
        },
        onQualityChanged: (quality) {
          setState(() => _currentQuality = quality);
          _saveCachedSettings();
          Navigator.pop(ctx);
        },
        onCaptionsToggled: (enabled) {
          setState(() => _captionsEnabled = enabled);
          _saveCachedSettings();
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<double> getCurrentTime() async {
    return _controller.value.position.inSeconds.toDouble();
  }
}

class _SettingsSheet extends StatefulWidget {
  final double currentSpeed;
  final String currentQuality;
  final bool captionsEnabled;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<String> onQualityChanged;
  final ValueChanged<bool> onCaptionsToggled;

  const _SettingsSheet({
    required this.currentSpeed,
    required this.currentQuality,
    required this.captionsEnabled,
    required this.onSpeedChanged,
    required this.onQualityChanged,
    required this.onCaptionsToggled,
  });

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  String _activePanel = 'main';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              if (_activePanel == 'main') _buildMainPanel(),
              if (_activePanel == 'speed') _buildSpeedPanel(),
              if (_activePanel == 'quality') _buildQualityPanel(),
              if (_activePanel == 'subtitles') _buildSubtitlesPanel(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SettingsTile(
          icon: Icons.speed_rounded,
          label: 'Playback speed',
          value: widget.currentSpeed == 1.0 ? 'Normal' : '${widget.currentSpeed}x',
          onTap: () => setState(() => _activePanel = 'speed'),
        ),
        _SettingsTile(
          icon: Icons.high_quality_rounded,
          label: 'Video quality',
          value: widget.currentQuality,
          onTap: () => setState(() => _activePanel = 'quality'),
        ),
        _SettingsTile(
          icon: Icons.subtitles_rounded,
          label: 'Subtitles / CC',
          value: widget.captionsEnabled ? 'On' : 'Off',
          onTap: () => setState(() => _activePanel = 'subtitles'),
        ),
      ],
    );
  }

  Widget _buildSpeedPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPanelHeader('Playback speed'),
        ...AppYoutubePlayerState._speedOptions.map((speed) {
          final isSelected = speed == widget.currentSpeed;
          return _SelectableTile(
            label: speed == 1.0 ? 'Normal' : '${speed}x',
            isSelected: isSelected,
            onTap: () => widget.onSpeedChanged(speed),
          );
        }),
      ],
    );
  }

  Widget _buildQualityPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPanelHeader('Video quality'),
        ...AppYoutubePlayerState._qualityOptions.map((quality) {
          final isSelected = quality == widget.currentQuality;
          return _SelectableTile(
            label: quality,
            subtitle: quality == 'Auto' ? 'Recommended' : null,
            isSelected: isSelected,
            onTap: () => widget.onQualityChanged(quality),
          );
        }),
      ],
    );
  }

  Widget _buildSubtitlesPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPanelHeader('Subtitles / CC'),
        _SelectableTile(
          label: 'Off',
          isSelected: !widget.captionsEnabled,
          onTap: () => widget.onCaptionsToggled(false),
        ),
        _SelectableTile(
          label: 'English (Auto-generated)',
          isSelected: widget.captionsEnabled,
          onTap: () => widget.onCaptionsToggled(true),
        ),
      ],
    );
  }

  Widget _buildPanelHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => setState(() => _activePanel = 'main'),
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70, size: 18),
          ),
          Text(
            title,
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: Colors.white70, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.dmSans(
                  color: Colors.white54,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectableTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectableTile({
    required this.label,
    this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: isSelected
                    ? const Icon(Icons.check_rounded, color: Color(0xFF7C6AFF), size: 20)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.dmSans(
                        color: isSelected ? const Color(0xFF7C6AFF) : Colors.white,
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 11),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}