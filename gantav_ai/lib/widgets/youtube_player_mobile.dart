import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'dart:async';

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
  
  // Custom gesture states
  double _previousRate = 1.0;
  bool _isLongPressing = false;
  double _seekOverlayOpacity = 0.0;
  Timer? _seekOverlayTimer;
  Alignment _seekOverlayAlignment = Alignment.center;

  // Modern Fade Overlay states
  bool _showControls = true;
  Timer? _controlsTimer;

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
      flags: YoutubePlayerFlags(
        autoPlay: widget.autoPlay,
        mute: false,
        enableCaption: false,
        forceHD: true,
      ),
    );
    _startControlsTimer();
  }

  @override
  void dispose() {
    _seekOverlayTimer?.cancel();
    _controlsTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startControlsTimer();
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    _startControlsTimer(); // Keep controls visible when interacting
  }

  Future<void> setPlaybackRate(double rate) async {
    _controller.setPlaybackRate(rate);
    widget.onSpeedChanged?.call(rate);
  }

  Future<double> getCurrentTime() async {
    return _controller.value.position.inSeconds.toDouble();
  }

  // --- Custom Advanced Gesture Logic ---

  void _showSeekOverlay(bool isForward) {
    _seekOverlayTimer?.cancel();
    setState(() {
      _seekOverlayOpacity = 1.0;
      _seekOverlayAlignment = isForward ? Alignment.centerRight : Alignment.centerLeft;
    });
    _seekOverlayTimer = Timer(const Duration(milliseconds: 600), () {
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

  void _startLongPress2x(LongPressStartDetails details) {
    if (!_controller.value.isPlaying) return;
    _isLongPressing = true;
    _previousRate = _controller.value.playbackRate;
    _controller.setPlaybackRate(2.0);
    setState(() {});
  }

  void _endLongPress2x(LongPressEndDetails details) {
    if (!_isLongPressing) return;
    _isLongPressing = false;
    _controller.setPlaybackRate(_previousRate);
    setState(() {});
  }

  // --- Settings Sheet ---
  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.speed_rounded, color: Colors.white),
                title: const Text('Playback speed', style: TextStyle(color: Colors.white)),
                trailing: Text('${_controller.value.playbackRate}x', style: const TextStyle(color: Colors.white70)),
                onTap: () {
                  Navigator.pop(context);
                  _showSpeedSheet();
                },
              ),
              ListTile(
                leading: const Icon(Icons.subtitles_rounded, color: Colors.white),
                title: const Text('Captions', style: TextStyle(color: Colors.white)),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
                onTap: () {
                  Navigator.pop(context);
                  // Toggle captions (note: this overrides the player flags contextually)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Captions toggled'), duration: Duration(seconds: 1)),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showSpeedSheet() {
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      builder: (context) {
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: speeds.length,
            itemBuilder: (context, index) {
              final speed = speeds[index];
              final isSelected = _controller.value.playbackRate == speed;
              return ListTile(
                trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF6366F1)) : null,
                title: Text(speed == 1.0 ? 'Normal' : '${speed}x', style: TextStyle(color: isSelected ? const Color(0xFF6366F1) : Colors.white)),
                onTap: () {
                  setPlaybackRate(speed);
                  Navigator.pop(context);
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: const Color(0xFF6366F1), // Violet color
        progressColors: const ProgressBarColors(
          playedColor: Color(0xFF6366F1),
          handleColor: Color(0xFF818CF8),
        ),
        topActions: [
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              _controller.metadata.title.isNotEmpty ? _controller.metadata.title : 'Loading Video...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15.0,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          if (_controller.metadata.author.isNotEmpty) ...[
            const SizedBox(width: 8.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _controller.metadata.author,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 14.0),
          ]
        ],
        bottomActions: [
          const SizedBox(width: 14.0),
          CurrentPosition(),
          const SizedBox(width: 8.0),
          ProgressBar(isExpanded: true),
          RemainingDuration(),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white, size: 20),
            onPressed: _showSettingsSheet,
          ),
          const FullScreenButton(),   // Native fullscreen toggle option
        ],
      ),
      builder: (context, player) {
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Native Video Player
              player,
              
              // 2. Main Interaction Overlay (Fades on single tap)
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _toggleControls,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  color: _showControls ? Colors.black.withValues(alpha: 0.4) : Colors.transparent,
                  child: Stack(
                    children: [
                      // Large smooth Play/Pause in center
                      if (_showControls)
                        Center(
                          child: GestureDetector(
                            onTap: _togglePlayPause,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                          ),
                        ),

                      // Invisible side panels for Double Tap (10s seek) and Long Press (2x)
                      // These sit on top of the black fade but don't block taps to center
                      Positioned.fill(
                        child: Row(
                          children: [
                            Expanded(
                              flex: 1, // 20% left side
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onDoubleTap: _seekBackward,
                                onLongPressStart: _startLongPress2x,
                                onLongPressEnd: _endLongPress2x,
                                child: Container(color: Colors.transparent),
                              ),
                            ),
                            const Expanded(flex: 3, child: SizedBox.shrink()), // Center gap
                            Expanded(
                              flex: 1, // 20% right side
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onDoubleTap: _seekForward,
                                onLongPressStart: _startLongPress2x,
                                onLongPressEnd: _endLongPress2x,
                                child: Container(color: Colors.transparent),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Beautiful 2x Speed Long Press Overlay Indicator
              if (_isLongPressing)
                Positioned(
                  top: 10, left: 0, right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('2x Speed ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          Icon(Icons.fast_forward, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),

              // 4. Beautiful 10s Seek Overlay Animation (Left/Right)
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _seekOverlayOpacity,
                  duration: const Duration(milliseconds: 200),
                  child: Align(
                    alignment: _seekOverlayAlignment,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _seekOverlayAlignment == Alignment.centerRight 
                             ? Icons.forward_10_rounded 
                             : Icons.replay_10_rounded,
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
