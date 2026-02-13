import 'package:flutter/material.dart';
import '../routes/app_routes.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _nameController = TextEditingController();
  int _selectedAvatarIndex = -1;

  final List<_AvatarOption> _avatars = [
    _AvatarOption(
      Icons.person,
      const Color(0xFF7C3AED),
      const Color(0xFFEDE9FE),
    ),
    _AvatarOption(Icons.face, const Color(0xFFEC4899), const Color(0xFFFCE7F3)),
    _AvatarOption(
      Icons.face_2,
      const Color(0xFFF59E0B),
      const Color(0xFFFEF3C7),
    ),
    _AvatarOption(
      Icons.face_3,
      const Color(0xFF10B981),
      const Color(0xFFD1FAE5),
    ),
    _AvatarOption(
      Icons.face_4,
      const Color(0xFF3B82F6),
      const Color(0xFFDBEAFE),
    ),
    _AvatarOption(
      Icons.face_5,
      const Color(0xFFEF4444),
      const Color(0xFFFEE2E2),
    ),
    _AvatarOption(
      Icons.face_6,
      const Color(0xFF8B5CF6),
      const Color(0xFFEDE9FE),
    ),
    _AvatarOption(
      Icons.tag_faces,
      const Color(0xFF06B6D4),
      const Color(0xFFCFFAFE),
    ),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile info'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          children: [
            const SizedBox(height: 16),

            Text(
              'Please provide your name and an optional\nprofile photo',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),

            const SizedBox(height: 36),

            // Avatar display
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _selectedAvatarIndex >= 0
                        ? _avatars[_selectedAvatarIndex].bgColor
                        : colorScheme.primaryContainer.withOpacity(0.4),
                    border: Border.all(
                      color: _selectedAvatarIndex >= 0
                          ? _avatars[_selectedAvatarIndex].color.withOpacity(
                              0.3,
                            )
                          : colorScheme.primary.withOpacity(0.2),
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    _selectedAvatarIndex >= 0
                        ? _avatars[_selectedAvatarIndex].icon
                        : Icons.person,
                    size: 56,
                    color: _selectedAvatarIndex >= 0
                        ? _avatars[_selectedAvatarIndex].color
                        : colorScheme.primary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Avatar picker grid
            Text(
              'Choose an avatar',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: List.generate(_avatars.length, (index) {
                final avatar = _avatars[index];
                final isSelected = _selectedAvatarIndex == index;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedAvatarIndex = index;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: avatar.bgColor,
                      border: Border.all(
                        color: isSelected ? avatar.color : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: avatar.color.withOpacity(0.3),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(avatar.icon, color: avatar.color, size: 28),
                  ),
                );
              }),
            ),

            const SizedBox(height: 32),

            // Name input
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Type your name here',
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  child: Icon(
                    Icons.person_outline,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 48),
                suffixIcon: IconButton(
                  icon: Icon(
                    Icons.emoji_emotions_outlined,
                    color: Colors.grey[400],
                  ),
                  onPressed: () {},
                ),
              ),
            ),

            const SizedBox(height: 16),

            // About / Status input
            TextField(
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'About (optional)',
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  child: Icon(
                    Icons.info_outline,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 48),
              ),
            ),
          ],
        ),
      ),

      // Bottom button
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: FilledButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.home,
                (route) => false,
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Text('Next'),
          ),
        ),
      ),
    );
  }
}

class _AvatarOption {
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _AvatarOption(this.icon, this.color, this.bgColor);
}
