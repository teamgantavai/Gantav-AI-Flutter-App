import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:google_fonts/google_fonts.dart';

class YoutubeWebViewPlayer extends StatefulWidget {
  final String videoId;
  final bool autoPlay;
  final VoidCallback? onVideoEnd;
  final ValueChanged<double>? onProgress;

  const YoutubeWebViewPlayer({
    super.key,
    required this.videoId,
    this.autoPlay = false,
    this.onVideoEnd,
    this.onProgress,
  });

  @override
  State<YoutubeWebViewPlayer> createState() => YoutubeWebViewPlayerState();
}

class YoutubeWebViewPlayerState extends State<YoutubeWebViewPlayer> with TickerProviderStateMixin {
  late final WebViewController _controller;
  bool _isPlayerReady = false;
  bool _isPlaying = false;
  double _currentTime = 0;
  double _totalDuration = 1;
  bool _showControls = true;
  bool _isDragging = false;
  double _currentSpeed = 1.0;
  Timer? _controlsTimer;

  // Gesture States
  bool _isLongPressing = false;
  bool _showPlayPauseOverlay = false;
  bool _showSeekForward = false;
  bool _showSeekBackward = false;
  int _seekAmount = 10;
  Timer? _seekTimer;

  late AnimationController _playPauseController;
  late Animation<double> _playPauseScaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeController();
    _playPauseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _playPauseScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _playPauseController, curve: Curves.easeOut),
    );
  }

  void _initializeController() {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const {},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(params);

    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'YoutubePlayer',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final data = jsonDecode(message.message);
            _handlePlayerEvent(data);
          } catch (e) {
            debugPrint('Error parsing player event: $e');
          }
        },
      )
      ..loadHtmlString(_getHtmlBody(widget.videoId));

    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
  }

  void _handlePlayerEvent(Map<String, dynamic> data) {
    if (!mounted) return;
    final method = data['method'];
    final args = data['args'];

    switch (method) {
      case 'onReady':
        setState(() {
          _isPlayerReady = true;
          if (widget.autoPlay) {
            _play();
          }
        });
        break;
      case 'onStateChange':
        final state = args['state'];
        setState(() {
          _isPlaying = state == 1; // 1: playing, 2: paused
          if (state == 0) { // 0: ended
            widget.onVideoEnd?.call();
          }
        });
        break;
      case 'onTimeUpdate':
        if (!_isDragging) {
          setState(() {
            _currentTime = args['currentTime'].toDouble();
            _totalDuration = args['duration'].toDouble();
          });
          widget.onProgress?.call(_currentTime);
        }
        break;
    }
  }

  String _getHtmlBody(String videoId) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <style>
        body { margin: 0; padding: 0; background: black; overflow: hidden; }
        .video-container { position: relative; width: 100vw; height: 100vh; }
        iframe { width: 100%; height: 100%; border: none; pointer-events: none; }
    </style>
