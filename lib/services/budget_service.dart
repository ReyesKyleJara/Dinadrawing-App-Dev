import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'plan_service.dart';

class BudgetExpenseInput {
  const BudgetExpenseInput({
    required this.name,
    required this.estimatedAmount,
    this.note,
  });

  final String name;
  final double estimatedAmount;
  final String? note;

  Map<String, dynamic> toJson() {
    final cleanNote = note?.trim();

    return {
      'name': name.trim(),
      'estimated_amount': estimatedAmount,
      'note': cleanNote == null || cleanNote.isEmpty ? null : cleanNote,
    };
  }
}

class BudgetAllocationInput {
  const BudgetAllocationInput({
    this.allocationId,
    this.userId,
    this.manualName,
    required this.isIncluded,
    required this.plannedShare,
  });

  final int? allocationId;
  final int? userId;
  final String? manualName;
  final bool isIncluded;
  final double plannedShare;

  Map<String, dynamic> toJson() {
    final cleanManualName = manualName?.trim();

    return {
      if (allocationId != null) 'id': allocationId,
      'user_id': userId,
      'manual_name': cleanManualName == null || cleanManualName.isEmpty
          ? null
          : cleanManualName,
      'is_included': isIncluded,
      'planned_share': isIncluded ? plannedShare : 0,
    };
  }
}

class BudgetService {
  BudgetService._();

  static const Duration _requestTimeout = Duration(seconds: 25);

