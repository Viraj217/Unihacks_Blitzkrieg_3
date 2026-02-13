import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

/// Example Usage Guide for Supabase Integration
///
/// This file demonstrates how to use the Supabase service in your Flutter app.
/// You can reference this when implementing authentication, database operations, etc.

class SupabaseUsageExamples {
  // ============= AUTHENTICATION EXAMPLES =============

  /// Example 1: Sign up a new user
  Future<void> exampleSignUp(String email, String password) async {
    try {
      final response = await SupabaseService.signUpWithEmail(
        email: email,
        password: password,
      );

      if (response.user != null) {
        print('User signed up: ${response.user!.email}');
      }
    } catch (e) {
      print('Sign up error: $e');
    }
  }

  /// Example 2: Sign in an existing user
  Future<void> exampleSignIn(String email, String password) async {
    try {
      final response = await SupabaseService.signInWithEmail(
        email: email,
        password: password,
      );

      if (response.user != null) {
        print('User signed in: ${response.user!.email}');
      }
    } catch (e) {
      print('Sign in error: $e');
    }
  }

  /// Example 3: Sign out
  Future<void> exampleSignOut() async {
    try {
      await SupabaseService.signOut();
      print('User signed out');
    } catch (e) {
      print('Sign out error: $e');
    }
  }

  /// Example 4: Check if user is signed in
  void exampleCheckAuth() {
    if (SupabaseService.isSignedIn) {
      print('User is signed in: ${SupabaseService.currentUser?.email}');
    } else {
      print('No user signed in');
    }
  }

  /// Example 5: Listen to auth state changes
  Widget exampleAuthStateListener() {
    return StreamBuilder(
      stream: SupabaseService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final session = snapshot.data!.session;
          if (session != null) {
            return Text('Logged in as: ${session.user.email}');
          }
        }
        return const Text('Not logged in');
      },
    );
  }

  // ============= DATABASE EXAMPLES =============

  /// Example 6: Fetch data from a table
  Future<void> exampleFetchData() async {
    try {
      // Replace 'users' with your actual table name
      final data = await SupabaseService.getDataFromTable('users');
      print('Fetched ${data.length} records');

      for (var record in data) {
        print(record);
      }
    } catch (e) {
      print('Fetch error: $e');
    }
  }

  /// Example 7: Insert data into a table
  Future<void> exampleInsertData() async {
    try {
      await SupabaseService.insertData('posts', {
        'title': 'My First Post',
        'content': 'Hello from Supabase!',
        'user_id': SupabaseService.currentUser?.id,
        'created_at': DateTime.now().toIso8601String(),
      });
      print('Data inserted successfully');
    } catch (e) {
      print('Insert error: $e');
    }
  }

  /// Example 8: Update data in a table
  Future<void> exampleUpdateData(String postId) async {
    try {
      await SupabaseService.updateData(
        'posts',
        {'title': 'Updated Title'},
        'id',
        postId,
      );
      print('Data updated successfully');
    } catch (e) {
      print('Update error: $e');
    }
  }

  /// Example 9: Delete data from a table
  Future<void> exampleDeleteData(String postId) async {
    try {
      await SupabaseService.deleteData('posts', 'id', postId);
      print('Data deleted successfully');
    } catch (e) {
      print('Delete error: $e');
    }
  }

  // ============= ADVANCED DATABASE QUERIES =============

  /// Example 10: Custom query with filters
  Future<void> exampleCustomQuery() async {
    try {
      // Using the raw supabase client for advanced queries
      final data = await supabase
          .from('posts')
          .select('id, title, content')
          .eq('user_id', SupabaseService.currentUser!.id)
          .order('created_at', ascending: false)
          .limit(10);

      print('Fetched ${data.length} posts');
    } catch (e) {
      print('Query error: $e');
    }
  }

  /// Example 11: Real-time subscription
  void exampleRealtimeSubscription() {
    // Subscribe to changes in a table
    // Store the subscription if you need to cancel it later
    supabase.from('posts').stream(primaryKey: ['id']).listen((data) {
      print('Posts updated: ${data.length} records');
    });

    // To cancel subscription later, store it in a variable:
    // final subscription = supabase.from('posts').stream(primaryKey: ['id']).listen(...);
    // Then call: subscription.cancel();
  }

  // ============= STORAGE EXAMPLES =============

  /// Example 12: Upload a file to Supabase Storage
  Future<void> exampleUploadFile(String filePath, String fileName) async {
    try {
      final bytes = await _readFileBytes(filePath); // Implement this

      await supabase.storage
          .from('avatars') // Your bucket name
          .uploadBinary('public/$fileName', bytes);

      // Get public URL
      final url = supabase.storage
          .from('avatars')
          .getPublicUrl('public/$fileName');

      print('File uploaded: $url');
    } catch (e) {
      print('Upload error: $e');
    }
  }

  Future<Uint8List> _readFileBytes(String filePath) async {
    // Implement file reading logic
    // Example: return await File(filePath).readAsBytes();
    return Uint8List(0);
  }
}

/// IMPORTANT NOTES:
/// 
/// 1. Make sure your .env file contains:
///    SUPABASE_URL=https://tcubtylogolarbylgteo.supabase.co
///    SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
/// 
/// 2. Create tables in your Supabase dashboard before querying them
/// 
/// 3. Set up Row Level Security (RLS) policies in Supabase for data protection
/// 
/// 4. For phone authentication, add the phone auth provider in Supabase dashboard
/// 
/// 5. Always handle errors appropriately in production code
