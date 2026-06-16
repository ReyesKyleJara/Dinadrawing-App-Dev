import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/auth_service.dart';
import '../../../services/plan_service.dart';

class MembersPage extends StatefulWidget {
  final int planId;

  const MembersPage({super.key, required this.planId});

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  static const Color brandYellow = Color(0xFFF5B335);
  static const Color brandYellowDark = Color(0xFFD6901A);

  List<Map<String, dynamic>> members = [];

  String inviteCode = '...';

  bool isLoading = true;
  String? errorMessage;

  int? _currentUserId;
  int? _planAdminId;
  final Set<int> _removingMemberIds = <int>{};

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  int? _parseNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString());
  }

  bool _parseBool(dynamic value, {bool fallback = false}) {
    if (value == null) {
      return fallback;
    }

    if (value is bool) {
      return value;
    }

    if (value is int) {
      return value == 1;
    }

    final text = value.toString().trim().toLowerCase();

    return text == 'true' || text == '1';
  }

  Map<String, dynamic> _normaliseMember(dynamic rawMember) {
    if (rawMember is! Map) {
      return <String, dynamic>{};
    }

    final member = Map<String, dynamic>.from(rawMember);

    final nestedUser = member['user'];

    if (nestedUser is Map) {
      final user = Map<String, dynamic>.from(nestedUser);

      member['user_id'] ??= user['id'];
      member['name'] ??= user['name'];
      member['username'] ??= user['username'];
      member['email'] ??= user['email'];
      member['photo_url'] ??=
          user['photo_url'] ?? user['profile_photo_url'] ?? user['avatar_url'];
    }

    return member;
  }

  int? _getMemberId(Map<String, dynamic> member) {
    final nestedUser = member['user'];

    if (nestedUser is Map) {
      final nestedId = _parseNullableInt(nestedUser['id']);

      if (nestedId != null) {
        return nestedId;
      }
    }

    return _parseNullableInt(member['user_id'] ?? member['id']);
  }

  String _getMemberName(Map<String, dynamic> member) {
    final name = member['name']?.toString().trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    final username = member['username']?.toString().trim();

    if (username != null && username.isNotEmpty) {
      return username.replaceFirst('@', '');
    }

    final email = member['email']?.toString().trim();

    if (email != null && email.isNotEmpty) {
      return email;
    }

    return 'Unknown';
  }

  String? _getMemberUsername(Map<String, dynamic> member) {
    final username = member['username']?.toString().trim();

    if (username == null || username.isEmpty) {
      return null;
    }

    if (username.startsWith('@')) {
      return username;
    }

    return '@$username';
  }

  String? _getMemberPhotoUrl(Map<String, dynamic> member) {
    final possibleValues = [
      member['photo_url'],
      member['profile_photo_url'],
      member['avatar_url'],
      member['image_url'],
    ];

    for (final value in possibleValues) {
      final url = value?.toString().trim();

      if (url != null && url.isNotEmpty) {
        return url;
      }
    }

    return null;
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

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String _normaliseRole(dynamic value) {
    return value
            ?.toString()
            .trim()
            .toLowerCase()
            .replaceAll('_', ' ')
            .replaceAll('-', ' ') ??
        '';
  }

  bool _isPlanAdmin(Map<String, dynamic> member) {
    final pivot = member['pivot'];

    final pivotRole = pivot is Map ? _normaliseRole(pivot['role']) : '';

    final directRole = _normaliseRole(member['role']);

    final memberType = _normaliseRole(
      member['member_type'] ?? member['memberType'],
    );

    return _parseBool(member['is_plan_admin'] ?? member['isPlanAdmin']) ||
        pivotRole == 'admin' ||
        pivotRole == 'plan admin' ||
        pivotRole == 'owner' ||
        pivotRole == 'creator' ||
        directRole == 'admin' ||
        directRole == 'plan admin' ||
        directRole == 'owner' ||
        directRole == 'creator' ||
        memberType == 'admin' ||
        memberType == 'plan admin';
  }

  bool _sameMember(Map<String, dynamic> first, Map<String, dynamic> second) {
    final firstId = _getMemberId(first);
    final secondId = _getMemberId(second);

    if (firstId != null && secondId != null) {
      return firstId == secondId;
    }

    final firstUsername = first['username']?.toString().trim().toLowerCase();

    final secondUsername = second['username']?.toString().trim().toLowerCase();

    if (firstUsername != null &&
        firstUsername.isNotEmpty &&
        secondUsername != null &&
        secondUsername.isNotEmpty) {
      return firstUsername == secondUsername;
    }

    final firstEmail = first['email']?.toString().trim().toLowerCase();

    final secondEmail = second['email']?.toString().trim().toLowerCase();

    if (firstEmail != null &&
        firstEmail.isNotEmpty &&
        secondEmail != null &&
        secondEmail.isNotEmpty) {
      return firstEmail == secondEmail;
    }

    return false;
  }

  bool get _currentUserIsPlanAdmin {
    return _currentUserId != null &&
        _planAdminId != null &&
        _currentUserId == _planAdminId;
  }

  bool _canRemoveMember(Map<String, dynamic> member) {
    final memberId = _getMemberId(member);

    return _currentUserIsPlanAdmin &&
        memberId != null &&
        memberId != _currentUserId &&
        !_isPlanAdmin(member);
  }

  Future<void> _fetchMembers() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final currentUserFuture = AuthService.getCurrentUser();
      final result = await PlanService.getPlanById(widget.planId);
      final currentUser = await currentUserFuture;

      final rawPlan = result['plan'];

      if (rawPlan is! Map) {
        throw Exception('Invalid plan information.');
      }

      final plan = Map<String, dynamic>.from(rawPlan);
      final combinedMembers = <Map<String, dynamic>>[];

      final rawMembers = plan['members'];

      if (rawMembers is List) {
        for (final rawMember in rawMembers) {
          final member = _normaliseMember(rawMember);

          if (member.isNotEmpty) {
            combinedMembers.add(member);
          }
        }
      }

      final adminId = _parseNullableInt(
        plan['admin_id'] ??
            plan['owner_id'] ??
            plan['creator_id'] ??
            plan['created_by'] ??
            plan['user_id'],
      );

      if (adminId != null) {
        for (final member in combinedMembers) {
          if (_getMemberId(member) == adminId) {
            member['is_plan_admin'] = true;
          }
        }
      }

      final possibleAdmin =
          plan['admin'] ??
          plan['owner'] ??
          plan['creator'] ??
          plan['created_by_user'];

      if (possibleAdmin is Map) {
        final separateAdmin = _normaliseMember(possibleAdmin);

        separateAdmin['is_plan_admin'] = true;

        final existingIndex = combinedMembers.indexWhere(
          (member) => _sameMember(member, separateAdmin),
        );

        if (existingIndex == -1) {
          combinedMembers.add(separateAdmin);
        } else {
          combinedMembers[existingIndex]['is_plan_admin'] = true;
          combinedMembers[existingIndex]['name'] ??= separateAdmin['name'];
          combinedMembers[existingIndex]['username'] ??=
              separateAdmin['username'];
          combinedMembers[existingIndex]['email'] ??= separateAdmin['email'];
          combinedMembers[existingIndex]['photo_url'] ??=
              separateAdmin['photo_url'];
        }
      }

      final uniqueMembers = <Map<String, dynamic>>[];

      for (final member in combinedMembers) {
        final existingIndex = uniqueMembers.indexWhere(
          (existing) => _sameMember(existing, member),
        );

        if (existingIndex == -1) {
          uniqueMembers.add(member);
          continue;
        }

        if (_isPlanAdmin(member)) {
          uniqueMembers[existingIndex]['is_plan_admin'] = true;
        }
      }

      uniqueMembers.sort((first, second) {
        final firstIsAdmin = _isPlanAdmin(first);
        final secondIsAdmin = _isPlanAdmin(second);

        if (firstIsAdmin != secondIsAdmin) {
          return firstIsAdmin ? -1 : 1;
        }

        final firstName = _getMemberName(first).toLowerCase();
        final secondName = _getMemberName(second).toLowerCase();
        final nameComparison = firstName.compareTo(secondName);

        if (nameComparison != 0) {
          return nameComparison;
        }

        final firstUsername = _getMemberUsername(first)?.toLowerCase() ?? '';
        final secondUsername = _getMemberUsername(second)?.toLowerCase() ?? '';

        return firstUsername.compareTo(secondUsername);
      });

      if (!mounted) {
        return;
      }

      setState(() {
        members = uniqueMembers;
        _planAdminId = adminId;
        _currentUserId = _parseNullableInt(currentUser?['id']);

        inviteCode = plan['invite_code']?.toString().trim() ?? 'No Code';

        if (inviteCode.isEmpty) {
          inviteCode = 'No Code';
        }

        isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
        errorMessage = 'Unable to load plan members.';
      });
    }
  }

  Future<void> _confirmRemoveMember(Map<String, dynamic> member) async {
    final memberId = _getMemberId(member);
    final name = _getMemberName(member);

    if (memberId == null || !_canRemoveMember(member)) {
      return;
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: colors.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_remove_alt_1_rounded,
              color: colors.onErrorContainer,
            ),
          ),
          title: Text(
            'Remove $name?',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            '$name will lose access to this plan. Their previous posts and '
            'budget history will remain for record purposes.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              child: const Text(
                'Remove Member',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _removingMemberIds.add(memberId);
    });

    final result = await PlanService.removePlanMember(
      planId: widget.planId,
      memberId: memberId,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _removingMemberIds.remove(memberId);
    });

    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Unable to remove this member.',
          ),
        ),
      );
      return;
    }

    setState(() {
      members.removeWhere((item) => _getMemberId(item) == memberId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['message']?.toString() ?? '$name was removed from the plan.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 100,
        leading: TextButton.icon(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_ios, size: 14, color: brandYellow),
          label: const Text(
            'Back',
            style: TextStyle(color: brandYellow, fontSize: 14),
          ),
          style: TextButton.styleFrom(padding: const EdgeInsets.only(left: 24)),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Members',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: colors.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'See plan members and invite new people.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 28),
              Expanded(child: _buildMembersContent()),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _showInviteDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandYellow,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: colors.surfaceContainerHighest,
                    disabledForegroundColor: colors.onSurfaceVariant,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Invite People',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMembersContent() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: brandYellow));
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.group_off_outlined,
              size: 44,
              color: colors.onSurfaceVariant.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 13,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _fetchMembers,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: TextButton.styleFrom(foregroundColor: brandYellowDark),
            ),
          ],
        ),
      );
    }

    if (members.isEmpty) {
      return Center(
        child: Text(
          'No members found.',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 13,
            color: colors.onSurfaceVariant,
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: brandYellow,
      onRefresh: _fetchMembers,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: members.length,
        separatorBuilder: (_, _) {
          return Divider(
            height: 1,
            color: colors.outlineVariant.withValues(alpha: 0.45),
          );
        },
        itemBuilder: (context, index) {
          return _buildMemberItem(members[index]);
        },
      ),
    );
  }

  Widget _buildMemberItem(Map<String, dynamic> member) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final name = _getMemberName(member);
    final username = _getMemberUsername(member);
    final photoUrl = _getMemberPhotoUrl(member);
    final isAdmin = _isPlanAdmin(member);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          _buildMemberAvatar(name: name, photoUrl: photoUrl, isAdmin: isAdmin),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                if (username != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  isAdmin ? 'Plan Admin' : 'Member',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          _buildMemberMenu(member: member, isAdmin: isAdmin),
        ],
      ),
    );
  }

  Widget _buildMemberAvatar({
    required String name,
    required String? photoUrl,
    required bool isAdmin,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 23,
          backgroundColor: isAdmin
              ? brandYellow.withValues(alpha: 0.20)
              : colors.surfaceContainerHighest,
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
          child: photoUrl == null
              ? Text(
                  _initials(name),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isAdmin ? brandYellowDark : colors.onSurface,
                  ),
                )
              : null,
        ),
        if (isAdmin)
          Positioned(
            right: -3,
            bottom: -2,
            child: Container(
              width: 19,
              height: 19,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: brandYellow,
                shape: BoxShape.circle,
                border: Border.all(color: colors.surface, width: 2),
              ),
              child: const Icon(
                Icons.star_rounded,
                size: 11,
                color: Colors.black,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMemberMenu({
    required Map<String, dynamic> member,
    required bool isAdmin,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final memberId = _getMemberId(member);
    final isRemoving =
        memberId != null && _removingMemberIds.contains(memberId);
    final canRemove = _canRemoveMember(member);

    if (isRemoving) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: Padding(
          padding: EdgeInsets.all(10),
          child: CircularProgressIndicator(strokeWidth: 2, color: brandYellow),
        ),
      );
    }

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz, color: colors.onSurfaceVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      offset: const Offset(0, 40),
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      onSelected: (value) async {
        final name = _getMemberName(member);

        if (value == 'message') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Messaging $name is coming soon.')),
          );
          return;
        }

        if (value == 'remove') {
          await _confirmRemoveMember(member);
        }
      },
      itemBuilder: (context) {
        return [
          PopupMenuItem<String>(
            value: 'message',
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 18,
                  color: colors.onSurface,
                ),
                const SizedBox(width: 12),
                Text(
                  'Message',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (canRemove)
            PopupMenuItem<String>(
              value: 'remove',
              child: Row(
                children: [
                  Icon(
                    Icons.remove_circle_outline,
                    size: 18,
                    color: colors.error,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Remove Member',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      color: colors.error,
                    ),
                  ),
                ],
              ),
            ),
        ];
      },
    );
  }

  Future<void> _showInviteDialog() async {
    final usernameController = TextEditingController();

    var isSending = false;
    String? inlineMessage;
    bool isSuccess = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSending,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> sendInvitation() async {
              if (isSending) {
                return;
              }

              final cleanUsername = usernameController.text.trim().replaceFirst(
                RegExp(r'^@+'),
                '',
              );

              if (cleanUsername.isEmpty) {
                setDialogState(() {
                  inlineMessage = 'Enter a username.';
                  isSuccess = false;
                });

                return;
              }

              setDialogState(() {
                isSending = true;
                inlineMessage = null;
                isSuccess = false;
              });

              final result = await PlanService.sendPlanInvitation(
                planId: widget.planId,
                username: cleanUsername,
              );

              if (!dialogContext.mounted) {
                return;
              }

              if (result['success'] == true) {
                setDialogState(() {
                  isSending = false;
                  inlineMessage = 'Invited!';
                  isSuccess = true;
                });

                usernameController.clear();
                return;
              }

              setDialogState(() {
                isSending = false;
                inlineMessage =
                    result['message']?.toString().trim().isNotEmpty == true
                    ? result['message'].toString().trim()
                    : 'Unable to send the invitation. Try again.';
                isSuccess = false;
              });
            }

            final theme = Theme.of(context);
            final colors = theme.colorScheme;
            final canSubmit =
                usernameController.text.trim().isNotEmpty && !isSending;

            return Dialog(
              backgroundColor: colors.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    24,
                    24,
                    24 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Invite New Member',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: colors.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: isSending
                                ? null
                                : () {
                                    Navigator.pop(dialogContext);
                                  },
                            icon: Icon(
                              Icons.close_rounded,
                              color: colors.onSurfaceVariant,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Invite someone directly using their exact username, or share the plan code.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'INVITE BY USERNAME',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: usernameController,
                              enabled: !isSending,
                              textInputAction: TextInputAction.send,
                              autocorrect: false,
                              enableSuggestions: false,
                              onChanged: (_) {
                                setDialogState(() {
                                  inlineMessage = null;
                                  isSuccess = false;
                                });
                              },
                              onSubmitted: (_) {
                                if (canSubmit) {
                                  sendInvitation();
                                }
                              },
                              decoration: InputDecoration(
                                hintText: 'username',
                                prefixText: '@',
                                filled: true,
                                fillColor: colors.surfaceContainerHighest
                                    .withValues(alpha: 0.45),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(11),
                                  borderSide: BorderSide(
                                    color: colors.outlineVariant,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(11),
                                  borderSide: BorderSide(
                                    color: colors.outlineVariant,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(11),
                                  borderSide: const BorderSide(
                                    color: brandYellow,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: canSubmit ? sendInvitation : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: brandYellow,
                                foregroundColor: Colors.black,
                                disabledBackgroundColor:
                                    colors.surfaceContainerHighest,
                                disabledForegroundColor:
                                    colors.onSurfaceVariant,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11),
                                ),
                              ),
                              child: isSending
                                  ? const SizedBox(
                                      width: 19,
                                      height: 19,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Text(
                                      'Invite',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      if (inlineMessage != null) ...[
                        const SizedBox(height: 9),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              isSuccess
                                  ? Icons.check_circle_rounded
                                  : Icons.error_outline_rounded,
                              size: 17,
                              color: isSuccess
                                  ? (theme.brightness == Brightness.dark
                                        ? Colors.greenAccent.shade400
                                        : Colors.green.shade700)
                                  : colors.error,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                inlineMessage!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isSuccess
                                      ? (theme.brightness == Brightness.dark
                                            ? Colors.greenAccent.shade400
                                            : Colors.green.shade700)
                                      : colors.error,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(color: colors.outlineVariant),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'OR',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(color: colors.outlineVariant),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'SHARE PLAN CODE',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest.withValues(
                            alpha: 0.35,
                          ),
                          border: Border.all(
                            color: brandYellow.withValues(alpha: 0.5),
                          ),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                inviteCode,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: colors.onSurface,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            TextButton.icon(
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: inviteCode),
                                );

                                if (!dialogContext.mounted) {
                                  return;
                                }

                                setDialogState(() {
                                  inlineMessage = 'Plan code copied!';
                                  isSuccess = true;
                                });
                              },
                              icon: const Icon(Icons.copy_rounded, size: 15),
                              label: const Text('Copy'),
                              style: TextButton.styleFrom(
                                foregroundColor: brandYellowDark,
                                backgroundColor: brandYellow.withValues(
                                  alpha: 0.14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    usernameController.dispose();
  }
}
