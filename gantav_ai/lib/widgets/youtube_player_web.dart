import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class AppYoutubePlayerState extends State<AppYoutubePlayer> {
  late YoutubePlayerController _controller;

  // Player settings (cached)
  double _currentSpeed = 1.0;
  String _currentQuality = 'Auto';
  bool _captionsEnabled = false;

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
    _controller = YoutubePlayerController.fromVideoId(
      videoId: _getSafeVideoId(widget.videoId),
      autoPlay: widget.autoPlay,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: false,
        enableCaption: false,
        playsInline: true,
        showVideoAnnotations: false,
      ),
    );
    
    _controller.listen((state) {
      if (state.playerState == PlayerState.ended) {
        widget.onVideoEnd?.call();
      }
    });

    _loadCachedSettings();
  }

  @override
  void dispose() {
    _controller.close();
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

  Future<void> setPlaybackRate(double rate) async {
    await _controller.setPlaybackRate(rate);
    setState(() => _currentSpeed = rate);
    _saveCachedSettings();
    widget.onSpeedChanged?.call(rate);
  }

  Future<double> getCurrentTime() async {
    return await _controller.currentTime;
  }

  void toggleFullScreen() {
    // Full screen is handled natively by the browser on Web,
    // so we don't need a manual toggle here. This method exists
    // for cross-platform compatibility with the mobile player.
  }

  void pause() {
    _controller.pauseVideo();
  }

  /// Show professional settings bottom sheet
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

  @override
  Widget build(BuildContext context) {
    return YoutubePlayer(
      controller: _controller,
      aspectRatio: 16 / 9,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Settings Bottom Sheet (shared with mobile)
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
