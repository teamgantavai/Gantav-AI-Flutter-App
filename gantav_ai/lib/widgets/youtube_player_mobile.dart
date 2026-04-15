import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

class AppYoutubePlayer extends StatefulWidget {
  final String videoId;
  final bool autoPlay;
  final void Function(double speed)? onSpeedChanged;

  const AppYoutubePlayer({
    super.key,
    required this.videoId,
    this.autoPlay = false,
    this.onSpeedChanged,
  });

  @override
  State<AppYoutubePlayer> createState() => AppYoutubePlayerState();
}

class AppYoutubePlayerState extends State<AppYoutubePlayer> with SingleTickerProviderStateMixin {
  late YoutubePlayerController _controller;

  // Controls
  bool _showControls = true;
  Timer? _controlsTimer;

  // Long press 2x
  bool _isLongPressing = false;
  double _previousRate = 1.0;

  // Seek overlay
  double _seekOverlayOpacity = 0.0;
  Timer? _seekOverlayTimer;
  Alignment _seekOverlayAlignment = Alignment.center;

  // Player settings (cached)
  double _currentSpeed = 1.0;
  String _currentQuality = 'Auto';
  bool _captionsEnabled = false;

  // Animation controller for smooth fade
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const List<double> _speedOptions = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
  static const List<String> _qualityOptions = ['Auto', '1080p', '720p', '480p', '360p', '240p'];

  String _getSafeVideoId(String input) {
    if (input.contains('youtube.com/watch?v=')) {
      return input.split('v=')[1].split('&')[0];
    }
    if (input.contains('youtu.be/')) {
      return input.split('youtu.be/')[1].split('?')[0];
    }
    return input;
  }

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: _getSafeVideoId(widget.videoId),
      flags: const YoutubePlayerFlags(
        autoPlay: false,           // Let user tap to play
        mute: false,
        enableCaption: false,
        forceHD: true,
        hideControls: true,       // We handle controls manually
        hideThumbnail: true,
      ),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _fadeController.value = 1.0; // Start with controls visible

    _loadCachedSettings();
    _startControlsTimer();
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _seekOverlayTimer?.cancel();
    _fadeController.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Load cached player settings
  Future<void> _loadCachedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('player_settings');
      if (settingsJson != null) {
        final settings = jsonDecode(settingsJson) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _currentSpeed = (settings['speed'] ?? 1.0).toDouble();
            _currentQuality = settings['quality'] ?? 'Auto';
            _captionsEnabled = settings['captions'] ?? false;
          });
          // Apply cached speed
          _controller.setPlaybackRate(_currentSpeed);
        }
      }
    } catch (_) {}
  }

  /// Save player settings to cache
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

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _fadeController.reverse();
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _fadeController.forward();
      _startControlsTimer();
    } else {
      _fadeController.reverse();
    }
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    _startControlsTimer();
  }

  void setPlaybackRate(double rate) {
    _controller.setPlaybackRate(rate);
    setState(() => _currentSpeed = rate);
    _saveCachedSettings();
    widget.onSpeedChanged?.call(rate);
  }

  Future<double> getCurrentTime() async {
    return _controller.value.position.inSeconds.toDouble();
  }

  // Seek with overlay
  void _showSeekOverlay(bool isForward) {
    _seekOverlayTimer?.cancel();
    setState(() {
      _seekOverlayOpacity = 1.0;
      _seekOverlayAlignment = isForward ? Alignment.centerRight : Alignment.centerLeft;
    });
    _seekOverlayTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _seekOverlayOpacity = 0.0);
    });
  }

  void _seekForward() {
    final current = _controller.value.position;
    _controller.seekTo(current + const Duration(seconds: 10));
    _showSeekOverlay(true);
  }

  void _seekBackward() {
    final current = _controller.value.position;
    _controller.seekTo(current - const Duration(seconds: 10));
    _showSeekOverlay(false);
  }

  void _startLongPress2x(_) {
    if (!_controller.value.isPlaying) return;
    _previousRate = _controller.value.playbackRate;
    _controller.setPlaybackRate(2.0);
    setState(() => _isLongPressing = true);
  }

  void _endLongPress2x(_) {
    if (!_isLongPressing) return;
    _controller.setPlaybackRate(_previousRate);
    setState(() => _isLongPressing = false);
  }

  /// Show professional settings bottom sheet
  void showSettingsSheet() {
    _controlsTimer?.cancel(); // Pause auto-hide while sheet is open
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
    ).then((_) {
      if (mounted) _startControlsTimer();
    });
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: false, // We use our own if needed
      ),
      builder: (context, player) {
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Main Video Player
              player,

              // Overlay for gestures + controls with smooth fade
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _toggleControls,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.55),
                    child: Stack(
                      children: [
                        // Center Play/Pause Button (Professional size)
                        Center(
                          child: GestureDetector(
                            onTap: _togglePlayPause,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                _controller.value.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                        ),

                        // Top Bar (Title + Settings)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(16, 10, 8, 20),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.black87, Colors.transparent],
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _controller.metadata.title.isNotEmpty
                                        ? _controller.metadata.title
                                        : widget.videoId,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Speed badge
                                if (_currentSpeed != 1.0)
                                  Container(
                                    margin: const EdgeInsets.only(right: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${_currentSpeed}x',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                // Settings gear
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: showSettingsSheet,
                                    borderRadius: BorderRadius.circular(20),
                                    child: const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Icon(Icons.settings_rounded, color: Colors.white, size: 22),
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
              ),

              // Gesture Zones (always active, transparent)
              Positioned.fill(
                child: Row(
                  children: [
                    // Left Side - Backward + Long Press 2x
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onDoubleTap: _seekBackward,
                        onLongPressStart: _startLongPress2x,
                        onLongPressEnd: _endLongPress2x,
                        child: const SizedBox.expand(),
                      ),
                    ),
                    // Center - Just for tap (play/pause handled above)
                    const Expanded(flex: 2, child: SizedBox()),
                    // Right Side - Forward + Long Press 2x
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onDoubleTap: _seekForward,
                        onLongPressStart: _startLongPress2x,
                        onLongPressEnd: _endLongPress2x,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),

              // 2x Speed Indicator
              if (_isLongPressing)
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('2× ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          Icon(Icons.fast_forward, color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),

              // 10s Seek Animation
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _seekOverlayOpacity,
                  duration: const Duration(milliseconds: 150),
                  child: Align(
                    alignment: _seekOverlayAlignment,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 50),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _seekOverlayAlignment == Alignment.centerRight
                              ? Icons.forward_10
                              : Icons.replay_10,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Settings Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════

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
  String _activePanel = 'main'; // 'main', 'speed', 'quality', 'subtitles'

  static const List<double> _speedOptions = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
  static const List<String> _qualityOptions = ['Auto', '1080p', '720p', '480p', '360p', '240p'];

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
              // Handle bar
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
        // Speed option
        _SettingsTile(
          icon: Icons.speed_rounded,
          label: 'Playback speed',
          value: widget.currentSpeed == 1.0 ? 'Normal' : '${widget.currentSpeed}x',
          onTap: () => setState(() => _activePanel = 'speed'),
        ),
        // Quality option
        _SettingsTile(
          icon: Icons.high_quality_rounded,
          label: 'Video quality',
          value: widget.currentQuality,
          onTap: () => setState(() => _activePanel = 'quality'),
        ),
        // Subtitles option
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