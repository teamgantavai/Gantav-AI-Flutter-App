import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

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

class AppYoutubePlayerState extends State<AppYoutubePlayer> {
  late YoutubePlayerController _controller;

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
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  Future<void> setPlaybackRate(double rate) async {
    await _controller.setPlaybackRate(rate);
    widget.onSpeedChanged?.call(rate);
  }

  Future<double> getCurrentTime() async {
    return await _controller.currentTime;
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: YoutubePlayer(
        controller: _controller,
        aspectRatio: 16 / 9,
      ),
    );
  }
}
