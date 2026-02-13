import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../services/cloudinary_service.dart';
import '../../widgets/bereal/upload_preview_sheet.dart';
import 'package:google_fonts/google_fonts.dart';

class BeRealPage extends StatefulWidget {
  const BeRealPage({super.key});

  @override
  State<BeRealPage> createState() => _BeRealPageState();
}

class _BeRealPageState extends State<BeRealPage> {
  final ImagePicker _picker = ImagePicker();

  // Feed state
  bool _isLoadingFeed = true;
  List<Map<String, dynamic>> _feedImages = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  // ─── LOAD FEED ────────────────────────────────────────────────
  Future<void> _loadFeed() async {
    setState(() => _isLoadingFeed = true);
    try {
      final images = await CloudinaryService.listImages(maxResults: 30);
      if (mounted) {
        setState(() {
          _feedImages = images;
          _isLoadingFeed = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFeed = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  // ─── CAMERA CAPTURE ───────────────────────────────────────────
  Future<void> _capturePhoto() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
        maxWidth: 1080,
      );

      if (photo != null && mounted) {
        _showUploadPreview(File(photo.path));
      }
    } catch (e) {
      _showErrorSnackBar('Failed to capture photo: $e');
    }
  }

  // ─── SHOW PREVIEW SHEET ───────────────────────────────────────
  void _showUploadPreview(File imageFile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BeRealUploadPreviewSheet(
        imageFile: imageFile,
        onRetake: _capturePhoto,
        onUploadSuccess: () {
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
          _loadFeed();
        },
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // ─── SCHEDULE DIALOG ──────────────────────────────────────────
  void _scheduleBeReal() {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    DateTime scheduled = DateTime(now.year, now.month, now.day, 12, 0);

    if (now.isAfter(scheduled)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final formattedDate = DateFormat('EEEE, MMM d').format(scheduled);
    final formattedTime = DateFormat('hh:mm a').format(scheduled);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Schedule BeReal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Reminder set for:',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Text(
              '$formattedTime\n$formattedDate',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('⏰ Scheduled for $formattedTime')),
              );
            },
            child: const Text('Schedule'),
          ),
        ],
      ),
    );
  }

  // ─── MAIN BUILD ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('BeReal'),
        actions: [
          IconButton(
            onPressed: _loadFeed,
            icon: Icon(Icons.refresh, color: Colors.grey[600]),
          ),
        ],
      ),
      body: _buildBody(colorScheme),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUploadOptions(colorScheme),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.camera_alt_rounded),
        label: const Text(
          'BeReal',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_isLoadingFeed) {
      return Center(
        child: CircularProgressIndicator(color: colorScheme.primary),
      );
    }

    if (_errorMessage != null && _feedImages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            TextButton(onPressed: _loadFeed, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_feedImages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No BeReals yet',
              style: TextStyle(fontSize: 20, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFeed,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: _feedImages.length,
        itemBuilder: (context, index) =>
            _buildFeedCard(_feedImages[index], colorScheme),
      ),
    );
  }

  Widget _buildFeedCard(Map<String, dynamic> image, ColorScheme colorScheme) {
    final url = image['secure_url'] ?? '';
    final createdAt = image['created_at'] ?? '';

    // Extract caption from Cloudinary context
    // Structure typically: context: { custom: { caption: "..." } }
    String caption = '';
    final context = image['context'];
    if (context is Map) {
      if (context['custom'] is Map && context['custom']['caption'] != null) {
        caption = context['custom']['caption'].toString();
      } else if (context['caption'] != null) {
        // Fallback for flat structure
        caption = context['caption'].toString();
      }
    }

    // Simple time ago logic
    String timeAgo = createdAt;
    try {
      final dt = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60)
        timeAgo = '${diff.inMinutes}m ago';
      else if (diff.inHours < 24)
        timeAgo = '${diff.inHours}h ago';
      else
        timeAgo = DateFormat('MMM d').format(dt);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Polaroid User Header (on the frame)
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(Icons.person, size: 16, color: colorScheme.primary),
              ),
              const SizedBox(width: 8),
              Text(
                'You',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
              const Spacer(),
              Text(
                timeAgo,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Main Image
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Container(
              color: Colors.grey[100],
              child: Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (ctx, child, progress) => progress == null
                    ? child
                    : Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary.withOpacity(0.5),
                        ),
                      ),
                errorBuilder: (ctx, _, __) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Caption Area (Polaroid style)
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                caption,
                style: GoogleFonts.grandstander(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  color: Colors.black87,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            const SizedBox(height: 16),

          // Reaction Row (Bottom of frame)
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.favorite_border, size: 20, color: Colors.grey[400]),
              const SizedBox(width: 12),
              Icon(
                Icons.chat_bubble_outline,
                size: 19,
                color: Colors.grey[400],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUploadOptions(ColorScheme colorScheme) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Upload Now'),
              onTap: () {
                Navigator.pop(context);
                _capturePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.alarm),
              title: const Text('Schedule for 12:00 PM'),
              onTap: () {
                Navigator.pop(context);
                _scheduleBeReal();
              },
            ),
          ],
        ),
      ),
    );
  }
}
