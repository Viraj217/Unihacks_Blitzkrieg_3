import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthService {
  // Get the base URL from environment or use default
  static String get _baseUrl {
    final port = dotenv.env['PORT'] ?? '3000';
    return 'http://localhost:$port';
  }

  /// Sign up a new user
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/user/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return AuthResponse(
          success: true,
          message: 'Signup successful',
          data: data,
        );
      } else {
        final error = jsonDecode(response.body);
        return AuthResponse(
          success: false,
          message: error['message'] ?? 'Signup failed',
          error: error,
        );
      }
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Network error: $e',
        error: e.toString(),
      );
    }
  }

  /// Login an existing user
  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/user/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AuthResponse(
          success: true,
          message: 'Login successful',
          data: data,
        );
      } else {
        final error = jsonDecode(response.body);
        return AuthResponse(
          success: false,
          message: error['message'] ?? 'Login failed',
          error: error,
        );
      }
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Network error: $e',
        error: e.toString(),
      );
    }
  }
}

/// Response class for authentication operations
class AuthResponse {
  final bool success;
  final String message;
  final dynamic data;
  final dynamic error;

  AuthResponse({
    required this.success,
    required this.message,
    this.data,
    this.error,
  });
}
