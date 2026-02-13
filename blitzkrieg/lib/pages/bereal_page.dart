import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/cloudinary_service.dart';

class BeRealPage extends StatefulWidget {
  const BeRealPage({super.key});

  @override
  State<BeRealPage> createState() => _BeRealPageState();
}

class _BeRealPageState extends State<BeRealPage> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  String? _uploadedImageUrl;
  String? _uploadTime;
  String? _errorMessage;

  Future<void> _captureAndUpload() async {
    try {
      // Open camera
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
        maxWidth: 1080,
        maxHeight: 1920,
      );

      if (photo == null) return; // User cancelled

      setState(() {
        _isUploading = true;
        _errorMessage = null;
      });

      // Upload to Cloudinary
      final result = await CloudinaryService.uploadImage(File(photo.path));

      setState(() {
        _isUploading = false;
        _uploadedImageUrl = result['secure_url'] as String?;
        _uploadTime = DateFormat('hh:mm a').format(DateTime.now());
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🎉 BeReal posted successfully!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BeReal'),
        actions: [
          if (_uploadedImageUrl != null)
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.grey[600]),
              onPressed: () {
                setState(() {
                  _uploadedImageUrl = null;
                  _uploadTime = null;
                });
              },
            ),
        ],
      ),
      body: _uploadedImageUrl != null
          ? _buildPostedView(colorScheme)
          : _buildCaptureView(colorScheme),
    );
  }

  Widget _buildCaptureView(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Camera icon
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  size: 48,
                  color: colorScheme.primary,
                ),
              ),
            ),

            const SizedBox(height: 28),

            Text(
              'Time to BeReal! ⚡',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Capture your moment right now.\nNo filters, no retakes — just be real.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                height: 1.5,
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[400], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(fontSize: 13, color: Colors.red[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 36),

            // Capture button
            if (_isUploading)
              Column(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Uploading your BeReal...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _captureAndUpload,
                  icon: const Icon(Icons.camera_alt_rounded, size: 20),
                  label: const Text('Take a BeReal'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Gallery option
            if (!_isUploading)
              TextButton.icon(
                onPressed: () async {
                  final XFile? photo = await _picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 85,
                    maxWidth: 1080,
                    maxHeight: 1920,
                  );
                  if (photo == null) return;

                  setState(() {
                    _isUploading = true;
                    _errorMessage = null;
                  });

                  try {
                    final result = await CloudinaryService.uploadImage(
                      File(photo.path),
                    );
                    setState(() {
                      _isUploading = false;
                      _uploadedImageUrl = result['secure_url'] as String?;
                      _uploadTime = DateFormat(
                        'hh:mm a',
                      ).format(DateTime.now());
                    });
                  } catch (e) {
                    setState(() {
                      _isUploading = false;
                      _errorMessage = e.toString().replaceFirst(
                        'Exception: ',
                        '',
                      );
                    });
                  }
                },
                icon: Icon(
                  Icons.photo_library_outlined,
                  color: colorScheme.primary,
                  size: 20,
                ),
                label: Text(
                  'Choose from gallery',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostedView(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colorScheme.primaryContainer.withOpacity(0.4),
                child: Icon(Icons.person, color: colorScheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your BeReal',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    _uploadTime ?? 'Just now',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
              const Spacer(),
              Icon(Icons.more_vert, color: Colors.grey[400]),
            ],
          ),

          const SizedBox(height: 16),

          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.network(
              _uploadedImageUrl!,
              width: double.infinity,
              height: 420,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  width: double.infinity,
                  height: 420,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: colorScheme.primary,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: double.infinity,
                  height: 420,
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red[300],
                          size: 40,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load image',
                          style: TextStyle(color: Colors.red[400]),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Reactions row
          Row(
            children: [
              _buildReactionChip('🔥', colorScheme),
              const SizedBox(width: 8),
              _buildReactionChip('❤️', colorScheme),
              const SizedBox(width: 8),
              _buildReactionChip('😂', colorScheme),
              const Spacer(),
              TextButton.icon(
                onPressed: _captureAndUpload,
                icon: Icon(
                  Icons.camera_alt_outlined,
                  size: 18,
                  color: colorScheme.primary,
                ),
                label: Text(
                  'Retake',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReactionChip(String emoji, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.primaryContainer.withOpacity(0.4),
        ),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 18)),
    );
  }
}
