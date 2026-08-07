import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../data/property_repository.dart';
import 'widgets/posting_widgets.dart';

class PhotosMediaScreen extends ConsumerStatefulWidget {
  const PhotosMediaScreen({super.key, this.propertyId});
  final String? propertyId;

  @override
  ConsumerState<PhotosMediaScreen> createState() => _PhotosMediaScreenState();
}

class _PhotosMediaScreenState extends ConsumerState<PhotosMediaScreen> {
  final _picker = ImagePicker();

  Uint8List? _cover;
  final _photos = <Uint8List>[];
  Uint8List? _video;
  String? _videoName;
  Uint8List? _floorPlan;
  String? _floorPlanName;
  bool _loading = false;

  int get _count => _photos.length + (_cover != null ? 1 : 0);

  Future<void> _pickCover() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (x != null) {
      final b = await x.readAsBytes();
      if (mounted) setState(() => _cover = b);
    }
  }

  Future<void> _pickPhotos() async {
    final xs = await _picker.pickMultiImage(imageQuality: 80);
    if (xs.isEmpty) return;
    for (final x in xs) {
      if (_count >= 20) break;
      _photos.add(await x.readAsBytes());
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickFloorPlan() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (x != null) {
      final b = await x.readAsBytes();
      if (mounted) {
        setState(() {
          _floorPlan = b;
          _floorPlanName = x.name;
        });
      }
    }
  }

  Future<void> _pickVideo() async {
    final x = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 2));
    if (x != null) {
      final b = await x.readAsBytes();
      if (mounted) {
        setState(() {
          _video = b;
          _videoName = x.name;
        });
      }
    }
  }

  Future<void> _continue() async {
    setState(() => _loading = true);
    try {
      final id = widget.propertyId;
      if (id != null) {
        final repo = ref.read(propertyRepositoryProvider);
        String? coverUrl;
        final photoUrls = <String>[];
        String? floorUrl;
        String? videoUrl;
        if (_cover != null) {
          coverUrl = await repo.uploadMedia(_cover!, 'cover_$id.jpg');
        }
        for (var i = 0; i < _photos.length; i++) {
          final u = await repo.uploadMedia(_photos[i], 'photo_${id}_$i.jpg');
          if (u != null) photoUrls.add(u);
        }
        if (_video != null) {
          videoUrl = await repo.uploadMedia(_video!, 'video_$id.mp4',
              contentType: 'video/mp4');
        }
        if (_floorPlan != null) {
          floorUrl = await repo.uploadMedia(_floorPlan!, 'floorplan_$id.jpg');
        }
        final allPhotos = <String>[
          ?coverUrl,
          ...photoUrls,
        ];
        await repo.saveMedia(
          id,
          coverUrl: coverUrl,
          photoUrls: allPhotos.isEmpty ? null : allPhotos,
          videoUrl: videoUrl,
          floorPlanUrl: floorUrl,
        );
      }
    } catch (_) {
      // Preview mode / no Storage bucket — ignore and continue.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (mounted) context.go('/post-property/review', extra: widget.propertyId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            PostingProgressBar(
                step: 5, onBack: () => context.go('/post-property/amenities')),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(),
                    const SizedBox(height: 16),
                    _tipBanner(),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Photos',
                            style: GoogleFonts.poppins(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        Text('($_count/20)',
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: AppColors.inkSoft)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _photosRow(),
                    const SizedBox(height: 18),
                    Text('More Photos',
                        style: GoogleFonts.poppins(
                            fontSize: 13.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    _uploadZone(),
                    const SizedBox(height: 18),
                    Text('Video Tour (Optional)',
                        style: GoogleFonts.poppins(
                            fontSize: 13.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    _actionRow(
                      icon: _video == null
                          ? Icons.videocam_outlined
                          : Icons.check_circle_rounded,
                      title: _video == null
                          ? 'Upload a video tour'
                          : (_videoName ?? 'Video selected'),
                      subtitle: _video == null
                          ? 'MP4 from your gallery, up to 2 min'
                          : 'Tap to replace',
                      onTap: _pickVideo,
                      trailing: _video == null
                          ? null
                          : GestureDetector(
                              onTap: () => setState(() {
                                _video = null;
                                _videoName = null;
                              }),
                              child: const Icon(Icons.close_rounded,
                                  color: AppColors.inkSoft),
                            ),
                    ),
                    const SizedBox(height: 18),
                    Text('Floor Plan (Optional)',
                        style: GoogleFonts.poppins(
                            fontSize: 13.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    _actionRow(
                      icon: Icons.upload_file_outlined,
                      title: _floorPlanName ?? 'Upload floor plan',
                      subtitle:
                          _floorPlan == null ? 'PDF, JPG or PNG' : 'Selected',
                      onTap: _pickFloorPlan,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: FilledButton(
                onPressed: _loading ? null : _continue,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.white))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text('Continue'),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add photos & media',
                  style: GoogleFonts.poppins(
                      fontSize: 23, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Good photos get more views and better\nresponse',
                  style: GoogleFonts.poppins(
                      fontSize: 13, height: 1.35, color: AppColors.inkSoft)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Image.asset('assets/images/photo_upload.png',
            width: 96, fit: BoxFit.contain),
      ],
    );
  }

  Widget _tipBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tip: Add more photos to increase trust and get up to 5x more inquiries!',
              style: GoogleFonts.poppins(
                  fontSize: 12.5, height: 1.35, color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photosRow() {
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _coverTile(),
          for (var i = 0; i < _photos.length; i++) _thumb(_photos[i], i),
        ],
      ),
    );
  }

  Widget _coverTile() {
    if (_cover == null) {
      return GestureDetector(
        onTap: _pickCover,
        child: Container(
          width: 96,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add, color: AppColors.primary),
              const SizedBox(height: 6),
              Text('Add Cover\nPhoto',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      height: 1.2,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
    }
    return Container(
      width: 96,
      margin: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(_cover!,
                width: 96, height: 96, fit: BoxFit.cover),
          ),
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6)),
              child: Text('Cover',
                  style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          _removeBtn(() => setState(() => _cover = null)),
        ],
      ),
    );
  }

  Widget _thumb(Uint8List bytes, int index) {
    return Container(
      width: 96,
      margin: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child:
                Image.memory(bytes, width: 96, height: 96, fit: BoxFit.cover),
          ),
          _removeBtn(() => setState(() => _photos.removeAt(index))),
        ],
      ),
    );
  }

  Widget _removeBtn(VoidCallback onTap) {
    return Positioned(
      top: 4,
      right: 4,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
              color: Colors.white, shape: BoxShape.circle),
          child: const Icon(Icons.close, size: 14, color: AppColors.ink),
        ),
      ),
    );
  }

  Widget _uploadZone() {
    return GestureDetector(
      onTap: _pickPhotos,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            const Icon(Icons.cloud_upload_outlined,
                color: AppColors.primary, size: 26),
            const SizedBox(height: 8),
            Text('Upload more photos',
                style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
            const SizedBox(height: 2),
            Text('or drag and drop here',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.inkSoft)),
            const SizedBox(height: 2),
            Text('JPG, PNG up to 10MB each',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 13.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.inkSoft)),
                ],
              ),
            ),
            trailing ??
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.inkSoft),
          ],
        ),
      ),
    );
  }
}
