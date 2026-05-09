import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para sa clipboard/copy function

class MembersPage extends StatefulWidget {
  const MembersPage({super.key});

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class MemberData {
  final String name;
  final String? role;
  final IconData avatarIcon;

  MemberData({required this.name, this.role, required this.avatarIcon});
}

class _MembersPageState extends State<MembersPage> {
  // Initial list of members based on your screenshot
  List<MemberData> members = [
    MemberData(name: "Andrea", role: "Plan Creator", avatarIcon: Icons.face_3),
    MemberData(name: "Samir", avatarIcon: Icons.face),
    MemberData(name: "Lena", avatarIcon: Icons.face_4),
    MemberData(name: "Carlos", avatarIcon: Icons.face_2),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB), // Light off-white background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 100,
        leading: TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, size: 14, color: Color(0xFFF5B335)),
          label: const Text('Back', style: TextStyle(color: Color(0xFFF5B335), fontSize: 14)),
          style: TextButton.styleFrom(padding: const EdgeInsets.only(left: 24)),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0), // Consistent 24px margin
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Members",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 4),
              const Text(
                "See plan members and invite new people.",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 32),

              // Expanded ListView para sa mga members
              Expanded(
                child: ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return _buildMemberItem(member, index);
                  },
                ),
              ),

              // Invite People Button sa bottom
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showInviteDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5B335),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Invite People",
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
      ),
    );
  }

  // --- UI Helper: Member Row with 3-dot Menu ---
  Widget _buildMemberItem(MemberData member, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.grey.shade200,
            child: Icon(member.avatarIcon, color: Colors.black87),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                if (member.role != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    member.role!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ]
              ],
            ),
          ),
          
          // 3-Dot Popup Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: Colors.grey),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            offset: const Offset(0, 40),
            color: Colors.white,
            elevation: 4,
            onSelected: (value) {
              if (value == 'remove') {
                setState(() {
                  members.removeAt(index); // Functionality to remove member
                });
              } else if (value == 'message') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Messaging ${member.name} coming soon!")),
                );
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'message',
                child: Row(
                  children: const [
                    Icon(Icons.chat_bubble_outline, size: 18, color: Colors.black87),
                    SizedBox(width: 12),
                    Text('Message', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'remove',
                child: Row(
                  children: const [
                    Icon(Icons.remove_circle_outline, size: 18, color: Colors.black87),
                    SizedBox(width: 12),
                    Text('Remove Member', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- UI Helper: Invite Dialog ---
  void _showInviteDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Invite New Member",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, size: 20, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "Share the plan code or link to invite others.",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),

                // Event Code Section
                const Text("EVENT CODE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFF5B335).withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "4MN3BL",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(const ClipboardData(text: "4MN3BL"));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Code copied!")));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5B335).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text("COPY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD6901A))),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Share Invite Link Section
                const Text("OR SHARE INVITE LINK", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "https://localhost/DINADRAWING/join...",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(const ClipboardData(text: "https://localhost/DINADRAWING/join/4MN3BL"));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link copied!")));
                        },
                        child: const Icon(Icons.copy, size: 16, color: Color(0xFFF5B335)),
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
  }
}