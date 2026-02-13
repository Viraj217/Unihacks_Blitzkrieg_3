import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../services/supabase_service.dart';
import '../services/cloudinary_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  int _postCount = 0;
  int _berealCount = 0;
  int _friendCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    setState(() => _isLoading = true);

    try {
      // Fetch profile from Supabase
      final profile = await SupabaseService.getUserProfile();

      // Fetch BeReals count from Cloudinary
      final bereals = await CloudinaryService.listImages(maxResults: 100);

      // Fetch posts count from Supabase (assuming 'posts' table exists)
      int posts = 0;
      final userId = SupabaseService.currentUser?.id;
      if (userId != null) {
        try {
          final response = await supabase
              .from('posts')
              .select('id')
              .eq('user_id', userId);
          posts = (response as List).length;
        } catch (e) {
          posts = 0; // Table might not exist yet
        }
      }

      if (mounted) {
        setState(() {
          _profileData = profile;
          _berealCount = bereals.length;
          _postCount = posts;
          _friendCount =
              248; // Keeping this as a placeholder or fetch from 'friends' table
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: Colors.white.withOpacity(0.7),
            ),
            onPressed: _fetchProfileData,
          ),
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: Colors.white.withOpacity(0.7),
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchProfileData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // Avatar
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.3),
                    width: 3,
                  ),
                ),
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: colorScheme.primaryContainer.withOpacity(
                    0.4,
                  ),
                  backgroundImage: _profileData?['avatar_url'] != null
                      ? NetworkImage(_profileData!['avatar_url'])
                      : null,
                  child: _profileData?['avatar_url'] == null
                      ? Icon(Icons.person, size: 52, color: colorScheme.primary)
                      : null,
                ),
              ),

              const SizedBox(height: 16),
              Text(
                _profileData?['full_name'] ?? 'User Name',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              // Email display
              Text(
                _profileData?['email'] ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _profileData?['bio'] ?? 'Hey there! I am using Blitzkrieg',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),

              const SizedBox(height: 28),

              // Stats card
              Card(
                elevation: 0,
                color: Colors.white.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat('Posts', _postCount.toString(), colorScheme),
                      Container(
                        height: 36,
                        width: 1,
                        color: Colors.white.withOpacity(0.1),
                      ),
                      _buildStat(
                        'Friends',
                        _friendCount.toString(),
                        colorScheme,
                      ),
                      Container(
                        height: 36,
                        width: 1,
                        color: Colors.white.withOpacity(0.1),
                      ),
                      _buildStat(
                        'BeReals',
                        _berealCount.toString(),
                        colorScheme,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Actions Section
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'My Activity',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
              ),

              _buildActivityItem(
                icon: Icons.camera_alt_outlined,
                title: 'My BeReals',
                subtitle: '$_berealCount captures shared',
                color: const Color(0xFF7C3AED),
                onTap: () {
                  // Navigate to a dedicated BeReal history page if it exists
                },
              ),

              const SizedBox(height: 12),

              _buildActivityItem(
                icon: Icons.grid_view_outlined,
                title: 'My Posts',
                subtitle: '$_postCount snapshots shared on timeline',
                color: const Color(0xFFEC4899),
                onTap: () {},
              ),

              const SizedBox(height: 40),

              // Logout
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Card(
                  elevation: 0,
                  color: Colors.red.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Colors.red.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Log Out',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.redAccent,
                        fontSize: 15,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.redAccent,
                    ),
                    onTap: () async {
                      await SupabaseService.signOut();
                      if (mounted) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.landing,
                          (route) => false,
                        );
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, ColorScheme colorScheme) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withOpacity(0.5),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Colors.white.withOpacity(0.3),
        ),
      ),
    );
  }
}
