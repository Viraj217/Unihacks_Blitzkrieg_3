import 'supabase_service.dart';

class TimeCapsule {
  final String id;
  final String groupId;
  final String title;
  final String? description;
  final DateTime unlockDate;
  final bool isLocked;
  final bool isCollaborative;
  final DateTime? contributionDeadline;
  final String? thumbnailUrl;
  final String theme;
  final DateTime createdAt;
  final DateTime? unlockedAt;
  final int viewsCount;

  TimeCapsule({
    required this.id,
    required this.groupId,
    required this.title,
    this.description,
    required this.unlockDate,
    required this.isLocked,
    required this.isCollaborative,
    this.contributionDeadline,
    this.thumbnailUrl,
    required this.theme,
    required this.createdAt,
    this.unlockedAt,
    required this.viewsCount,
  });

  factory TimeCapsule.fromMap(Map<String, dynamic> map) {
    return TimeCapsule(
      id: map['id'],
      groupId: map['group_id'],
      title: map['title'],
      description: map['description'],
      unlockDate: DateTime.parse(map['unlock_date']).toLocal(),
      isLocked: map['is_locked'] ?? true,
      isCollaborative: map['is_collaborative'] ?? false,
      contributionDeadline: map['contribution_deadline'] != null
          ? DateTime.parse(map['contribution_deadline']).toLocal()
          : null,
      thumbnailUrl: map['thumbnail_url'],
      theme: map['theme'] ?? 'default',
      createdAt: DateTime.parse(map['created_at']).toLocal(),
      unlockedAt: map['unlocked_at'] != null
          ? DateTime.parse(map['unlocked_at']).toLocal()
          : null,
      viewsCount: map['views_count'] ?? 0,
    );
  }
}

class CapsuleContent {
  final String id;
  final String capsuleId;
  final String? userId; // Owner
  final String contentType; // 'photo', 'note', 'voice', 'video'
  final String? contentText;
  final String? mediaUrl;
  final DateTime createdAt;

  CapsuleContent({
    required this.id,
    required this.capsuleId,
    this.userId,
    required this.contentType,
    this.contentText,
    this.mediaUrl,
    required this.createdAt,
  });

  factory CapsuleContent.fromMap(Map<String, dynamic> map) {
    return CapsuleContent(
      id: map['id'],
      capsuleId: map['capsule_id'],
      userId: map['user_id'],
      contentType: map['content_type'],
      contentText: map['content_text'],
      mediaUrl: map['media_url'],
      createdAt: DateTime.parse(map['created_at']).toLocal(),
    );
  }
}

class TimeCapsuleService {
  /// Fetch all capsules for a specific group
  static Future<List<TimeCapsule>> getGroupCapsules(String groupId) async {
    try {
      final data = await supabase
          .from('time_capsules')
          .select()
          .eq('group_id', groupId)
          .order('created_at', ascending: false);

      return (data as List).map((e) => TimeCapsule.fromMap(e)).toList();
    } catch (e) {
      print('Error fetching capsules: $e');
      return [];
    }
  }

  /// Create a new time capsule
  static Future<TimeCapsule?> createCapsule({
    required String groupId,
    required String title,
    String? description,
    required DateTime unlockDate,
    bool isCollaborative = false,
    DateTime? contributionDeadline,
    String theme = 'default',
  }) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      // Get profile ID first (assuming auth_id -> profile id mapping exists or using auth_id if schema changed,
      // but based on init.sql created_by is UUID references profiles(id))
      // For simplicity, we'll try to get the profile ID for the current user first.
      final profile = await SupabaseService.getUserProfile();
      final profileId = profile?['id'];
      if (profileId == null) throw Exception("User profile not found");

      final data = await supabase
          .from('time_capsules')
          .insert({
            'group_id': groupId,
            'created_by': profileId,
            'title': title,
            'description': description,
            'unlock_date': unlockDate.toUtc().toIso8601String(),
            'is_locked': true,
            'is_collaborative': isCollaborative,
            'contribution_deadline': contributionDeadline
                ?.toUtc()
                .toIso8601String(),
            'theme': theme,
          })
          .select()
          .single();

      return TimeCapsule.fromMap(data);
    } catch (e) {
      print('Error creating capsule: $e');
      rethrow;
    }
  }

  /// Add content (Note/Photo) to a capsule
  static Future<void> addContent({
    required String capsuleId,
    required String contentType,
    String? contentText,
    String? mediaUrl,
  }) async {
    try {
      final profile = await SupabaseService.getUserProfile();
      final profileId = profile?['id'];
      if (profileId == null) throw Exception("User not found");

      await supabase.from('capsule_contents').insert({
        'capsule_id': capsuleId,
        'user_id': profileId,
        'content_type': contentType,
        'content_text': contentText,
        'media_url': mediaUrl,
      });

      // Trigger 'mark_contributor_contributed' happens automatically via DB trigger
    } catch (e) {
      print('Error adding content: $e');
      rethrow;
    }
  }

  /// Get contents of a capsule (Only if unlocked or if user is owner/contributor logic?
  /// Usually only if unlocked. Locked capsules hide contents.)
  static Future<List<CapsuleContent>> getCapsuleContents(
    String capsuleId,
  ) async {
    try {
      final data = await supabase
          .from('capsule_contents')
          .select()
          .eq('capsule_id', capsuleId)
          .order('created_at', ascending: true);

      return (data as List).map((e) => CapsuleContent.fromMap(e)).toList();
    } catch (e) {
      print('Error fetching contents: $e');
      return [];
    }
  }
}
