import 'dart:convert';
import 'dart:typed_data';

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

  static Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String username,
    Uint8List? imageBytes,
    String? fileName,
    String? mimeType,
    http.Client? client,
  }) async {
    final token = await getToken();

    if (token == null) {
      return {
        'success': false,
        'message': 'You must be logged in to update your profile.',
      };
    }

    try {
      final trimmedName = name.trim();
      final trimmedUsername = username.trim().replaceAll('@', '').trim();

      print('STEP 1');
      print('NAME TEXT = $name');
      print('USERNAME TEXT = $username');
      print('NAME = $trimmedName');
      print('USERNAME = $trimmedUsername');
      print('Sending profile update');

      final hasImage = imageBytes != null && imageBytes.isNotEmpty;
      final payload = jsonEncode({
        'name': trimmedName,
        'username': trimmedUsername,
      });

      print('REQUEST PAYLOAD = $payload');

      if (!hasImage) {
        final baseClient = client ?? http.Client();

        try {
          final response = await baseClient.put(
            Uri.parse('$baseUrl/user/profile'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: payload,
          ).timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('Profile update request timed out after 30 seconds.'),
          );

          print('RESPONSE STATUS = ${response.statusCode}');
          print('RESPONSE BODY = ${response.body}');

          final decoded = _safeJsonDecode(response.body);

          if (response.statusCode < 200 || response.statusCode >= 300) {
            return {
              'success': false,
              'message': decoded['message'] ?? 'Profile update failed (HTTP ${response.statusCode}).',
              'statusCode': response.statusCode,
              'body': response.body,
            };
          }

          return {
            'success': true,
            'message': decoded['message'] ?? 'Profile updated successfully.',
            'statusCode': response.statusCode,
            'user': decoded['user'],
            'body': response.body,
          };
        } finally {
          if (client == null) {
            baseClient.close();
          }
        }
      }

      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/user/profile'),
      );

      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });
      request.fields.addAll({
        'name': trimmedName,
        'username': trimmedUsername,
      });

      final mediaType = mimeType != null && mimeType.trim().isNotEmpty
          ? http.MediaType.parse(mimeType.trim())
          : null;

      request.files.add(
        http.MultipartFile.fromBytes(
          'photo',
          imageBytes!,
          filename: (fileName != null && fileName.trim().isNotEmpty)
              ? fileName.trim()
              : 'profile_picture.jpg',
          contentType: mediaType,
        ),
      );

      print('MULTIPART REQUEST URL = ${request.url}');
      print('MULTIPART REQUEST FIELDS = ${request.fields.toString()}');
      print('MULTIPART REQUEST FILES = ${request.files.map((f) => {
        'field': f.field,
        'filename': f.filename,
        'contentType': f.contentType?.mimeType,
        'length': f.length,
      }).toList()}');
      print('MULTIPART REQUEST PAYLOAD = {name: ${request.fields['name']}, username: ${request.fields['username']}, photo: ${request.files.firstWhere((f) => f.field == 'photo').filename}}');

      final baseClient = client ?? http.Client();

      try {
        final streamedResponse = await baseClient.send(request).timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw Exception('Profile update request timed out after 30 seconds.'),
        );

        final response = await http.Response.fromStream(streamedResponse);

      print('STEP 2');
      print('RESPONSE STATUS = ${response.statusCode}');
      print('STEP 3');
      print('RESPONSE BODY = ${response.body}');

      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return {
          'success': false,
          'message': decoded['message'] ?? 'Profile update failed (HTTP ${response.statusCode}).',
          'statusCode': response.statusCode,
          'body': response.body,
        };
      }

        return {
          'success': true,
          'message': decoded['message'] ?? 'Profile updated successfully.',
          'statusCode': response.statusCode,
          'user': decoded['user'],
          'body': response.body,
        };
      } finally {
        if (client == null) {
          baseClient.close();
        }
      }
    } catch (e, stackTrace) {
      print('Save Profile failed: $e');
      print('Save Profile stacktrace: $stackTrace');
      return {
        'success': false,
        'message': 'Profile update failed: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final token = await getToken();

    if (token == null) {
      return {
        'message': 'You must be logged in to change your password.',
      };
    }

    final response = await http.post(
      Uri.parse('$baseUrl/user/password'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'current_password': currentPassword,
        'password': newPassword,
        'password_confirmation': confirmPassword,
      }),
    );

    print('CHANGE PASSWORD STATUS: ${response.statusCode}');
    print('CHANGE PASSWORD BODY: ${response.body}');

    return _safeJsonDecode(response.body);
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