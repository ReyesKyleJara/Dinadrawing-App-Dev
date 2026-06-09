import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  static Future<Map<String, dynamic>> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    print('REGISTER STATUS: ${response.statusCode}');
    print('REGISTER BODY: ${response.body}');

    final result = _safeJsonDecode(response.body);

    if (result.containsKey('token')) {
      await saveToken(result['token'].toString());
    }

    return result;
  }

  static Future<Map<String, dynamic>> login({
    required String login,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'login': login,
        'password': password,
      }),
    );

    print('LOGIN STATUS: ${response.statusCode}');
    print('LOGIN BODY: ${response.body}');

    final result = _safeJsonDecode(response.body);

    if (result.containsKey('token')) {
      await saveToken(result['token'].toString());
    }

    return result;
  }

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final token = await getToken();

    if (token == null) {
      return null;
    }

    final response = await http.get(
      Uri.parse('$baseUrl/user'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print('USER STATUS: ${response.statusCode}');
    print('USER BODY: ${response.body}');

    if (response.statusCode == 200) {
      return _safeJsonDecode(response.body);
    }

    return null;
  }

  static Future<Map<String, dynamic>> logout() async {
    final token = await getToken();

    if (token == null) {
      await removeToken();

      return {
        'message': 'No user is currently logged in.',
      };
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/logout'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('LOGOUT STATUS: ${response.statusCode}');
      print('LOGOUT BODY: ${response.body}');

      await removeToken();

      if (response.body.trim().isEmpty) {
        return {
          'message': 'Logged out successfully.',
        };
      }

      return _safeJsonDecode(response.body);
    } catch (e) {
      print('LOGOUT ERROR: $e');

      // Important: remove token locally even if backend logout request fails.
      await removeToken();

      return {
        'message': 'Logged out locally.',
      };
    }
  }

  static Map<String, dynamic> _safeJsonDecode(String body) {
    try {
      final decoded = jsonDecode(body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {
        'message': decoded.toString(),
      };
    } catch (_) {
      return {
        'message': body,
      };
    }
  }
}