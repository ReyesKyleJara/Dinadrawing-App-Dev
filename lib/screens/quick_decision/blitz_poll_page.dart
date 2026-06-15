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
    _options = <PollOption>[];
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
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
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
            child: Text(
              'Add',
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
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
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
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
            child: Text(
              'Save',
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
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
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
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
            child: Text(
              'Save',
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
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
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
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
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
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
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
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
              child: Text(
                'Save',
                style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
              ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Player ${_currentPlayerIndex + 1} of ${_players.length}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
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
                              ? colorScheme.primaryContainer
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 22,
                              color: _turnOpen
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
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
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Choose one option',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
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
                                      ? colorScheme.tertiaryContainer
                                      : (_turnOpen
                                          ? colorScheme.surface
                                          : colorScheme.surfaceContainerLow),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected
                                        ? colorScheme.primary
                                        : colorScheme.outlineVariant,
                                    width: selected ? 1.8 : 1.2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _options[index].name,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: colorScheme.onSurface,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (selected)
                                      Icon(
                                        Icons.check_circle,
                                        color: colorScheme.primary,
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
                              backgroundColor: Theme.of(context).colorScheme.primary,
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
                              style: TextStyle(
                                color: colorScheme.onPrimary,
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
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Done',
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Blitz Poll',
          style: theme.textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
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
              Text(
                'Private turn-by-turn voting',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.groups_2_outlined, color: colorScheme.onSurface, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${_players.length} players',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
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
                          icon: Icon(Icons.edit, size: 16, color: colorScheme.onSurface),
                          label: Text(
                            'Edit',
                            style: TextStyle(
                              color: colorScheme.onSurface,
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
                          icon: Icon(Icons.schedule, size: 16, color: colorScheme.onSurface),
                          label: Text(
                            '${_votingDuration}s',
                            style: TextStyle(
                              color: colorScheme.onSurface,
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
                              backgroundColor: colorScheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                            ),
                            icon: Icon(Icons.add, color: colorScheme.onPrimary, size: 18),
                            label: Text(
                              'Add Option',
                              style: TextStyle(
                                color: colorScheme.onPrimary,
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
                              backgroundColor: colorScheme.secondary,
                              disabledBackgroundColor: colorScheme.surfaceContainerHighest,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                            ),
                            child: Text(
                              'Start Session',
                              style: TextStyle(
                                color: colorScheme.onSecondary,
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
              Text(
                'Options',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
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
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: colorScheme.outlineVariant),
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
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _editOption(index),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          splashRadius: 20,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        IconButton(
                          onPressed: () => _removeOption(index),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          splashRadius: 20,
                          color: colorScheme.error,
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