  /*
   * Reuses the same backend URL used by PlanService.
   *
   * This means you only need to update PlanService.baseUrl
   * when your MacBook IP address changes.
   */
  static String get baseUrl => PlanService.baseUrl;

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      return <String, dynamic>{'data': decoded};
    } catch (_) {
      return <String, dynamic>{'message': response.body};
    }
  }

  static bool _isSuccessful(http.Response response) {
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  static Future<Map<String, String>?> _authHeaders({
    bool hasBody = false,
  }) async {
    final token = await AuthService.getToken();

    if (token == null || token.trim().isEmpty) {
      return null;
    }

    return {
      'Accept': 'application/json',
      if (hasBody) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Map<String, dynamic> _notLoggedInResponse() {
    return {
      'success': false,
      'status_code': 401,
      'message': 'User is not logged in.',
    };
  }

  static Map<String, dynamic> _resultFromResponse(
    http.Response response, {
    String? fallbackMessage,
  }) {
    final data = _decodeResponse(response);
    final success = _isSuccessful(response);

    return {
      ...data,
      'success': success,
      'status_code': response.statusCode,
      if (fallbackMessage != null &&
          (data['message'] == null ||
              data['message'].toString().trim().isEmpty))
        'message': fallbackMessage,
    };
  }

  static Future<Map<String, dynamic>> _executeRequest(
    Future<http.Response> Function() request, {
    String? fallbackMessage,
  }) async {
    try {
      final response = await request().timeout(_requestTimeout);

      return _resultFromResponse(response, fallbackMessage: fallbackMessage);
    } on TimeoutException {
      return {
        'success': false,
        'status_code': null,
        'message':
            'The request took too long. Check your connection and try again.',
      };
    } catch (_) {
      return {
        'success': false,
        'status_code': null,
        'message':
            'Unable to connect to the server. Check your connection and try again.',
      };
    }
  }

  static String errorMessage(
    Map<String, dynamic> result, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    final errors = result['errors'];

    if (errors is Map) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }

        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
    }

    final message = result['message']?.toString().trim();

    if (message != null && message.isNotEmpty) {
      return message;
    }

    return fallback;
  }

  static Map<String, dynamic>? budgetFromResult(Map<String, dynamic> result) {
    final rawBudget = result['budget'];

    if (rawBudget is Map) {
      return Map<String, dynamic>.from(rawBudget);
    }

    return null;
  }

  static List<Map<String, dynamic>> membersFromResult(
    Map<String, dynamic> result,
  ) {
    final rawMembers = result['available_members'];

    if (rawMembers is! List) {
      return <Map<String, dynamic>>[];
    }

    return rawMembers
        .whereType<Map>()
        .map((member) => Map<String, dynamic>.from(member))
        .toList();
  }

  static Map<String, dynamic>? _validateBudgetInput({
    required String splitType,
    required List<BudgetExpenseInput> expenses,
    required List<BudgetAllocationInput> allocations,
  }) {
    if (splitType != 'equal' && splitType != 'custom') {
      return {
        'success': false,
        'message': 'Choose either Split Equally or Custom Allocation.',
      };
    }

    if (expenses.isEmpty) {
      return {'success': false, 'message': 'Add at least one planned expense.'};
    }

    for (final expense in expenses) {
      if (expense.name.trim().isEmpty) {
        return {'success': false, 'message': 'Every expense must have a name.'};
      }

      if (expense.estimatedAmount <= 0) {
        return {
          'success': false,
          'message': 'Every expense must have an amount greater than zero.',
        };
      }
    }

    if (allocations.isEmpty) {
      return {
        'success': false,
        'message': 'Add at least one person to the budget.',
      };
    }

    final includedPeople = allocations.where(
      (allocation) => allocation.isIncluded,
    );

    if (includedPeople.isEmpty) {
      return {
        'success': false,
        'message': 'Add at least one person to the budget.',
      };
    }

    final userIds = <int>{};
    final manualNames = <String>{};

    for (final allocation in allocations) {
      final cleanManualName = allocation.manualName?.trim() ?? '';

      final hasUser = allocation.userId != null;

      final hasManualName = cleanManualName.isNotEmpty;

      /*
       * Valid:
       *
       * Actual member:
       * userId != null
       * manualName empty
       *
       * Manual person:
       * userId == null
       * manualName not empty
       */
      if (hasUser == hasManualName) {
        return {
          'success': false,
          'message':
              'Each budget person must be either a plan member or a manually added name.',
        };
      }

      if (allocation.userId != null && !userIds.add(allocation.userId!)) {
        return {
          'success': false,
          'message': 'The same plan member was added more than once.',
        };
      }

      if (hasManualName && !manualNames.add(cleanManualName.toLowerCase())) {
        return {
          'success': false,
          'message': 'The same manually added person appears more than once.',
        };
      }
    }

    if (splitType == 'custom') {
      for (final allocation in includedPeople) {
        if (allocation.plannedShare < 0) {
          return {
            'success': false,
            'message': 'A planned share cannot be negative.',
          };
        }
      }

      final estimatedBudget = expenses.fold<double>(0, (sum, expense) {
        return sum + expense.estimatedAmount;
      });

      final allocatedAmount = includedPeople.fold<double>(0, (sum, allocation) {
        return sum + allocation.plannedShare;
      });

      final excess = allocatedAmount - estimatedBudget;

      /*
       * Custom allocation may leave an amount
       * unallocated.
       *
       * It becomes invalid only when shares exceed
       * the estimated budget.
       */
      if (excess >= 0.01) {
        return {
          'success': false,
          'message': 'Custom allocations cannot exceed the estimated budget.',
        };
      }
    }

    return null;
  }

  static Map<String, dynamic> _buildBudgetPayload({
    required String splitType,
    required List<BudgetExpenseInput> expenses,
    required List<BudgetAllocationInput> allocations,
  }) {
    return {
      'split_type': splitType,
      'expenses': expenses.map((expense) => expense.toJson()).toList(),
      'allocations': allocations
          .map((allocation) => allocation.toJson())
          .toList(),
    };
  }

  // ---------------------------------------------------------------------------
  // Load Budget
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> getBudget(int planId) async {
    final headers = await _authHeaders();

    if (headers == null) {
      return _notLoggedInResponse();
    }

    return _executeRequest(() {
      return http.get(
        Uri.parse('$baseUrl/plans/$planId/budget'),
        headers: headers,
      );
    }, fallbackMessage: 'Unable to load the budget.');
  }

  // ---------------------------------------------------------------------------
  // Create Budget
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> createBudget({
    required int planId,
    required String splitType,
    required List<BudgetExpenseInput> expenses,
    required List<BudgetAllocationInput> allocations,
  }) async {
    final validationError = _validateBudgetInput(
      splitType: splitType,
      expenses: expenses,
      allocations: allocations,
    );

    if (validationError != null) {
      return validationError;
    }

    final headers = await _authHeaders(hasBody: true);

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final payload = _buildBudgetPayload(
      splitType: splitType,
      expenses: expenses,
      allocations: allocations,
    );

    return _executeRequest(() {
      return http.post(
        Uri.parse('$baseUrl/plans/$planId/budget'),
        headers: headers,
        body: jsonEncode(payload),
      );
    }, fallbackMessage: 'Unable to create the budget.');
  }

  // ---------------------------------------------------------------------------
  // Update Budget
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> updateBudget({
    required int planId,
    required String splitType,
    required List<BudgetExpenseInput> expenses,
    required List<BudgetAllocationInput> allocations,
  }) async {
    final validationError = _validateBudgetInput(
      splitType: splitType,
      expenses: expenses,
      allocations: allocations,
    );

    if (validationError != null) {
      return validationError;
    }

    final headers = await _authHeaders(hasBody: true);

    if (headers == null) {
      return _notLoggedInResponse();
    }

    final payload = _buildBudgetPayload(
      splitType: splitType,
      expenses: expenses,
      allocations: allocations,
    );

    return _executeRequest(() {
      return http.put(
        Uri.parse('$baseUrl/plans/$planId/budget'),
        headers: headers,
        body: jsonEncode(payload),
      );
    }, fallbackMessage: 'Unable to update the budget.');
  }

  // ---------------------------------------------------------------------------
  // Contribution Tracking Settings
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> updateContributionSettings({
    required int planId,
    bool? contributionTrackingEnabled,
    bool? allowMemberMarkPaid,
    bool? showStatusToMembers,
  }) async {
    final body = <String, dynamic>{};

    if (contributionTrackingEnabled != null) {
      body['contribution_tracking_enabled'] = contributionTrackingEnabled;
    }

    if (allowMemberMarkPaid != null) {
      body['allow_member_mark_paid'] = allowMemberMarkPaid;
    }

    if (showStatusToMembers != null) {
      body['show_status_to_members'] = showStatusToMembers;
    }

    if (body.isEmpty) {
      return {
        'success': false,
        'message': 'There are no contribution settings to save.',
      };
    }

    final headers = await _authHeaders(hasBody: true);

    if (headers == null) {
      return _notLoggedInResponse();
    }

    return _executeRequest(() {
      return http.patch(
        Uri.parse('$baseUrl/plans/$planId/budget/settings'),
        headers: headers,
        body: jsonEncode(body),
      );
    }, fallbackMessage: 'Unable to update contribution tracking settings.');
  }

  // ---------------------------------------------------------------------------
  // Resolve Budget Review
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> resolveBudgetReview({
    required int planId,
    required String action,
  }) async {
    if (action != 'redistribute_equally' && action != 'keep_unallocated') {
      return {
        'success': false,
        'message': 'Choose how the departed member share should be handled.',
      };
    }

    final headers = await _authHeaders(hasBody: true);

    if (headers == null) {
      return _notLoggedInResponse();
    }

    return _executeRequest(() {
      return http.patch(
        Uri.parse('$baseUrl/plans/$planId/budget/review'),
        headers: headers,
        body: jsonEncode({'action': action}),
      );
    }, fallbackMessage: 'Unable to resolve the budget review.');
  }

  // ---------------------------------------------------------------------------
  // Paid / Unpaid
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> setContributionPaidStatus({
    required int planId,
    required int allocationId,
    required bool isPaid,
  }) async {
    final headers = await _authHeaders(hasBody: true);

    if (headers == null) {
      return _notLoggedInResponse();
    }

    return _executeRequest(
      () {
        return http.patch(
          Uri.parse(
            '$baseUrl/plans/$planId/budget/allocations/$allocationId/paid',
          ),
          headers: headers,
          body: jsonEncode({'is_paid': isPaid}),
        );
      },
      fallbackMessage: isPaid
          ? 'Unable to mark the contribution as paid.'
          : 'Unable to mark the contribution as unpaid.',
    );
  }

  // ---------------------------------------------------------------------------
  // Reset Budget
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> resetBudget(int planId) async {
    final headers = await _authHeaders();

    if (headers == null) {
      return _notLoggedInResponse();
    }

    return _executeRequest(() {
      return http.delete(
        Uri.parse('$baseUrl/plans/$planId/budget'),
        headers: headers,
      );
    }, fallbackMessage: 'Unable to reset the budget.');
  }
}
