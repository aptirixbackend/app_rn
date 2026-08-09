import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../data/property_repository.dart';
import '../data/property_view.dart';
import 'video_player_screen.dart';

/// All photos and the video tour for a listing, shown as a grid.
class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key, required this.propertyId});
  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(propertyByIdProvider(propertyId));
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text('Photos & Videos',
            style:
                GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Could not load media.\n$e',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 12.5, color: AppColors.inkSoft))),
        data: (row) {
          if (row == null) {
            return Center(
                child: Text('Property not found.',
                    style: GoogleFonts.poppins(color: AppColors.inkSoft)));
          }
          final v = PropertyView(row);
          final images = v.galleryImages;
          return GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.all(14),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              if (v.hasVideo)
                _tile(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image(image: images.first, fit: BoxFit.cover),
                      Container(color: Colors.black.withValues(alpha: 0.28)),
                      const Center(
                        child: Icon(Icons.play_circle_fill_rounded,
                            color: Colors.white, size: 46),
                      ),
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text('Video Tour',
                              style: GoogleFonts.poppins(
                                  fontSize: 10, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => VideoPlayerScreen(
                          url: v.videoUrl!, title: v.title))),
                ),
              for (var i = 0; i < images.length; i++)
                _tile(
                  child: Image(image: images[i], fit: BoxFit.cover),
                  onTap: () => _openPhoto(context, images, i),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _tile({required Widget child, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(color: AppColors.primarySoft, child: child),
        ),
      );

  void _openPhoto(BuildContext context, List<ImageProvider> images, int index) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _PhotoViewer(images: images, initial: index),
    ));
  }
}

/// Full-screen swipeable, zoomable photo viewer.
class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.images, required this.initial});
  final List<ImageProvider> images;
  final int initial;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _ctrl = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${widget.images.length}',
            style: GoogleFonts.poppins(fontSize: 14)),
      ),
      body: PageView.builder(
        controller: _ctrl,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(child: Image(image: widget.images[i])),
        ),
      ),
    );
  }
}
