import 'package:flutter/material.dart';

class BlitzPollPage extends StatefulWidget {
  const BlitzPollPage({super.key});

  @override
  State<BlitzPollPage> createState() => _BlitzPollPageState();
}

class PollOption {
  final String name;
  int votes;

  PollOption({
    required this.name,
    this.votes = 0,
  });
}

class _BlitzPollPageState extends State<BlitzPollPage> {
  late List<PollOption> options;
  late int votingDuration;
  late int timeLeft;
  late bool pollActive;
  late bool timerStarted;

  @override
  void initState() {
    super.initState();
    options = [
      PollOption(name: 'KFC'),
      PollOption(name: 'McDonalds'),
    ];
    votingDuration = 30;
    timeLeft = votingDuration;
    pollActive = false;
    timerStarted = false;
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && pollActive) {
        setState(() {
          timeLeft--;
        });
        if (timeLeft > 0) {
          _startTimer();
        } else {
          setState(() {
            pollActive = false;
          });
          _showResultDialog();
        }
      }
    });
  }

  void _startPoll() {
    if (timeLeft <= 0 || pollActive) return;
    setState(() {
      pollActive = true;
      timerStarted = true;
    });
    _startTimer();
  }

  void _vote(int index) {
    if (pollActive) {
      setState(() {
        options[index].votes++;
      });
    }
  }

  int get totalVotes => options.fold(0, (sum, opt) => sum + opt.votes);

  void _addOption() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Add Option'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Enter option name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() {
                    options.add(
                      PollOption(name: controller.text),
                    );
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _editDuration() {
    final controller = TextEditingController(text: votingDuration.toString());
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Voting Duration'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Enter duration in seconds',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final value = int.tryParse(controller.text);
                if (value == null || value <= 0 || value > 60) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a duration between 1 and 60 seconds.'),
                    ),
                  );
                  return;
                }
                setState(() {
                  pollActive = false;
                  timerStarted = false;
                  votingDuration = value;
                  timeLeft = votingDuration;
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showResultDialog() {
    final winner = options.reduce((a, b) => a.votes > b.votes ? a : b);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Poll Result'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The winner is:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text(
              winner.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFFC107),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'with ${winner.votes} vote${winner.votes != 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FA),
        elevation: 0,
        shadowColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Blitz Poll',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                'Get instant opinions',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 16),
              // Description
              Text(
                'Vote fast! The option with the most votes in $votingDuration seconds wins. Don\'t keep the group waiting.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Duration',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$votingDuration sec',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: _editDuration,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.grey[100],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      child: const Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Poll Options
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1,
                ),
                itemCount: options.length,
                itemBuilder: (context, index) {
                  return _buildPollOptionCard(index);
                },
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _addOption,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Add option',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Results Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Current Results: (${pollActive ? '$timeLeft seconds left' : timerStarted && timeLeft > 0 ? '$timeLeft seconds left' : timeLeft == 0 ? 'Poll ended' : 'Ready to start'})',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        if (!pollActive && timeLeft > 0)
                          ElevatedButton(
                            onPressed: _startPoll,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFC107),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Start',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Results for each option
                    ...options.asMap().entries.map((entry) {
                      int idx = entry.key;
                      PollOption option = entry.value;
                      double percentage = totalVotes > 0
                          ? (option.votes / totalVotes) * 100
                          : 0;
                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${option.name}: ${percentage.toStringAsFixed(0)}% (${option.votes} vote${option.votes != 1 ? 's' : ''})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Progress Bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value:
                                  totalVotes > 0 ? option.votes / totalVotes : 0,
                              minHeight: 12,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getColorForIndex(idx),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Avatars
                          Row(
                            children: List.generate(
                              option.votes > 0 ? 1 : 0,
                              (i) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: _getColorForIndex(idx),
                                  child: Icon(
                                    Icons.person,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (idx < options.length - 1)
                            const SizedBox(height: 16),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPollOptionCard(int index) {
    final option = options[index];
    return GestureDetector(
      onTap: pollActive ? () => _vote(index) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: pollActive ? Colors.white : Colors.grey[100],
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: pollActive ? Colors.grey[200]! : Colors.grey[300]!,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: pollActive ? 0.03 : 0.01),
              blurRadius: pollActive ? 16 : 4,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              option.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _getColorForIndex(index).withValues(
                  alpha: pollActive ? 0.12 : 0.06,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${option.votes} vote${option.votes != 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: pollActive
                      ? _getColorForIndex(index)
                      : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForIndex(int index) {
    const colors = [
      Color(0xFFE53935), // Red for KFC
      Color(0xFF4CAF50), // Green for McDonalds
      Color(0xFF1E88E5), // Blue
      Color(0xFFFFA500), // Orange
    ];
    return colors[index % colors.length];
  }
}