</head>
<body>
    <div class="video-container">
        <div id="player"></div>
    </div>
    <script>
        var tag = document.createElement('script');
        tag.src = "https://www.youtube.com/iframe_api";
        var firstScriptTag = document.getElementsByTagName('script')[0];
        firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

        var player;
        function onYouTubeIframeAPIReady() {
            player = new YT.Player('player', {
                height: '100%',
                width: '100%',
                videoId: '$videoId',
                playerVars: {
                    'autoplay': ${widget.autoPlay ? 1 : 0},
                    'controls': 0,
                    'rel': 0,
                    'showinfo': 0,
                    'modestbranding': 1,
                    'iv_load_policy': 3,
                    'playsinline': 1,
                    'fs': 0,
                    'disablekb': 1,
                    'enablejsapi': 1,
                    'origin': 'https://www.youtube.com'
                },
                events: {
                    'onReady': onPlayerReady,
                    'onStateChange': onPlayerStateChange,
                    'onError': function(e) { sendMessage('onError', { 'code': e.data }); }
                }
            });
        }

        function onPlayerReady(event) {
            sendMessage('onReady', {});
            setInterval(updateTime, 500);
        }

        function onPlayerStateChange(event) {
            sendMessage('onStateChange', { 'state': event.data });
        }

        function updateTime() {
            if (player && player.getCurrentTime) {
                sendMessage('onTimeUpdate', {
                    'currentTime': player.getCurrentTime(),
                    'duration': player.getDuration()
                });
            }
        }

        function sendMessage(method, args) {
            if (window.YoutubePlayer) {
                YoutubePlayer.postMessage(JSON.stringify({
                    'method': method,
                    'args': args
                }));
            }
        }

        // Bridge methods
        function playVideo() { if(player && player.playVideo) player.playVideo(); }
        function pauseVideo() { if(player && player.pauseVideo) player.pauseVideo(); }
        function seekTo(seconds) { if(player && player.seekTo) player.seekTo(seconds, true); }
        function setPlaybackRate(rate) { if(player && player.setPlaybackRate) player.setPlaybackRate(rate); }
    </script>
