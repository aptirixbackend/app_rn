import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

/// Simple full-screen player for a property's uploaded video tour.
class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, required this.url, this.title});
  final String url;
  final String? title;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(true)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _controller.play();
      }).catchError((Object e) {
        if (mounted) setState(() => _error = '$e');
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title ?? 'Video Tour',
            style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w600)),
      ),
      body: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not play this video.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: Colors.white70)),
              )
            : !_ready
                ? const CircularProgressIndicator(color: Colors.white)
                : GestureDetector(
                    onTap: () => setState(() => _controller.value.isPlaying
                        ? _controller.pause()
                        : _controller.play()),
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio == 0
                          ? 16 / 9
                          : _controller.value.aspectRatio,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          VideoPlayer(_controller),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: VideoProgressIndicator(_controller,
                                allowScrubbing: true),
                          ),
                          if (!_controller.value.isPlaying)
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.play_arrow_rounded,
                                  color: Colors.white, size: 38),
                            ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}
