import 'dart:convert';
import 'dart:io';

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

    return <String, dynamic>{
      'data': decoded,
    };
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
      return {
        'success': false,
        'message': 'User is not logged in.',
      };
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
      return {
        'success': false,
        'message': 'User is not logged in.',
      };
    }

    final response = await http.post(
      Uri.parse('$baseUrl/plans/join'),
      headers: headers,
      body: jsonEncode({
        'invite_code': inviteCode,
      }),
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
      return {
        'success': false,
        'message': 'User is not logged in.',
      };
    }

    final response = await http.post(
      Uri.parse('$baseUrl/plans/$planId/leave'),
      headers: headers,
      body: newAdminId != null
          ? jsonEncode({
              'new_admin_id': newAdminId,
            })
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
      return {
        'success': false,
        'message': 'User is not logged in.',
      };
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
        if (bannerColor != null) 'banner_color': bannerColor,
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
      return {
        'success': false,
        'message': 'User is not logged in.',
      };
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
      return {
        'success': false,
        'message': 'User is not logged in.',
      };
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
      return {
        'success': false,
        'message': 'User is not logged in.',
      };
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
      return {
        'success': false,
        'message': 'User is not logged in.',
      };
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
      return {
        'success': false,
        'message': 'User is not logged in.',
      };
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
    String content = '',
    File? imageFile,
  }) async {
    final headers = await _authHeaders();

    if (headers == null) {
      return {
        'success': false,
        'message': 'User is not logged in.',
      };
    }

    if (content.trim().isEmpty && imageFile == null) {
      return {
        'success': false,
        'message': 'Please add text or an image before posting.',
      };
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/plans/$planId/posts'),
    );

    request.headers.addAll(headers);

    if (content.trim().isNotEmpty) {
      request.fields['content'] = content.trim();
    }

    if (imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
        ),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = _decodeResponse(response);

    return {
      ...data,
      'success': response.statusCode >= 200 && response.statusCode < 300,
    };
  }

  static Future<Map<String, dynamic>> createPollPost({
    required int planId,
    required String question,
    required List<String> options,
    bool allowMultiple = false,
    bool anonymous = true,
    bool allowMembersAddOptions = false,
    String? endsOn,
  }) async {
    final headers = await _authHeaders(hasBody: true);

    if (headers == null) {
      return {
        'success': false,
        'message': 'User is not logged in.',
      };
    }

    final cleanOptions = options
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty)
        .toList();

    if (question.trim().isEmpty) {
      return {
        'success': false,
        'message': 'Please enter a poll question.',
      };
    }

    if (cleanOptions.length < 2) {
      return {
        'success': false,
        'message': 'Please add at least two poll options.',
      };
    }

    final response = await http.post(
      Uri.parse('$baseUrl/plans/$planId/posts'),
      headers: headers,
      body: jsonEncode({
        'post_type': 'poll',
        'poll_question': question.trim(),
        'poll_options': cleanOptions,
        'allow_multiple': allowMultiple,
        'anonymous': anonymous,
        'allow_members_add_options': allowMembersAddOptions,
        'ends_on': endsOn,
      }),
    );

    final data = _decodeResponse(response);

    return {
      ...data,
      'success': response.statusCode >= 200 && response.statusCode < 300,
    };
  }
 static Future<Map<String, dynamic>> votePollPost({
  required int postId,
  required List<int> optionIndexes,
}) async {
  final headers = await _authHeaders(hasBody: true);

  if (headers == null) {
    return {
      'success': false,
      'message': 'User is not logged in.',
    };
  }

  if (optionIndexes.isEmpty) {
    return {
      'success': false,
      'message': 'Please select an option.',
    };
  }

  final response = await http.post(
    Uri.parse('$baseUrl/plan-posts/$postId/vote'),
    headers: headers,
    body: jsonEncode({
      'option_indexes': optionIndexes,
    }),
  );

  final data = _decodeResponse(response);

  return {
    ...data,
    'success': response.statusCode >= 200 && response.statusCode < 300,
  };
}


}