import 'package:dinadrawing/screens/plans/plan_dashboard/create_poll.dart';
import 'package:dinadrawing/screens/plans/plan_dashboard/create_task.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _loadPosts();
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
            ? postsData.map((item) {
                final post = item as Map<String, dynamic>;

                return {
                  'id': post['id'],
                  'type': 'text',
                  'name': _getUserDisplayName(post),
                  'time': _formatPostTime(post['created_at']?.toString()),
                  'content': post['content']?.toString() ?? '',
                };
              }).toList()
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

  void _openMainComposer() {
  final TextEditingController textCtrl = TextEditingController();
  final BuildContext parentContext = context;

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
          Future<void> submitPost() async {
            final content = textCtrl.text.trim();

            if (content.isEmpty || modalIsSubmitting) {
              return;
            }

            setModalState(() {
              modalIsSubmitting = true;
            });

            try {
              final result = await PlanService.createPlanPost(
                planId: widget.planId,
                content: content,
              );

              if (!mounted) return;

              if (result['post'] != null) {
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

                if (!mounted) return;

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
                      "Create Post",
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
                              "Post",
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
                          "You",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Just Now",
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

                const Divider(),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Add to your post",
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
                  "Post photo",
                  () {
                    Navigator.of(sheetContext).pop();
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      const SnackBar(
                        content: Text("Photo upload coming soon!"),
                      ),
                    );
                  },
                ),
                _buildComposerOption(
                  Icons.bar_chart,
                  "Create Poll",
                  () {
                    Navigator.of(sheetContext).pop();
                    _openCreatePoll();
                  },
                ),
                _buildComposerOption(
                  Icons.content_paste,
                  "Create Task list",
                  () {
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
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreatePoll()),
    );

    if (result != null) {
      setState(() {
        posts.insert(0, {
          'type': 'poll',
          'name': 'You',
          'time': 'Just now',
          ...result as Map<String, dynamic>,
        });
      });
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
                  "Type something..",
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
                    radius: 18,
                    backgroundColor: Colors.grey.shade200,
                    child: const Icon(Icons.person, color: Colors.black54),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post['name']?.toString() ?? 'User',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        post['time']?.toString() ?? '',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Icon(Icons.more_vert, color: Colors.grey[400], size: 20),
            ],
          ),
          const SizedBox(height: 16),

          if (post['type'] == 'text') _buildTextBody(post),
          if (post['type'] == 'poll') _buildPollBody(post),
          if (post['type'] == 'task') _buildTaskBody(post),

          const SizedBox(height: 16),

          Row(
            children: [
              Icon(Icons.favorite_border, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                "Like",
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(width: 24),
              Icon(
                Icons.chat_bubble_outline,
                size: 18,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                "Comment",
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextBody(Map<String, dynamic> post) {
    return Text(
      post['content']?.toString() ?? '',
      style: const TextStyle(fontSize: 14),
    );
  }

  Widget _buildPollBody(Map<String, dynamic> post) {
    List<String> options = List<String>.from(post['options']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          post['question'],
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFDECB2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "Ends in ${post['endsOn']}",
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
        ...options.map((opt) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.radio_button_unchecked,
                  size: 18,
                  color: Colors.grey,
                ),
                const SizedBox(width: 12),
                Text(
                  opt,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "0 total votes",
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            if (post['anonymous'] == true)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "Anonymous",
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTaskBody(Map<String, dynamic> post) {
    List<String> tasks = List<String>.from(post['tasks']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text(
            "TASKS",
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
                    "@mention",
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
                "Add a new task...",
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
                "@mention",
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }
}