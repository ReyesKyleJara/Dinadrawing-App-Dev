import 'package:flutter/material.dart';

import '../../../services/plan_service.dart';

enum ResponsibilityMode { personBased, roleTaskBased }

class ResponsibilityPersonDraft {
  final int? itemId;
  final int? userId;
  final String name;
  final String? username;
  final bool isManual;
  final String contribution;

  const ResponsibilityPersonDraft({
    this.itemId,
    this.userId,
    required this.name,
    this.username,
    required this.isManual,
    this.contribution = '',
  });

  String get identityKey {
    if (userId != null) {
      return 'user:$userId';
    }

    return 'manual:${name.trim().toLowerCase()}';
  }
}

class ResponsibilitySelectedPerson {
  final int? assignmentId;
  final int? userId;
  final String name;
  final String? username;
  final bool isManual;
  final String status;
  final String source;

  const ResponsibilitySelectedPerson({
    this.assignmentId,
    this.userId,
    required this.name,
    this.username,
    required this.isManual,
    this.status = 'pending',
    this.source = 'preassigned',
  });

  String get identityKey {
    if (userId != null) {
      return 'user:$userId';
    }

    return 'manual:${name.trim().toLowerCase()}';
  }

  ResponsibilitySelectedPerson copyWith({
    int? assignmentId,
    int? userId,
    String? name,
    String? username,
    bool? isManual,
    String? status,
    String? source,
  }) {
    return ResponsibilitySelectedPerson(
      assignmentId: assignmentId ?? this.assignmentId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      username: username ?? this.username,
      isManual: isManual ?? this.isManual,
      status: status ?? this.status,
      source: source ?? this.source,
    );
  }
}

class ResponsibilityRoleTaskDraft {
  final int? itemId;
  final TextEditingController titleController;

  int slots;
  int reservedOutsidePreassignments;

  final List<ResponsibilitySelectedPerson> preAssignedPeople;
  final List<ResponsibilitySelectedPerson> originalPreAssignedPeople;

  ResponsibilityRoleTaskDraft({
    this.itemId,
    String title = '',
    this.slots = 1,
    this.reservedOutsidePreassignments = 0,
    List<ResponsibilitySelectedPerson>? preAssignedPeople,
    List<ResponsibilitySelectedPerson>? originalPreAssignedPeople,
  }) : titleController = TextEditingController(text: title),
       preAssignedPeople = preAssignedPeople ?? [],
       originalPreAssignedPeople = originalPreAssignedPeople ?? [];

  void dispose() {
    titleController.dispose();
  }
}

class CreateResponsibility extends StatefulWidget {
  final int planId;
  final List<Map<String, dynamic>> planMembers;
  final int? currentUserId;
  final Map<String, dynamic>? initialData;

  const CreateResponsibility({
    super.key,
    required this.planId,
    required this.planMembers,
    required this.currentUserId,
    this.initialData,
  });

  @override
  State<CreateResponsibility> createState() => _CreateResponsibilityState();
}

class _CreateResponsibilityState extends State<CreateResponsibility> {
  static const Color brandYellow = Color(0xFFF5B335);
  static const Color brandYellowDark = Color(0xFFB87500);
  static const Color brandCream = Color(0xFFFFF8E8);
  static const Color brandCreamLight = Color(0xFFFFFCF4);
  static const Color softBorder = Color(0xFFF2D999);

  ThemeData get _theme => Theme.of(context);
  ColorScheme get _colors => _theme.colorScheme;
  bool get _isDark => _theme.brightness == Brightness.dark;
  Color get _pageColor => _theme.scaffoldBackgroundColor;
  Color get _surfaceColor => _isDark ? const Color(0xFF202024) : Colors.white;
  Color get _surfaceAltColor =>
      _isDark ? const Color(0xFF29292E) : Colors.grey.shade50;
  Color get _borderColor => _isDark ? Colors.white24 : Colors.grey.shade300;
  Color get _subtleBorderColor =>
      _isDark ? Colors.white12 : Colors.grey.shade200;
  Color get _textColor => _colors.onSurface;
  Color get _mutedTextColor => _colors.onSurfaceVariant;
  Color get _accentTextColor => _isDark ? brandYellow : brandYellowDark;
  Color get _accentSoftColor => _isDark ? const Color(0xFF3A3020) : brandCream;
  Color get _accentSoftestColor =>
      _isDark ? const Color(0xFF2D281F) : brandCreamLight;
  Color get _accentCircleColor =>
      _isDark ? const Color(0xFF594217) : const Color(0xFFFFE8A3);
  Color get _accentBorderColor =>
      _isDark ? brandYellow.withValues(alpha: 0.45) : softBorder;

  final TextEditingController _titleController = TextEditingController();

  final List<ResponsibilityPersonDraft> _people = [];
  final List<ResponsibilityRoleTaskDraft> _roleTasks = [];

  ResponsibilityMode _selectedMode = ResponsibilityMode.personBased;

  bool _allowMembersAddItems = false;
  bool _showProgress = true;
  bool _isSubmitting = false;

  bool get _isEditing => widget.initialData != null;

  String get _backendMode {
    return _selectedMode == ResponsibilityMode.personBased
        ? 'person_based'
        : 'role_task_based';
  }

