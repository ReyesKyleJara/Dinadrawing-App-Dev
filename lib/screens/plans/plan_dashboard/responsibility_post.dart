import 'package:flutter/material.dart';

import '../../../services/plan_service.dart';

class ResponsibilityPost extends StatefulWidget {
  final Map<String, dynamic> post;
  final List<Map<String, dynamic>> planMembers;
  final int? currentUserId;
  final ValueChanged<Map<String, dynamic>> onPostUpdated;

  const ResponsibilityPost({
    super.key,
    required this.post,
    required this.planMembers,
    required this.currentUserId,
    required this.onPostUpdated,
  });

  @override
  State<ResponsibilityPost> createState() =>
      _ResponsibilityPostState();
}

class _ResponsibilityPostState
    extends State<ResponsibilityPost> {
  static const Color brandYellow = Color(0xFFF5B335);
  static const Color brandYellowDark = Color(0xFFB87500);
  static const Color brandCream = Color(0xFFFFF8E8);
  static const Color brandCreamLight = Color(0xFFFFFCF4);
  static const Color softYellow = Color(0xFFFFE8A3);
  static const Color softBorder = Color(0xFFF2D999);

  late Map<String, dynamic> _post;

  final Set<int> _busyItemIds = <int>{};

  bool _isAddingItem = false;

  @override
  void initState() {
    super.initState();

    _post = Map<String, dynamic>.from(widget.post);
  }

  @override
  void didUpdateWidget(
    covariant ResponsibilityPost oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.post, widget.post)) {
      _post = Map<String, dynamic>.from(widget.post);
    }
  }

  int _parseInt(
    dynamic value, {
    int fallback = 0,
  }) {
    if (value == null) return fallback;
    if (value is int) return value;

    return int.tryParse(value.toString()) ?? fallback;
  }

  int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;

    return int.tryParse(value.toString());
  }

  bool _parseBool(
    dynamic value, {
    bool fallback = false,
  }) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is int) return value == 1;

    final text = value.toString().trim().toLowerCase();

    return text == 'true' || text == '1';
  }

  String _readString(
    Map<String, dynamic> map,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = map[key];

      if (value == null) continue;

      final text = value.toString().trim();

      if (text.isNotEmpty) {
        return text;
      }
    }

    return fallback;
  }

  dynamic _readValue(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      if (map.containsKey(key)) {
        return map[key];
      }
    }

    return null;
  }

  String get _mode {
    return _readString(
      _post,
      [
        'responsibility_mode',
        'responsibilityMode',
        'mode',
      ],
      fallback: 'person_based',
    );
  }

  bool get _isPersonBased {
    return _mode == 'person_based';
  }

  bool get _isFinalized {
    return _parseBool(
      _readValue(
        _post,
        [
          'responsibility_is_finalized',
          'responsibilityIsFinalized',
          'isFinalized',
        ],
      ),
    );
  }

  bool get _showProgress {
    return _parseBool(
      _readValue(
        _post,
        [
          'responsibility_show_progress',
          'responsibilityShowProgress',
          'showProgress',
        ],
      ),
      fallback: true,
    );
  }

  bool get _canAddItems {
    return _parseBool(
      _readValue(
        _post,
        [
          'can_add_responsibility_items',
          'canAddResponsibilityItems',
        ],
      ),
    );
  }

  String get _title {
    return _readString(
      _post,
      [
        'responsibility_title',
        'responsibilityTitle',
        'title',
        'content',
      ],
      fallback: 'Responsibilities',
    );
  }

  List<Map<String, dynamic>> get _items {
    final rawItems = _readValue(
      _post,
      [
        'responsibility_items',
        'responsibilityItems',
        'items',
      ],
    );

    if (rawItems is! List) {
      return <Map<String, dynamic>>[];
    }

    return rawItems
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

  List<Map<String, dynamic>> _assignments(
    Map<String, dynamic> item,
  ) {
    final rawAssignments = _readValue(
      item,
      [
        'assignments',
        'claimedBy',
        'claimed_by',
      ],
    );

    if (rawAssignments is! List) {
      return <Map<String, dynamic>>[];
    }

    return rawAssignments
        .whereType<Map>()
        .map(
          (assignment) =>
              Map<String, dynamic>.from(assignment),
        )
        .toList();
  }

  List<Map<String, dynamic>> _activeAssignments(
    Map<String, dynamic> item,
  ) {
    return _assignments(item).where((assignment) {
      final status = _readString(
        assignment,
        ['status'],
      );

      return status == 'accepted' || status == 'pending';
    }).toList();
  }

  Map<String, dynamic>? _currentUserAssignment(
    Map<String, dynamic> item,
  ) {
    final rawValue = _readValue(
      item,
      [
        'current_user_assignment',
        'currentUserAssignment',
      ],
    );

    if (rawValue is Map) {
      return Map<String, dynamic>.from(rawValue);
    }

    for (final assignment in _assignments(item)) {
      final isCurrentUser = _parseBool(
        _readValue(
          assignment,
          [
            'is_current_user',
            'isCurrentUser',
          ],
        ),
      );

      final userId = _parseNullableInt(
        _readValue(
          assignment,
          [
            'user_id',
            'userId',
          ],
        ),
      );

      if (isCurrentUser ||
          (userId != null &&
              widget.currentUserId != null &&
              userId == widget.currentUserId)) {
        return assignment;
      }
    }

    return null;
  }

  int get _totalCount {
    final backendValue = _parseNullableInt(
      _readValue(
        _post,
        [
          'responsibility_total_count',
          'responsibilityTotalCount',
          'totalCount',
        ],
      ),
    );

    if (backendValue != null) {
      return backendValue;
    }

    if (_isPersonBased) {
      return _items.length;
    }

    return _items.fold<int>(
      0,
      (sum, item) {
        return sum +
            _parseInt(
              item['slots'],
              fallback: 1,
            );
      },
    );
  }

  int get _filledCount {
    final backendValue = _parseNullableInt(
      _readValue(
        _post,
        [
          'responsibility_filled_count',
          'responsibilityFilledCount',
          'filledCount',
        ],
      ),
    );

    if (backendValue != null) {
      return backendValue;
    }

    if (_isPersonBased) {
      return _items.where((item) {
        return _readString(
          item,
          ['contribution'],
        ).isNotEmpty;
      }).length;
    }

    return _items.fold<int>(
      0,
      (sum, item) {
        final acceptedCount = _assignments(item).where(
          (assignment) {
            return _readString(
                  assignment,
                  ['status'],
                ) ==
                'accepted';
          },
        ).length;

        return sum + acceptedCount;
      },
    );
  }

  double get _progress {
    if (_totalCount <= 0) {
      return 0;
    }

    final rawProgress = _filledCount / _totalCount;

    return rawProgress.clamp(0.0, 1.0);
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _formatUsername(String username) {
    final cleanUsername = username.trim();

    if (cleanUsername.startsWith('@')) {
      return cleanUsername;
    }

    return '@$cleanUsername';
  }

  String _memberName(Map<String, dynamic> member) {
    final nestedUser = member['user'];

    if (nestedUser is Map) {
      final user = Map<String, dynamic>.from(nestedUser);

      final nestedName = _readString(
        user,
        [
          'name',
          'username',
          'email',
        ],
      );

      if (nestedName.isNotEmpty) {
        return nestedName;
      }
    }

    return _readString(
      member,
      [
        'displayName',
        'name',
        'username',
        'email',
      ],
      fallback: 'Member',
    );
  }

  String? _memberUsername(
    Map<String, dynamic> member,
  ) {
    final nestedUser = member['user'];

    if (nestedUser is Map) {
      final user = Map<String, dynamic>.from(nestedUser);
      final username = _readString(
        user,
        ['username'],
      );

      if (username.isNotEmpty) {
        return username;
      }
    }

    final username = _readString(
      member,
      ['username'],
    );

    return username.isEmpty ? null : username;
  }

  int? _memberId(Map<String, dynamic> member) {
    final nestedUser = member['user'];

    if (nestedUser is Map) {
      final user = Map<String, dynamic>.from(nestedUser);
      final id = _parseNullableInt(user['id']);

      if (id != null) {
        return id;
      }
    }

    return _parseNullableInt(
      member['id'] ?? member['user_id'],
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void _applyUpdatedPost(
    Map<String, dynamic> updatedPost,
  ) {
    setState(() {
      _post = Map<String, dynamic>.from(updatedPost);
    });

    widget.onPostUpdated(
      Map<String, dynamic>.from(updatedPost),
    );
  }

  Future<void> _runItemAction({
    required int itemId,
    required Future<Map<String, dynamic>> Function()
        request,
  }) async {
    if (_busyItemIds.contains(itemId)) {
      return;
    }

    setState(() {
      _busyItemIds.add(itemId);
    });

    try {
      final result = await request();

      if (!mounted) return;

      if (result['success'] == true &&
          result['post'] is Map) {
        _applyUpdatedPost(
          Map<String, dynamic>.from(
            result['post'] as Map,
          ),
        );
      } else {
        _showMessage(
          result['message']?.toString() ??
              'The action could not be completed.',
        );
      }
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Connection error: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyItemIds.remove(itemId);
        });
      }
    }
  }

  Future<bool> _showActionConfirmation({
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(
                cancelLabel,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: destructive
                    ? Colors.redAccent
                    : brandYellow,
                foregroundColor: destructive
                    ? Colors.white
                    : Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                confirmLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> _claimItem(
    Map<String, dynamic> item,
  ) async {
    final itemId = _parseInt(
      item['id'],
      fallback: -1,
    );

    if (itemId <= 0) {
      _showMessage('This role or task is invalid.');
      return;
    }

    final title = _readString(
      item,
      ['title'],
      fallback: 'this role/task',
    );

    final confirmed = await _showActionConfirmation(
      title: 'Claim this role/task?',
      message:
          'You’ll be added to “$title,” and the list creator may be notified.',
      confirmLabel: 'Claim',
    );

    if (!confirmed || !mounted) {
      return;
    }

    await _runItemAction(
      itemId: itemId,
      request: () {
        return PlanService.claimResponsibilityItem(
          itemId: itemId,
        );
      },
    );
  }

  Future<void> _unclaimItem(
    Map<String, dynamic> item,
  ) async {
    final itemId = _parseInt(
      item['id'],
      fallback: -1,
    );

    if (itemId <= 0) {
      _showMessage('This role or task is invalid.');
      return;
    }

    final title = _readString(
      item,
      ['title'],
      fallback: 'this role/task',
    );

    final confirmed = await _showActionConfirmation(
      title: 'Unclaim this role/task?',
      message:
          'Your spot in “$title” will become available to others.',
      confirmLabel: 'Unclaim',
      cancelLabel: 'Keep My Spot',
      destructive: true,
    );

    if (!confirmed || !mounted) {
      return;
    }

    await _runItemAction(
      itemId: itemId,
      request: () {
        return PlanService.unclaimResponsibilityItem(
          itemId: itemId,
        );
      },
    );
  }

  Future<void> _respondToPreAssignment({
    required Map<String, dynamic> item,
    required bool accept,
  }) async {
    final itemId = _parseInt(
      item['id'],
      fallback: -1,
    );

    if (itemId <= 0) {
      _showMessage('This role or task is invalid.');
      return;
    }

    final itemTitle = _readString(
      item,
      ['title'],
      fallback: 'this role/task',
    );

    final confirmed = await _showActionConfirmation(
      title: accept
          ? 'Accept this role/task?'
          : 'Decline this role/task?',
      message: accept
          ? 'You’ll be confirmed for “$itemTitle,” and the list creator may be notified.'
          : 'Your spot in “$itemTitle” will become available, and the list creator may be notified.',
      confirmLabel: accept ? 'Accept' : 'Decline',
      destructive: !accept,
    );

    if (!confirmed || !mounted) {
      return;
    }

    await _runItemAction(
      itemId: itemId,
      request: () {
        return PlanService.respondToResponsibility(
          itemId: itemId,
          responseValue:
              accept ? 'accepted' : 'declined',
        );
      },
    );
  }

  Future<void> _editContribution(
    Map<String, dynamic> item,
  ) async {
    final itemId = _parseInt(
      item['id'],
      fallback: -1,
    );

    if (itemId <= 0) {
      _showMessage('This entry is invalid.');
      return;
    }

    final personName = _readString(
      item,
      [
        'member_display_name',
        'memberDisplayName',
        'title',
      ],
      fallback: 'this person',
    );

    final controller = TextEditingController(
      text: _readString(
        item,
        ['contribution'],
      ),
    );

    final contribution = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'Entry for $personName',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 1,
            maxLines: 4,
            textCapitalization:
                TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText:
                  'What will they bring, share, or do?',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: brandYellow,
                  width: 1.5,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(
                  controller.text.trim(),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: brandYellow,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Save',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (contribution == null || !mounted) {
      return;
    }

    await _runItemAction(
      itemId: itemId,
      request: () {
        return PlanService.updateResponsibilityContribution(
          itemId: itemId,
          contribution: contribution,
        );
      },
    );
  }

  Set<int> _includedMemberIds() {
    return _items
        .map(
          (item) => _parseNullableInt(
            item['member_user_id'] ??
                item['memberUserId'],
          ),
        )
        .whereType<int>()
        .toSet();
  }

  List<Map<String, dynamic>> _availablePlanMembers(
    String query,
  ) {
    final includedIds = _includedMemberIds();
    final cleanQuery = query.trim().toLowerCase();

    return widget.planMembers.where((member) {
      final memberId = _memberId(member);

      if (memberId != null &&
          includedIds.contains(memberId)) {
        return false;
      }

      if (cleanQuery.isEmpty) {
        return true;
      }

      final name = _memberName(member).toLowerCase();
      final username =
          _memberUsername(member)?.toLowerCase() ?? '';

      return name.contains(cleanQuery) ||
          username.contains(cleanQuery);
    }).toList();
  }

  Future<Map<String, dynamic>?> _pickPersonToAdd() async {
    final controller = TextEditingController();
    String query = '';

    final result =
        await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final suggestions =
                _availablePlanMembers(query);

            final cleanQuery = query.trim();

            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                18,
                24,
                MediaQuery.of(sheetContext).viewInsets.bottom +
                    24,
              ),
              child: SizedBox(
                height:
                    MediaQuery.of(sheetContext).size.height *
                        0.70,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius:
                              BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Add person',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      onChanged: (value) {
                        setSheetState(() {
                          query = value;
                        });
                      },
                      textCapitalization:
                          TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText:
                            'Search a member or type a name',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        focusedBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: brandYellow,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: ListView(
                        children: [
                          if (suggestions.isNotEmpty) ...[
                            Text(
                              'Plan members',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...suggestions.map((member) {
                              final id = _memberId(member);
                              final name =
                                  _memberName(member);
                              final username =
                                  _memberUsername(member);

                              return Padding(
                                padding:
                                    const EdgeInsets.only(
                                  bottom: 8,
                                ),
                                child: InkWell(
                                  borderRadius:
                                      BorderRadius.circular(14),
                                  onTap: () {
                                    Navigator.of(sheetContext).pop({
                                      'title': name,
                                      'member_user_id': id,
                                      'is_manual': false,
                                      'contribution': '',
                                      'slots': 1,
                                    });
                                  },
                                  child: Container(
                                    padding:
                                        const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(14),
                                      border: Border.all(
                                        color:
                                            Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        _buildInitialAvatar(
                                          name: name,
                                          isManual: false,
                                          size: 38,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child:
                                              _buildIdentityText(
                                            name: name,
                                            username: username,
                                            isYou: id != null &&
                                                widget.currentUserId !=
                                                    null &&
                                                id ==
                                                    widget.currentUserId,
                                          ),
                                        ),
                                        const Icon(
                                          Icons
                                              .add_circle_outline_rounded,
                                          color: brandYellow,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                          if (cleanQuery.isNotEmpty) ...[
                            if (suggestions.isNotEmpty)
                              const SizedBox(height: 8),
                            InkWell(
                              borderRadius:
                                  BorderRadius.circular(14),
                              onTap: () {
                                Navigator.of(sheetContext).pop({
                                  'title': cleanQuery,
                                  'member_user_id': null,
                                  'is_manual': true,
                                  'contribution': '',
                                  'slots': 1,
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(13),
                                decoration: BoxDecoration(
                                  color: brandCream,
                                  borderRadius:
                                      BorderRadius.circular(14),
                                  border: Border.all(
                                    color: softBorder,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _buildInitialAvatar(
                                      name: cleanQuery,
                                      isManual: true,
                                      size: 38,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Add “$cleanQuery”',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight:
                                              FontWeight.w800,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();

    return result;
  }

  Future<Map<String, dynamic>?> _createRoleTaskItem() async {
    final controller = TextEditingController();
    int slots = 1;

    final result =
        await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                18,
                24,
                MediaQuery.of(sheetContext).viewInsets.bottom +
                    24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius:
                            BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Add role or task',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization:
                        TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Role or task',
                      hintText:
                          'e.g., Presenter, Buy materials',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: brandYellow,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: brandCreamLight,
                      borderRadius:
                          BorderRadius.circular(12),
                      border: Border.all(
                        color: softBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Available slots',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight.w800,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'How many people can take this?',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: slots <= 1
                              ? null
                              : () {
                                  setSheetState(() {
                                    slots--;
                                  });
                                },
                          icon: const Icon(
                            Icons
                                .remove_circle_outline_rounded,
                          ),
                          color: brandYellowDark,
                        ),
                        Text(
                          '$slots',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        IconButton(
                          onPressed: slots >= 50
                              ? null
                              : () {
                                  setSheetState(() {
                                    slots++;
                                  });
                                },
                          icon: const Icon(
                            Icons
                                .add_circle_outline_rounded,
                          ),
                          color: brandYellowDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final title =
                            controller.text.trim();

                        if (title.isEmpty) {
                          return;
                        }

                        Navigator.of(sheetContext).pop({
                          'title': title,
                          'slots': slots,
                          'is_manual': false,
                          'contribution': '',
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandYellow,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Add',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    controller.dispose();

    return result;
  }

  Future<void> _addItem() async {
    if (_isAddingItem || _isFinalized) {
      return;
    }

    final payload = _isPersonBased
        ? await _pickPersonToAdd()
        : await _createRoleTaskItem();

    if (payload == null || !mounted) {
      return;
    }

    final postId = _parseInt(
      _post['id'],
      fallback: -1,
    );

    if (postId <= 0) {
      _showMessage('This responsibility post is invalid.');
      return;
    }

    setState(() {
      _isAddingItem = true;
    });

    try {
      final result = await PlanService.addResponsibilityItem(
        postId: postId,
        item: payload,
      );

      if (!mounted) return;

      if (result['success'] == true &&
          result['post'] is Map) {
        _applyUpdatedPost(
          Map<String, dynamic>.from(
            result['post'] as Map,
          ),
        );
      } else {
        _showMessage(
          result['message']?.toString() ??
              'The item could not be added.',
        );
      }
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Connection error: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAddingItem = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brandCreamLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: softBorder,
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFCF4),
            Color(0xFFFFF6DA),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 18),
          Text(
            _title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isPersonBased
                ? 'By Person • Fill what each person will bring, share, or do'
                : 'By Role/Task • Claim a responsibility or respond to an assignment',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
              height: 1.3,
            ),
          ),
          if (_showProgress) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 8,
                backgroundColor: softYellow,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(
                  brandYellow,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _totalCount > 0 &&
                      _filledCount >= _totalCount
                  ? 'Everything is filled.'
                  : '$_filledCount of $_totalCount filled',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: brandYellowDark,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (items.isEmpty)
            _buildEmptyItems()
          else
            ...items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _isPersonBased
                    ? _buildPersonItem(item)
                    : _buildRoleTaskItem(item),
              );
            }),
          if (_canAddItems && !_isFinalized) ...[
            const SizedBox(height: 2),
            _buildAddItemButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            color: softYellow,
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isPersonBased
                ? Icons.groups_rounded
                : Icons.assignment_ind_rounded,
            size: 18,
            color: brandYellowDark,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Who\'s Doing What',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: brandYellowDark,
          ),
        ),
        const Spacer(),
        _buildHeaderChip(),
      ],
    );
  }

  Widget _buildHeaderChip() {
    final label = _isFinalized
        ? 'Finalized'
        : _showProgress
            ? '$_filledCount/$_totalCount Filled'
            : _isPersonBased
                ? 'By Person'
                : 'By Role/Task';

    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 150,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 11,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: _isFinalized
              ? const Color(0xFFFFE8E2)
              : softYellow,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: _isFinalized
                ? const Color(0xFFB42318)
                : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyItems() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        _isPersonBased
            ? 'No people are included yet.'
            : 'No roles or tasks are available yet.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildPersonItem(
    Map<String, dynamic> item,
  ) {
    final itemId = _parseInt(
      item['id'],
      fallback: -1,
    );

    final isBusy = _busyItemIds.contains(itemId);

    final name = _readString(
      item,
      [
        'member_display_name',
        'memberDisplayName',
        'title',
      ],
      fallback: 'Person',
    );

    final username = _readString(
      item,
      [
        'member_username',
        'memberUsername',
      ],
    );

    final isManual = _parseBool(
      _readValue(
        item,
        [
          'is_manual',
          'isManual',
        ],
      ),
      fallback: _parseNullableInt(
            item['member_user_id'],
          ) ==
          null,
    );

    final isCurrentUser = _parseBool(
      _readValue(
        item,
        [
          'is_current_user_member',
          'isCurrentUserMember',
        ],
      ),
      fallback: _parseNullableInt(
                item['member_user_id'],
              ) !=
              null &&
          widget.currentUserId != null &&
          _parseNullableInt(
                item['member_user_id'],
              ) ==
              widget.currentUserId,
    );

    final contribution = _readString(
      item,
      ['contribution'],
    );

    final canEdit = !_isFinalized &&
        _parseBool(
          _readValue(
            item,
            [
              'can_current_user_fill_contribution',
              'canCurrentUserFillContribution',
            ],
          ),
        );

    final hasContribution = contribution.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              hasContribution ? brandYellow : softBorder,
          width: hasContribution ? 1.5 : 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInitialAvatar(
            name: name,
            isManual: isManual,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _buildIdentityText(
                  name: name,
                  username:
                      isManual || username.isEmpty
                          ? null
                          : username,
                  isYou: isCurrentUser,
                ),
                const SizedBox(height: 7),
                Text(
                  hasContribution
                      ? contribution
                      : 'Nothing added yet',
                  style: TextStyle(
                    fontSize: 13,
                    color: hasContribution
                        ? Colors.grey.shade700
                        : Colors.grey.shade500,
                    height: 1.3,
                    fontStyle: hasContribution
                        ? FontStyle.normal
                        : FontStyle.italic,
                  ),
                ),
                if (canEdit) ...[
                  const SizedBox(height: 10),
                  _buildSmallActionButton(
                    label: hasContribution
                        ? 'Edit entry'
                        : 'Add entry',
                    icon: hasContribution
                        ? Icons.edit_outlined
                        : Icons.add_rounded,
                    filled: !hasContribution,
                    isBusy: isBusy,
                    onTap: () {
                      _editContribution(item);
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleTaskItem(
    Map<String, dynamic> item,
  ) {
    final itemId = _parseInt(
      item['id'],
      fallback: -1,
    );

    final isBusy = _busyItemIds.contains(itemId);

    final title = _readString(
      item,
      ['title'],
      fallback: 'Role or Task',
    );

    final slots = _parseInt(
      item['slots'],
      fallback: 1,
    );

    final activeAssignments =
        _activeAssignments(item);

    final acceptedAssignments =
        activeAssignments.where((assignment) {
      return _readString(
            assignment,
            ['status'],
          ) ==
          'accepted';
    }).toList();

    final pendingAssignments =
        activeAssignments.where((assignment) {
      return _readString(
            assignment,
            ['status'],
          ) ==
          'pending';
    }).toList();

    final reservedCount = activeAssignments.length;
    final isFull = reservedCount >= slots;

    final currentAssignment =
        _currentUserAssignment(item);

    final currentStatus = currentAssignment == null
        ? ''
        : _readString(
            currentAssignment,
            ['status'],
          );

    final currentSource = currentAssignment == null
        ? ''
        : _readString(
            currentAssignment,
            ['source'],
          );

    final hasPendingPreAssignment =
        currentStatus == 'pending' &&
            currentSource == 'preassigned';

    final currentUserAccepted =
        currentStatus == 'accepted';

    final canClaim = !_isFinalized &&
        !hasPendingPreAssignment &&
        !currentUserAccepted &&
        _parseBool(
          _readValue(
            item,
            [
              'can_current_user_claim',
              'canCurrentUserClaim',
            ],
          ),
          fallback: !isFull,
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFull ? brandYellow : softBorder,
          width: isFull ? 1.5 : 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: softYellow,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.assignment_ind_rounded,
              size: 19,
              color: brandYellowDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${acceptedAssignments.length}/$slots accepted'
                  '${pendingAssignments.isNotEmpty ? ' • ${pendingAssignments.length} pending' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: brandYellowDark,
                  ),
                ),
                if (activeAssignments.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...activeAssignments.map(
                    (assignment) {
                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: 7),
                        child: _buildAssignmentPersonRow(
                          assignment,
                        ),
                      );
                    },
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Text(
                    'No one has taken this yet',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
                if (!_isFinalized) ...[
                  const SizedBox(height: 11),
                  if (hasPendingPreAssignment)
                    _buildPendingResponse(
                      item: item,
                      isBusy: isBusy,
                    )
                  else if (currentUserAccepted)
                    _buildSmallActionButton(
                      label: 'Unclaim',
                      icon: Icons.undo_rounded,
                      isBusy: isBusy,
                      onTap: () {
                        _unclaimItem(item);
                      },
                    )
                  else if (canClaim)
                    _buildSmallActionButton(
                      label: 'Claim',
                      icon: Icons.add_task_rounded,
                      filled: true,
                      isBusy: isBusy,
                      onTap: () {
                        _claimItem(item);
                      },
                    )
                  else if (isFull)
                    _buildNeutralStatusChip('Full'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentPersonRow(
    Map<String, dynamic> assignment,
  ) {
    final nestedUser = assignment['user'];

    final user = nestedUser is Map
        ? Map<String, dynamic>.from(nestedUser)
        : <String, dynamic>{};

    final name = _readString(
      assignment,
      [
        'display_name',
        'displayName',
        'name',
        'manual_name',
      ],
      fallback: _readString(
        user,
        ['name'],
        fallback: 'Person',
      ),
    );

    final username = _readString(
      assignment,
      [
        'username_value',
        'usernameValue',
        'username',
      ],
      fallback: _readString(
        user,
        ['username'],
      ),
    );

    final userId = _parseNullableInt(
      assignment['user_id'] ??
          assignment['userId'] ??
          user['id'],
    );

    final isManual = userId == null;

    final isCurrentUser = _parseBool(
      assignment['is_current_user'] ??
          assignment['isCurrentUser'],
      fallback: userId != null &&
          widget.currentUserId != null &&
          userId == widget.currentUserId,
    );

    final status = _readString(
      assignment,
      ['status'],
      fallback: 'accepted',
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: brandCreamLight,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: softBorder,
        ),
      ),
      child: Row(
        children: [
          _buildInitialAvatar(
            name: name,
            isManual: isManual,
            size: 30,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _buildIdentityText(
              name: name,
              username:
                  isManual || username.isEmpty
                      ? null
                      : username,
              isYou: isCurrentUser,
              compact: true,
            ),
          ),
          const SizedBox(width: 8),
          _buildAssignmentStatus(status),
        ],
      ),
    );
  }

  Widget _buildAssignmentStatus(String status) {
    final isPending = status == 'pending';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: isPending
            ? const Color(0xFFFFF4D6)
            : const Color(0xFFEAF7EE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isPending ? 'Pending' : 'Accepted',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: isPending
              ? const Color(0xFF9A6700)
              : const Color(0xFF18794E),
        ),
      ),
    );
  }

  Widget _buildPendingResponse({
    required Map<String, dynamic> item,
    required bool isBusy,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: brandCream,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: softBorder,
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'You were pre-assigned',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Accept or decline this role/task.',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildResponseIcon(
            icon: Icons.close_rounded,
            tooltip: 'Decline',
            backgroundColor: Colors.white,
            iconColor: Colors.redAccent,
            borderColor: Colors.redAccent,
            isBusy: isBusy,
            onTap: () {
              _respondToPreAssignment(
                item: item,
                accept: false,
              );
            },
          ),
          const SizedBox(width: 8),
          _buildResponseIcon(
            icon: Icons.check_rounded,
            tooltip: 'Accept',
            backgroundColor: brandYellow,
            iconColor: Colors.black,
            borderColor: brandYellow,
            isBusy: isBusy,
            onTap: () {
              _respondToPreAssignment(
                item: item,
                accept: true,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildResponseIcon({
    required IconData icon,
    required String tooltip,
    required Color backgroundColor,
    required Color iconColor,
    required Color borderColor,
    required bool isBusy,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isBusy ? null : onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 37,
            height: 37,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor,
                width: 1.2,
              ),
            ),
            child: isBusy
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: iconColor,
                    ),
                  )
                : Icon(
                    icon,
                    size: 20,
                    color: iconColor,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmallActionButton({
    required String label,
    required IconData icon,
    required bool isBusy,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: isBusy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 11,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: filled
              ? brandYellow
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(999),
          border: filled
              ? null
              : Border.all(
                  color: Colors.grey.shade300,
                ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isBusy)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            else
              Icon(
                icon,
                size: 14,
                color: filled
                    ? Colors.black
                    : Colors.grey.shade800,
              ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: filled
                    ? Colors.black
                    : Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeutralStatusChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildInitialAvatar({
    required String name,
    required bool isManual,
    double size = 36,
  }) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isManual
            ? Colors.grey.shade100
            : softYellow,
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials(name),
        style: TextStyle(
          fontSize: size <= 30 ? 9 : 11,
          fontWeight: FontWeight.w900,
          color: isManual
              ? Colors.grey.shade700
              : brandYellowDark,
        ),
      ),
    );
  }

  Widget _buildIdentityText({
    required String name,
    required String? username,
    required bool isYou,
    bool compact = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 5,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: compact ? 12 : 14,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
            if (isYou)
              const Text(
                '(You)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: brandYellowDark,
                ),
              ),
          ],
        ),
        if (username != null &&
            username.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            _formatUsername(username),
            style: TextStyle(
              fontSize: compact ? 9 : 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAddItemButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _isAddingItem ? null : _addItem,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: softBorder,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            if (_isAddingItem)
              const SizedBox(
                width: 21,
                height: 21,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: brandYellowDark,
                ),
              )
            else
              const Icon(
                Icons.add_circle_outline_rounded,
                size: 22,
                color: brandYellowDark,
              ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                _isPersonBased
                    ? 'Add another person'
                    : 'Add another role or task',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: brandYellowDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}