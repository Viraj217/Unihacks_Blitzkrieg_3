import 'package:supabase_flutter/supabase_flutter.dart';

// Get the Supabase client instance
final supabase = Supabase.instance.client;

// Helper class for Supabase operations
class SupabaseService {
  // Get the authenticated user
  static User? get currentUser => supabase.auth.currentUser;

  // Check if user is signed in
  static bool get isSignedIn => currentUser != null;

  // Get the current access token
  static String? get accessToken => supabase.auth.currentSession?.accessToken;

  // Sign in with email and password
  static Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign up with email and password
  static Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return await supabase.auth.signUp(email: email, password: password);
  }

  // Sign out
  static Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  // Listen to auth state changes
  static Stream<AuthState> get authStateChanges =>
      supabase.auth.onAuthStateChange;

  // Database query example - customize based on your tables
  static Future<List<Map<String, dynamic>>> getDataFromTable(
    String tableName,
  ) async {
    return await supabase.from(tableName).select();
  }

  // Insert data into table
  static Future<void> insertData(
    String tableName,
    Map<String, dynamic> data,
  ) async {
    await supabase.from(tableName).insert(data);
  }

  // Update data in table
  static Future<void> updateData(
    String tableName,
    Map<String, dynamic> data,
    String column,
    dynamic value,
  ) async {
    await supabase.from(tableName).update(data).eq(column, value);
  }

  // Delete data from table
  static Future<void> deleteData(
    String tableName,
    String column,
    dynamic value,
  ) async {
    await supabase.from(tableName).delete().eq(column, value);
  }

  // Get current user's profile
  static Future<Map<String, dynamic>?> getUserProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final data = await supabase
          .from('profiles')
          .select()
          .eq('auth_id', user.id)
          .single();

      // Create a specific profile map and inject the email from auth if needed
      final profile = Map<String, dynamic>.from(data);

      // Ensure email is available (use from profile or fallback to auth email)
      if (profile['email'] == null) {
        profile['email'] = user.email;
      }

      // Ensure display name is available
      if (profile['display_name'] == null) {
        profile['display_name'] = user.email?.split('@').first ?? 'User';
      }

      return profile;
    } catch (e) {
      // If profile doesn't exist, return basic user info
      return {
        'auth_id': user.id,
        'email': user.email,
        'display_name': user.email?.split('@').first ?? 'User',
        'username': user.email?.split('@').first ?? 'user',
        'avatar_url': null,
        'bio': 'Hey there! I am using Blitzkrieg',
      };
    }
  }
}
