import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class PlanService {
  static const String baseUrl = 'http://192.168.1.190:8000/api';

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return <String, dynamic>{'data': decoded};
    } catch (_) {
      return <String, dynamic>{'message': response.body};
    }
  }

  static bool _isSuccessful(http.Response response) {
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  static Map<String, dynamic> _notLoggedInResponse({
    Map<String, dynamic>? additionalData,
  }) {
    return {
      'success': false,
      'message': 'User is not logged in.',
      ...?additionalData,
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

  static Map<String, dynamic> _resultFromResponse(
    http.Response response, {
    String? fallbackMessage,
  }) {
    final data = _decodeResponse(response);

    return {
      ...data,
      'success': _isSuccessful(response),
      if (fallbackMessage != null)
        'message': data['message'] ?? fallbackMessage,
    };
  }

  static int? _nullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;

    return int.tryParse(value.toString());
  }

  static bool _boolValue(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is int) return value == 1;

    final text = value.toString().trim().toLowerCase();

    return text == 'true' || text == '1';
  }

  static List<int> _intList(dynamic value) {
    if (value is! List) {
      return <int>[];
    }

    return value.map(_nullableInt).whereType<int>().toSet().toList();
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) {
      return <String>[];
    }

    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  static List<Map<String, dynamic>> _normalizeResponsibilityItems(
    List<Map<String, dynamic>> items,
  ) {
    return items
        .map((item) {
          final title = (item['title'] ?? item['task'] ?? '').toString().trim();

          final memberUserId = _nullableInt(
            item['member_user_id'] ?? item['memberUserId'] ?? item['userId'],
          );

          final itemId = _nullableInt(item['id']);

          final slotsValue = _nullableInt(item['slots']) ?? 1;
          final slots = slotsValue < 1 ? 1 : slotsValue;

          final contribution = item['contribution']?.toString().trim() ?? '';

          final preassignedUserIds = _intList(
            item['preassigned_user_ids'] ??
                item['preassignedUserIds'] ??
                item['preAssignedUserIds'],
          );

          final manualPreassignedNames = _stringList(
            item['manual_preassigned_names'] ??
                item['manualPreassignedNames'] ??
                item['manualPreAssignedNames'],
          );

          return <String, dynamic>{
            'id': itemId,
            'title': title,
            'member_user_id': memberUserId,
            'is_manual': _boolValue(
              item['is_manual'] ?? item['isManual'],
              fallback: memberUserId == null,
            ),
            'contribution': contribution,
            'slots': slots,
            if (preassignedUserIds.isNotEmpty)
              'preassigned_user_ids': preassignedUserIds,
            if (manualPreassignedNames.isNotEmpty)
              'manual_preassigned_names': manualPreassignedNames,
          };
        })
        .where((item) => item['title'].toString().trim().isNotEmpty)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Plans
  // ---------------------------------------------------------------------------

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
      return _notLoggedInResponse();
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

    return _resultFromResponse(response);
  }

  static Future<Map<String, dynamic>> getPlans() async {
    final headers = await _authHeaders();

    if (headers == null) {
      return _notLoggedInResponse(
        additionalData: {'plans_by_me': [], 'plans_with_me': []},
      );
    }

    final response = await http.get(
      Uri.parse('$baseUrl/plans'),
      headers: headers,
    );

    return _resultFromResponse(response);
  }

  static Future<Map<String, dynamic>> getPlanById(int planId) async {
    final headers = await _authHeaders();

    if (headers == null) {
      return _notLoggedInResponse(additionalData: {'plan': null});
    }

    final response = await http.get(
      Uri.parse('$baseUrl/plans/$planId'),
      headers: headers,
    );

    return _resultFromResponse(response);
  }

  static Future<Map<String, dynamic>> joinPlan({
    required String inviteCode,
  }) async {
    final headers = await _authHeaders(hasBody: true);

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final response = await http.post(
      Uri.parse('$baseUrl/plans/join'),
      headers: headers,
      body: jsonEncode({'invite_code': inviteCode.trim()}),
    );

    return _resultFromResponse(response);
  }

  static Future<Map<String, dynamic>> sendPlanInvitation({
    required int planId,
    required String username,
  }) async {
    final cleanUsername = username.trim().replaceFirst(RegExp(r'^@+'), '');

    if (cleanUsername.isEmpty) {
      return {
        'success': false,
        'code': 'invalid_username',
        'message': 'Enter a username.',
      };
    }

    final headers = await _authHeaders(hasBody: true);

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final response = await http.post(
      Uri.parse('$baseUrl/plans/$planId/invitations'),
      headers: headers,
      body: jsonEncode({'username': cleanUsername}),
    );

    return _resultFromResponse(
      response,
      fallbackMessage: 'Unable to send the invitation.',
    );
  }

  static Future<Map<String, dynamic>> getPlanInvitations() async {
    final headers = await _authHeaders();

    if (headers == null) {
      return _notLoggedInResponse(
        additionalData: {
          'invitations': <Map<String, dynamic>>[],
          'unread_count': 0,
        },
      );
    }

    final response = await http.get(
      Uri.parse('$baseUrl/invitations'),
      headers: headers,
    );

    return _resultFromResponse(
      response,
      fallbackMessage: 'Unable to load invitations.',
    );
  }

  static Future<Map<String, dynamic>> markPlanInvitationRead({
    required int invitationId,
  }) async {
    final headers = await _authHeaders();

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final response = await http.patch(
      Uri.parse(
        '$baseUrl/invitations/'
        '$invitationId/read',
      ),
      headers: headers,
    );

    return _resultFromResponse(
      response,
      fallbackMessage: 'Unable to mark the invitation as read.',
    );
  }

  static Future<Map<String, dynamic>> respondToPlanInvitation({
    required int invitationId,
    required String responseValue,
  }) async {
    if (responseValue != 'accepted' && responseValue != 'declined') {
      return {
        'success': false,
        'message': 'Choose whether to accept or decline the invitation.',
      };
    }

    final headers = await _authHeaders(hasBody: true);

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final response = await http.patch(
      Uri.parse(
        '$baseUrl/invitations/'
        '$invitationId/respond',
      ),
      headers: headers,
      body: jsonEncode({'response': responseValue}),
    );

    return _resultFromResponse(
      response,
      fallbackMessage: 'Unable to respond to the invitation.',
    );
  }

  // ---------------------------------------------------------------------------
  // Unified Activity
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> getActivityFeed() async {
    final headers = await _authHeaders();

    if (headers == null) {
      return _notLoggedInResponse(
        additionalData: {
          'activities': <Map<String, dynamic>>[],
          'unread_count': 0,
        },
      );
    }

    final response = await http.get(
      Uri.parse('$baseUrl/activity'),
      headers: headers,
    );

    return _resultFromResponse(
      response,
      fallbackMessage: 'Unable to load activity.',
    );
  }

  static Future<Map<String, dynamic>> markActivityNotificationRead({
    required int notificationId,
  }) async {
    final headers = await _authHeaders();

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final response = await http.patch(
      Uri.parse(
        '$baseUrl/activity-notifications/'
        '$notificationId/read',
      ),
      headers: headers,
    );

    return _resultFromResponse(
      response,
      fallbackMessage: 'Unable to mark the notification as read.',
    );
  }

  static Future<Map<String, dynamic>> markAllActivityRead() async {
    final headers = await _authHeaders();

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final response = await http.patch(
      Uri.parse('$baseUrl/activity/read-all'),
      headers: headers,
    );

    return _resultFromResponse(
      response,
      fallbackMessage: 'Unable to mark activity as read.',
    );
  }

  static Future<Map<String, dynamic>> leavePlan(
    int planId, {
    int? newAdminId,
  }) async {
    final headers = await _authHeaders(hasBody: newAdminId != null);

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final response = await http.post(
      Uri.parse('$baseUrl/plans/$planId/leave'),
      headers: headers,
      body: newAdminId == null
          ? null
          : jsonEncode({'new_admin_id': newAdminId}),
    );

    return _resultFromResponse(response);
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
      return _notLoggedInResponse();
    }

    final response = await http.patch(
      Uri.parse('$baseUrl/plans/$planId'),
      headers: headers,
      body: jsonEncode({
        'title': title.trim(),
        'description': description,
        'plan_date': planDate,
        'location': location,
        'status': status,
        'banner_color': bannerColor,
      }),
    );

    return _resultFromResponse(response);
  }

  static Future<Map<String, dynamic>> deletePlan(int planId) async {
    final headers = await _authHeaders();

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final response = await http.delete(
      Uri.parse('$baseUrl/plans/$planId'),
      headers: headers,
    );

    return _resultFromResponse(
      response,
      fallbackMessage: 'Plan moved to Deleted Plans.',
    );
  }

  // ---------------------------------------------------------------------------
  // Archived Plans
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> getArchivedPlans() async {
    final headers = await _authHeaders();

    if (headers == null) {
      return _notLoggedInResponse(
        additionalData: {'plansByMe': [], 'plansWithMe': []},
      );
    }

    final response = await http.get(
      Uri.parse('$baseUrl/archived-plans'),
      headers: headers,
    );

    return _resultFromResponse(response);
  }

  static Future<Map<String, dynamic>> archivePlan(int planId) async {
    final headers = await _authHeaders();

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final response = await http.post(
      Uri.parse('$baseUrl/plans/$planId/archive'),
      headers: headers,
    );

    return _resultFromResponse(
      response,
      fallbackMessage: 'Plan archived successfully.',
    );
  }

  static Future<Map<String, dynamic>> unarchivePlan(int planId) async {
    final headers = await _authHeaders();

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final response = await http.post(
      Uri.parse('$baseUrl/plans/$planId/unarchive'),
      headers: headers,
    );

    return _resultFromResponse(
      response,
      fallbackMessage: 'Plan restored from Archived Plans.',
    );
  }

  // ---------------------------------------------------------------------------
  // Deleted Plans
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> getDeletedPlans() async {
    final headers = await _authHeaders();

    if (headers == null) {
      return _notLoggedInResponse(
        additionalData: {'plansByMe': [], 'plansWithMe': []},
      );
    }

    final response = await http.get(
      Uri.parse('$baseUrl/deleted-plans'),
      headers: headers,
    );

    return _resultFromResponse(response);
  }

  static Future<Map<String, dynamic>> restorePlan(int planId) async {
    final headers = await _authHeaders();

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final response = await http.post(
      Uri.parse('$baseUrl/plans/$planId/restore'),
      headers: headers,
    );

    return _resultFromResponse(
      response,
      fallbackMessage: 'Plan restored successfully.',
    );
  }

  static Future<Map<String, dynamic>> permanentDeletePlan(int planId) async {
    final headers = await _authHeaders();

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final response = await http.delete(
      Uri.parse('$baseUrl/plans/$planId/force'),
      headers: headers,
    );

    return _resultFromResponse(
      response,
      fallbackMessage: 'Plan permanently deleted.',
    );
  }

  // ---------------------------------------------------------------------------
  // Feed Posts
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> getPlanPosts(int planId) async {
    final headers = await _authHeaders();

    if (headers == null) {
      return _notLoggedInResponse(additionalData: {'posts': []});
    }

    final response = await http.get(
      Uri.parse('$baseUrl/plans/$planId/posts'),
      headers: headers,
    );

    return _resultFromResponse(response);
  }

  // ---------------------------------------------------------------------------
  // Post Comments
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> getPostComments({
    required int postId,
  }) async {
    final headers = await _authHeaders();

    if (headers == null) {
      return _notLoggedInResponse(
        additionalData: {
          'comments': <Map<String, dynamic>>[],
          'comment_count': 0,
        },
      );
    }

    final response = await http.get(
      Uri.parse(
        '$baseUrl/plan-posts/'
        '$postId/comments',
      ),
      headers: headers,
    );

    return _resultFromResponse(
      response,
      fallbackMessage: 'Unable to load comments.',
    );
  }

  static Future<Map<String, dynamic>> addPostComment({
    required int postId,
    required String content,
  }) async {
    final cleanContent = content.trim();

    if (cleanContent.isEmpty) {
      return {'success': false, 'message': 'Please write a comment.'};
    }

    if (cleanContent.length > 2000) {
      return {
        'success': false,
        'message': 'Comments cannot exceed 2,000 characters.',
      };
    }

    final headers = await _authHeaders(hasBody: true);

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final response = await http.post(
      Uri.parse(
        '$baseUrl/plan-posts/'
        '$postId/comments',
      ),
      headers: headers,
      body: jsonEncode({'content': cleanContent}),
    );

    return _resultFromResponse(
      response,
      fallbackMessage: 'Unable to add the comment.',
    );
  }

  static Future<Map<String, dynamic>> deletePostComment({
    required int commentId,
  }) async {
    final headers = await _authHeaders();

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final response = await http.delete(
      Uri.parse(
        '$baseUrl/plan-post-comments/'
        '$commentId',
      ),
      headers: headers,
    );

    return _resultFromResponse(
      response,
      fallbackMessage: 'Unable to delete the comment.',
    );
  }

  static Future<Map<String, dynamic>> createPlanPost({
    required int planId,
    String content = '',
    File? imageFile,
  }) async {
    final headers = await _authHeaders();

    if (headers == null) {
      return _notLoggedInResponse();
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
        await http.MultipartFile.fromPath('image', imageFile.path),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    return _resultFromResponse(response);
  }

  static Future<Map<String, dynamic>> togglePostPin({
    required int postId,
    required bool isPinned,
  }) async {
    final headers = await _authHeaders(hasBody: true);

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final response = await http.patch(
      Uri.parse('$baseUrl/plan-posts/$postId/pin'),
      headers: headers,
      body: jsonEncode({'is_pinned': isPinned}),
    );

    return _resultFromResponse(response);
  }

  static Future<Map<String, dynamic>> deletePost({required int postId}) async {
    final headers = await _authHeaders();

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final response = await http.delete(
      Uri.parse('$baseUrl/plan-posts/$postId'),
      headers: headers,
    );

    return _resultFromResponse(
      response,
      fallbackMessage: 'Post deleted successfully.',
    );
  }

  // ---------------------------------------------------------------------------
  // Polls
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> createPollPost({
    required int planId,
    required String question,
    required List<String> options,
    bool allowMultiple = false,
    bool anonymous = false,
    bool allowMembersAddOptions = false,
    String? endsOn,
    DateTime? votingStartsAt,
    DateTime? votingEndsAt,
  }) async {
    final headers = await _authHeaders(hasBody: true);

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final cleanQuestion = question.trim();

    final cleanOptions = options
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty)
        .toList();

    if (cleanQuestion.isEmpty) {
      return {'success': false, 'message': 'Please enter a poll question.'};
    }

    if (cleanOptions.length < 2) {
      return {
        'success': false,
        'message': 'Please add at least two poll options.',
      };
    }

    final body = <String, dynamic>{
      'post_type': 'poll',
      'poll_question': cleanQuestion,
      'poll_options': cleanOptions,
      'allow_multiple': allowMultiple,
      'anonymous': anonymous,
      'allow_members_add_options': allowMembersAddOptions,
      'ends_on': endsOn,
    };

    if (votingStartsAt != null) {
      body['voting_starts_at'] = votingStartsAt.toIso8601String();
    }

    if (votingEndsAt != null) {
      body['voting_ends_at'] = votingEndsAt.toIso8601String();
    }

    final response = await http.post(
      Uri.parse('$baseUrl/plans/$planId/posts'),
      headers: headers,
      body: jsonEncode(body),
    );

    return _resultFromResponse(response);
  }

  static Future<Map<String, dynamic>> votePollPost({
    required int postId,
    required List<int> optionIndexes,
  }) async {
    final headers = await _authHeaders(hasBody: true);

    if (headers == null) {
      return _notLoggedInResponse();
    }

    if (optionIndexes.isEmpty) {
      return {'success': false, 'message': 'Please select an option.'};
    }

    final response = await http.post(
      Uri.parse('$baseUrl/plan-posts/$postId/vote'),
      headers: headers,
      body: jsonEncode({'option_indexes': optionIndexes}),
    );

    return _resultFromResponse(response);
  }

  static Future<Map<String, dynamic>> addPollOption({
    required int postId,
    required String option,
  }) async {
    final headers = await _authHeaders(hasBody: true);

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final cleanOption = option.trim();

    if (cleanOption.isEmpty) {
      return {'success': false, 'message': 'Please enter an option.'};
    }

    final response = await http.post(
      Uri.parse('$baseUrl/plan-posts/$postId/options'),
      headers: headers,
      body: jsonEncode({'option': cleanOption}),
    );

    return _resultFromResponse(response);
  }

  static Future<Map<String, dynamic>> togglePollVoting({
    required int postId,
    required bool isVotingClosed,
  }) async {
    final headers = await _authHeaders(hasBody: true);

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final response = await http.patch(
      Uri.parse('$baseUrl/plan-posts/$postId/voting'),
      headers: headers,
      body: jsonEncode({'is_voting_closed': isVotingClosed}),
    );

    return _resultFromResponse(response);
  }

  static Future<Map<String, dynamic>> updatePollPost({
    required int postId,
    String? question,
    List<String>? options,
    bool? allowMultiple,
    bool? anonymous,
    bool? allowMembersAddOptions,
    String? endsOn,
    DateTime? votingStartsAt,
    DateTime? votingEndsAt,
  }) async {
    final headers = await _authHeaders(hasBody: true);

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final body = <String, dynamic>{};

    if (question != null) {
      body['poll_question'] = question.trim();
    }

    if (options != null) {
      body['poll_options'] = options
          .map((option) => option.trim())
          .where((option) => option.isNotEmpty)
          .toList();
    }

    if (allowMultiple != null) {
      body['allow_multiple'] = allowMultiple;
    }

    if (anonymous != null) {
      body['anonymous'] = anonymous;
    }

    if (allowMembersAddOptions != null) {
      body['allow_members_add_options'] = allowMembersAddOptions;
    }

    if (endsOn != null) {
      body['ends_on'] = endsOn;
    }

    if (votingStartsAt != null) {
      body['voting_starts_at'] = votingStartsAt.toIso8601String();
    }

    if (votingEndsAt != null) {
      body['voting_ends_at'] = votingEndsAt.toIso8601String();
    }

    final response = await http.patch(
      Uri.parse('$baseUrl/plan-posts/$postId/poll'),
      headers: headers,
      body: jsonEncode(body),
    );

    return _resultFromResponse(response);
  }

  // ---------------------------------------------------------------------------
  // Responsibilities / Decide Who Does What
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> createResponsibilityPost({
    required int planId,
    required String title,
    required String mode,
    required List<Map<String, dynamic>> items,
    bool allowMembersAddItems = false,
    bool showProgress = true,
  }) async {
    final headers = await _authHeaders(hasBody: true);

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final cleanTitle = title.trim();

    if (cleanTitle.isEmpty) {
      return {'success': false, 'message': 'Please enter a title.'};
    }

    if (mode != 'person_based' && mode != 'role_task_based') {
      return {'success': false, 'message': 'Invalid responsibility mode.'};
    }

    final cleanItems = _normalizeResponsibilityItems(items);

    if (cleanItems.isEmpty) {
      return {
        'success': false,
        'message': mode == 'person_based'
            ? 'Please add at least one person.'
            : 'Please add at least one role or task.',
      };
    }

    final response = await http.post(
      Uri.parse('$baseUrl/plans/$planId/responsibilities'),
      headers: headers,
      body: jsonEncode({
        'responsibility_title': cleanTitle,
        'responsibility_mode': mode,
        'responsibility_allow_member_items': allowMembersAddItems,
        'responsibility_show_progress': showProgress,
        'items': cleanItems,
      }),
    );

    return _resultFromResponse(
      response,
      fallbackMessage: 'Responsibilities created successfully.',
    );
  }

  static Future<Map<String, dynamic>> updateResponsibilityPost({
    required int postId,
    String? title,
    String? mode,
    List<Map<String, dynamic>>? items,
    bool? allowMembersAddItems,
    bool? showProgress,
  }) async {
    final headers = await _authHeaders(hasBody: true);

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final body = <String, dynamic>{};

    if (title != null) {
      final cleanTitle = title.trim();

      if (cleanTitle.isEmpty) {
        return {'success': false, 'message': 'Please enter a title.'};
      }

      body['responsibility_title'] = cleanTitle;
    }

    if (mode != null) {
      if (mode != 'person_based' && mode != 'role_task_based') {
        return {'success': false, 'message': 'Invalid responsibility mode.'};
      }

      body['responsibility_mode'] = mode;
    }

    if (items != null) {
      final cleanItems = _normalizeResponsibilityItems(items);

      if (cleanItems.isEmpty) {
        return {'success': false, 'message': 'Please add at least one item.'};
      }

      body['items'] = cleanItems;
    }

    if (allowMembersAddItems != null) {
      body['responsibility_allow_member_items'] = allowMembersAddItems;
    }

    if (showProgress != null) {
      body['responsibility_show_progress'] = showProgress;
    }

    if (body.isEmpty) {
      return {'success': false, 'message': 'There are no changes to save.'};
    }

    final response = await http.patch(
      Uri.parse('$baseUrl/plan-posts/$postId/responsibility'),
      headers: headers,
      body: jsonEncode(body),
    );

    return _resultFromResponse(
      response,
      fallbackMessage: 'Responsibilities updated successfully.',
    );
  }

  static Future<Map<String, dynamic>> toggleResponsibilityFinalized({
    required int postId,
    required bool isFinalized,
  }) async {
    final headers = await _authHeaders(hasBody: true);

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final response = await http.patch(
      Uri.parse('$baseUrl/plan-posts/$postId/responsibility/finalized'),
      headers: headers,
      body: jsonEncode({'is_finalized': isFinalized}),
    );

    return _resultFromResponse(
      response,
      fallbackMessage: isFinalized
          ? 'Responsibilities finalized successfully.'
          : 'Responsibilities reopened successfully.',
    );
  }

  static Future<Map<String, dynamic>> addResponsibilityItem({
    required int postId,
    required Map<String, dynamic> item,
  }) async {
    final headers = await _authHeaders(hasBody: true);

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final normalizedItems = _normalizeResponsibilityItems([item]);

    if (normalizedItems.isEmpty) {
      return {
        'success': false,
        'message': 'Please enter a person, role, or task.',
      };
    }

    final response = await http.post(
      Uri.parse('$baseUrl/plan-posts/$postId/responsibility/items'),
      headers: headers,
      body: jsonEncode(normalizedItems.first),
    );

    return _resultFromResponse(
      response,
      fallbackMessage: 'Item added successfully.',
    );
  }

  static Future<Map<String, dynamic>> updateResponsibilityContribution({
    required int itemId,
    required String contribution,
  }) async {
    final headers = await _authHeaders(hasBody: true);

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final response = await http.patch(
      Uri.parse('$baseUrl/responsibility-items/$itemId/contribution'),
      headers: headers,
      body: jsonEncode({'contribution': contribution.trim()}),
    );

    return _resultFromResponse(
      response,
      fallbackMessage: 'Contribution updated successfully.',
    );
  }

  static Future<Map<String, dynamic>> claimResponsibilityItem({
    required int itemId,
  }) async {
    final headers = await _authHeaders();

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final response = await http.post(
      Uri.parse('$baseUrl/responsibility-items/$itemId/claim'),
      headers: headers,
    );

    return _resultFromResponse(
      response,
      fallbackMessage: 'Responsibility claimed successfully.',
    );
  }

  static Future<Map<String, dynamic>> unclaimResponsibilityItem({
    required int itemId,
  }) async {
    final headers = await _authHeaders();

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final response = await http.delete(
      Uri.parse('$baseUrl/responsibility-items/$itemId/claim'),
      headers: headers,
    );

    return _resultFromResponse(
      response,
      fallbackMessage: 'Responsibility unclaimed successfully.',
    );
  }

  static Future<Map<String, dynamic>> respondToResponsibility({
    required int itemId,
    required String responseValue,
  }) async {
    final headers = await _authHeaders(hasBody: true);

    if (headers == null) {
      return _notLoggedInResponse();
    }

    if (responseValue != 'accepted' && responseValue != 'declined') {
      return {'success': false, 'message': 'Invalid assignment response.'};
    }

    final response = await http.patch(
      Uri.parse('$baseUrl/responsibility-items/$itemId/response'),
      headers: headers,
      body: jsonEncode({'response': responseValue}),
    );

    return _resultFromResponse(
      response,
      fallbackMessage: responseValue == 'accepted'
          ? 'Assignment accepted successfully.'
          : 'Assignment declined successfully.',
    );
  }

  static Future<Map<String, dynamic>> preassignResponsibilityPerson({
    required int itemId,
    int? userId,
    String? manualName,
  }) async {
    final headers = await _authHeaders(hasBody: true);

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final cleanManualName = manualName?.trim();

    if (userId == null &&
        (cleanManualName == null || cleanManualName.isEmpty)) {
      return {
        'success': false,
        'message': 'Please select a member or enter a name.',
      };
    }

    final response = await http.post(
      Uri.parse('$baseUrl/responsibility-items/$itemId/preassign'),
      headers: headers,
      body: jsonEncode({
        'user_id': userId,
        if (userId == null &&
            cleanManualName != null &&
            cleanManualName.isNotEmpty)
          'manual_name': cleanManualName,
      }),
    );

    return _resultFromResponse(
      response,
      fallbackMessage: 'Person pre-assigned successfully.',
    );
  }

  static Future<Map<String, dynamic>> removeResponsibilityPreassignment({
    required int itemId,
    required int assignmentId,
  }) async {
    final headers = await _authHeaders();

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final response = await http.delete(
      Uri.parse(
        '$baseUrl/responsibility-items/$itemId/preassign/$assignmentId',
      ),
      headers: headers,
    );

    return _resultFromResponse(
      response,
      fallbackMessage: 'Pre-assignment removed successfully.',
    );
  }
}
