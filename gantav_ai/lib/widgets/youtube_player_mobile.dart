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

    _startControlsTimer();
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _seekOverlayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startControlsTimer();
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

              // Overlay for gestures + controls
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _toggleControls,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  color: _showControls
                      ? Colors.black.withValues(alpha: 0.65)
                      : Colors.transparent,
                  child: Stack(
                    children: [
                      // Center Play/Pause Button (Big & Beautiful)
                      if (_showControls)
                        Center(
                          child: GestureDetector(
                            onTap: _togglePlayPause,
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                              ),
                              child: Icon(
                                _controller.value.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 62,
                              ),
                            ),
                          ),
                        ),

                      // Top Bar (Title + Settings)
                      if (_showControls)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.settings, color: Colors.white, size: 26),
                                  onPressed: () {
                                    // You can call your speed sheet here if needed
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Gesture Zones for Double Tap Seek + Long Press 2x
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
                    ],
                  ),
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
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _seekOverlayAlignment == Alignment.centerRight
                              ? Icons.forward_10
                              : Icons.replay_10,
                          color: Colors.white,
                          size: 42,
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