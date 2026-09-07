import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImageUrlUploadField extends StatefulWidget {
  final TextEditingController controller;
  final String pathPrefix;
  final String labelText;
  final IconData prefixIcon;

  const ImageUrlUploadField({
    super.key,
    required this.controller,
    required this.pathPrefix,
    this.labelText = 'Image URL',
    this.prefixIcon = Icons.image_outlined,
  });

  @override
  State<ImageUrlUploadField> createState() => _ImageUrlUploadFieldState();
}

class _ImageUrlUploadFieldState extends State<ImageUrlUploadField> {
  bool _uploading = false;

  String _contentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      default:
        return 'image/*';
    }
  }

  Future<void> _pickAndUpload() async {
    if (_uploading) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to read the selected image.')),
      );
      return;
    }

    final originalExtension = file.extension?.toLowerCase() ?? 'png';
    final extension = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp']
            .contains(originalExtension)
        ? originalExtension
        : 'png';
    final path =
        '${widget.pathPrefix}/${DateTime.now().microsecondsSinceEpoch}.$extension';

    setState(() {
      _uploading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final storage = supabase.storage.from('module-images');

      await storage.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: _contentType(extension),
          upsert: false,
        ),
      );

      final publicUrl = storage.getPublicUrl(path);
      widget.controller.text = publicUrl;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image upload failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.controller.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.controller,
          decoration: InputDecoration(
            labelText: widget.labelText,
            prefixIcon: Icon(widget.prefixIcon),
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 42,
              child: FilledButton.icon(
                onPressed: _uploading ? null : _pickAndUpload,
                icon: _uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_rounded),
                label: Text(_uploading ? 'Uploading...' : 'Upload Image'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 92,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: imageUrl.isEmpty
                    ? Center(
                        child: Text(
                          'Image preview',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}