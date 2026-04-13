import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: YoutubePlayerFlags(
        autoPlay: widget.autoPlay,
        mute: false,
        enableCaption: false,
        forceHD: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> setPlaybackRate(double rate) async {
    _controller.setPlaybackRate(rate);
    widget.onSpeedChanged?.call(rate);
  }

  Future<double> getCurrentTime() async {
    return _controller.value.position.inSeconds.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: const Color(0xFF6366F1), // Violet color from AppTheme
        progressColors: const ProgressBarColors(
          playedColor: Color(0xFF6366F1),
          handleColor: Color(0xFF818CF8),
        ),
        bottomActions: [
          const SizedBox(width: 14.0),
          CurrentPosition(),
          const SizedBox(width: 8.0),
          ProgressBar(isExpanded: true),
          RemainingDuration(),
          const PlaybackSpeedButton(),
        ],
      ),
    );
  }
}