</body>
</html>
''';
  }

  void _play() {
    _controller.runJavaScript('playVideo()');
    _startControlsTimer();
  }

  void _pause() {
    _controller.runJavaScript('pauseVideo()');
    setState(() => _showControls = true);
    _controlsTimer?.cancel();
  }

  void _seekTo(double seconds) {
    _controller.runJavaScript('seekTo($seconds)');
    _startControlsTimer();
  }

  void setPlaybackRate(double speed) {
    setState(() => _currentSpeed = speed);
    _controller.runJavaScript('setPlaybackRate($speed)');
  }

  Future<double> getCurrentTime() async {
    return _currentTime;
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    if (_isPlaying) {
      _controlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _isPlaying && !_isDragging) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _pause();
    } else {
      _play();
    }

    setState(() {
      _showPlayPauseOverlay = true;
      _showControls = true;
    });
    _playPauseController.forward().then((_) => _playPauseController.reverse());

    Timer(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _showPlayPauseOverlay = false);
    });

    HapticFeedback.lightImpact();
  }

  void _handleDoubleTap(TapDownDetails details) {
    final width = context.size?.width ?? MediaQuery.of(context).size.width;
    final isRightSide = details.localPosition.dx > width / 2;

    if (isRightSide) {
      _seekRelative(10);
      setState(() {
        _showSeekForward = true;
        _seekAmount = 10;
        _showControls = true;
      });
    } else {
      _seekRelative(-10);
      setState(() {
        _showSeekBackward = true;
        _seekAmount = 10;
        _showControls = true;
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
    final newPos = (_currentTime + seconds).clamp(0.0, _totalDuration);
    _seekTo(newPos);
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    setPlaybackRate(2.0);
    setState(() => _isLongPressing = true);
    HapticFeedback.heavyImpact();
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    setPlaybackRate(1.0);
    setState(() => _isLongPressing = false);
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  void showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SettingsSheet(
        currentSpeed: _currentSpeed,
        onSpeedChanged: (speed) {
          setPlaybackRate(speed);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _seekTimer?.cancel();
    _playPauseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The WebView
            IgnorePointer(
              ignoring: true, 
              child: WebViewWidget(controller: _controller),
            ),

            // Native Gestures Overlay
            GestureDetector(
              onTap: () {
                if (_showControls) {
                  _togglePlayPause();
                } else {
                  setState(() => _showControls = true);
                  _startControlsTimer();
                }
              },
              onDoubleTapDown: _handleDoubleTap,
              onLongPressStart: _handleLongPressStart,
              onLongPressEnd: _handleLongPressEnd,
              behavior: HitTestBehavior.opaque,
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                  ),
                  child: _isPlayerReady ? _buildControls() : _buildLoading(),
                ),
              ),
            ),

            // Always visible overlays
            if (_showSeekForward) _buildSeekAnimation(true),
            if (_showSeekBackward) _buildSeekAnimation(false),
            if (_isLongPressing) _buildLongPressIndicator(),
            if (_showPlayPauseOverlay) _buildPlayPauseOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C6AFF)),
        strokeWidth: 3,
      ),
    );
  }

  Widget _buildPlayPauseOverlay() {
    return Center(
      child: ScaleTransition(
        scale: _playPauseScaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white12, width: 1),
          ),
          child: Icon(
            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 48,
          ),
        ),
      ),
    );
  }

  Widget _buildLongPressIndicator() {
    return Positioned(
      top: 16,
      left: 0, right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF7C6AFF).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(color: const Color(0xFF7C6AFF).withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 2),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.speed_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                '2.0× Speeding',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeekAnimation(bool isForward) {
    return Positioned(
      left: isForward ? null : 0,
      right: isForward ? 0 : null,
      top: 0, bottom: 0,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.3,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isForward
                ? [Colors.transparent, Colors.white10]
                : [Colors.white10, Colors.transparent],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isForward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
                color: Colors.white,
                size: 40,
              ),
              const SizedBox(height: 4),
              Text(
                '${isForward ? '+' : '-'}$_seekAmount s',
                style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Column(
      children: [
        const Expanded(child: SizedBox()),
        // Play/Pause Center
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ControlIconButton(
                icon: Icons.replay_10_rounded,
                size: 32,
                onPressed: () => _seekRelative(-10),
              ),
              const SizedBox(width: 40),
              _ControlIconButton(
                icon: _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 56,
                onPressed: _togglePlayPause,
                isPrimary: true,
              ),
              const SizedBox(width: 40),
              _ControlIconButton(
                icon: Icons.forward_10_rounded,
                size: 32,
                onPressed: () => _seekRelative(10),
              ),
            ],
          ),
        ),
        const Expanded(child: SizedBox()),
        // Progress Bar and Time
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black54, Colors.transparent],
            ),
          ),
          child: Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: const Color(0xFF7C6AFF),
                  inactiveTrackColor: Colors.white24,
                  thumbColor: const Color(0xFF7C6AFF),
                  trackShape: const RectangularSliderTrackShape(),
                ),
                child: Slider(
                  value: _currentTime.clamp(0, _totalDuration),
                  max: _totalDuration,
                  onChangeStart: (_) => _isDragging = true,
                  onChanged: (value) {
                    setState(() => _currentTime = value);
                  },
                  onChangeEnd: (value) {
                    _isDragging = false;
                    _seekTo(value);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_currentTime),
                      style: GoogleFonts.dmMono(color: Colors.white70, fontSize: 11),
                    ),
                    Text(
                      _formatDuration(_totalDuration),
                      style: GoogleFonts.dmMono(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ControlIconButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _ControlIconButton({
    required this.icon,
    required this.size,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: size),
      onPressed: () {
        HapticFeedback.selectionClick();
        onPressed();
      },
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      splashRadius: size * 0.8,
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  final double currentSpeed;
  final ValueChanged<double> onSpeedChanged;

  const _SettingsSheet({required this.currentSpeed, required this.onSpeedChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Playback Speed', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            const Divider(color: Colors.white10),
            ...[0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) => ListTile(
              leading: Icon(Icons.speed_rounded, color: speed == currentSpeed ? const Color(0xFF7C6AFF) : Colors.white54, size: 20),
              title: Text(speed == 1.0 ? 'Normal' : '${speed}x', style: GoogleFonts.dmSans(color: speed == currentSpeed ? const Color(0xFF7C6AFF) : Colors.white, fontSize: 15)),
              trailing: speed == currentSpeed ? const Icon(Icons.check_rounded, color: Color(0xFF7C6AFF), size: 20) : null,
              onTap: () => onSpeedChanged(speed),
            )),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
