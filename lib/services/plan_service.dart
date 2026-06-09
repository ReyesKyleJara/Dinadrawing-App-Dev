import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class PlanService {
  static const String baseUrl = 'http://127.0.0.1:8000/api';

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
    final token = await AuthService.getToken();

    if (token == null) {
      return {
        'message': 'User is not logged in.',
      };
    }

    final response = await http.post(
      Uri.parse('$baseUrl/plans'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
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

    print('CREATE PLAN STATUS: ${response.statusCode}');
    print('CREATE PLAN BODY: ${response.body}');

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getPlans() async {
    final token = await AuthService.getToken();

    if (token == null) {
      return {
        'message': 'User is not logged in.',
        'plans_by_me': [],
        'plans_with_me': [],
      };
    }

    final response = await http.get(
      Uri.parse('$baseUrl/plans'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print('GET PLANS STATUS: ${response.statusCode}');
    print('GET PLANS BODY: ${response.body}');

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getPlanById(int planId) async {
    final token = await AuthService.getToken();

    if (token == null) {
      return {
        'message': 'User is not logged in.',
        'plan': null,
      };
    }

    final response = await http.get(
      Uri.parse('$baseUrl/plans/$planId'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print('GET SINGLE PLAN STATUS: ${response.statusCode}');
    print('GET SINGLE PLAN BODY: ${response.body}');

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> joinPlan({
    required String inviteCode,
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      return {
        'message': 'User is not logged in.',
      };
    }

    final response = await http.post(
      Uri.parse('$baseUrl/plans/join'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'invite_code': inviteCode,
      }),
    );

    print('JOIN PLAN STATUS: ${response.statusCode}');
    print('JOIN PLAN BODY: ${response.body}');

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getPlanPosts(int planId) async {
    final token = await AuthService.getToken();

    if (token == null) {
      return {
        'message': 'User is not logged in.',
        'posts': [],
      };
    }

    final response = await http.get(
      Uri.parse('$baseUrl/plans/$planId/posts'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print('GET PLAN POSTS STATUS: ${response.statusCode}');
    print('GET PLAN POSTS BODY: ${response.body}');

    return jsonDecode(response.body);
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
    final token = await AuthService.getToken();
    if (token == null) return {'message': 'User is not logged in.'};

    final response = await http.patch(
      Uri.parse('$baseUrl/plans/$planId'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'title': title,
        'description': description,
        'plan_date': planDate,
        'location': location,
        'status': status,
        if (bannerColor != null) 'banner_color': bannerColor,
      }),
    );

    print('UPDATE PLAN STATUS: ${response.statusCode}');
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> deletePlan(int planId) async {
    final token = await AuthService.getToken();
    if (token == null) return {'message': 'User is not logged in.'};

    final response = await http.delete(
      Uri.parse('$baseUrl/plans/$planId'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print('DELETE PLAN STATUS: ${response.statusCode}');
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> createPlanPost({
    required int planId,
    required String content,
  }) async {
    final token = await AuthService.getToken();

    if (token == null) {
      return {
        'message': 'User is not logged in.',
      };
    }

    final response = await http.post(
      Uri.parse('$baseUrl/plans/$planId/posts'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'content': content,
      }),
    );

    print('CREATE PLAN POST STATUS: ${response.statusCode}');
    print('CREATE PLAN POST BODY: ${response.body}');

    return jsonDecode(response.body);
  }
}