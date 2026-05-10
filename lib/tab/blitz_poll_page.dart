import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BlitzPollPage extends StatefulWidget {
  const BlitzPollPage({super.key});

  @override
  State<BlitzPollPage> createState() => _BlitzPollPageState();
}

class PollOption {
  PollOption({required this.name, this.votes = 0});

  String name;
  int votes;
}

class Player {
  Player({required this.name, this.selectedOptionIndex});

  final String name;
  int? selectedOptionIndex;
}

class _BlitzPollPageState extends State<BlitzPollPage> {
  static const Color _accent = Color(0xFFF5B335);
  static const Color _pageBg = Color(0xFFF6F7FB);
  static const Color _ink = Color(0xFF1A1D23);

  late final List<Player> _players;
  late final List<PollOption> _options;

  int _votingDuration = 10;
  int _currentPlayerIndex = 0;
  int _timeLeft = 10;
  bool _sessionActive = false;
  bool _turnOpen = false;

  Timer? _countdownTimer;
  StateSetter? _voteDialogSetState;

  @override
  void initState() {
    super.initState();
    _players = <Player>[
      Player(name: 'Friend #1'),
      Player(name: 'Friend #2'),
      Player(name: 'Friend #3'),
      Player(name: 'Friend #4'),
    ];
    _options = <PollOption>[
      PollOption(name: 'KFC'),
      PollOption(name: 'McDonalds'),
      PollOption(name: 'Jollibee'),
    ];
    _timeLeft = _votingDuration;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  int get _totalVotes => _options.fold<int>(0, (sum, item) => sum + item.votes);

  void _refreshVoteDialog() {
    final dialogSetter = _voteDialogSetState;
    if (dialogSetter != null) {
      dialogSetter(() {});
    }
  }

  void _addOption() {
    final controller = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Option'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(
            hintText: 'Type option name',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _accent),
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) {
                return;
              }
              setState(() {
                _options.add(PollOption(name: value));
              });
              Navigator.pop(context);
            },
            child: const Text('Add', style: TextStyle(color: _ink)),
          ),
        ],
      ),
    );
  }

  void _editOption(int index) {
    final controller = TextEditingController(text: _options[index].name);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Option'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(
            hintText: 'Update option name',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _accent),
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) {
                return;
              }
              setState(() {
                _options[index].name = value;
              });
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: _ink)),
          ),
        ],
      ),
    );
  }

  void _removeOption(int index) {
    if (_options.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 2 options are required.')),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Option'),
        content: Text('Delete "${_options[index].name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _options.removeAt(index);
              });
              Navigator.pop(context);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _editDuration() {
    final controller = TextEditingController(text: _votingDuration.toString());

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Time Per Player'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Seconds (1-60)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _accent),
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value < 1 || value > 60) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a value between 1 and 60.')),
                );
                return;
              }
              setState(() {
                _votingDuration = value;
                _timeLeft = value;
              });
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: _ink)),
          ),
        ],
      ),
    );
  }

  void _editPlayerCount() {
    if (_sessionActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finish current session before editing players.')),
      );
      return;
    }

    final controller = TextEditingController(text: _players.length.toString());
    int tempCount = _players.length;

    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Set Number of Players'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(hintText: 'Players (2-12)'),
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null && parsed >= 2 && parsed <= 12) {
                    setDialogState(() {
                      tempCount = parsed;
                    });
                  }
                },
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filled(
                    onPressed: tempCount > 2
                        ? () {
                            setDialogState(() {
                              tempCount -= 1;
                              controller.text = tempCount.toString();
                              controller.selection = TextSelection.fromPosition(
                                TextPosition(offset: controller.text.length),
                              );
                            });
                          }
                        : null,
                    icon: const Icon(Icons.remove),
                    style: IconButton.styleFrom(backgroundColor: _accent),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    '$tempCount',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 14),
                  IconButton.filled(
                    onPressed: tempCount < 12
                        ? () {
                            setDialogState(() {
                              tempCount += 1;
                              controller.text = tempCount.toString();
                              controller.selection = TextSelection.fromPosition(
                                TextPosition(offset: controller.text.length),
                              );
                            });
                          }
                        : null,
                    icon: const Icon(Icons.add),
                    style: IconButton.styleFrom(backgroundColor: _accent),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _accent),
              onPressed: () {
                final value = int.tryParse(controller.text.trim());
                if (value == null || value < 2 || value > 12) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a value between 2 and 12.')),
                  );
                  return;
                }

                setState(() {
                  final updatedPlayers = List<Player>.generate(
                    value,
                    (index) => Player(name: 'Friend #${index + 1}'),
                  );

                  for (int i = 0;
                      i < updatedPlayers.length && i < _players.length;
                      i++) {
                    updatedPlayers[i].selectedOptionIndex =
                        _players[i].selectedOptionIndex;
                  }

                  _players
                    ..clear()
                    ..addAll(updatedPlayers);

                  if (_currentPlayerIndex >= _players.length) {
                    _currentPlayerIndex = _players.length - 1;
                  }
                });

                Navigator.pop(context);
              },
              child: const Text('Save', style: TextStyle(color: _ink)),
            ),
          ],
        ),
      ),
    );
  }

  void _startVotingSession() {
    _countdownTimer?.cancel();

    setState(() {
      _sessionActive = true;
      _currentPlayerIndex = 0;
      _timeLeft = _votingDuration;
      _turnOpen = true;

      for (final player in _players) {
        player.selectedOptionIndex = null;
      }
      for (final option in _options) {
        option.votes = 0;
      }
    });

    _showVotingModal();
    _startPlayerTimer();
  }

  void _startPlayerTimer() {
    _countdownTimer?.cancel();

    setState(() {
      _turnOpen = true;
      _timeLeft = _votingDuration;
    });
    _refreshVoteDialog();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (!_turnOpen) {
        timer.cancel();
        return;
      }

      if (_timeLeft > 1) {
        setState(() {
          _timeLeft -= 1;
        });
        _refreshVoteDialog();
      } else {
        _finishCurrentTurn();
      }
    });
  }

  void _finishCurrentTurn() {
    _countdownTimer?.cancel();
    setState(() {
      _timeLeft = 0;
      _turnOpen = false;
    });
    _refreshVoteDialog();
  }

  void _recordVote(int optionIndex) {
    if (!_turnOpen) {
      return;
    }

    final player = _players[_currentPlayerIndex];
    if (player.selectedOptionIndex != null) {
      return;
    }

    setState(() {
      player.selectedOptionIndex = optionIndex;
      _options[optionIndex].votes += 1;
    });
    _refreshVoteDialog();

    _finishCurrentTurn();
  }

  void _goNextPlayer() {
    if (_currentPlayerIndex < _players.length - 1) {
      setState(() {
        _currentPlayerIndex += 1;
      });
      _refreshVoteDialog();
      _startPlayerTimer();
      return;
    }

    _endVotingSession();
  }

  void _endVotingSession() {
    _countdownTimer?.cancel();

    setState(() {
      _sessionActive = false;
      _turnOpen = false;
    });

    Navigator.of(context).pop();
    _showResultsDialog();
  }

  void _showVotingModal() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            _voteDialogSetState = modalSetState;
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420, maxHeight: 620),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _players[_currentPlayerIndex].name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Player ${_currentPlayerIndex + 1} of ${_players.length}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _turnOpen
                              ? const Color(0xFFE9F1FF)
                              : const Color(0xFFF1F3F7),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 22,
                              color: _turnOpen
                                  ? const Color(0xFF2F6BDB)
                                  : const Color(0xFF8B92A5),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _turnOpen
                                    ? '${_timeLeft}s left to vote'
                                    : 'Time is up. Pass the phone.',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _turnOpen
                                      ? const Color(0xFF2F6BDB)
                                      : const Color(0xFF606A80),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Choose one option',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _options.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final selected =
                                _players[_currentPlayerIndex].selectedOptionIndex ==
                                    index;
                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _turnOpen
                                  ? () {
                                      _recordVote(index);
                                    }
                                  : null,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 13,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFFFFF1CC)
                                      : (_turnOpen
                                          ? Colors.white
                                          : const Color(0xFFF6F7FA)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected
                                        ? const Color(0xFFF5B335)
                                        : const Color(0xFFDCE1EC),
                                    width: selected ? 1.8 : 1.2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _options[index].name,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: _ink,
                                        ),
                                      ),
                                    ),
                                    if (selected)
                                      const Icon(
                                        Icons.check_circle,
                                        color: Color(0xFFE9A500),
                                        size: 20,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (!_turnOpen)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _accent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _goNextPlayer,
                            child: Text(
                              _currentPlayerIndex < _players.length - 1
                                  ? 'Next'
                                  : 'View Results',
                              style: const TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
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
    ).then((_) {
      _countdownTimer?.cancel();
      _voteDialogSetState = null;
      if (!mounted) {
        return;
      }
      setState(() {
        _sessionActive = false;
        _turnOpen = false;
      });
    });
  }

  void _showResultsDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session Results'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final pct = _totalVotes == 0
                  ? 0
                  : ((option.votes / _totalVotes) * 100).round();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            option.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          '${option.votes} vote${option.votes == 1 ? '' : 's'} • $pct%',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _getColorForIndex(index),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        minHeight: 9,
                        value: _totalVotes == 0 ? 0 : option.votes / _totalVotes,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getColorForIndex(index),
                        ),
                        backgroundColor: const Color(0xFFE7EBF3),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _accent),
            onPressed: () => Navigator.pop(context),
            child: const Text('Done', style: TextStyle(color: _ink)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Blitz Poll',
          style: TextStyle(
            color: _ink,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Private turn-by-turn voting',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF5E6678),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x140D1526),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.groups_2_outlined, color: _ink, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${_players.length} players',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _editPlayerCount,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            backgroundColor: const Color(0xFFF4F6FA),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.edit, size: 16, color: _ink),
                          label: const Text(
                            'Edit',
                            style: TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _editDuration,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            backgroundColor: const Color(0xFFF4F6FA),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.schedule, size: 16, color: _ink),
                          label: Text(
                            '${_votingDuration}s',
                            style: const TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _addOption,
                            style: FilledButton.styleFrom(
                              backgroundColor: _accent,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                            ),
                            icon: const Icon(Icons.add, color: _ink, size: 18),
                            label: const Text(
                              'Add Option',
                              style: TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: _sessionActive || _options.length < 2
                                ? null
                                : _startVotingSession,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1F9F63),
                              disabledBackgroundColor: const Color(0xFFC6CFD8),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                            ),
                            child: const Text(
                              'Start Session',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Options',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 10),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _options.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final option = _options[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: const Color(0xFFDCE1EC)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _getColorForIndex(index),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _ink,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _editOption(index),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          splashRadius: 20,
                          color: const Color(0xFF50607E),
                        ),
                        IconButton(
                          onPressed: () => _removeOption(index),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          splashRadius: 20,
                          color: const Color(0xFFCA3A3A),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getColorForIndex(int index) {
    const colors = <Color>[
      Color(0xFFE74C3C),
      Color(0xFF1F9F63),
      Color(0xFF357AE8),
      Color(0xFFF59E0B),
      Color(0xFF8B5CF6),
      Color(0xFF14B8A6),
    ];
    return colors[index % colors.length];
  }
}
