import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class QuickDecisionService {
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<List<dynamic>> getWheels() async {
    final response = await http.get(Uri.parse('$baseUrl/wheels'), headers: await _headers());
    return _decodeList(response);
  }

  static Future<Map<String, dynamic>> createWheel(String title, List<Map<String, dynamic>> options) async {
    final response = await http.post(
      Uri.parse('$baseUrl/wheels'),
      headers: await _headers(),
      body: jsonEncode({'title': title, 'options': options}),
    );
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> updateWheel(int wheelId, String title, List<Map<String, dynamic>> options) async {
    final response = await http.put(
      Uri.parse('$baseUrl/wheels/$wheelId'),
      headers: await _headers(),
      body: jsonEncode({'title': title, 'options': options}),
    );
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> deleteWheel(int wheelId) async {
    final response = await http.delete(Uri.parse('$baseUrl/wheels/$wheelId'), headers: await _headers());
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> deleteWheelOption(int optionId) async {
    final response = await http.delete(Uri.parse('$baseUrl/wheels/options/$optionId'), headers: await _headers());
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> shuffleWheel(int wheelId) async {
    final response = await http.post(Uri.parse('$baseUrl/wheels/$wheelId/shuffle'), headers: await _headers());
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> sortWheel(int wheelId) async {
    final response = await http.post(Uri.parse('$baseUrl/wheels/$wheelId/sort'), headers: await _headers());
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> spinWheel(int wheelId) async {
    final response = await http.post(Uri.parse('$baseUrl/wheels/$wheelId/spin'), headers: await _headers());
    return _decodeMap(response);
  }

  static Future<List<dynamic>> getPolls() async {
    final response = await http.get(Uri.parse('$baseUrl/polls'), headers: await _headers());
    return _decodeList(response);
  }

  static Future<Map<String, dynamic>> createPoll(String title, int durationSeconds, List<Map<String, dynamic>> options) async {
    final response = await http.post(
      Uri.parse('$baseUrl/polls'),
      headers: await _headers(),
      body: jsonEncode({'title': title, 'duration_seconds': durationSeconds, 'options': options}),
    );
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> updatePoll(int pollId, String title, int durationSeconds, List<Map<String, dynamic>> options) async {
    final response = await http.put(
      Uri.parse('$baseUrl/polls/$pollId'),
      headers: await _headers(),
      body: jsonEncode({'title': title, 'duration_seconds': durationSeconds, 'options': options}),
    );
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> deletePoll(int pollId) async {
    final response = await http.delete(Uri.parse('$baseUrl/polls/$pollId'), headers: await _headers());
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> startPoll(int pollId) async {
    final response = await http.post(Uri.parse('$baseUrl/polls/$pollId/start'), headers: await _headers());
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> votePoll(int pollId, int optionId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/polls/$pollId/vote'),
      headers: await _headers(),
      body: jsonEncode({'option_id': optionId}),
    );
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> getPollResults(int pollId) async {
    final response = await http.get(Uri.parse('$baseUrl/polls/$pollId/results'), headers: await _headers());
    return _decodeMap(response);
  }

  static List<dynamic> _decodeList(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      return decoded is List ? decoded : [decoded];
    }
    throw Exception('Quick decision request failed (${response.statusCode}): ${response.body}');
  }

  static Map<String, dynamic> _decodeMap(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded is Map<String, dynamic> ? decoded : {'message': decoded.toString()};
    }
    return {
      'success': false,
      'message': decoded is Map<String, dynamic> ? (decoded['message'] ?? 'Request failed') : decoded.toString(),
      'statusCode': response.statusCode,
      'body': response.body,
    };
  }
}
