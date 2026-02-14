import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/time_capsule_service.dart';
import '../../widgets/glass_container.dart';
import 'create_capsule_page.dart';
import 'capsule_detail_page.dart';

class TimeCapsuleListPage extends StatefulWidget {
  final String groupId;
  final String groupName;

  const TimeCapsuleListPage({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<TimeCapsuleListPage> createState() => _TimeCapsuleListPageState();
}

class _TimeCapsuleListPageState extends State<TimeCapsuleListPage> {
  List<TimeCapsule> _capsules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCapsules();
  }

  Future<void> _loadCapsules() async {
    setState(() => _isLoading = true);
    final capsules = await TimeCapsuleService.getGroupCapsules(widget.groupId);
    if (mounted) {
      setState(() {
        _capsules = capsules;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                'Time Capsules',
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
          // Background handled by Scaffold theme or main
          SafeArea(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
                  )
                : _capsules.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _capsules.length,
                    itemBuilder: (context, index) {
                      return _buildCapsuleCard(_capsules[index]);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF7C3AED),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateCapsulePage(groupId: widget.groupId),
            ),
          );
          _loadCapsules();
        },
        icon: const Icon(Icons.add_alarm, color: Colors.white),
        label: const Text('New Capsule', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.access_time_filled_outlined,
            size: 80,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 20),
          Text(
            'No Time Capsules yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create one to preserve memories for the future!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapsuleCard(TimeCapsule capsule) {
    final now = DateTime.now();
    final isLocked = capsule.unlockDate.isAfter(now);
    final daysLeft = capsule.unlockDate.difference(now).inDays;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(20),
        opacity: 0.1,
        blur: 10,
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            // Navigate to detail
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CapsuleDetailPage(capsule: capsule),
              ),
            );
            _loadCapsules(); // Refresh on return
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isLocked
                        ? Colors.white.withOpacity(0.1)
                        : const Color(0xFF10B981).withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isLocked
                          ? Colors.white.withOpacity(0.2)
                          : const Color(0xFF10B981).withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    isLocked ? Icons.lock : Icons.lock_open,
                    color: isLocked ? Colors.white70 : const Color(0xFF10B981),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        capsule.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isLocked ? 'Opens in $daysLeft days' : 'Unlocked!',
                        style: TextStyle(
                          color: isLocked
                              ? Colors.white.withOpacity(0.6)
                              : const Color(0xFF10B981),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (capsule.description != null &&
                          capsule.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            capsule.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!isLocked)
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white30,
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
