import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/cloudinary_service.dart';
import 'package:google_fonts/google_fonts.dart';

class BeRealUploadPreviewSheet extends StatefulWidget {
  final File imageFile;
  final VoidCallback onRetake;
  final VoidCallback onUploadSuccess;

  const BeRealUploadPreviewSheet({
    super.key,
    required this.imageFile,
    required this.onRetake,
    required this.onUploadSuccess,
  });

  @override
  State<BeRealUploadPreviewSheet> createState() =>
      _BeRealUploadPreviewSheetState();
}

class _BeRealUploadPreviewSheetState extends State<BeRealUploadPreviewSheet> {
  bool _isUploading = false;
  String? _errorMessage;
  final TextEditingController _captionController = TextEditingController();

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _uploadImage() async {
    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      final String postId = DateTime.now().millisecondsSinceEpoch.toString();

      await CloudinaryService.uploadImage(
        widget.imageFile,
        subfolder: 'posts',
        publicId: postId,
        caption: _captionController.text.trim(),
      );

      // Brief delay for indexing
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        // Close the sheet first
        Navigator.pop(context);
        widget.onUploadSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Use Padding with ViewInsets to handle keyboard pushing up content
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text(
                'New BeReal',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
            ),

            // Error Message
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Polaroid Preview
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
                    child: Column(
                      children: [
                        AspectRatio(
                          aspectRatio: 3 / 4,
                          child: Image.file(
                            widget.imageFile,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _captionController,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.grandstander(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Write a caption...',
                            hintStyle: GoogleFonts.grandstander(
                              color: Colors.black38,
                              fontStyle: FontStyle.italic,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: _isUploading
                  ? Column(
                      children: [
                        CircularProgressIndicator(color: colorScheme.primary),
                        const SizedBox(height: 16),
                        Text(
                          'Posting...',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        // Retake
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onRetake();
                            },
                            icon: const Icon(Icons.refresh, size: 20),
                            label: const Text('Retake'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colorScheme.primary,
                              minimumSize: const Size(0, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              side: BorderSide(
                                color: colorScheme.primary.withOpacity(0.3),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Upload
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: _uploadImage,
                            icon: const Icon(Icons.send_rounded, size: 20),
                            label: const Text('Post'),
                            style: FilledButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
