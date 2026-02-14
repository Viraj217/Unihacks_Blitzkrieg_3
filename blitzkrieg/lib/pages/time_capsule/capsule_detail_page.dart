import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/time_capsule_service.dart';
import '../../widgets/glass_container.dart';

class CapsuleDetailPage extends StatefulWidget {
  final TimeCapsule capsule;

  const CapsuleDetailPage({super.key, required this.capsule});

  @override
  State<CapsuleDetailPage> createState() => _CapsuleDetailPageState();
}

class _CapsuleDetailPageState extends State<CapsuleDetailPage> {
  List<CapsuleContent> _contents = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (!widget.capsule.isLocked) {
      _loadContents();
    }
  }

  Future<void> _loadContents() async {
    setState(() => _isLoading = true);
    final contents = await TimeCapsuleService.getCapsuleContents(
      widget.capsule.id,
    );
    if (mounted) {
      setState(() {
        _contents = contents;
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddNoteDialog() async {
    final noteController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.all(24),
          opacity: 0.2, // Darker glass
          blur: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add a Memory',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                style: const TextStyle(color: Colors.white),
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Write something for the future...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      if (noteController.text.trim().isNotEmpty) {
                        Navigator.pop(ctx);
                        await _addContent('note', noteController.text.trim());
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Add to Capsule'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addContent(String type, String text) async {
    try {
      await TimeCapsuleService.addContent(
        capsuleId: widget.capsule.id,
        contentType: type,
        contentText: text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Memory added to capsule!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = widget.capsule.isLocked;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: Colors.black.withOpacity(0.2),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                widget.capsule.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background handled by creation call
          if (isLocked) _buildLockedView() else _buildUnlockedView(),
        ],
      ),
      floatingActionButton: (isLocked && widget.capsule.isCollaborative)
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF7C3AED),
              onPressed: _showAddNoteDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add Memory',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildLockedView() {
    final unlockDate = widget.capsule.unlockDate;
    final now = DateTime.now();
    final diff = unlockDate.difference(now);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withOpacity(0.2),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: const Icon(
              Icons.lock_outline,
              size: 80,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 40),
          GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            borderRadius: BorderRadius.circular(24),
            opacity: 0.1,
            child: Column(
              children: [
                const Text(
                  'Capsule Locked',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Unlocks on ${unlockDate.year}-${unlockDate.month}-${unlockDate.day}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTimeBox('${diff.inDays}', 'Days'),
                    const SizedBox(width: 16),
                    _buildTimeBox('${diff.inHours % 24}', 'Hours'),
                    const SizedBox(width: 16),
                    _buildTimeBox('${diff.inMinutes % 60}', 'Mins'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBox(String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.5)),
          ),
          child: Text(
            value.padLeft(2, '0'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label.toUpperCase(),
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildUnlockedView() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
      );
    }

    if (_contents.isEmpty) {
      return Center(
        child: Text(
          'This capsule is empty!',
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 18),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 120, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _contents.length,
      itemBuilder: (context, index) {
        final content = _contents[index];
        return GlassContainer(
          borderRadius: BorderRadius.circular(20),
          opacity: 0.1,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (content.contentType == 'note')
                Expanded(
                  child: Center(
                    child: Text(
                      content.contentText ?? '',
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                const Expanded(
                  child: Center(
                    child: Icon(Icons.image, color: Colors.white, size: 40),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                _formatDate(content.createdAt),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
