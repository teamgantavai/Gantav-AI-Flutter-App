import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 12D.7 — All gesture interactions verified:
/// • Double-tap LEFT  → seek −10 s
/// • Double-tap RIGHT → seek +10 s
/// • Long-press start → speed 2×
/// • Long-press end   → speed restored to pre-press value
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

class AppYoutubePlayerState extends State<AppYoutubePlayer>
    with SingleTickerProviderStateMixin {
  late YoutubePlayerController _controller;
  bool _isReady = false;

  // Settings
  double _currentSpeed = 1.0;
  /// 12D.7 — Speed before long-press so we can restore it on release
  double _speedBeforeLongPress = 1.0;
  String _currentQuality = 'Auto';
  bool _captionsEnabled = false;

  // Gesture States
  bool _isLongPressing = false;
  bool _showSeekForward = false;
  bool _showSeekBackward = false;

  Timer? _overlayTimer;
  Timer? _seekTimer;

  // Custom gesture tracking
  int _lastTapTime = 0;
  Offset _lastTapPosition = Offset.zero;
  Timer? _longPressTimer;
  bool _isLongPressActive = false;

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

    final safeId = _getSafeVideoId(widget.videoId);
    _controller = YoutubePlayerController(
      initialVideoId: safeId.isNotEmpty ? safeId : 'dQw4w9WgXcQ',
      flags: YoutubePlayerFlags(
        autoPlay: widget.autoPlay,
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
    _longPressTimer?.cancel();
    _controller.removeListener(_onControllerUpdate);
    
    // Ensure we exit full screen and restore orientations
    if (_controller.value.isFullScreen) {
      _controller.pause();
    }
    
    _controller.dispose();
    
    // Restore preferred orientations to app defaults
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    super.dispose();
  }

  // ── Settings ──────────────────────────────────────────────────────────

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
      await prefs.setString(
          'player_settings',
          jsonEncode({
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

  Future<double> getCurrentTime() async {
    return _controller.value.position.inSeconds.toDouble();
  }

  // ── Gestures ─────────────────────────────────────────────────────────

  void _handleDoubleTap(Offset localPosition) {
    final renderBox = context.findRenderObject() as RenderBox?;
    final width = renderBox?.size.width ?? MediaQuery.of(context).size.width;
    final isRightSide = localPosition.dx > width / 2;

    if (isRightSide) {
      _seekRelative(10);
      setState(() => _showSeekForward = true);
    } else {
      _seekRelative(-10);
      setState(() => _showSeekBackward = true);
    }

    HapticFeedback.mediumImpact();

    _seekTimer?.cancel();
    _seekTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showSeekForward = false;
          _showSeekBackward = false;
        });
      }
    });
  }

  void _seekRelative(int seconds) {
    final current = _controller.value.position.inSeconds;
    final duration = _controller.metadata.duration.inSeconds;
    final newPos = (current + seconds).clamp(0, duration > 0 ? duration : 999999);
    _controller.seekTo(Duration(seconds: newPos));
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
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
          const SizedBox(width: 8),
          CurrentPosition(),
          const SizedBox(width: 8),
          const Expanded(child: ProgressBar(isExpanded: true)),
          const SizedBox(width: 8),
          RemainingDuration(),
          if (_currentSpeed != 1.0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${_currentSpeed}x',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
          const FullScreenButton(),
          const SizedBox(width: 8),
        ],
      ),
      onExitFullScreen: () {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      },
      builder: (context, player) {
        return Stack(
          fit: StackFit.expand,
          children: [
            player,

            // Gesture Overlay for Double Tap & Long Press
            // Positioned over the top part of the player to avoid bottom controls
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 60,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onDoubleTapDown: (details) => _handleDoubleTap(details.localPosition),
                onLongPressStart: (details) {
                  _isLongPressActive = true;
                  _speedBeforeLongPress = _currentSpeed;
                  setPlaybackRate(2.0);
                  if (mounted) setState(() => _isLongPressing = true);
                  HapticFeedback.heavyImpact();
                },
                onLongPressEnd: (details) {
                  if (_isLongPressActive) {
                    _isLongPressActive = false;
                    setPlaybackRate(_speedBeforeLongPress);
                    if (mounted) setState(() => _isLongPressing = false);
                    HapticFeedback.selectionClick();
                  }
                },
                child: Container(color: Colors.transparent),
              ),
            ),

            // ── Double-tap seek animations ──────────────────────────
            if (_showSeekForward) _buildSeekOverlay(isForward: true),
            if (_showSeekBackward) _buildSeekOverlay(isForward: false),

              // ── Long-press 2× indicator ─────────────────────────────
              if (_isLongPressing)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
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
                        Icon(Icons.speed_rounded,
                            color: Colors.white, size: 20),
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
          );
      },
    );
  }

  /// 12D.7 — Seek overlay with icon + label, half-screen width hit area.
  Widget _buildSeekOverlay({required bool isForward}) {
    return Positioned(
      left: isForward ? null : 0,
      right: isForward ? 0 : null,
      top: 0,
      bottom: 0,
      width: MediaQuery.of(context).size.width * 0.5,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
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
              isForward ? '+10 s' : '−10 s',
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
}

// ═══════════════════════════════════════════════════════════════════════════
// Settings Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════════

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

  static const List<double> _speedOptions = [
    0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0
  ];
  static const List<String> _qualityOptions = [
    'Auto', '1080p', '720p', '480p', '360p', '240p'
  ];

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
        ..._speedOptions.map((speed) {
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
        ..._qualityOptions.map((quality) {
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
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: Colors.white70, size: 18),
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
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white38, size: 20),
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
                    ? const Icon(Icons.check_rounded,
                        color: Color(0xFF7C6AFF), size: 20)
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
                        color: isSelected
                            ? const Color(0xFF7C6AFF)
                            : Colors.white,
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: GoogleFonts.dmSans(
                            color: Colors.white38, fontSize: 11),
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