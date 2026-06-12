import 'dart:io';

import 'package:dinadrawing/screens/plans/plan_dashboard/create_poll.dart';
import 'package:dinadrawing/screens/plans/plan_dashboard/create_task.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../services/plan_service.dart';

class FeedTab extends StatefulWidget {
  final int planId;

  const FeedTab({
    super.key,
    required this.planId,
  });

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  List<Map<String, dynamic>> posts = [];

  bool isLoadingPosts = true;
  bool isSubmittingPost = false;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadPosts();
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

  Map<String, dynamic> _mapPostFromApi(dynamic item) {
    final post = Map<String, dynamic>.from(item as Map);
    final postType = post['post_type']?.toString() ?? 'text';

    return {
      'id': post['id'],
      'type': postType == 'poll' ? 'poll' : 'text',
      'name': _getUserDisplayName(post),
      'time': _formatPostTime(post['created_at']?.toString()),
      'content': post['content']?.toString() ?? '',
      'imageUrl': post['image_url']?.toString() ?? '',
      'question': post['poll_question']?.toString() ??
          post['content']?.toString() ??
          '',
      'options': _parseStringList(post['poll_options']),
      'endsOn': post['ends_on']?.toString() ?? '',
      'anonymous': _parseBool(post['anonymous'], fallback: true),
      'allowMultiple': _parseBool(post['allow_multiple']),
      'allowMembersAddOptions': _parseBool(
        post['allow_members_add_options'],
      ),
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
    };
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load posts: $e')),
      );
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

  Future<void> _voteOnPoll(Map<String, dynamic> post, int optionIndex) async {
    final postId = _parseInt(post['id'], fallback: -1);

    if (postId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid poll post.')),
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
            const SnackBar(
              content: Text('Select at least one option.'),
            ),
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

        setState(() {
          final postIndex = posts.indexWhere(
            (item) => _parseInt(item['id']) == postId,
          );

          if (postIndex != -1) {
            posts[postIndex] = updatedPost;
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to save vote.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection error: $e')),
      );
    }
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
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
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
                    content: Text('Please add text or an image before posting.'),
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
                    const SnackBar(
                      content: Text('Post created successfully!'),
                    ),
                  );
                } else {
                  final message =
                      result['message']?.toString() ?? 'Failed to create post.';

                  setModalState(() {
                    modalIsSubmitting = false;
                  });

                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(content: Text(message)),
                  );
                }
              } catch (e) {
                if (!mounted) return;

                setModalState(() {
                  modalIsSubmitting = false;
                });

                ScaffoldMessenger.of(parentContext).showSnackBar(
                  SnackBar(content: Text('Connection error: $e')),
                );
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
                          foregroundColor: const Color(0xFFF5B335),
                          padding: EdgeInsets.zero,
                        ),
                        child: modalIsSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFF5B335),
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
                                      color:
                                          Colors.black.withValues(alpha: 0.55),
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
                    'Create Poll',
                    modalIsSubmitting
                        ? () {}
                        : () {
                            Navigator.of(sheetContext).pop();
                            _openCreatePoll();
                          },
                  ),
                  _buildComposerOption(
                    Icons.content_paste,
                    'Create Task list',
                    modalIsSubmitting
                        ? () {}
                        : () {
                            Navigator.of(sheetContext).pop();
                            _openCreateTask();
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Poll added to feed.'),
        ),
      );
    }
  }

  void _openCreateTask() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateTask()),
    );

    if (result != null) {
      setState(() {
        posts.insert(0, {
          'type': 'task',
          'name': 'You',
          'time': 'Just now',
          ...result as Map<String, dynamic>,
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadPosts,
      color: const Color(0xFFF5B335),
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
                child: CircularProgressIndicator(
                  color: Color(0xFFF5B335),
                ),
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
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: 20,
              ),
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
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
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
          Icon(
            Icons.forum_outlined,
            size: 42,
            color: Colors.grey.shade400,
          ),
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
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
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
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostWrapper(Map<String, dynamic> post) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
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
              Icon(
                Icons.more_vert,
                color: Colors.grey.shade500,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (post['type'] == 'text') _buildTextBody(post),
          if (post['type'] == 'poll') _buildPollBody(post),
          if (post['type'] == 'task') _buildTaskBody(post),
          const SizedBox(height: 18),
          Divider(
            height: 1,
            color: Colors.grey.shade200,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {},
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.favorite_border,
                        size: 22,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Like',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 28),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {},
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 22,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Comment',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextBody(Map<String, dynamic> post) {
    final content = post['content']?.toString() ?? '';
    final imageUrl = post['imageUrl']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (content.trim().isNotEmpty)
          Text(
            content,
            style: const TextStyle(fontSize: 14),
          ),
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

    final String pollMeta = anonymous
        ? '$totalVotes total votes • Anonymous voting'
        : '$totalVotes total votes';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE7DFFF),
          width: 1,
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFBF8FF),
            Color(0xFFF3EEFF),
          ],
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
                  color: Color(0xFFE8DFFF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  size: 18,
                  color: Color(0xFF5D3FD3),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Poll',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF3C2A99),
                ),
              ),
              const Spacer(),
              if (endsOn.trim().isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE8A3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Ends in $endsOn',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ),
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
          const SizedBox(height: 16),
          if (options.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'No poll options available.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            )
          else
            ...options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;

              final percentage =
                  index < votePercentages.length ? votePercentages[index] : 0;

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
        ],
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

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF5D3FD3) : const Color(0xFFE8E3F6),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                color: Colors.white,
              ),
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      color: isSelected
                          ? const Color(0xFFE9DFFF)
                          : const Color(0xFFF3EEFF),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF5D3FD3)
                                : Colors.transparent,
                            shape: allowMultiple
                                ? BoxShape.rectangle
                                : BoxShape.circle,
                            borderRadius:
                                allowMultiple ? BorderRadius.circular(6) : null,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF5D3FD3)
                                  : Colors.grey.shade500,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 15,
                                  color: Colors.white,
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
                        Text(
                          '$percentage%',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF5D3FD3),
                          ),
                        ),
                      ],
                    ),
                    if (!anonymous && (voters.isNotEmpty || extraCount > 0)) ...[
                      const SizedBox(height: 10),
                      _buildPollVoterPreview(
                        voters: voters,
                        extraCount: extraCount,
                      ),
                    ],
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
                backgroundColor: const Color(0xFFE8DFFF),
                textColor: const Color(0xFF5D3FD3),
              ),
            ),
          if (extraCount > 0)
            Positioned(
              left: visibleCount * 18.0,
              child: _buildSmallVoterBubble(
                label: '+$extraCount',
                backgroundColor: const Color(0xFF5D3FD3),
                textColor: Colors.white,
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

  Widget _buildTaskBody(Map<String, dynamic> post) {
    List<String> tasks = List<String>.from(post['tasks']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text(
            'TASKS',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
        ...tasks.map((task) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(task, style: const TextStyle(fontSize: 14)),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5B335),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '@mention',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.add, size: 14, color: Colors.grey),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Add a new task...',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF5B335),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '@mention',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }
}