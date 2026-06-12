import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dinadrawing/services/auth_service.dart';

class CapturingClient extends http.BaseClient {
  final List<http.BaseRequest> requests = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);

    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({
        'success': true,
        'message': 'Profile updated successfully',
      }))),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('updateProfile sends name and username fields in multipart request', () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'token-123'});

    final client = CapturingClient();

    final result = await AuthService.updateProfile(
      name: '  jovan  ',
      username: '@jovan',
      imageBytes: Uint8List.fromList([1, 2, 3]),
      client: client,
    );

    expect(result['success'], isTrue);
    expect(client.requests, hasLength(1));
    expect(client.requests.single, isA<http.MultipartRequest>());
    final multipartRequest = client.requests.single as http.MultipartRequest;
    expect(multipartRequest.fields['name'], 'jovan');
    expect(multipartRequest.fields['username'], 'jovan');
    expect(multipartRequest.fields.containsKey('display_name'), isFalse);
    expect(multipartRequest.fields.containsKey('full_name'), isFalse);
    expect(multipartRequest.fields.containsKey('user_name'), isFalse);
    expect(multipartRequest.headers['Authorization'], 'Bearer token-123');
  });

  test('updateProfile uses JSON when no image is attached', () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'token-123'});

    final client = CapturingClient();

    final result = await AuthService.updateProfile(
      name: 'jovan',
      username: 'jovan',
      imageBytes: null,
      client: client,
    );

    expect(result['success'], isTrue);
    expect(client.requests, hasLength(1));
    expect(client.requests.single, isA<http.Request>());
    expect((client.requests.single as http.Request).headers['Content-Type'], contains('application/json'));
  });

  test('updateProfile sends the profile image as photo in multipart request', () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'token-123'});

    final client = CapturingClient();

    final result = await AuthService.updateProfile(
      name: 'jovan',
      username: 'jovan',
      imageBytes: Uint8List.fromList([1, 2, 3]),
      client: client,
    );

    expect(result['success'], isTrue);
    expect(client.requests, hasLength(1));
    expect(client.requests.single, isA<http.MultipartRequest>());
    final multipartRequest = client.requests.single as http.MultipartRequest;
    expect(multipartRequest.files, isNotEmpty);
    expect(multipartRequest.files.any((file) => file.field == 'photo'), isTrue);
    final photoFile = multipartRequest.files.firstWhere((file) => file.field == 'photo');
    expect(photoFile.filename, 'profile_picture.jpg');
  });
}
