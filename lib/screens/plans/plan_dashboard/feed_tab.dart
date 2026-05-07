import 'package:flutter/material.dart';

class FeedTab extends StatelessWidget {
  const FeedTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildCreatePostBox(),
        const SizedBox(height: 16),
        // Sample Post matching your screenshot
        _buildPostCard(
          name: "andrea",
          time: "Mar 1, 2026 • 2:18 PM",
          content: "agahan!!!",
          avatarPath: 'images/avatar_female.png', // Change to your actual image
        ),
      ],
    );
  }

  Widget _buildCreatePostBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, color: Colors.white),
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
                  child: const Text("Type something..", style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(width: 48), // Indent to align with text box
              Icon(Icons.image_outlined, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 16),
              Icon(Icons.bar_chart, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 16),
              Icon(Icons.content_paste, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 16),
              Icon(Icons.more_horiz, size: 20, color: Colors.grey[600]),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPostCard({required String name, required String time, required String content, required String avatarPath}) {
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
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: AssetImage(avatarPath),
                    onBackgroundImageError: (_, __) {},
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(time, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                    ],
                  ),
                ],
              ),
              Icon(Icons.more_vert, color: Colors.grey[400], size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Text(content, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 16),
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
}