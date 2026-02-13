import 'package:supabase_flutter/supabase_flutter.dart';

// Get the Supabase client instance
final supabase = Supabase.instance.client;

// Helper class for Supabase operations
class SupabaseService {
  // Get the authenticated user
  static User? get currentUser => supabase.auth.currentUser;

  // Check if user is signed in
  static bool get isSignedIn => currentUser != null;

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
}
