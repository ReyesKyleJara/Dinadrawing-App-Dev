import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../services/auth_service.dart';
import '../../../services/plan_service.dart';
import 'create_poll.dart';
import 'create_responsibility.dart';
import 'responsibility_post.dart';

class FeedTab extends StatefulWidget {
  final int planId;

  const FeedTab({super.key, required this.planId});

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  List<Map<String, dynamic>> posts = [];

  List<Map<String, dynamic>> planMembers = [];
  int? currentUserId;

  bool isLoadingPosts = true;
  bool isSubmittingPost = false;

  final ImagePicker _imagePicker = ImagePicker();

  static const Color brandYellow = Color(0xFFF5B335);
  static const Color brandYellowDark = Color(0xFFB87500);
  static const Color brandCreamLight = Color(0xFFFFFCF4);

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _loadPlanMembers();
  }

  int _parseInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? fallback;
  }

  List<int> _parseIntList(dynamic value) {
    if (value is List) {
      return value.map((item) => _parseInt(item)).toList();
    }

    return <int>[];
  }

  List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList();
    }

    return <String>[];
  }

  List<Map<String, dynamic>> _parseMapList(dynamic value) {
    if (value is! List) {
      return <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<List<Map<String, dynamic>>> _parseVoterPreviewGroups(dynamic value) {
    if (value is! List) {
      return <List<Map<String, dynamic>>>[];
    }

    return value.map<List<Map<String, dynamic>>>((group) {
      if (group is! List) {
        return <Map<String, dynamic>>[];
      }

      return group.map<Map<String, dynamic>>((item) {
        if (item is Map) {
          return Map<String, dynamic>.from(item);
        }

        return <String, dynamic>{};
      }).toList();
    }).toList();
  }

  bool _parseBool(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is int) return value == 1;

    final text = value.toString().toLowerCase();

    return text == 'true' || text == '1';
  }

  int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;

    return int.tryParse(value.toString());
  }

  String _getMemberDisplayName(Map<String, dynamic> member) {
    final name = member['name']?.toString();
    final username = member['username']?.toString();
    final email = member['email']?.toString();

    if (name != null && name.trim().isNotEmpty) {
      return name.trim();
    }

    if (username != null && username.trim().isNotEmpty) {
      return username.trim();
    }

    if (email != null && email.trim().isNotEmpty) {
      return email.trim();
    }

    return 'Member';
  }

  Future<void> _loadPlanMembers() async {
    try {
      final user = await AuthService.getCurrentUser();
      final result = await PlanService.getPlanById(widget.planId);

      if (!mounted) return;

      final currentId = _parseNullableInt(user?['id']);
      final parsedMembers = <Map<String, dynamic>>[];

      void addMember(dynamic rawMember) {
        if (rawMember is! Map) return;

        final member = Map<String, dynamic>.from(rawMember);
        final memberId = _parseNullableInt(member['id'] ?? member['user_id']);

        final alreadyAdded = parsedMembers.any((existing) {
          final existingId = _parseNullableInt(
            existing['id'] ?? existing['user_id'],
          );

          if (memberId != null && existingId != null) {
            return memberId == existingId;
          }

          final existingUsername = existing['username']
              ?.toString()
              .trim()
              .toLowerCase();

          final memberUsername = member['username']
              ?.toString()
              .trim()
              .toLowerCase();

          return existingUsername != null &&
              existingUsername.isNotEmpty &&
              existingUsername == memberUsername;
        });

        if (alreadyAdded) return;

        parsedMembers.add({
          ...member,
          'displayName': _getMemberDisplayName(member),
        });
      }

      final plan = result['plan'];

      if (plan is Map) {
        final planMap = Map<String, dynamic>.from(plan);
        final rawMembers = planMap['members'];

        if (rawMembers is List) {
          for (final member in rawMembers) {
            addMember(member);
          }
        }

        // Include the plan admin if returned separately.
        addMember(planMap['admin']);
      }

      // Make sure the current user is included with the real name/username.
      addMember(user);

      parsedMembers.sort((a, b) {
        final aId = _parseNullableInt(a['id'] ?? a['user_id']);
        final bId = _parseNullableInt(b['id'] ?? b['user_id']);

        final aIsYou = currentId != null && aId == currentId;
        final bIsYou = currentId != null && bId == currentId;

        if (aIsYou && !bIsYou) return -1;
        if (!aIsYou && bIsYou) return 1;

        return _getMemberDisplayName(
          a,
        ).toLowerCase().compareTo(_getMemberDisplayName(b).toLowerCase());
      });

      setState(() {
        currentUserId = currentId;
        planMembers = parsedMembers;
      });
    } catch (error) {
      debugPrint('Failed to load plan members: $error');
    }
  }

  Map<String, dynamic> _mapPostFromApi(dynamic item) {
    final post = Map<String, dynamic>.from(item as Map);

    final postType = post['post_type']?.toString() ?? 'text';

    String mappedType = 'text';

    if (postType == 'poll') {
      mappedType = 'poll';
    } else if (postType == 'responsibility') {
      mappedType = 'responsibility';
    }

    final responsibilityItems = _parseMapList(
      post['responsibility_items'] ?? post['responsibilityItems'],
    );

    return {
      'id': post['id'],
      'type': mappedType,
      'rawPost': post,

      'name': _getUserDisplayName(post),
      'time': _formatPostTime(post['created_at']?.toString()),
      'content': post['content']?.toString() ?? '',
      'imageUrl': post['image_url']?.toString() ?? '',
      'commentCount': _parseInt(post['comment_count']),

      'isPinned': _parseBool(post['is_pinned_value'] ?? post['is_pinned']),
      'isPlanAdmin': _parseBool(post['is_plan_admin']),
      'isPostOwner': _parseBool(post['is_post_owner']),
      'canPinPost': _parseBool(post['can_pin_post']),
      'canDeletePost': _parseBool(post['can_delete_post']),

      'question':
          post['poll_question']?.toString() ??
          post['content']?.toString() ??
          '',
      'options': _parseStringList(post['poll_options']),
      'endsOn': post['ends_on']?.toString() ?? '',
      'anonymous': _parseBool(post['anonymous'], fallback: false),
      'allowMultiple': _parseBool(post['allow_multiple']),
      'allowMembersAddOptions': _parseBool(post['allow_members_add_options']),
      'voteCounts': _parseIntList(post['vote_counts']),
      'votePercentages': _parseIntList(post['vote_percentages']),
      'userVotes': _parseIntList(post['user_votes']),
      'totalVotes': _parseInt(post['total_votes']),
      'optionVoterPreviews': _parseVoterPreviewGroups(
        post['option_voter_previews'],
      ),
      'optionVoterExtraCounts': _parseIntList(
        post['option_voter_extra_counts'],
      ),
      'canEditPoll': _parseBool(post['can_edit_poll']),
      'canToggleVoting': _parseBool(post['can_toggle_voting']),
      'votingStartsAt':
          post['voting_starts_at_value']?.toString() ??
          post['voting_starts_at']?.toString() ??
          '',
      'votingEndsAt':
          post['voting_ends_at_value']?.toString() ??
          post['voting_ends_at']?.toString() ??
          '',
      'isVotingClosed': _parseBool(
        post['is_voting_closed_value'] ?? post['is_voting_closed'],
      ),
      'votingStatus': post['voting_status']?.toString() ?? 'open',
      'canVote': _parseBool(post['can_vote'], fallback: true),
      'votingMessage': post['voting_message']?.toString() ?? '',

      'responsibilityTitle':
          post['responsibility_title']?.toString() ??
          post['content']?.toString() ??
          'Responsibilities',
      'responsibilityMode':
          post['responsibility_mode']?.toString() ?? 'person_based',
      'responsibilityItems': responsibilityItems,
      'responsibilityAllowMemberItems': _parseBool(
        post['responsibility_allow_member_items'],
      ),
      'responsibilityShowProgress': _parseBool(
        post['responsibility_show_progress'],
        fallback: true,
      ),
      'responsibilityIsFinalized': _parseBool(
        post['responsibility_is_finalized'],
      ),
      'responsibilityTotalCount': _parseInt(post['responsibility_total_count']),
      'responsibilityFilledCount': _parseInt(
        post['responsibility_filled_count'],
      ),
      'canManageResponsibility': _parseBool(post['can_manage_responsibility']),
      'canFinalizeResponsibility': _parseBool(
        post['can_finalize_responsibility'],
      ),
      'canAddResponsibilityItems': _parseBool(
        post['can_add_responsibility_items'],
      ),
    };
  }

  void _replacePostInList(Map<String, dynamic> updatedPost) {
    final updatedPostId = _parseInt(updatedPost['id']);

    setState(() {
      final index = posts.indexWhere(
        (item) => _parseInt(item['id']) == updatedPostId,
      );

      if (index != -1) {
        posts[index] = updatedPost;
      }

      final pinnedPosts = posts
          .where((post) => post['isPinned'] == true)
          .toList();

      final regularPosts = posts
          .where((post) => post['isPinned'] != true)
          .toList();

      posts = [...pinnedPosts, ...regularPosts];
    });
  }

  void _removePostFromList(int postId) {
    setState(() {
      posts.removeWhere((post) => _parseInt(post['id']) == postId);
    });
  }

  void _updatePostCommentCount(int postId, int commentCount) {
    if (!mounted) {
      return;
    }

    setState(() {
      final index = posts.indexWhere((post) => _parseInt(post['id']) == postId);

      if (index == -1) {
        return;
      }

      posts[index] = {
        ...posts[index],
        'commentCount': commentCount < 0 ? 0 : commentCount,
      };
    });
  }

  Future<void> _openCommentsSheet(Map<String, dynamic> post) async {
    final postId = _parseInt(post['id'], fallback: -1);

    if (postId <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid post.')));

      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _PostCommentsSheet(
          postId: postId,
          initialCommentCount: _parseInt(post['commentCount']),
          onCommentCountChanged: (count) {
            _updatePostCommentCount(postId, count);
          },
        );
      },
    );
  }

  Future<void> _loadPosts() async {
    setState(() {
      isLoadingPosts = true;
    });

    try {
      final result = await PlanService.getPlanPosts(widget.planId);
      final postsData = result['posts'];

      if (!mounted) return;

      setState(() {
        posts = postsData is List
            ? postsData.map((item) => _mapPostFromApi(item)).toList()
            : [];

        isLoadingPosts = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoadingPosts = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load posts: $e')));
    }
  }

  String _getUserDisplayName(Map<String, dynamic> post) {
    final user = post['user'];

    if (user is Map<String, dynamic>) {
      final name = user['name']?.toString();
      final username = user['username']?.toString();

      if (name != null && name.trim().isNotEmpty) {
        return name;
      }

      if (username != null && username.trim().isNotEmpty) {
        return username;
      }
    }

    return 'User';
  }

  String _formatPostTime(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) {
      return '';
    }

    try {
      final date = DateTime.parse(rawDate).toLocal();

      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];

      final hour = date.hour > 12
          ? date.hour - 12
          : date.hour == 0
          ? 12
          : date.hour;

      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';

      return '${months[date.month - 1]} ${date.day}, ${date.year} • $hour:$minute $period';
    } catch (_) {
      return rawDate;
    }
  }

  Future<void> _addOptionToPoll(Map<String, dynamic> post) async {
    final postId = _parseInt(post['id'], fallback: -1);

    if (postId <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid poll post.')));
      return;
    }

    final TextEditingController optionCtrl = TextEditingController();

    final option = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Add poll option',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: TextField(
            controller: optionCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter new option',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(optionCtrl.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: brandYellow,
                foregroundColor: Colors.black,
              ),
              child: const Text(
                'Add',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );

    optionCtrl.dispose();

    if (option == null || option.trim().isEmpty) return;

    try {
      final result = await PlanService.addPollOption(
        postId: postId,
        option: option,
      );

      if (!mounted) return;

      if (result['success'] == true && result['post'] != null) {
        final updatedPost = _mapPostFromApi(result['post']);

        _replacePostInList(updatedPost);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Option added.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to add option.')),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Connection error: $e')));
    }
  }

  Future<void> _voteOnPoll(Map<String, dynamic> post, int optionIndex) async {
    final postId = _parseInt(post['id'], fallback: -1);

    if (postId <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid poll post.')));
      return;
    }

    final canVote = post['canVote'] == true;
    final votingMessage = post['votingMessage']?.toString() ?? '';

    if (!canVote) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            votingMessage.isNotEmpty ? votingMessage : 'Voting is not open.',
          ),
        ),
      );
      return;
    }

    final allowMultiple = post['allowMultiple'] == true;

    final currentVotes = post['userVotes'] is List
        ? List<int>.from(post['userVotes'])
        : <int>[];

    List<int> nextVotes;

    if (allowMultiple) {
      nextVotes = [...currentVotes];

      if (nextVotes.contains(optionIndex)) {
        if (nextVotes.length == 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select at least one option.')),
          );
          return;
        }

        nextVotes.remove(optionIndex);
      } else {
        nextVotes.add(optionIndex);
      }
    } else {
      nextVotes = [optionIndex];
    }

    try {
      final result = await PlanService.votePollPost(
        postId: postId,
        optionIndexes: nextVotes,
      );

      if (!mounted) return;

      if (result['success'] == true && result['post'] != null) {
        final updatedPost = _mapPostFromApi(result['post']);

        _replacePostInList(updatedPost);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to save vote.')),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Connection error: $e')));
    }
  }

  Future<void> _togglePostPin(Map<String, dynamic> post) async {
    final postId = _parseInt(post['id'], fallback: -1);

    if (postId <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid post.')));
      return;
    }

    final nextPinnedState = post['isPinned'] != true;

    try {
      final result = await PlanService.togglePostPin(
        postId: postId,
        isPinned: nextPinnedState,
      );

      if (!mounted) return;

      if (result['success'] == true && result['post'] != null) {
        final updatedPost = _mapPostFromApi(result['post']);

        _replacePostInList(updatedPost);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              updatedPost['isPinned'] == true
                  ? 'Post pinned.'
                  : 'Post unpinned.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to update pin.')),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Connection error: $e')));
    }
  }

  Future<void> _togglePollVoting(Map<String, dynamic> post) async {
    final postId = _parseInt(post['id'], fallback: -1);

    if (postId <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid poll.')));
      return;
    }

    final nextClosedState = post['isVotingClosed'] != true;

    try {
      final result = await PlanService.togglePollVoting(
        postId: postId,
        isVotingClosed: nextClosedState,
      );

      if (!mounted) return;

      if (result['success'] == true && result['post'] != null) {
        final updatedPost = _mapPostFromApi(result['post']);

        _replacePostInList(updatedPost);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              updatedPost['isVotingClosed'] == true
                  ? 'Voting closed.'
                  : 'Voting reopened.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to update voting.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Connection error: $e')));
    }
  }

  Future<void> _toggleResponsibilityFinalized(Map<String, dynamic> post) async {
    final postId = _parseInt(post['id'], fallback: -1);

    if (postId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid responsibility post.')),
      );
      return;
    }

    final currentlyFinalized = post['responsibilityIsFinalized'] == true;

    final nextFinalizedState = !currentlyFinalized;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            nextFinalizedState
                ? 'Finalize responsibilities?'
                : 'Reopen responsibilities?',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          content: Text(
            nextFinalizedState
                ? 'Members will no longer be able to add entries, claim roles, or respond to assignments.'
                : 'Members will be able to update entries and claim or respond to roles again.',
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
                Navigator.of(dialogContext).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: brandYellow,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                nextFinalizedState ? 'Finalize' : 'Reopen',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      final result = await PlanService.toggleResponsibilityFinalized(
        postId: postId,
        isFinalized: nextFinalizedState,
      );

      if (!mounted) return;

      if (result['success'] == true && result['post'] is Map) {
        final updatedPost = _mapPostFromApi(result['post']);

        _replacePostInList(updatedPost);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? 'Failed to update responsibilities.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Connection error: $error')));
    }
  }

  Future<void> _deletePost(Map<String, dynamic> post) async {
    final postId = _parseInt(post['id'], fallback: -1);

    if (postId <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid post.')));
      return;
    }

    final type = post['type']?.toString() ?? 'text';

    final itemName = type == 'poll'
        ? 'poll'
        : type == 'responsibility'
        ? 'responsibility list'
        : 'post';

    final confirmed = await _showDeletePostConfirmation(itemName: itemName);

    if (confirmed != true || !mounted) return;

    try {
      final result = await PlanService.deletePost(postId: postId);

      if (!mounted) return;

      if (result['success'] == true) {
        _removePostFromList(postId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to delete post.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Connection error: $e')));
    }
  }

  Future<bool?> _showDeletePostConfirmation({required String itemName}) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'Delete $itemName?',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          content: Text(
            'This action cannot be undone. Are you sure you want to delete this $itemName?',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.35,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openEditPoll(Map<String, dynamic> post) async {
    final postId = _parseInt(post['id'], fallback: -1);

    if (postId <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid poll.')));
      return;
    }

    final totalVotes = _parseInt(post['totalVotes']);
    final hasVotes = totalVotes > 0;

    final questionController = TextEditingController(
      text: post['question']?.toString() ?? '',
    );

    final existingOptions = post['options'] is List
        ? List<String>.from(post['options'])
        : <String>[];

    final optionControllers = existingOptions
        .map((option) => TextEditingController(text: option))
        .toList();

    if (optionControllers.length < 2) {
      while (optionControllers.length < 2) {
        optionControllers.add(TextEditingController());
      }
    }

    final originalOptionCount = optionControllers.length;

    bool allowMultiple = post['allowMultiple'] == true;
    bool anonymous = post['anonymous'] == true;
    bool allowMembersAddOptions = post['allowMembersAddOptions'] == true;
    String endsOn = post['endsOn']?.toString() ?? '1 Week';

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            void addOptionField() {
              if (optionControllers.length >= 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('You can only add up to 10 options.'),
                  ),
                );
                return;
              }

              setModalState(() {
                optionControllers.add(TextEditingController());
              });
            }

            void removeOptionField(int index) {
              if (optionControllers.length <= 2) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('At least 2 options are required.'),
                  ),
                );
                return;
              }

              if (hasVotes && index < originalOptionCount) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Options cannot be edited after voting has started.',
                    ),
                  ),
                );
                return;
              }

              final controller = optionControllers[index];

              setModalState(() {
                optionControllers.removeAt(index);
              });

              controller.dispose();
            }

            void saveChanges() {
              final options = optionControllers
                  .map((controller) => controller.text.trim())
                  .where((option) => option.isNotEmpty)
                  .toList();

              if (questionController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a poll question.'),
                  ),
                );
                return;
              }

              if (options.length < 2) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please add at least two poll options.'),
                  ),
                );
                return;
              }

              Navigator.of(sheetContext).pop({
                'question': questionController.text.trim(),
                'options': options,
                'allowMultiple': allowMultiple,
                'anonymous': anonymous,
                'allowMembersAddOptions': allowMembersAddOptions,
                'endsOn': endsOn,
              });
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                18,
                24,
                MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: SizedBox(
                height: MediaQuery.of(sheetContext).size.height * 0.88,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Edit Poll',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasVotes
                          ? 'Options cannot be edited after voting has started.'
                          : 'You can still edit the question and options.',
                      style: TextStyle(
                        fontSize: 13,
                        color: hasVotes
                            ? brandYellowDark
                            : Colors.grey.shade600,
                        fontWeight: hasVotes
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: ListView(
                        children: [
                          TextField(
                            controller: questionController,
                            enabled: !hasVotes,
                            decoration: InputDecoration(
                              labelText: 'Poll Question',
                              helperText: hasVotes
                                  ? 'Question is locked because voting has started.'
                                  : null,
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
                          const SizedBox(height: 18),
                          const Text(
                            'Options',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...List.generate(optionControllers.length, (index) {
                            final isExistingLockedOption =
                                hasVotes && index < originalOptionCount;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: optionControllers[index],
                                      enabled: !isExistingLockedOption,
                                      decoration: InputDecoration(
                                        labelText: 'Option ${index + 1}',
                                        helperText: isExistingLockedOption
                                            ? 'Locked'
                                            : null,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: brandYellow,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () => removeOptionField(index),
                                    icon: Icon(
                                      Icons.close,
                                      color: isExistingLockedOption
                                          ? Colors.grey.shade300
                                          : Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          TextButton.icon(
                            onPressed: addOptionField,
                            icon: const Icon(Icons.add, color: brandYellow),
                            label: const Text(
                              'Add option',
                              style: TextStyle(
                                color: brandYellow,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Poll Settings',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildEditSwitchRow(
                            label: 'Allow multiple votes',
                            value: allowMultiple,
                            enabled: !hasVotes,
                            onChanged: (value) {
                              setModalState(() {
                                allowMultiple = value;
                              });
                            },
                          ),
                          if (hasVotes)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                'Multiple voting cannot be changed after voting has started.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          _buildEditSwitchRow(
                            label: 'Anonymous voting',
                            value: anonymous,
                            enabled: true,
                            onChanged: (value) {
                              setModalState(() {
                                anonymous = value;
                              });
                            },
                          ),
                          _buildEditSwitchRow(
                            label: 'Allow members to add options',
                            value: allowMembersAddOptions,
                            enabled: true,
                            onChanged: (value) {
                              setModalState(() {
                                allowMembersAddOptions = value;
                              });
                            },
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Ends on',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value:
                                    [
                                      '1 Day',
                                      '3 Days',
                                      '1 Week',
                                      'Custom',
                                    ].contains(endsOn)
                                    ? endsOn
                                    : '1 Week',
                                isExpanded: true,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: brandYellow,
                                ),
                                items:
                                    const [
                                      '1 Day',
                                      '3 Days',
                                      '1 Week',
                                      'Custom',
                                    ].map((value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.calendar_today_outlined,
                                              size: 18,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              value,
                                              style: const TextStyle(
                                                fontSize: 15,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                onChanged: (value) {
                                  if (value == null) return;

                                  setModalState(() {
                                    endsOn = value;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandYellow,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
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

    questionController.dispose();

    for (final controller in optionControllers) {
      controller.dispose();
    }

    if (result == null) return;

    try {
      final updateResult = await PlanService.updatePollPost(
        postId: postId,
        question: result['question']?.toString(),
        options: result['options'] is List
            ? List<String>.from(result['options'])
            : null,
        allowMultiple: result['allowMultiple'] == true,
        anonymous: result['anonymous'] == true,
        allowMembersAddOptions: result['allowMembersAddOptions'] == true,
        endsOn: result['endsOn']?.toString(),
      );

      if (!mounted) return;

      if (updateResult['success'] == true && updateResult['post'] != null) {
        final updatedPost = _mapPostFromApi(updateResult['post']);

        _replacePostInList(updatedPost);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Poll updated.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updateResult['message'] ?? 'Failed to update poll.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Connection error: $e')));
    }
  }

  Widget _buildEditSwitchRow({
    required String label,
    required bool value,
    required bool enabled,
    required Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: enabled ? Colors.black87 : Colors.grey.shade500,
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: brandYellow,
            activeTrackColor: brandYellow.withValues(alpha: 0.35),
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }

  void _openMainComposer() {
    final TextEditingController textCtrl = TextEditingController();
    final BuildContext parentContext = context;
    File? selectedImage;

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        bool modalIsSubmitting = false;

        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            Future<void> pickImage() async {
              final picked = await _imagePicker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 85,
                maxWidth: 1600,
              );

              if (picked == null) return;

              setModalState(() {
                selectedImage = File(picked.path);
              });
            }

            Future<void> submitPost() async {
              final content = textCtrl.text.trim();

              if ((content.isEmpty && selectedImage == null) ||
                  modalIsSubmitting) {
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Please add text or an image before posting.',
                    ),
                  ),
                );
                return;
              }

              setModalState(() {
                modalIsSubmitting = true;
              });

              try {
                final result = await PlanService.createPlanPost(
                  planId: widget.planId,
                  content: content,
                  imageFile: selectedImage,
                );

                if (!mounted) return;

                if (result['success'] == true && result['post'] != null) {
                  Navigator.of(sheetContext).pop();

                  await _loadPosts();

                  if (!mounted) return;

                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(content: Text('Post created successfully!')),
                  );
                } else {
                  final message =
                      result['message']?.toString() ?? 'Failed to create post.';

                  setModalState(() {
                    modalIsSubmitting = false;
                  });

                  ScaffoldMessenger.of(
                    parentContext,
                  ).showSnackBar(SnackBar(content: Text(message)));
                }
              } catch (e) {
                if (!mounted) return;

                setModalState(() {
                  modalIsSubmitting = false;
                });

                ScaffoldMessenger.of(
                  parentContext,
                ).showSnackBar(SnackBar(content: Text('Connection error: $e')));
              }
            }

            return Container(
              height: MediaQuery.of(sheetContext).size.height * 0.9,
              padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.black,
                          size: 20,
                        ),
                        onPressed: modalIsSubmitting
                            ? null
                            : () => Navigator.of(sheetContext).pop(),
                      ),
                      const Text(
                        'Create Post',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: modalIsSubmitting ? null : submitPost,
                        style: TextButton.styleFrom(
                          foregroundColor: brandYellow,
                          padding: EdgeInsets.zero,
                        ),
                        child: modalIsSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: brandYellow,
                                ),
                              )
                            : const Text(
                                'Post',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.grey,
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'You',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Just Now',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: textCtrl,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            decoration: const InputDecoration(
                              hintText: "What's on your mind?",
                              hintStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        if (selectedImage != null) ...[
                          const SizedBox(height: 12),
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.file(
                                  selectedImage!,
                                  width: double.infinity,
                                  height: 180,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: modalIsSubmitting
                                      ? null
                                      : () {
                                          setModalState(() {
                                            selectedImage = null;
                                          });
                                        },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.55,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Add to your post',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildComposerOption(
                    Icons.image_outlined,
                    selectedImage == null ? 'Post photo' : 'Change photo',
                    modalIsSubmitting ? () {} : pickImage,
                  ),
                  _buildComposerOption(
                    Icons.bar_chart,
                    'Decide With a Poll',
                    modalIsSubmitting
                        ? () {}
                        : () {
                            Navigator.of(sheetContext).pop();
                            _openCreatePoll();
                          },
                  ),
                  _buildComposerOption(
                    Icons.content_paste,
                    'Decide Who Does What',
                    modalIsSubmitting
                        ? () {}
                        : () {
                            Navigator.of(sheetContext).pop();
                            _openCreateResponsibility();
                          },
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      textCtrl.dispose();

      if (mounted) {
        setState(() {
          isSubmittingPost = false;
        });
      }
    });
  }

  void _openCreatePoll() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePoll(planId: widget.planId),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      await _loadPosts();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Poll added to feed.')));
    }
  }

  Future<void> _openCreateResponsibility({
    Map<String, dynamic>? editingPost,
  }) async {
    if (planMembers.isEmpty || currentUserId == null) {
      await _loadPlanMembers();
    }

    if (!mounted) return;

    Map<String, dynamic>? initialData;

    if (editingPost != null) {
      final rawPost = editingPost['rawPost'];

      if (rawPost is Map) {
        initialData = Map<String, dynamic>.from(rawPost);
      } else {
        initialData = Map<String, dynamic>.from(editingPost);
      }
    }

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => CreateResponsibility(
          planId: widget.planId,
          planMembers: planMembers,
          currentUserId: currentUserId,
          initialData: initialData,
        ),
      ),
    );

    if (!mounted || result == null) return;

    final mappedPost = _mapPostFromApi(result);

    if (editingPost == null) {
      setState(() {
        final firstUnpinnedIndex = posts.indexWhere(
          (post) => post['isPinned'] != true,
        );

        if (firstUnpinnedIndex == -1) {
          posts.add(mappedPost);
        } else {
          posts.insert(firstUnpinnedIndex, mappedPost);
        }
      });

      return;
    }

    _replacePostInList(mappedPost);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadPosts,
      color: brandYellow,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildSimplifiedCreatePostBox(),
          const SizedBox(height: 10),
          if (isLoadingPosts)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(
                child: CircularProgressIndicator(color: brandYellow),
              ),
            )
          else if (posts.isEmpty)
            _buildEmptyPostState()
          else
            ...posts.map((post) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildPostWrapper(post),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSimplifiedCreatePostBox() {
    return GestureDetector(
      onTap: _openMainComposer,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Type something..',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPostState() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(Icons.forum_outlined, size: 42, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'No posts yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Start the conversation by creating the first post.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildComposerOption(IconData icon, String text, VoidCallback onTap) {
    return InkWell(
      onTap: isSubmittingPost ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.black87),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  bool _hasPostMenu(Map<String, dynamic> post) {
    final type = post['type']?.toString();

    final isPoll = type == 'poll';
    final isResponsibility = type == 'responsibility';

    return post['canPinPost'] == true ||
        (isPoll && post['canEditPoll'] == true) ||
        (isPoll && post['canToggleVoting'] == true) ||
        (isResponsibility && post['canManageResponsibility'] == true) ||
        (isResponsibility && post['canFinalizeResponsibility'] == true) ||
        post['canDeletePost'] == true;
  }

  Widget _buildPostMenuButton(Map<String, dynamic> post) {
    final type = post['type']?.toString();

    final isPoll = type == 'poll';
    final isResponsibility = type == 'responsibility';
    final isPinned = post['isPinned'] == true;
    final isVotingClosed = post['isVotingClosed'] == true;
    final isResponsibilityFinalized = post['responsibilityIsFinalized'] == true;

    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_vert, color: Colors.grey.shade500, size: 22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) {
        switch (value) {
          case 'pin':
            _togglePostPin(post);
            break;
          case 'edit_poll':
            _openEditPoll(post);
            break;
          case 'toggle_voting':
            _togglePollVoting(post);
            break;
          case 'edit_responsibility':
            _openCreateResponsibility(editingPost: post);
            break;
          case 'toggle_responsibility':
            _toggleResponsibilityFinalized(post);
            break;
          case 'delete':
            _deletePost(post);
            break;
        }
      },
      itemBuilder: (context) {
        return [
          if (post['canPinPost'] == true)
            PopupMenuItem<String>(
              value: 'pin',
              child: Row(
                children: [
                  Icon(
                    isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 20,
                    color: Colors.black87,
                  ),
                  const SizedBox(width: 12),
                  Text(isPinned ? 'Unpin post' : 'Pin post'),
                ],
              ),
            ),
          if (isPoll && post['canEditPoll'] == true)
            const PopupMenuItem<String>(
              value: 'edit_poll',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 20, color: Colors.black87),
                  SizedBox(width: 12),
                  Text('Edit poll'),
                ],
              ),
            ),
          if (isPoll && post['canToggleVoting'] == true)
            PopupMenuItem<String>(
              value: 'toggle_voting',
              child: Row(
                children: [
                  Icon(
                    isVotingClosed
                        ? Icons.lock_open_outlined
                        : Icons.lock_outline,
                    size: 20,
                    color: Colors.black87,
                  ),
                  const SizedBox(width: 12),
                  Text(isVotingClosed ? 'Reopen voting' : 'Close voting'),
                ],
              ),
            ),
          if (isResponsibility && post['canManageResponsibility'] == true)
            const PopupMenuItem<String>(
              value: 'edit_responsibility',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 20, color: Colors.black87),
                  SizedBox(width: 12),
                  Text('Edit responsibilities'),
                ],
              ),
            ),
          if (isResponsibility && post['canFinalizeResponsibility'] == true)
            PopupMenuItem<String>(
              value: 'toggle_responsibility',
              child: Row(
                children: [
                  Icon(
                    isResponsibilityFinalized
                        ? Icons.lock_open_outlined
                        : Icons.check_circle_outline_rounded,
                    size: 20,
                    color: Colors.black87,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isResponsibilityFinalized
                        ? 'Reopen responsibilities'
                        : 'Finalize responsibilities',
                  ),
                ],
              ),
            ),
          if (post['canDeletePost'] == true)
            PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isPoll
                        ? 'Delete poll'
                        : isResponsibility
                        ? 'Delete responsibilities'
                        : 'Delete post',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ];
      },
    );
  }

  Widget _buildPostWrapper(Map<String, dynamic> post) {
    final isPinned = post['isPinned'] == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPinned ? brandYellow : Colors.grey.shade200,
          width: isPinned ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPinned) ...[
            Row(
              children: [
                const Icon(Icons.push_pin, size: 14, color: brandYellowDark),
                const SizedBox(width: 6),
                Text(
                  'Pinned',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.grey.shade200,
                    child: const Icon(
                      Icons.person,
                      color: Colors.black54,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post['name']?.toString() ?? 'User',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        post['time']?.toString() ?? '',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_hasPostMenu(post)) _buildPostMenuButton(post),
            ],
          ),
          const SizedBox(height: 18),
          if (post['type'] == 'text') _buildTextBody(post),
          if (post['type'] == 'poll') _buildPollBody(post),
          if (post['type'] == 'responsibility')
            ResponsibilityPost(
              post: post,
              planMembers: planMembers,
              currentUserId: currentUserId,
              onPostUpdated: (updatedPost) {
                final mappedPost = _mapPostFromApi(updatedPost);

                _replacePostInList(mappedPost);
              },
            ),
          const SizedBox(height: 18),
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.center,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                _openCommentsSheet(post);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 21,
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _commentActionLabel(_parseInt(post['commentCount'])),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _commentActionLabel(int commentCount) {
    if (commentCount <= 0) {
      return 'Comment';
    }

    if (commentCount == 1) {
      return '1 Comment';
    }

    return '$commentCount Comments';
  }

  Widget _buildTextBody(Map<String, dynamic> post) {
    final content = post['content']?.toString() ?? '';
    final imageUrl = post['imageUrl']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (content.trim().isNotEmpty)
          Text(content, style: const TextStyle(fontSize: 14)),
        if (content.trim().isNotEmpty && imageUrl.trim().isNotEmpty)
          const SizedBox(height: 12),
        if (imageUrl.trim().isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              imageUrl,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
      ],
    );
  }

  Widget _buildPollStatusChip({
    required String votingStatus,
    required String endsOn,
  }) {
    String label = '';
    Color backgroundColor = const Color(0xFFFFE8A3);
    Color textColor = Colors.black;

    if (votingStatus == 'closed') {
      label = 'Voting Closed';
      backgroundColor = const Color(0xFFFFE8E2);
      textColor = const Color(0xFFB42318);
    } else if (votingStatus == 'scheduled') {
      label = 'Scheduled';
      backgroundColor = const Color(0xFFFFE8A3);
      textColor = Colors.black;
    } else if (endsOn.trim().isNotEmpty) {
      final isCustomDate = endsOn.contains('•') || endsOn.contains(',');
      label = isCustomDate ? 'Ends $endsOn' : 'Ends in $endsOn';
      backgroundColor = const Color(0xFFFFE8A3);
      textColor = Colors.black;
    }

    if (label.isEmpty) {
      return const SizedBox.shrink();
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 185),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildPollBody(Map<String, dynamic> post) {
    final String question = post['question']?.toString() ?? 'Poll';

    final List<String> options = post['options'] is List
        ? List<String>.from(post['options'])
        : <String>[];

    final List<int> votePercentages = _parseIntList(post['votePercentages']);
    final List<int> userVotes = _parseIntList(post['userVotes']);

    final List<List<Map<String, dynamic>>> optionVoterPreviews =
        _parseVoterPreviewGroups(post['optionVoterPreviews']);

    final List<int> optionVoterExtraCounts = _parseIntList(
      post['optionVoterExtraCounts'],
    );

    final int totalVotes = _parseInt(post['totalVotes']);
    final String endsOn = post['endsOn']?.toString() ?? '';
    final bool anonymous = post['anonymous'] == true;
    final bool allowMultiple = post['allowMultiple'] == true;
    final bool allowMembersAddOptions = post['allowMembersAddOptions'] == true;

    final String votingStatus = post['votingStatus']?.toString() ?? 'open';
    final String votingMessage = post['votingMessage']?.toString() ?? '';

    final String pollMeta = anonymous
        ? '$totalVotes total votes • Anonymous voting'
        : '$totalVotes total votes';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brandCreamLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF2D999), width: 1),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFCF4), Color(0xFFFFF6DA)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE8A3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  size: 18,
                  color: brandYellowDark,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Poll',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: brandYellowDark,
                ),
              ),
              const Spacer(),
              _buildPollStatusChip(votingStatus: votingStatus, endsOn: endsOn),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            question,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            pollMeta,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
              height: 1.25,
            ),
          ),
          if (votingStatus == 'scheduled' && votingMessage.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              votingMessage,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: brandYellowDark,
                height: 1.25,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (options.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'No poll options available.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
            if (allowMembersAddOptions && votingStatus != 'closed') ...[
              const SizedBox(height: 10),
              _buildAddPollOptionButton(post),
            ],
          ] else ...[
            ...options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;

              final percentage = index < votePercentages.length
                  ? votePercentages[index]
                  : 0;

              final isSelected = userVotes.contains(index);

              final voters = index < optionVoterPreviews.length
                  ? optionVoterPreviews[index]
                  : <Map<String, dynamic>>[];

              final extraCount = index < optionVoterExtraCounts.length
                  ? optionVoterExtraCounts[index]
                  : 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildPollOptionCard(
                  option: option,
                  percentage: percentage,
                  isSelected: isSelected,
                  allowMultiple: allowMultiple,
                  anonymous: anonymous,
                  voters: voters,
                  extraCount: extraCount,
                  onTap: () => _voteOnPoll(post, index),
                ),
              );
            }),
            if (allowMembersAddOptions && votingStatus != 'closed')
              _buildAddPollOptionButton(post),
          ],
        ],
      ),
    );
  }

  Widget _buildAddPollOptionButton(Map<String, dynamic> post) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _addOptionToPoll(post),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF2D999), width: 1.3),
        ),
        child: const Row(
          children: [
            Icon(Icons.add_circle_outline, size: 22, color: brandYellowDark),
            SizedBox(width: 12),
            Text(
              'Add an option',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: brandYellowDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPollOptionCard({
    required String option,
    required int percentage,
    required bool isSelected,
    required bool allowMultiple,
    required bool anonymous,
    required List<Map<String, dynamic>> voters,
    required int extraCount,
    required VoidCallback onTap,
  }) {
    final progress = percentage.clamp(0, 100) / 100.0;
    final hasVoters = voters.isNotEmpty || extraCount > 0;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? brandYellow : const Color(0xFFF0E0B8),
            width: isSelected ? 1.7 : 1.4,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Container(width: double.infinity, color: Colors.white),
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      color: isSelected
                          ? const Color(0xFFFFE8A3)
                          : const Color(0xFFFFF1C7),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: isSelected ? brandYellow : Colors.transparent,
                        shape: allowMultiple
                            ? BoxShape.rectangle
                            : BoxShape.circle,
                        borderRadius: allowMultiple
                            ? BorderRadius.circular(6)
                            : null,
                        border: Border.all(
                          color: isSelected
                              ? brandYellow
                              : Colors.grey.shade500,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 15,
                              color: Colors.black,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        option,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (anonymous)
                      Text(
                        '$percentage%',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: brandYellowDark,
                        ),
                      )
                    else if (hasVoters)
                      _buildPollVoterPreview(
                        voters: voters,
                        extraCount: extraCount,
                      )
                    else
                      const SizedBox(width: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPollVoterPreview({
    required List<Map<String, dynamic>> voters,
    required int extraCount,
  }) {
    final visibleCount = voters.length;
    final totalBubbles = visibleCount + (extraCount > 0 ? 1 : 0);
    final width = totalBubbles <= 0 ? 0.0 : 24.0 + ((totalBubbles - 1) * 18.0);

    return SizedBox(
      height: 24,
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < visibleCount; i++)
            Positioned(
              left: i * 18.0,
              child: _buildSmallVoterBubble(
                label: _getInitials(voters[i]),
                backgroundColor: const Color(0xFFFFE8A3),
                textColor: brandYellowDark,
              ),
            ),
          if (extraCount > 0)
            Positioned(
              left: visibleCount * 18.0,
              child: _buildSmallVoterBubble(
                label: '+$extraCount',
                backgroundColor: brandYellow,
                textColor: Colors.black,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSmallVoterBubble({
    required String label,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: label.startsWith('+') ? 9 : 8.5,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }

  String _getInitials(Map<String, dynamic> voter) {
    final name = voter['name']?.toString().trim() ?? '';
    final username = voter['username']?.toString().trim() ?? '';

    final source = name.isNotEmpty ? name : username;

    if (source.isEmpty) return '?';

    final parts = source
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

class _PostCommentsSheet extends StatefulWidget {
  const _PostCommentsSheet({
    required this.postId,
    required this.initialCommentCount,
    required this.onCommentCountChanged,
  });

  final int postId;
  final int initialCommentCount;
  final ValueChanged<int> onCommentCountChanged;

  @override
  State<_PostCommentsSheet> createState() {
    return _PostCommentsSheetState();
  }
}

class _PostCommentsSheetState extends State<_PostCommentsSheet> {
  static const Color _brandYellow = Color(0xFFF5B335);
  static const Color _brandYellowDark = Color(0xFFB87500);

  final TextEditingController _commentController = TextEditingController();

  final FocusNode _commentFocusNode = FocusNode();

  final Set<int> _deletingCommentIds = <int>{};

  List<Map<String, dynamic>> _comments = <Map<String, dynamic>>[];

  bool _isLoading = true;
  bool _isSubmitting = false;

  String? _loadError;
  String? _submitError;

  @override
  void initState() {
    super.initState();

    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();

    super.dispose();
  }

  int? _asInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString());
  }

  bool _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final text = value?.toString().trim().toLowerCase();

    return text == 'true' || text == '1';
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  Future<void> _loadComments() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    final result = await PlanService.getPostComments(postId: widget.postId);

    if (!mounted) {
      return;
    }

    if (result['success'] != true) {
      setState(() {
        _isLoading = false;
        _loadError = result['message']?.toString().trim().isNotEmpty == true
            ? result['message'].toString().trim()
            : 'Unable to load comments.';
      });

      return;
    }

    final rawComments = result['comments'];

    final comments = rawComments is List
        ? rawComments
              .whereType<Map>()
              .map((comment) => Map<String, dynamic>.from(comment))
              .toList()
        : <Map<String, dynamic>>[];

    final count = _asInt(result['comment_count']) ?? comments.length;

    setState(() {
      _comments = comments;
      _isLoading = false;
      _loadError = null;
    });

    widget.onCommentCountChanged(count);
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();

    if (content.isEmpty || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    final result = await PlanService.addPostComment(
      postId: widget.postId,
      content: content,
    );

    if (!mounted) {
      return;
    }

    if (result['success'] != true || result['comment'] is! Map) {
      setState(() {
        _isSubmitting = false;
        _submitError = result['message']?.toString().trim().isNotEmpty == true
            ? result['message'].toString().trim()
            : 'Unable to add the comment.';
      });

      return;
    }

    final comment = Map<String, dynamic>.from(result['comment'] as Map);

    final count = _asInt(result['comment_count']) ?? (_comments.length + 1);

    setState(() {
      _comments = [..._comments, comment];
      _isSubmitting = false;
      _submitError = null;
      _commentController.clear();
    });

    widget.onCommentCountChanged(count);

    _commentFocusNode.requestFocus();
  }

  Future<void> _deleteComment(Map<String, dynamic> comment) async {
    final commentId = _asInt(comment['id']);

    if (commentId == null || _deletingCommentIds.contains(commentId)) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colors = theme.colorScheme;

        return AlertDialog(
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'Delete comment?',
            style: theme.textTheme.titleLarge?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'This comment will be permanently removed.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _deletingCommentIds.add(commentId);
    });

    final result = await PlanService.deletePostComment(commentId: commentId);

    if (!mounted) {
      return;
    }

    if (result['success'] != true) {
      setState(() {
        _deletingCommentIds.remove(commentId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Unable to delete the comment.',
          ),
        ),
      );

      return;
    }

    final count = _asInt(result['comment_count']) ?? (_comments.length - 1);

    setState(() {
      _deletingCommentIds.remove(commentId);

      _comments = _comments
          .where((item) => _asInt(item['id']) != commentId)
          .toList();
    });

    widget.onCommentCountChanged(count < 0 ? 0 : count);
  }

  String _displayName(Map<String, dynamic> comment) {
    final user = _asMap(comment['user']);

    final name = user?['name']?.toString().trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    final username = user?['username']?.toString().trim();

    if (username != null && username.isNotEmpty) {
      return username.startsWith('@') ? username : '@$username';
    }

    return 'Member';
  }

  String _initials(String value) {
    final parts = value
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

    return '${parts.first[0]}'
            '${parts.last[0]}'
        .toUpperCase();
  }

  String _timeAgo(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();

    if (date == null) {
      return '';
    }

    final difference = DateTime.now().difference(date);

    if (difference.inSeconds < 60) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours}h';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}d';
    }

    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.86,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Comments',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.outlineVariant),
            Expanded(child: _buildCommentBody()),
            Divider(height: 1, color: colors.outlineVariant),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: _brandYellow.withValues(alpha: 0.18),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 19,
                            color: _brandYellowDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            focusNode: _commentFocusNode,
                            enabled: !_isSubmitting,
                            minLines: 1,
                            maxLines: 5,
                            maxLength: 2000,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.newline,
                            onChanged: (_) {
                              if (_submitError != null) {
                                setState(() {
                                  _submitError = null;
                                });
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'Write a comment...',
                              counterText: '',
                              filled: true,
                              fillColor: colors.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: _brandYellow,
                                  width: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _isSubmitting ? null : _submitComment,
                          style: IconButton.styleFrom(
                            backgroundColor: _brandYellow,
                            foregroundColor: Colors.black,
                            disabledBackgroundColor:
                                colors.surfaceContainerHighest,
                          ),
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 19),
                        ),
                      ],
                    ),
                    if (_submitError != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _submitError!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentBody() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _brandYellow),
      );
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 42,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _loadComments,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: TextButton.styleFrom(foregroundColor: _brandYellowDark),
              ),
            ],
          ),
        ),
      );
    }

    if (_comments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: _brandYellow.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 31,
                  color: _brandYellowDark,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'No comments yet',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Start the conversation.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: _brandYellow,
      onRefresh: _loadComments,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _comments.length,
        separatorBuilder: (_, _) {
          return const SizedBox(height: 16);
        },
        itemBuilder: (context, index) {
          return _buildCommentCard(_comments[index]);
        },
      ),
    );
  }

  Widget _buildCommentCard(Map<String, dynamic> comment) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final commentId = _asInt(comment['id']);

    final deleting =
        commentId != null && _deletingCommentIds.contains(commentId);

    final canDelete = _asBool(comment['can_delete']);

    final displayName = _displayName(comment);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 19,
          backgroundColor: colors.surfaceContainerHighest,
          child: Text(
            _initials(displayName),
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(13, 10, 8, 10),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (deleting)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _brandYellowDark,
                          ),
                        ),
                      )
                    else if (canDelete)
                      PopupMenuButton<String>(
                        tooltip: 'Comment options',
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.more_horiz_rounded,
                          size: 20,
                          color: colors.onSurfaceVariant,
                        ),
                        onSelected: (value) {
                          if (value == 'delete') {
                            _deleteComment(comment);
                          }
                        },
                        itemBuilder: (_) {
                          return const [
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline_rounded,
                                    size: 19,
                                    color: Colors.redAccent,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Delete comment',
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                ],
                              ),
                            ),
                          ];
                        },
                      ),
                  ],
                ),
                Text(
                  comment['content']?.toString() ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _timeAgo(comment['created_at']),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
