import '../models/saved_photo.dart';
import '../services/photo_library_service.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter/material.dart';

class ImagesSection extends StatefulWidget {
  const ImagesSection({Key? key}) : super(key: key);
  @override
  State<ImagesSection> createState() => _ImagesSectionState();
}

class _ImagesSectionState extends State<ImagesSection> {
  List<SavedPhoto> _photos = [];
  bool _isLoading = true;
  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    try {
      final photos = await PhotoLibraryService.getUserPhotos();
      if (mounted)
        setState(() {
          _photos = photos;
          _isLoading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_photos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: m.Text('No saved images yet.')),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _photos.length,
      itemBuilder: (context, i) {
        final photo = _photos[i];
        return Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              photo.imageData,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        );
      },
    );
  }
}
