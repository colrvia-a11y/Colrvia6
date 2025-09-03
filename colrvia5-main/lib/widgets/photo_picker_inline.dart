// lib/widgets/photo_picker_inline.dart
import 'package:flutter/material.dart';
import 'package:color_canvas/services/photo_upload_service.dart';

class PhotoPickerInline extends StatefulWidget {
  final List<String> value; // current URLs
  final int max;
  final ValueChanged<List<String>> onChanged;
  const PhotoPickerInline({super.key, required this.value, required this.onChanged, this.max = 6});

  @override
  State<PhotoPickerInline> createState() => _PhotoPickerInlineState();
}

class _PhotoPickerInlineState extends State<PhotoPickerInline> {
  double _progress = 0;
  bool _busy = false;

  Future<void> _add() async {
    setState(() { _busy = true; _progress = 0; });
    final files = await PhotoUploadService.instance.pickPhotos(max: widget.max - widget.value.length);
    if (files.isEmpty) { setState(() { _busy = false; }); return; }
    final urls = await PhotoUploadService.instance.uploadAll(files, onProgress: (p) => setState(() => _progress = p));
    final next = [...widget.value, ...urls];
    widget.onChanged(next);
    setState(() { _busy = false; _progress = 0; });
  }

  void _remove(String url) {
    final next = [...widget.value]..remove(url);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final url in urls) _thumb(url, onRemove: () => _remove(url)),
            if (urls.length < widget.max)
              OutlinedButton.icon(
                onPressed: _busy ? null : _add,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(_busy ? 'Uploading ${(100 * _progress).toStringAsFixed(0)}%' : 'Add photo'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text('Tip: 2–3 daytime and 1 nighttime photo help the AI read your lighting.', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _thumb(String url, {required VoidCallback onRemove}) {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(url, width: 96, height: 96, fit: BoxFit.cover),
        ),
        Positioned(
          right: 0, top: 0,
          child: Material(
            color: Colors.black54, borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(999),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        )
      ],
    );
  }
}
