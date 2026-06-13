import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class PlanService {
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.body.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(response.body);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return <String, dynamic>{'data': decoded};
  }

  static Future<Map<String, String>?> _authHeaders({
    bool hasBody = false,
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      return null;
    }

    return {
      'Accept': 'application/json',
      if (hasBody) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> createPlan({
    required String title,
    String? description,
    String? planDate,
    String? planTime,
    String? location,
    double? latitude,
    double? longitude,
    String status = 'Plan Ongoing',
  }) async {
    final headers = await _authHeaders(hasBody: true);

    if (headers == null) {
      return {'success': false, 'message': 'User is not logged in.'};
    }

    final response = await http.post(
      Uri.parse('$baseUrl/plans'),
      headers: headers,
      body: jsonEncode({
        'title': title,
        'description': description,
        'plan_date': planDate,
        'plan_time': planTime,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'status': status,
      }),
    );

    final data = _decodeResponse(response);

    return {
      ...data,
      'success': response.statusCode >= 200 && response.statusCode < 300,
    };
  }

  static Future<Map<String, dynamic>> getPlans() async {
    final headers = await _authHeaders();

    if (headers == null) {
      return {
        'success': false,
        'message': 'User is not logged in.',
        'plans_by_me': [],
        'plans_with_me': [],
      };
    }

    final response = await http.get(
      Uri.parse('$baseUrl/plans'),
      headers: headers,
    );

    final data = _decodeResponse(response);

    return {
      ...data,
      'success': response.statusCode >= 200 && response.statusCode < 300,
    };
  }

  static Future<Map<String, dynamic>> getPlanById(int planId) async {
    final headers = await _authHeaders();

    if (headers == null) {
      return {
        'success': false,
        'message': 'User is not logged in.',
        'plan': null,
      };
    }

    final response = await http.get(
      Uri.parse('$baseUrl/plans/$planId'),
      headers: headers,
    );

    final data = _decodeResponse(response);

    return {
      ...data,
      'success': response.statusCode >= 200 && response.statusCode < 300,
    };
  }

  static Future<Map<String, dynamic>> joinPlan({
    required String inviteCode,
  }) async {
    final headers = await _authHeaders(hasBody: true);

    if (headers == null) {
      return {'success': false, 'message': 'User is not logged in.'};
    }

    final response = await http.post(
      Uri.parse('$baseUrl/plans/join'),
      headers: headers,
      body: jsonEncode({'invite_code': inviteCode}),
    );

    final data = _decodeResponse(response);

    return {
      ...data,
      'success': response.statusCode >= 200 && response.statusCode < 300,
    };
  }

  static Future<Map<String, dynamic>> leavePlan(
    int planId, {
    int? newAdminId,
  }) async {
    final headers = await _authHeaders(hasBody: newAdminId != null);

    if (headers == null) {
      return {'success': false, 'message': 'User is not logged in.'};
    }

    final response = await http.post(
      Uri.parse('$baseUrl/plans/$planId/leave'),
      headers: headers,
      body: newAdminId != null
          ? jsonEncode({'new_admin_id': newAdminId})
          : null,
    );

    final data = _decodeResponse(response);

    return {
      ...data,
      'success': response.statusCode >= 200 && response.statusCode < 300,
    };
  }

  static Future<Map<String, dynamic>> updatePlan({
    required int planId,
    required String title,
    String? description,
    String? planDate,
    String? location,
    String? status,
    String? bannerColor,
  }) async {
    final headers = await _authHeaders(hasBody: true);

    if (headers == null) {
      return {'success': false, 'message': 'User is not logged in.'};
    }

    final response = await http.patch(
      Uri.parse('$baseUrl/plans/$planId'),
      headers: headers,
      body: jsonEncode({
        'title': title,
        'description': description,
        'plan_date': planDate,
        'location': location,
        'status': status,
        'banner_color': ?bannerColor,
      }),
    );

    final data = _decodeResponse(response);

    return {
      ...data,
      'success': response.statusCode >= 200 && response.statusCode < 300,
    };
  }

  static Future<Map<String, dynamic>> deletePlan(int planId) async {
    final headers = await _authHeaders();

    if (headers == null) {
      return {'success': false, 'message': 'User is not logged in.'};
    }

    final response = await http.delete(
      Uri.parse('$baseUrl/plans/$planId'),
      headers: headers,
    );

    final data = _decodeResponse(response);

    return {
      ...data,
      'success': response.statusCode >= 200 && response.statusCode < 300,
      'message': data['message'] ?? 'Plan moved to Deleted Plans.',
    };
  }

  static Future<Map<String, dynamic>> getArchivedPlans() async {
    final headers = await _authHeaders();

    if (headers == null) {
      return {
        'success': false,
        'message': 'User is not logged in.',
        'plansByMe': [],
        'plansWithMe': [],
      };
    }

    final response = await http.get(
      Uri.parse('$baseUrl/archived-plans'),
      headers: headers,
    );

    final data = _decodeResponse(response);

    return {
      ...data,
      'success': response.statusCode >= 200 && response.statusCode < 300,
    };
  }

  static Future<Map<String, dynamic>> archivePlan(int planId) async {
    final headers = await _authHeaders();

    if (headers == null) {
      return {'success': false, 'message': 'User is not logged in.'};
    }

    final response = await http.post(
      Uri.parse('$baseUrl/plans/$planId/archive'),
      headers: headers,
    );

    final data = _decodeResponse(response);

    return {
      ...data,
      'success': response.statusCode >= 200 && response.statusCode < 300,
      'message': data['message'] ?? 'Plan archived successfully.',
    };
  }

  static Future<Map<String, dynamic>> unarchivePlan(int planId) async {
    final headers = await _authHeaders();

    if (headers == null) {
      return {'success': false, 'message': 'User is not logged in.'};
    }

    final response = await http.post(
      Uri.parse('$baseUrl/plans/$planId/unarchive'),
      headers: headers,
    );

    final data = _decodeResponse(response);

    return {
      ...data,
      'success': response.statusCode >= 200 && response.statusCode < 300,
      'message': data['message'] ?? 'Plan restored from Archived Plans.',
    };
  }

  static Future<Map<String, dynamic>> getDeletedPlans() async {
    final headers = await _authHeaders();

    if (headers == null) {
      return {
        'success': false,
        'message': 'User is not logged in.',
        'plansByMe': [],
        'plansWithMe': [],
      };
    }

    final response = await http.get(
      Uri.parse('$baseUrl/deleted-plans'),
      headers: headers,
    );

    final data = _decodeResponse(response);

    return {
      ...data,
      'success': response.statusCode >= 200 && response.statusCode < 300,
    };
  }

  static Future<Map<String, dynamic>> restorePlan(int planId) async {
    final headers = await _authHeaders();

    if (headers == null) {
      return {'success': false, 'message': 'User is not logged in.'};
    }

    final response = await http.post(
      Uri.parse('$baseUrl/plans/$planId/restore'),
      headers: headers,
    );

    final data = _decodeResponse(response);

    return {
      ...data,
      'success': response.statusCode >= 200 && response.statusCode < 300,
      'message': data['message'] ?? 'Plan restored successfully.',
    };
  }

  static Future<Map<String, dynamic>> permanentDeletePlan(int planId) async {
    final headers = await _authHeaders();

    if (headers == null) {
      return {'success': false, 'message': 'User is not logged in.'};
    }

    final response = await http.delete(
      Uri.parse('$baseUrl/plans/$planId/force'),
      headers: headers,
    );

    final data = _decodeResponse(response);

    return {
      ...data,
      'success': response.statusCode >= 200 && response.statusCode < 300,
      'message': data['message'] ?? 'Plan permanently deleted.',
    };
  }

  static Future<Map<String, dynamic>> getPlanPosts(int planId) async {
    final headers = await _authHeaders();

    if (headers == null) {
      return {
        'success': false,
        'message': 'User is not logged in.',
        'posts': [],
      };
    }

    final response = await http.get(
      Uri.parse('$baseUrl/plans/$planId/posts'),
      headers: headers,
    );

    final data = _decodeResponse(response);

    return {
      ...data,
      'success': response.statusCode >= 200 && response.statusCode < 300,
    };
  }

  static Future<Map<String, dynamic>> createPlanPost({
    required int planId,
    required String content,
  }) async {
    final headers = await _authHeaders(hasBody: true);

    if (headers == null) {
      return {'success': false, 'message': 'User is not logged in.'};
    }

    final response = await http.post(
      Uri.parse('$baseUrl/plans/$planId/posts'),
      headers: headers,
      body: jsonEncode({'content': content}),
    );

    final data = _decodeResponse(response);

    return {
      ...data,
      'success': response.statusCode >= 200 && response.statusCode < 300,
    };
  }
}
