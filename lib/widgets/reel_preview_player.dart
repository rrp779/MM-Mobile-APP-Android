import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ReelPreviewPlayer extends StatefulWidget {
  final String videoUrl;

  const ReelPreviewPlayer({super.key, required this.videoUrl});

  @override
  State<ReelPreviewPlayer> createState() => _ReelPreviewPlayerState();
}

class _ReelPreviewPlayerState extends State<ReelPreviewPlayer> {
  late VideoPlayerController controller;

  @override
  void initState() {
    super.initState();

    controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    )
      ..initialize().then((_) {
        if (mounted) setState(() {});
        controller.setLooping(true);
        controller.setVolume(0);
        controller.play();
      }).catchError((e) {
        debugPrint("Video error: $e");
        print("VIDEO URL: ${widget.videoUrl}");
      });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: VideoPlayer(controller),
      ),
    );
  }
}