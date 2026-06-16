import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = 'http://192.168.1.190:8000/api';

  // ─────────────────────────────────────────────
  // TOKEN
  // ─────────────────────────────────────────────

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

  // ─────────────────────────────────────────────
  // REGISTER
  // ─────────────────────────────────────────────

  static Future<Map<String, dynamic>> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name.trim(),
          'username': _normalizeUsername(username),
          'email': email.trim().toLowerCase(),
          'password': password,
        }),
      );

      _debugResponse(label: 'REGISTER', response: response);

      final result = _decodeResponse(response);
      final token = result['token']?.toString();

      if (token != null && token.isNotEmpty) {
        await saveToken(token);
      }

      return result;
    } catch (error) {
      debugPrint('REGISTER ERROR: $error');

      return _connectionErrorResult(error);
    }
  }

  // ─────────────────────────────────────────────
  // LOGIN
  // ─────────────────────────────────────────────

  static Future<Map<String, dynamic>> login({
    required String login,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'login': login.trim(), 'password': password}),
      );

      _debugResponse(label: 'LOGIN', response: response);

      final result = _decodeResponse(response);
      final token = result['token']?.toString();

      if (token != null && token.isNotEmpty) {
        await saveToken(token);
      }

      return result;
    } catch (error) {
      debugPrint('LOGIN ERROR: $error');

      return _connectionErrorResult(error);
    }
  }

  // ─────────────────────────────────────────────
  // CURRENT USER
  // ─────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      _debugResponse(label: 'CURRENT USER', response: response);

      if (response.statusCode == 401) {
        await removeToken();

        return null;
      }

      if (!_isSuccessful(response.statusCode)) {
        return null;
      }

      return _safeJsonDecode(response.body);
    } catch (error) {
      debugPrint('CURRENT USER ERROR: $error');

      return null;
    }
  }

  // ─────────────────────────────────────────────
  // USER SETTINGS
  // ─────────────────────────────────────────────

  static Future<Map<String, dynamic>> getUserSettings() async {
    return _authenticatedJsonRequest(method: 'GET', path: '/user/settings');
  }

  // ─────────────────────────────────────────────
  // PROFILE
  // ─────────────────────────────────────────────

  static Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String username,
    Uint8List? photoBytes,
    String photoFilename = 'profile_photo.jpg',
    bool removePhoto = false,
  }) async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      return _unauthenticatedResult();
    }

    try {
      /*
       * Laravel handles multipart file uploads reliably through
       * POST with method spoofing.
       *
       * The backend still treats this as:
       * PUT /api/user/profile
       */
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/user/profile'),
      );

      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      request.fields.addAll({
        '_method': 'PUT',
        'name': name.trim(),
        'username': _normalizeUsername(username),
        'remove_photo': removePhoto ? '1' : '0',
      });

      if (photoBytes != null && photoBytes.isNotEmpty) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'photo',
            photoBytes,
            filename: photoFilename,
          ),
        );
      }

      final streamedResponse = await request.send();

      final response = await http.Response.fromStream(streamedResponse);

      _debugResponse(label: 'UPDATE PROFILE', response: response);

      if (response.statusCode == 401) {
        await removeToken();
      }

      return _decodeResponse(response);
    } catch (error) {
      debugPrint('UPDATE PROFILE ERROR: $error');

      return {
        'success': false,
        'message': 'Unable to update profile.',
        'error': error.toString(),
      };
    }
  }

  // ─────────────────────────────────────────────
  // USERNAME AVAILABILITY
  // ─────────────────────────────────────────────

  static Future<Map<String, dynamic>> checkUsername({
    required String username,
  }) async {
    final cleanUsername = _normalizeUsername(username);
    final token = await getToken();

    try {
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

      /*
       * The token is optional because this endpoint is also used
       * publicly during Sign Up.
       *
       * When included, the backend can exclude the logged-in
       * user's current username from duplicate checking.
       */
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.post(
        Uri.parse('$baseUrl/check-username'),
        headers: headers,
        body: jsonEncode({'username': cleanUsername}),
      );

      _debugResponse(label: 'CHECK USERNAME', response: response);

      return _decodeResponse(response);
    } catch (error) {
      debugPrint('CHECK USERNAME ERROR: $error');

      return {
        'success': false,
        'available': false,
        'message': 'Unable to check username availability.',
        'error': error.toString(),
      };
    }
  }

  // ─────────────────────────────────────────────
  // USERNAME UPDATE
  // Kept for backward compatibility.
  // The Settings page now saves username through updateProfile().
  // ─────────────────────────────────────────────

  static Future<Map<String, dynamic>> updateUsername({
    required String username,
  }) async {
    return _authenticatedJsonRequest(
      method: 'PATCH',
      path: '/user/username',
      body: {'username': _normalizeUsername(username)},
    );
  }

  // ─────────────────────────────────────────────
  // NOTIFICATION PREFERENCES
  // ─────────────────────────────────────────────

  static Future<Map<String, dynamic>> updateNotificationPreferences({
    required bool emailReminders,
    required bool pushNotifications,
    required bool inAppAlerts,
  }) async {
    return _authenticatedJsonRequest(
      method: 'PATCH',
      path: '/user/notifications',
      body: {
        'email_reminders': emailReminders,
        'push_notifications': pushNotifications,
        'in_app_alerts': inAppAlerts,
      },
    );
  }

  // ─────────────────────────────────────────────
  // PASSWORD
  // ─────────────────────────────────────────────

  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    return _authenticatedJsonRequest(
      method: 'POST',
      path: '/user/password',
      body: {
        'current_password': currentPassword,
        'password': newPassword,
        'password_confirmation': confirmPassword,
      },
    );
  }

  // ─────────────────────────────────────────────
  // LOGOUT
  // ─────────────────────────────────────────────

  static Future<Map<String, dynamic>> logout() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      await removeToken();

      return {'success': true, 'message': 'No user is currently logged in.'};
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/logout'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      _debugResponse(label: 'LOGOUT', response: response);

      await removeToken();

      if (response.body.trim().isEmpty) {
        return {
          'success': true,
          'status_code': response.statusCode,
          'message': 'Logged out successfully.',
        };
      }

      return _decodeResponse(response);
    } catch (error) {
      debugPrint('LOGOUT ERROR: $error');

      /*
       * Remove the local token even when the backend request fails.
       */
      await removeToken();

      return {'success': true, 'message': 'Logged out locally.'};
    }
  }

  // ─────────────────────────────────────────────
  // AUTHENTICATED JSON REQUEST
  // ─────────────────────────────────────────────

  static Future<Map<String, dynamic>> _authenticatedJsonRequest({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      return _unauthenticatedResult();
    }

    final uri = Uri.parse('$baseUrl$path');

    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      late final http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri, headers: headers);
          break;

        case 'POST':
          response = await http.post(
            uri,
            headers: headers,
            body: jsonEncode(body ?? {}),
          );
          break;

        case 'PUT':
          response = await http.put(
            uri,
            headers: headers,
            body: jsonEncode(body ?? {}),
          );
          break;

        case 'PATCH':
          response = await http.patch(
            uri,
            headers: headers,
            body: jsonEncode(body ?? {}),
          );
          break;

        case 'DELETE':
          response = await http.delete(
            uri,
            headers: headers,
            body: jsonEncode(body ?? {}),
          );
          break;

        default:
          return {
            'success': false,
            'message': 'Unsupported request method: $method',
          };
      }

      _debugResponse(label: '$method $path', response: response);

      if (response.statusCode == 401) {
        await removeToken();
      }

      return _decodeResponse(response);
    } catch (error) {
      debugPrint('$method $path ERROR: $error');

      return _connectionErrorResult(error);
    }
  }

  // ─────────────────────────────────────────────
  // RESPONSE HELPERS
  // ─────────────────────────────────────────────

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    final result = response.body.trim().isEmpty
        ? <String, dynamic>{}
        : _safeJsonDecode(response.body);

    final successful = _isSuccessful(response.statusCode);

    result.putIfAbsent('success', () => successful);

    result['status_code'] = response.statusCode;

    if (!successful && !result.containsKey('message')) {
      result['message'] = 'The request could not be completed.';
    }

    return result;
  }

  static Map<String, dynamic> _safeJsonDecode(String body) {
    try {
      final decoded = jsonDecode(body);

      if (decoded is Map<String, dynamic>) {
        return Map<String, dynamic>.from(decoded);
      }

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      return {'message': decoded.toString()};
    } catch (_) {
      return {
        'message': body.trim().isEmpty
            ? 'The server returned an empty response.'
            : body,
      };
    }
  }

  static Map<String, dynamic> _unauthenticatedResult() {
    return {
      'success': false,
      'status_code': 401,
      'message': 'Your session has expired. Please log in again.',
    };
  }

  static Map<String, dynamic> _connectionErrorResult(Object error) {
    return {
      'success': false,
      'message': 'Unable to connect to the server.',
      'error': error.toString(),
    };
  }

  static bool _isSuccessful(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }

  static String _normalizeUsername(String username) {
    return username.trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase();
  }

  static void _debugResponse({
    required String label,
    required http.Response response,
  }) {
    if (!kDebugMode) {
      return;
    }

    debugPrint('$label STATUS: ${response.statusCode}');

    debugPrint('$label BODY: ${response.body}');
  }
}
