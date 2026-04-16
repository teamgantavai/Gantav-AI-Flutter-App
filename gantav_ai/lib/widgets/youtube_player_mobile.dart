import 'package:flutter/material.dart';
import 'youtube_webview_player.dart';

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
  final GlobalKey<YoutubeWebViewPlayerState> _playerKey = GlobalKey();

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

  void setPlaybackRate(double rate) {
    _playerKey.currentState?.setPlaybackRate(rate);
    widget.onSpeedChanged?.call(rate);
  }

  Future<double> getCurrentTime() async {
    return await _playerKey.currentState?.getCurrentTime() ?? 0.0;
  }

  void showSettingsSheet() {
    _playerKey.currentState?.showSettingsSheet();
  }

  @override
  Widget build(BuildContext context) {
    final safeId = _getSafeVideoId(widget.videoId);
    
    return YoutubeWebViewPlayer(
      key: _playerKey,
      videoId: safeId.isNotEmpty ? safeId : 'dQw4w9WgXcQ',
      autoPlay: widget.autoPlay,
      onVideoEnd: widget.onVideoEnd,
    );
  }
}