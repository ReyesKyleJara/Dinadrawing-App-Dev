import 'package:dinadrawing/screens/plans/plan_dashboard/create_poll.dart';
import 'package:dinadrawing/screens/plans/plan_dashboard/create_task.dart';
import 'package:flutter/material.dart';


class FeedTab extends StatefulWidget {
  const FeedTab({super.key});

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  // Ang dynamic memory ng feed natin!
  List<Map<String, dynamic>> posts = [
    // Default initial post para may laman
    {
      'type': 'text',
      'name': 'andrea',
      'time': 'Mar 1, 2026 • 2:18 PM',
      'content': 'agahan!!!',
    }
  ];

  // --- COMPOSER MODAL ACTIONS ---

  void _openMainComposer() {
    TextEditingController textCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // For almost full-screen modal
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        // Set height to about 90% of screen to match image style
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          children: [
            // --- HEADER ROW (Close | Title | Post) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close, color: Colors.black, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  "Create Post",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    if (textCtrl.text.isNotEmpty) {
                      setState(() {
                        posts.insert(0, {
                          'type': 'text',
                          'name': 'You',
                          'time': 'Just now',
                          'content': textCtrl.text,
                        });
                      });
                      Navigator.pop(context); // Close modal
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFF5B335), // The yellow from your design
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text("Post", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ),
            const Divider(),
            
            // --- CONTENT AREA (Avatar | Input) ---
            Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Andrea", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    Text("Just Now", style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: textCtrl,
                maxLines: null, // Makes it expand as you type
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

            // --- FOOTER (Add to post title | Selectable options) ---
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Add to your post",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 12),
            
            _buildComposerOption(
              Icons.image_outlined, 
              "Post photo", 
              () { 
                Navigator.pop(context); // Close composer first
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Photo upload coming soon!")));
              }
            ),
            _buildComposerOption(
              Icons.bar_chart, 
              "Create Poll", 
              () { 
                Navigator.pop(context); // Close composer first
                _openCreatePoll(); // Then open poll screen
              }
            ),
            _buildComposerOption(
              Icons.content_paste, 
              "Create Task list", 
              () { 
                Navigator.pop(context); // Close composer first
                _openCreateTask(); // Then open task screen
              }
            ),
          ],
        ),
      ),
    );
  }

  // --- Dynamic Route Handlers ---

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
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // FIXED: Shrunk this box by 2px on all sides for cleaner look
        _buildSimplifiedCreatePostBox(),
        const SizedBox(height: 24),
        
        // Render dynamic posts
        ...posts.map((post) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildPostWrapper(post),
          );
        }).toList(),
      ],
    );
  }

  // --- THE NEW MINIMALIST CLEAN POST BOX (Base design Turn 24) ---

  Widget _buildSimplifiedCreatePostBox() {
    return GestureDetector(
      onTap: _openMainComposer, // Tap anywhere inside the box opens the expanded modal
      child: Container(
        // FIXED: Reduced padding to horizontal:16, vertical:12 for Turn 24 clean look
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
                // Matches grey text in simplified box Turn 24
                child: const Text("Type something..", style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI Helpers ---

  Widget _buildComposerOption(IconData icon, String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.black87),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text, 
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // --- POST RENDERERS ---

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
          // Header (Profile & Time)
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
                      Text(post['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(post['time'], style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                    ],
                  ),
                ],
              ),
              Icon(Icons.more_vert, color: Colors.grey[400], size: 20),
            ],
          ),
          const SizedBox(height: 16),

          // Dynamic Body
          if (post['type'] == 'text') _buildTextBody(post),
          if (post['type'] == 'poll') _buildPollBody(post),
          if (post['type'] == 'task') _buildTaskBody(post),

          const SizedBox(height: 16),

          // Footer Actions
          Row(
            children: [
              Icon(Icons.favorite_border, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text("Like", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const SizedBox(width: 24),
              Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text("Comment", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTextBody(Map<String, dynamic> post) {
    return Text(post['content'], style: const TextStyle(fontSize: 14));
  }

  Widget _buildPollBody(Map<String, dynamic> post) {
    List<String> options = List<String>.from(post['options']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(post['question'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFDECB2), // Light yellow pill
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text("Ends in ${post['endsOn']}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
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
                const Icon(Icons.radio_button_unchecked, size: 18, color: Colors.grey),
                const SizedBox(width: 12),
                Text(opt, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          );
        }).toList(),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("0 total votes", style: TextStyle(fontSize: 11, color: Colors.grey)),
            if (post['anonymous'])
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                child: const Text("Anonymous", style: TextStyle(fontSize: 10, color: Colors.grey)),
              )
          ],
        )
      ],
    );
  }

  Widget _buildTaskBody(Map<String, dynamic> post) {
    List<String> tasks = List<String>.from(post['tasks']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(child: Text("TASKS", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
        const SizedBox(height: 16),
        ...tasks.map((task) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(task, style: const TextStyle(fontSize: 14)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5B335),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text("@mention", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }).toList(),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.add, size: 14, color: Colors.grey),
            const SizedBox(width: 8),
            const Expanded(child: Text("Add a new task...", style: TextStyle(fontSize: 13, color: Colors.grey))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF5B335),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text("@mention", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        )
      ],
    );
  }
}