  String get _titleHint {
    return _selectedMode == ResponsibilityMode.personBased
        ? 'e.g., What Everyone Will Bring'
        : 'e.g., Capstone Roles and Tasks';
  }

  String get _submitLabel {
    if (_isEditing) {
      return 'Save Changes';
    }

    return 'Create Responsibilities';
  }

  @override
  void initState() {
    super.initState();

    if (_isEditing) {
      _loadInitialData(widget.initialData!);
    } else {
      _initializeNewResponsibility();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();

    for (final item in _roleTasks) {
      item.dispose();
    }

    super.dispose();
  }

  void _initializeNewResponsibility() {
    _people
      ..clear()
      ..addAll(_buildDefaultPeople());

    _roleTasks
      ..clear()
      ..addAll([ResponsibilityRoleTaskDraft(), ResponsibilityRoleTaskDraft()]);
  }

  int _parseInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;

    return int.tryParse(value.toString()) ?? fallback;
  }

  int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;

    return int.tryParse(value.toString());
  }

  bool _parseBool(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is int) return value == 1;

    final text = value.toString().trim().toLowerCase();

    return text == 'true' || text == '1';
  }

  String _memberName(Map<String, dynamic> member) {
    final nestedUser = member['user'];

    if (nestedUser is Map) {
      final nestedMap = Map<String, dynamic>.from(nestedUser);
      final nestedName = nestedMap['name']?.toString().trim();

      if (nestedName != null && nestedName.isNotEmpty) {
        return nestedName;
      }
    }

    final displayName = member['displayName']?.toString().trim();
    final name = member['name']?.toString().trim();
    final username = member['username']?.toString().trim();
    final email = member['email']?.toString().trim();

    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    if (name != null && name.isNotEmpty) {
      return name;
    }

    if (username != null && username.isNotEmpty) {
      return username;
    }

    if (email != null && email.isNotEmpty) {
      return email;
    }

    return 'Member';
  }

  String? _memberUsername(Map<String, dynamic> member) {
    final nestedUser = member['user'];

    if (nestedUser is Map) {
      final nestedMap = Map<String, dynamic>.from(nestedUser);
      final nestedUsername = nestedMap['username']?.toString().trim();

      if (nestedUsername != null && nestedUsername.isNotEmpty) {
        return nestedUsername;
      }
    }

    final username = member['username']?.toString().trim();

    if (username == null || username.isEmpty) {
      return null;
    }

    return username;
  }

  int? _memberId(Map<String, dynamic> member) {
    final nestedUser = member['user'];

    if (nestedUser is Map) {
      final nestedMap = Map<String, dynamic>.from(nestedUser);
      final nestedId = _parseNullableInt(nestedMap['id']);

      if (nestedId != null) {
        return nestedId;
      }
    }

    return _parseNullableInt(member['id'] ?? member['user_id']);
  }

  String _formatUsername(String username) {
    final cleanUsername = username.trim();

    if (cleanUsername.startsWith('@')) {
      return cleanUsername;
    }

    return '@$cleanUsername';
  }

  bool _isCurrentUser(int? userId) {
    return userId != null &&
        widget.currentUserId != null &&
        userId == widget.currentUserId;
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

  List<ResponsibilityPersonDraft> _buildDefaultPeople() {
    final people = <ResponsibilityPersonDraft>[];
    final usedIds = <int>{};
    final usedNames = <String>{};

    for (final member in widget.planMembers) {
      final id = _memberId(member);
      final name = _memberName(member);
      final username = _memberUsername(member);

      if (id != null && usedIds.contains(id)) {
        continue;
      }

      final cleanName = name.trim().toLowerCase();

      if (id == null && usedNames.contains(cleanName)) {
        continue;
      }

      if (id != null) {
        usedIds.add(id);
      }

      usedNames.add(cleanName);

      people.add(
        ResponsibilityPersonDraft(
          userId: id,
          name: name,
          username: username,
          isManual: false,
        ),
      );
    }

    final containsCurrentUser = people.any(
      (person) => _isCurrentUser(person.userId),
    );

    if (!containsCurrentUser && widget.currentUserId != null) {
      people.insert(
        0,
        ResponsibilityPersonDraft(
          userId: widget.currentUserId,
          name: 'You',
          isManual: false,
        ),
      );
    }

    people.sort((first, second) {
      final firstIsYou = _isCurrentUser(first.userId);
      final secondIsYou = _isCurrentUser(second.userId);

      if (firstIsYou && !secondIsYou) {
        return -1;
      }

      if (!firstIsYou && secondIsYou) {
        return 1;
      }

      return first.name.toLowerCase().compareTo(second.name.toLowerCase());
    });

    return people;
  }

  List<dynamic> _extractItems(Map<String, dynamic> data) {
    final value =
        data['responsibility_items'] ??
        data['responsibilityItems'] ??
        data['taskDetails'] ??
        data['items'];

    return value is List ? value : <dynamic>[];
  }

  List<dynamic> _extractAssignments(Map<String, dynamic> item) {
    final value =
        item['assignments'] ?? item['claimedBy'] ?? item['claimed_by'];

    return value is List ? value : <dynamic>[];
  }

  void _loadInitialData(Map<String, dynamic> data) {
    final mode =
        data['responsibility_mode']?.toString() ??
        data['responsibilityMode']?.toString() ??
        data['taskMode']?.toString() ??
        'person_based';

    _selectedMode = mode == 'role_task_based'
        ? ResponsibilityMode.roleTaskBased
        : ResponsibilityMode.personBased;

    _titleController.text =
        data['responsibility_title']?.toString() ??
        data['responsibilityTitle']?.toString() ??
        data['title']?.toString() ??
        data['content']?.toString() ??
        '';

    _allowMembersAddItems = _parseBool(
      data['responsibility_allow_member_items'] ?? data['allowMembersAddItems'],
    );

    _showProgress = _parseBool(
      data['responsibility_show_progress'] ?? data['showProgress'],
      fallback: true,
    );

    final rawItems = _extractItems(data);

    if (_selectedMode == ResponsibilityMode.personBased) {
      for (final rawItem in rawItems) {
        if (rawItem is! Map) continue;

        final item = Map<String, dynamic>.from(rawItem);
        final nestedMember = item['member'];

        final member = nestedMember is Map
            ? Map<String, dynamic>.from(nestedMember)
            : <String, dynamic>{};

        final userId = _parseNullableInt(
          item['member_user_id'] ??
              item['memberUserId'] ??
              item['userId'] ??
              member['id'],
        );

        final name =
            item['member_display_name']?.toString().trim() ??
            item['title']?.toString().trim() ??
            member['name']?.toString().trim() ??
            '';

        final username =
            item['member_username']?.toString().trim() ??
            member['username']?.toString().trim();

        if (name.isEmpty) continue;

        _people.add(
          ResponsibilityPersonDraft(
            itemId: _parseNullableInt(item['id']),
            userId: userId,
            name: name,
            username: username?.isEmpty == true ? null : username,
            isManual: _parseBool(
              item['is_manual'] ?? item['isManual'],
              fallback: userId == null,
            ),
            contribution: item['contribution']?.toString() ?? '',
          ),
        );
      }

      if (_people.isEmpty) {
        _people.addAll(_buildDefaultPeople());
      }

      _roleTasks.addAll([
        ResponsibilityRoleTaskDraft(),
        ResponsibilityRoleTaskDraft(),
      ]);

      return;
    }

    for (final rawItem in rawItems) {
      if (rawItem is! Map) continue;

      final item = Map<String, dynamic>.from(rawItem);
      final assignments = _extractAssignments(item);

      final preAssignedPeople = <ResponsibilitySelectedPerson>[];

      int reservedOutsidePreassignments = 0;

      for (final rawAssignment in assignments) {
        if (rawAssignment is! Map) continue;

        final assignment = Map<String, dynamic>.from(rawAssignment);

        final source = assignment['source']?.toString() ?? 'claimed';

        final status = assignment['status']?.toString() ?? 'accepted';

        final isActive = status == 'pending' || status == 'accepted';

        if (!isActive) {
          continue;
        }

        if (source != 'preassigned') {
          reservedOutsidePreassignments++;
          continue;
        }

        final nestedUser = assignment['user'];

        final user = nestedUser is Map
            ? Map<String, dynamic>.from(nestedUser)
            : <String, dynamic>{};

        final userId = _parseNullableInt(
          assignment['user_id'] ?? assignment['userId'] ?? user['id'],
        );

        final name =
            assignment['display_name']?.toString().trim() ??
            assignment['name']?.toString().trim() ??
            assignment['manual_name']?.toString().trim() ??
            user['name']?.toString().trim() ??
            '';

        final username =
            assignment['username_value']?.toString().trim() ??
            assignment['username']?.toString().trim() ??
            user['username']?.toString().trim();

        if (name.isEmpty) {
          continue;
        }

        preAssignedPeople.add(
          ResponsibilitySelectedPerson(
            assignmentId: _parseNullableInt(assignment['id']),
            userId: userId,
            name: name,
            username: username?.isEmpty == true ? null : username,
            isManual: userId == null,
            status: status,
            source: source,
          ),
        );
      }

      final originalPeople = preAssignedPeople
          .map((person) => person.copyWith())
          .toList();

      _roleTasks.add(
        ResponsibilityRoleTaskDraft(
          itemId: _parseNullableInt(item['id']),
          title: item['title']?.toString() ?? '',
          slots: _parseInt(item['slots'], fallback: 1),
          reservedOutsidePreassignments: reservedOutsidePreassignments,
          preAssignedPeople: preAssignedPeople,
          originalPreAssignedPeople: originalPeople,
        ),
      );
    }

    if (_roleTasks.isEmpty) {
      _roleTasks.addAll([
        ResponsibilityRoleTaskDraft(),
        ResponsibilityRoleTaskDraft(),
      ]);
    }

    _people.addAll(_buildDefaultPeople());
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _selectMode(ResponsibilityMode mode) {
    if (_isSubmitting || _isEditing) {
      return;
    }

    setState(() {
      _selectedMode = mode;

      if (_selectedMode == ResponsibilityMode.personBased && _people.isEmpty) {
        _people.addAll(_buildDefaultPeople());
      }

      if (_selectedMode == ResponsibilityMode.roleTaskBased &&
          _roleTasks.isEmpty) {
        _roleTasks.addAll([
          ResponsibilityRoleTaskDraft(),
          ResponsibilityRoleTaskDraft(),
        ]);
      }
    });
  }

  bool _personAlreadyIncluded({int? userId, required String name}) {
    return _people.any((person) {
      if (userId != null && person.userId != null) {
        return userId == person.userId;
      }

      return person.name.trim().toLowerCase() == name.trim().toLowerCase();
    });
  }

  Set<String> _personListIdentityKeys() {
    return _people.map((person) => person.identityKey).toSet();
  }

  Set<String> _preAssignedIdentityKeys(ResponsibilityRoleTaskDraft item) {
    return item.preAssignedPeople.map((person) => person.identityKey).toSet();
  }

  List<Map<String, dynamic>> _availableMembers({
    required Set<String> excludedKeys,
    required String query,
  }) {
    final cleanQuery = query.trim().toLowerCase();

    return widget.planMembers.where((member) {
      final id = _memberId(member);
      final name = _memberName(member);
      final username = _memberUsername(member);

      final key = id != null
          ? 'user:$id'
          : 'manual:${name.trim().toLowerCase()}';

      if (excludedKeys.contains(key)) {
        return false;
      }

      if (cleanQuery.isEmpty) {
        return true;
      }

      return name.toLowerCase().contains(cleanQuery) ||
          (username?.toLowerCase().contains(cleanQuery) ?? false);
    }).toList();
  }

  Future<ResponsibilitySelectedPerson?> _openPersonPicker({
    required String title,
    required Set<String> excludedKeys,
    required bool allowManualName,
  }) async {
    final searchController = TextEditingController();
    String query = '';

    final selected = await showModalBottomSheet<ResponsibilitySelectedPerson>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surfaceColor,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final suggestions = _availableMembers(
              excludedKeys: excludedKeys,
              query: query,
            );

            final cleanQuery = query.trim();
            final manualKey = 'manual:${cleanQuery.toLowerCase()}';

            final canAddManual =
                allowManualName &&
                cleanQuery.isNotEmpty &&
                !excludedKeys.contains(manualKey);

            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                18,
                24,
                MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: SizedBox(
                height: MediaQuery.of(sheetContext).size.height * 0.72,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _borderColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              color: _textColor,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: searchController,
                      style: TextStyle(color: _textColor),
                      cursorColor: brandYellow,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (value) {
                        setSheetState(() {
                          query = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search a member or type a name',
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: _mutedTextColor,
                        ),
                        filled: true,
                        fillColor: _surfaceAltColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _borderColor),
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
                    const SizedBox(height: 14),
                    Expanded(
                      child: ListView(
                        children: [
                          if (suggestions.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'Plan members',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: _mutedTextColor,
                                ),
                              ),
                            ),
                            ...suggestions.map((member) {
                              final id = _memberId(member);
                              final name = _memberName(member);
                              final username = _memberUsername(member);
                              final isYou = _isCurrentUser(id);

                              return _buildPickerMemberTile(
                                name: name,
                                username: username,
                                isYou: isYou,
                                onTap: () {
                                  Navigator.of(sheetContext).pop(
                                    ResponsibilitySelectedPerson(
                                      userId: id,
                                      name: name,
                                      username: username,
                                      isManual: false,
                                    ),
                                  );
                                },
                              );
                            }),
                          ],
                          if (canAddManual) ...[
                            if (suggestions.isNotEmpty)
                              const SizedBox(height: 10),
                            InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                Navigator.of(sheetContext).pop(
                                  ResponsibilitySelectedPerson(
                                    name: cleanQuery,
                                    isManual: true,
                                  ),
                                );
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: _accentSoftColor,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _accentBorderColor),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: _accentCircleColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.person_add_alt_1_rounded,
                                        size: 19,
                                        color: _accentTextColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Add “$cleanQuery”',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: _textColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          if (suggestions.isEmpty && !canAddManual)
                            Padding(
                              padding: const EdgeInsets.only(top: 50),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.person_search_rounded,
                                    size: 48,
                                    color: _borderColor,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    query.trim().isEmpty
                                        ? 'All plan members are already included.'
                                        : 'No matching member found.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _mutedTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

    searchController.dispose();

    return selected;
  }

  Widget _buildPickerMemberTile({
    required String name,
    required String? username,
    required bool isYou,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _accentCircleColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _initials(name),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: _accentTextColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPersonIdentity(
                  name: name,
                  username: username,
                  isYou: isYou,
                ),
              ),
              Icon(Icons.add_circle_outline_rounded, color: brandYellow),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addPerson() async {
    if (_isSubmitting) return;

    final selected = await _openPersonPicker(
      title: 'Add person',
      excludedKeys: _personListIdentityKeys(),
      allowManualName: true,
    );

    if (selected == null || !mounted) {
      return;
    }

    if (_personAlreadyIncluded(userId: selected.userId, name: selected.name)) {
      _showMessage('This person is already included.');
      return;
    }

    setState(() {
      _people.add(
        ResponsibilityPersonDraft(
          userId: selected.userId,
          name: selected.name,
          username: selected.username,
          isManual: selected.isManual,
        ),
      );
    });
  }

  void _removePerson(int index) {
    if (_isSubmitting) return;

    final person = _people[index];

    if (_isEditing && person.contribution.trim().isNotEmpty) {
      _showMessage('This person already has an entry and cannot be removed.');
      return;
    }

    setState(() {
      _people.removeAt(index);
    });
  }

  void _addRoleTask() {
    if (_isSubmitting) return;

    if (_roleTasks.length >= 30) {
      _showMessage('You can only add up to 30 roles or tasks.');
      return;
    }

    setState(() {
      _roleTasks.add(ResponsibilityRoleTaskDraft());
    });
  }

  void _removeRoleTask(int index) {
    if (_isSubmitting) return;

    final item = _roleTasks[index];

    final activeAssignments =
        item.reservedOutsidePreassignments +
        item.originalPreAssignedPeople.length;

    if (_isEditing && activeAssignments > 0) {
      _showMessage('Roles or tasks with assigned people cannot be removed.');
      return;
    }

    setState(() {
      final removedItem = _roleTasks.removeAt(index);
      removedItem.dispose();
    });
  }

  int _minimumSlots(ResponsibilityRoleTaskDraft item) {
    final minimum =
        item.reservedOutsidePreassignments + item.preAssignedPeople.length;

    return minimum < 1 ? 1 : minimum;
  }

  void _decreaseSlots(int index) {
    if (_isSubmitting) return;

    final item = _roleTasks[index];
    final minimum = _minimumSlots(item);

    if (item.slots <= minimum) {
      if (minimum > 1) {
        _showMessage(
          'Slots cannot be lower than the number of assigned people.',
        );
      }

      return;
    }

    setState(() {
      item.slots--;
    });
  }

  void _increaseSlots(int index) {
    if (_isSubmitting) return;

    final item = _roleTasks[index];

    if (item.slots >= 50) {
      _showMessage('A role or task can have up to 50 slots.');
      return;
    }

    setState(() {
      item.slots++;
    });
  }

  Future<void> _addPreAssignedPerson(int index) async {
    if (_isSubmitting) return;

    final item = _roleTasks[index];

    final selected = await _openPersonPicker(
      title: 'Pre-assign person',
      excludedKeys: _preAssignedIdentityKeys(item),
      allowManualName: true,
    );

    if (selected == null || !mounted) {
      return;
    }

    final alreadyIncluded = item.preAssignedPeople.any(
      (person) => person.identityKey == selected.identityKey,
    );

    if (alreadyIncluded) {
      _showMessage('This person is already pre-assigned.');
      return;
    }

    setState(() {
      item.preAssignedPeople.add(selected);

      final requiredSlots = _minimumSlots(item);

      if (item.slots < requiredSlots) {
        item.slots = requiredSlots;
      }
    });
  }

  void _removePreAssignedPerson(
    int itemIndex,
    ResponsibilitySelectedPerson person,
  ) {
    if (_isSubmitting) return;

    setState(() {
      _roleTasks[itemIndex].preAssignedPeople.removeWhere(
        (item) => item.identityKey == person.identityKey,
      );
    });
  }

  Map<String, dynamic> _personItemPayload(ResponsibilityPersonDraft person) {
    return {
      if (person.itemId != null) 'id': person.itemId,
      'title': person.name,
      'member_user_id': person.userId,
      'is_manual': person.isManual,
      'contribution': person.contribution,
      'slots': 1,
    };
  }

  Map<String, dynamic> _roleTaskItemPayload(
    ResponsibilityRoleTaskDraft item, {
    required bool includePreAssignments,
  }) {
    final userIds = item.preAssignedPeople
        .where((person) => person.userId != null)
        .map((person) => person.userId!)
        .toList();

    final manualNames = item.preAssignedPeople
        .where((person) => person.userId == null)
        .map((person) => person.name.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    return {
      if (item.itemId != null) 'id': item.itemId,
      'title': item.titleController.text.trim(),
      'slots': item.slots,
      'is_manual': false,
      'contribution': '',
      if (includePreAssignments && userIds.isNotEmpty)
        'preassigned_user_ids': userIds,
      if (includePreAssignments && manualNames.isNotEmpty)
        'manual_preassigned_names': manualNames,
    };
  }

  bool _hasDuplicateRoleTaskTitles() {
    final seen = <String>{};

    for (final item in _roleTasks) {
      final title = item.titleController.text.trim().toLowerCase();

      if (title.isEmpty) {
        continue;
      }

      if (seen.contains(title)) {
        return true;
      }

      seen.add(title);
    }

    return false;
  }

  bool _validateForm() {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      _showMessage('Please enter a title.');
      return false;
    }

    if (_selectedMode == ResponsibilityMode.personBased) {
      if (_people.isEmpty) {
        _showMessage('Please add at least one person.');
        return false;
      }

      return true;
    }

    final validItems = _roleTasks.where(
      (item) => item.titleController.text.trim().isNotEmpty,
    );

    if (validItems.isEmpty) {
      _showMessage('Please add at least one role or task.');
      return false;
    }

    if (_hasDuplicateRoleTaskTitles()) {
      _showMessage('Role or task names must be different.');
      return false;
    }

    for (final item in validItems) {
      final requiredSlots = _minimumSlots(item);

      if (item.slots < requiredSlots) {
        _showMessage(
          'Available slots cannot be lower than the number of assigned people.',
        );
        return false;
      }
    }

    return true;
  }

  List<Map<String, dynamic>> _serverItems(Map<String, dynamic> post) {
    final value =
        post['responsibility_items'] ??
        post['responsibilityItems'] ??
        post['items'];

    if (value is! List) {
      return <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Map<String, dynamic>? _findServerItemForDraft({
    required ResponsibilityRoleTaskDraft draft,
    required List<Map<String, dynamic>> serverItems,
    required Set<int> usedItemIds,
  }) {
    if (draft.itemId != null) {
      for (final serverItem in serverItems) {
        final serverId = _parseNullableInt(serverItem['id']);

        if (serverId == draft.itemId) {
          usedItemIds.add(serverId!);
          return serverItem;
        }
      }
    }

    final cleanTitle = draft.titleController.text.trim().toLowerCase();

    for (final serverItem in serverItems) {
      final serverId = _parseNullableInt(serverItem['id']);

      final serverTitle =
          serverItem['title']?.toString().trim().toLowerCase() ?? '';

      if (serverId != null &&
          !usedItemIds.contains(serverId) &&
          serverTitle == cleanTitle) {
        usedItemIds.add(serverId);
        return serverItem;
      }
    }

    return null;
  }

  Future<Map<String, dynamic>> _synchronizeEditedPreAssignments(
    Map<String, dynamic> updatedPost,
  ) async {
    var latestPost = updatedPost;

    final items = _serverItems(latestPost);
    final usedItemIds = <int>{};

    for (final draft in _roleTasks) {
      if (draft.titleController.text.trim().isEmpty) {
        continue;
      }

      final serverItem = _findServerItemForDraft(
        draft: draft,
        serverItems: items,
        usedItemIds: usedItemIds,
      );

      final itemId = _parseNullableInt(serverItem?['id']);

      if (itemId == null) {
        return {
          'success': false,
          'message': 'A saved role or task could not be matched.',
        };
      }

      final originalByKey = {
        for (final person in draft.originalPreAssignedPeople)
          person.identityKey: person,
      };

      final currentByKey = {
        for (final person in draft.preAssignedPeople)
          person.identityKey: person,
      };

      final removedKeys = originalByKey.keys
          .where((key) => !currentByKey.containsKey(key))
          .toList();

      for (final key in removedKeys) {
        final originalPerson = originalByKey[key];
        final assignmentId = originalPerson?.assignmentId;

        if (assignmentId == null) {
          continue;
        }

        final result = await PlanService.removeResponsibilityPreassignment(
          itemId: itemId,
          assignmentId: assignmentId,
        );

        if (result['success'] != true) {
          return {
            'success': false,
            'message':
                result['message'] ?? 'Failed to remove a pre-assignment.',
          };
        }

        final returnedPost = result['post'];

        if (returnedPost is Map) {
          latestPost = Map<String, dynamic>.from(returnedPost);
        }
      }

      final addedKeys = currentByKey.keys
          .where((key) => !originalByKey.containsKey(key))
          .toList();

      for (final key in addedKeys) {
        final person = currentByKey[key];

        if (person == null) {
          continue;
        }

        final result = await PlanService.preassignResponsibilityPerson(
          itemId: itemId,
          userId: person.userId,
          manualName: person.userId == null ? person.name : null,
        );

        if (result['success'] != true) {
          return {
            'success': false,
            'message': result['message'] ?? 'Failed to add a pre-assignment.',
          };
        }

        final returnedPost = result['post'];

        if (returnedPost is Map) {
          latestPost = Map<String, dynamic>.from(returnedPost);
        }
      }
    }

    return {'success': true, 'post': latestPost};
  }

  Future<void> _submitResponsibility() async {
    if (_isSubmitting || !_validateForm()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    bool completed = false;

    try {
      final title = _titleController.text.trim();

      final items = _selectedMode == ResponsibilityMode.personBased
          ? _people.map(_personItemPayload).toList()
          : _roleTasks
                .where((item) => item.titleController.text.trim().isNotEmpty)
                .map(
                  (item) => _roleTaskItemPayload(
                    item,
                    includePreAssignments: !_isEditing,
                  ),
                )
                .toList();

      Map<String, dynamic> result;

      if (_isEditing) {
        final postId = _parseInt(widget.initialData?['id'], fallback: -1);

        if (postId <= 0) {
          _showMessage('This responsibility post is invalid.');
          return;
        }

        result = await PlanService.updateResponsibilityPost(
          postId: postId,
          title: title,
          mode: _backendMode,
          items: items,
          allowMembersAddItems: _allowMembersAddItems,
          showProgress: _showProgress,
        );
      } else {
        result = await PlanService.createResponsibilityPost(
          planId: widget.planId,
          title: title,
          mode: _backendMode,
          items: items,
          allowMembersAddItems: _allowMembersAddItems,
          showProgress: _showProgress,
        );
      }

      if (!mounted) return;

      if (result['success'] != true || result['post'] == null) {
        _showMessage(result['message'] ?? 'Failed to save responsibilities.');
        return;
      }

      var savedPost = Map<String, dynamic>.from(result['post'] as Map);

      if (_isEditing && _selectedMode == ResponsibilityMode.roleTaskBased) {
        final syncResult = await _synchronizeEditedPreAssignments(savedPost);

        if (!mounted) return;

        if (syncResult['success'] != true) {
          _showMessage(
            syncResult['message'] ??
                'The list was saved, but some pre-assignments could not be updated.',
          );
          return;
        }

        final syncedPost = syncResult['post'];

        if (syncedPost is Map) {
          savedPost = Map<String, dynamic>.from(syncedPost);
        }
      }

      completed = true;

      if (!mounted) return;

      Navigator.pop(context, savedPost);
    } catch (error) {
      if (!mounted) return;

      _showMessage('Connection error: $error');
    } finally {
      if (mounted && !completed) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPersonBased = _selectedMode == ResponsibilityMode.personBased;

    return Scaffold(
      backgroundColor: _pageColor,
      appBar: AppBar(
        backgroundColor: _pageColor,
        surfaceTintColor: _pageColor,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 100,
        leading: TextButton.icon(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios, size: 14, color: brandYellow),
          label: Text(
            'Back',
            style: TextStyle(color: brandYellow, fontSize: 14),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.only(left: 24),
            overlayColor: Colors.transparent,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Edit Responsibilities' : 'Set Up Who Does What',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Organize people, roles, tasks, and shared responsibilities.',
              style: TextStyle(
                fontSize: 15,
                color: _mutedTextColor,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'How should this work?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 14),
            _buildModeSelector(),
            if (_isEditing) ...[
              const SizedBox(height: 10),
              Text(
                'The setup type cannot be changed after posting.',
                style: TextStyle(fontSize: 12, color: _mutedTextColor),
              ),
            ],
            const SizedBox(height: 24),
            Divider(color: _borderColor),
            const SizedBox(height: 22),
            _buildTitleField(),
            const SizedBox(height: 24),
            _buildSectionHeading(
              title: isPersonBased ? 'People' : 'Roles or Tasks',
              countLabel: isPersonBased
                  ? '${_people.length} people'
                  : '${_roleTasks.where((item) => item.titleController.text.trim().isNotEmpty).length} items',
            ),
            const SizedBox(height: 6),
            Text(
              isPersonBased
                  ? 'Plan members are included automatically. Remove anyone who is not involved, or add another name.'
                  : 'Add the roles or tasks your plan needs, set the available slots, and optionally pre-assign people.',
              style: TextStyle(
                fontSize: 12,
                color: _mutedTextColor,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            if (isPersonBased)
              _buildPeopleSection()
            else
              _buildRoleTaskSection(),
            const SizedBox(height: 26),
            _buildSettingsSection(),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitResponsibility,
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandYellow,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        _submitLabel,
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          _buildModeOption(
            mode: ResponsibilityMode.personBased,
            icon: Icons.groups_rounded,
            title: 'Start with people',
            description:
                'List people first, then add what each person will bring, share, or do.',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Divider(height: 1, color: _subtleBorderColor),
          ),
          _buildModeOption(
            mode: ResponsibilityMode.roleTaskBased,
            icon: Icons.assignment_ind_rounded,
            title: 'Start with roles or tasks',
            description:
                'List responsibilities first, then let people claim or respond to them.',
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption({
    required ResponsibilityMode mode,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final isSelected = _selectedMode == mode;
    final isDisabled = _isEditing || _isSubmitting;

    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: isDisabled ? null : () => _selectMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isSelected ? _accentSoftColor : _surfaceColor,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: isSelected ? brandYellow : Colors.transparent,
            width: 1.3,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? _accentCircleColor : _surfaceAltColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 21,
                color: isSelected ? _accentTextColor : _mutedTextColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: _mutedTextColor,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 21,
              color: isSelected ? brandYellow : _mutedTextColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return TextField(
      controller: _titleController,
      style: TextStyle(color: _textColor),
      cursorColor: brandYellow,
      enabled: !_isSubmitting,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: 'Title',
        hintText: _titleHint,
        labelStyle: TextStyle(color: _mutedTextColor, fontSize: 14),
        hintStyle: TextStyle(color: _mutedTextColor, fontSize: 14),
        prefixIcon: Icon(Icons.title_rounded, color: _mutedTextColor),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brandYellow, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSectionHeading({
    required String title,
    required String countLabel,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _textColor,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _accentSoftColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _accentBorderColor),
          ),
          child: Text(
            countLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _accentTextColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPeopleSection() {
    return Column(
      children: [
        if (_people.isEmpty)
          _buildEmptySection(
            icon: Icons.group_off_outlined,
            message: 'No one is included yet. Add a person below.',
          )
        else
          ...List.generate(_people.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildPersonRow(index),
            );
          }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _isSubmitting ? null : _addPerson,
            icon: Icon(
              Icons.person_add_alt_1_rounded,
              size: 19,
              color: brandYellow,
            ),
            label: Text(
              'Add person',
              style: TextStyle(
                color: brandYellow,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonRow(int index) {
    final person = _people[index];
    final isYou = _isCurrentUser(person.userId);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: person.isManual ? _surfaceAltColor : _accentCircleColor,
              shape: BoxShape.circle,
            ),
            child: Text(
              _initials(person.name),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: person.isManual ? _mutedTextColor : _accentTextColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildPersonIdentity(
              name: person.name,
              username: person.isManual ? null : person.username,
              isYou: isYou,
            ),
          ),
          IconButton(
            onPressed: _isSubmitting ? null : () => _removePerson(index),
            tooltip: 'Remove',
            icon: Icon(Icons.close, size: 21, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonIdentity({
    required String name,
    required String? username,
    required bool isYou,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: _textColor,
              ),
            ),
            if (isYou)
              Text(
                '(You)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _accentTextColor,
                ),
              ),
          ],
        ),
        if (username != null && username.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            _formatUsername(username),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _mutedTextColor,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRoleTaskSection() {
    return Column(
      children: [
        if (_roleTasks.isEmpty)
          _buildEmptySection(
            icon: Icons.assignment_outlined,
            message: 'No roles or tasks yet. Add one below.',
          )
        else
          ...List.generate(_roleTasks.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildRoleTaskCard(index),
            );
          }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _isSubmitting ? null : _addRoleTask,
            icon: Icon(Icons.add_rounded, size: 20, color: brandYellow),
            label: Text(
              'Add role or task',
              style: TextStyle(
                color: brandYellow,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleTaskCard(int index) {
    final item = _roleTasks[index];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _accentSoftestColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 29,
                height: 29,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _accentCircleColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: _accentTextColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Role or Task ${index + 1}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: _textColor,
                  ),
                ),
              ),
              IconButton(
                onPressed: _isSubmitting ? null : () => _removeRoleTask(index),
                tooltip: 'Remove',
                icon: Icon(Icons.close, size: 21, color: Colors.redAccent),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: item.titleController,
            style: TextStyle(color: _textColor),
            cursorColor: brandYellow,
            enabled: !_isSubmitting,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) {
              setState(() {});
            },
            decoration: InputDecoration(
              labelText: 'Role or task',
              hintText: 'e.g., Presenter, Buy materials',
              prefixIcon: Icon(
                Icons.assignment_ind_outlined,
                color: _mutedTextColor,
              ),
              filled: true,
              fillColor: _surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: brandYellow, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildSlotStepper(index),
          const SizedBox(height: 12),
          _buildPreAssignedSection(index),
        ],
      ),
    );
  }

  Widget _buildSlotStepper(int index) {
    final item = _roleTasks[index];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.groups_rounded, size: 20, color: _accentTextColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available slots',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _textColor,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'How many people can take this?',
                  style: TextStyle(fontSize: 10, color: _mutedTextColor),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isSubmitting ? null : () => _decreaseSlots(index),
            icon: Icon(Icons.remove_circle_outline_rounded),
            color: _accentTextColor,
          ),
          Text(
            '${item.slots}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: _textColor,
            ),
          ),
          IconButton(
            onPressed: _isSubmitting ? null : () => _increaseSlots(index),
            icon: Icon(Icons.add_circle_outline_rounded),
            color: _accentTextColor,
          ),
        ],
      ),
    );
  }

  Widget _buildPreAssignedSection(int index) {
    final item = _roleTasks[index];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pre-assign people',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Plan members can accept or decline. Names added manually are confirmed immediately.',
            style: TextStyle(fontSize: 10, color: _mutedTextColor, height: 1.3),
          ),
          if (item.preAssignedPeople.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...item.preAssignedPeople.map((person) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildPreAssignedPersonRow(
                  itemIndex: index,
                  person: person,
                ),
              );
            }),
          ],
          TextButton.icon(
            onPressed: _isSubmitting
                ? null
                : () => _addPreAssignedPerson(index),
            icon: Icon(
              Icons.person_add_alt_1_rounded,
              size: 18,
              color: brandYellow,
            ),
            label: Text(
              'Add person',
              style: TextStyle(
                color: brandYellow,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
          ),
        ],
      ),
    );
  }

  Widget _buildPreAssignedPersonRow({
    required int itemIndex,
    required ResponsibilitySelectedPerson person,
  }) {
    final isYou = _isCurrentUser(person.userId);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: _accentSoftestColor,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _accentBorderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: person.isManual ? _surfaceAltColor : _accentCircleColor,
              shape: BoxShape.circle,
            ),
            child: Text(
              _initials(person.name),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: person.isManual ? _mutedTextColor : _accentTextColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildPersonIdentity(
              name: person.name,
              username: person.isManual ? null : person.username,
              isYou: isYou,
            ),
          ),
          IconButton(
            onPressed: _isSubmitting
                ? null
                : () => _removePreAssignedPerson(itemIndex, person),
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close, size: 18, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySection({required IconData icon, required String message}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _accentSoftestColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accentBorderColor),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: _accentTextColor),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: _mutedTextColor,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    final isPersonBased = _selectedMode == ResponsibilityMode.personBased;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 14),
          _buildSwitchRow(
            label: isPersonBased
                ? 'Allow members to add people'
                : 'Allow members to add roles or tasks',
            description: isPersonBased
                ? 'Members can add another participant or name to this organizer.'
                : 'Members can suggest or add another responsibility.',
            value: _allowMembersAddItems,
            onChanged: (value) {
              setState(() {
                _allowMembersAddItems = value;
              });
            },
          ),
          Divider(height: 24, color: _subtleBorderColor),
          _buildSwitchRow(
            label: 'Show progress',
            description: isPersonBased
                ? 'Track how many people have filled in their entry.'
                : 'Track how many available slots have been filled.',
            value: _showProgress,
            onChanged: (value) {
              setState(() {
                _showProgress = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow({
    required String label,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: TextStyle(
                  fontSize: 11,
                  color: _mutedTextColor,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: value,
          activeThumbColor: brandYellow,
          activeTrackColor: brandYellow.withValues(alpha: 0.35),
          onChanged: _isSubmitting ? null : onChanged,
        ),
      ],
    );
  }
}
