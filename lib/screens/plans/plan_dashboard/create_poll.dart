import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/plan_service.dart';

enum PollTemplateType { blank, date, location }

class CreatePoll extends StatefulWidget {
  final int planId;
  final PollTemplateType initialTemplate;

  const CreatePoll({
    super.key,
    required this.planId,
    this.initialTemplate = PollTemplateType.blank,
  });

  @override
  State<CreatePoll> createState() => _CreatePollScreenState();
}

class _CreatePollScreenState extends State<CreatePoll> {
  static const Color _accent = Color(0xFFF5B335);

  ThemeData get _theme => Theme.of(context);
  ColorScheme get _colors => _theme.colorScheme;
  bool get _isDark => _theme.brightness == Brightness.dark;
  Color get _surfaceColor => _isDark ? const Color(0xFF202024) : Colors.white;
  Color get _fieldColor => _isDark ? const Color(0xFF29292E) : Colors.white;
  Color get _borderColor => _isDark ? Colors.white24 : Colors.grey.shade300;
  Color get _mutedTextColor => _colors.onSurfaceVariant;
  Color get _accentSoftColor =>
      _isDark ? const Color(0xFF3A3020) : const Color(0xFFFFF8E8);

  final TextEditingController _questionController = TextEditingController();

  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  PollTemplateType _selectedTemplate = PollTemplateType.blank;

  bool _allowMultiple = false;

  // Anonymous voting is OFF by default.
  bool _anonymous = false;

  bool _allowMembersAdd = false;
  bool _isSubmitting = false;

  bool _scheduleVotingStart = false;
  DateTime? _votingStartsAt;

  bool _setVotingDeadline = false;
  String _deadlineChoice = '1 Week';
  DateTime? _customVotingEndsAt;

  @override
  void initState() {
    super.initState();

    _selectedTemplate = widget.initialTemplate;
    _applyTemplate(_selectedTemplate, clearOptions: true);
  }

  @override
  void dispose() {
    _questionController.dispose();

    for (final controller in _optionControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  void _applyTemplate(PollTemplateType template, {bool clearOptions = false}) {
    if (clearOptions) {
      for (final controller in _optionControllers) {
        controller.clear();
      }
    }

    switch (template) {
      case PollTemplateType.blank:
        if (clearOptions) {
          _questionController.clear();
        }
        break;

      case PollTemplateType.date:
        _questionController.text = 'What date works best for this plan?';
        break;

      case PollTemplateType.location:
        _questionController.text = 'Where should we hold this plan?';
        break;
    }
  }

  void _selectTemplate(PollTemplateType template) {
    if (_isSubmitting) return;

    setState(() {
      _selectedTemplate = template;
      _applyTemplate(template, clearOptions: true);
    });
  }

  String get _templateName {
    switch (_selectedTemplate) {
      case PollTemplateType.blank:
        return 'Blank Poll';
      case PollTemplateType.date:
        return 'Date Poll';
      case PollTemplateType.location:
        return 'Location Poll';
    }
  }

  String get _pollKind {
    switch (_selectedTemplate) {
      case PollTemplateType.blank:
        return 'general';
      case PollTemplateType.date:
        return 'date';
      case PollTemplateType.location:
        return 'location';
    }
  }

  String _optionHint(int index) {
    switch (_selectedTemplate) {
      case PollTemplateType.blank:
        return 'Poll Option ${index + 1}';

      case PollTemplateType.date:
        if (index == 0) return 'e.g., Sat, Jun 7';
        if (index == 1) return 'e.g., Sun, Jun 8';
        return 'Select another date';

      case PollTemplateType.location:
        if (index == 0) return 'e.g., SM Baliwag';
        if (index == 1) return 'e.g., PUP Santa Maria';
        return 'Enter another place';
    }
  }

  IconData _optionIcon() {
    switch (_selectedTemplate) {
      case PollTemplateType.blank:
        return Icons.radio_button_unchecked;
      case PollTemplateType.date:
        return Icons.calendar_month_outlined;
      case PollTemplateType.location:
        return Icons.location_on_outlined;
    }
  }

  Future<void> _pickDateForOption(int index) async {
    if (_isSubmitting) return;

    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: 'Select date option',
      confirmText: 'Use Date',
      cancelText: 'Cancel',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: _accent, onPrimary: Colors.black),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF5B335),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;

    final formattedDate = DateFormat('EEE, MMM d, yyyy').format(pickedDate);

    setState(() {
      _optionControllers[index].text = formattedDate;
    });
  }

  String _formatScheduleDateTime(DateTime dateTime) {
    return DateFormat('MMM d, yyyy • h:mm a').format(dateTime);
  }

  Future<bool> _pickVotingStartDateTime() async {
    if (_isSubmitting) return false;

    final now = DateTime.now();
    final currentValue =
        _votingStartsAt ?? now.add(const Duration(minutes: 10));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: currentValue,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      helpText: 'Select voting start date',
      confirmText: 'Next',
      cancelText: 'Cancel',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: _accent, onPrimary: Colors.black),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF5B335),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return false;
    if (!mounted) return false;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentValue),
      helpText: 'Select voting start time',
      confirmText: 'Use Time',
      cancelText: 'Cancel',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: _accent, onPrimary: Colors.black),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF5B335),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null) return false;

    final selectedDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (selectedDateTime.isBefore(DateTime.now())) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a future start time.')),
      );

      return false;
    }

    setState(() {
      _votingStartsAt = selectedDateTime;
    });

    return true;
  }

  Future<bool> _pickVotingEndDateTime() async {
    if (_isSubmitting) return false;

    final now = DateTime.now();

    final minimumDateTime = _scheduleVotingStart && _votingStartsAt != null
        ? _votingStartsAt!
        : now;

    final currentValue =
        _customVotingEndsAt ?? minimumDateTime.add(const Duration(hours: 1));

    final initialDate = currentValue.isBefore(minimumDateTime)
        ? minimumDateTime
        : currentValue;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: minimumDateTime,
      lastDate: DateTime(now.year + 2),
      helpText: 'Select voting deadline date',
      confirmText: 'Next',
      cancelText: 'Cancel',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: _accent, onPrimary: Colors.black),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF5B335),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return false;
    if (!mounted) return false;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
      helpText: 'Select voting deadline time',
      confirmText: 'Use Time',
      cancelText: 'Cancel',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: _accent, onPrimary: Colors.black),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF5B335),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null) return false;

    final selectedDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (selectedDateTime.isBefore(DateTime.now())) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a future deadline.')),
      );

      return false;
    }

    if (_scheduleVotingStart &&
        _votingStartsAt != null &&
        selectedDateTime.isBefore(_votingStartsAt!)) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deadline must be after the voting start time.'),
        ),
      );

      return false;
    }

    setState(() {
      _customVotingEndsAt = selectedDateTime;
    });

    return true;
  }

  Future<void> _toggleScheduleVotingStart(bool value) async {
    if (_isSubmitting) return;

    if (!value) {
      setState(() {
        _scheduleVotingStart = false;
        _votingStartsAt = null;
      });
      return;
    }

    setState(() {
      _scheduleVotingStart = true;
    });

    final picked = await _pickVotingStartDateTime();

    if (!mounted) return;

    if (!picked) {
      setState(() {
        _scheduleVotingStart = false;
        _votingStartsAt = null;
      });
    }
  }

  Future<void> _toggleVotingDeadline(bool value) async {
    if (_isSubmitting) return;

    if (!value) {
      setState(() {
        _setVotingDeadline = false;
        _deadlineChoice = '1 Week';
        _customVotingEndsAt = null;
      });
      return;
    }

    setState(() {
      _setVotingDeadline = true;
      _deadlineChoice = '1 Week';
      _customVotingEndsAt = null;
    });
  }

  Duration _durationForDeadlineChoice(String choice) {
    switch (choice) {
      case '1 Day':
        return const Duration(days: 1);
      case '3 Days':
        return const Duration(days: 3);
      case '1 Week':
        return const Duration(days: 7);
      default:
        return const Duration(days: 7);
    }
  }

  DateTime? _resolvedVotingEndsAt() {
    if (!_setVotingDeadline) return null;

    if (_deadlineChoice == 'Custom') {
      return _customVotingEndsAt;
    }

    final baseTime = _scheduleVotingStart && _votingStartsAt != null
        ? _votingStartsAt!
        : DateTime.now();

    return baseTime.add(_durationForDeadlineChoice(_deadlineChoice));
  }

  String? _resolvedEndsOnLabel(DateTime? votingEndsAt) {
    if (!_setVotingDeadline) return null;

    if (_deadlineChoice == 'Custom') {
      if (votingEndsAt == null) return null;
      return _formatScheduleDateTime(votingEndsAt);
    }

    return _deadlineChoice;
  }

  Future<void> _handleDeadlineChoiceChanged(String value) async {
    if (_isSubmitting) return;

    if (value != 'Custom') {
      setState(() {
        _deadlineChoice = value;
        _customVotingEndsAt = null;
      });
      return;
    }

    setState(() {
      _deadlineChoice = 'Custom';
    });

    final picked = await _pickVotingEndDateTime();

    if (!mounted) return;

    if (!picked && _customVotingEndsAt == null) {
      setState(() {
        _deadlineChoice = '1 Week';
      });
    }
  }

  Future<void> _submitPoll() async {
    final question = _questionController.text.trim();

    final options = _optionControllers
        .map((controller) => controller.text.trim())
        .where((option) => option.isNotEmpty)
        .toList();

    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a poll question.')),
      );
      return;
    }

    if (options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least two poll options.')),
      );
      return;
    }

    if (_scheduleVotingStart && _votingStartsAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a voting start time.')),
      );
      return;
    }

    final votingEndsAt = _resolvedVotingEndsAt();

    if (_setVotingDeadline && votingEndsAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a voting deadline.')),
      );
      return;
    }

    if (_scheduleVotingStart &&
        _votingStartsAt != null &&
        votingEndsAt != null &&
        votingEndsAt.isBefore(_votingStartsAt!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deadline must be after the voting start time.'),
        ),
      );
      return;
    }

    final endsOnLabel = _resolvedEndsOnLabel(votingEndsAt);

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await PlanService.createPollPost(
        planId: widget.planId,
        question: question,
        options: options,
        pollKind: _pollKind,
        allowMultiple: _allowMultiple,
        anonymous: _anonymous,
        allowMembersAddOptions: _allowMembersAdd,
        endsOn: endsOnLabel,
        votingStartsAt: _scheduleVotingStart ? _votingStartsAt : null,
        votingEndsAt: votingEndsAt,
      );

      if (!mounted) return;

      if (result['success'] == true && result['post'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Poll created successfully.'),
          ),
        );

        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to create poll.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Connection error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _addOption() {
    if (_optionControllers.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only add up to 10 options.')),
      );
      return;
    }

    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 2 options are required.')),
      );
      return;
    }

    final controller = _optionControllers[index];

    setState(() {
      _optionControllers.removeAt(index);
    });

    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: theme.scaffoldBackgroundColor,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 110,
        leading: TextButton.icon(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios,
            size: 14,
            color: Color(0xFFF5B335),
          ),
          label: const Text(
            'Back',
            style: TextStyle(
              color: Color(0xFFF5B335),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.only(left: 20),
            overlayColor: Colors.transparent,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create Poll',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Start a poll and collect member feedback',
              style: TextStyle(fontSize: 15, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            Text(
              'Start from a template',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildTemplateCard(
                    template: PollTemplateType.blank,
                    icon: Icons.format_list_bulleted_rounded,
                    title: 'Blank Poll',
                    subtitle: 'Custom options',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTemplateCard(
                    template: PollTemplateType.date,
                    icon: Icons.calendar_month_outlined,
                    title: 'Date Poll',
                    subtitle: 'Pick the best date',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTemplateCard(
                    template: PollTemplateType.location,
                    icon: Icons.location_on_outlined,
                    title: 'Location Poll',
                    subtitle: 'Choose a place',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Divider(color: _borderColor),
            const SizedBox(height: 22),
            _buildQuestionField(),
            const SizedBox(height: 16),
            ...List.generate(_optionControllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(child: _buildOptionField(index)),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => _removeOption(index),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.redAccent,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: _isSubmitting ? null : _addOption,
              icon: const Icon(Icons.add, size: 20, color: Color(0xFFF5B335)),
              label: const Text(
                'Add more option',
                style: TextStyle(
                  color: Color(0xFFF5B335),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Poll Settings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            _buildSwitchRow('Allow multiple votes', _allowMultiple, (value) {
              setState(() => _allowMultiple = value);
            }),
            _buildSwitchRow('Anonymous voting', _anonymous, (value) {
              setState(() => _anonymous = value);
            }),
            _buildSwitchRow('Allow members to add options', _allowMembersAdd, (
              value,
            ) {
              setState(() => _allowMembersAdd = value);
            }),
            const SizedBox(height: 22),
            _buildVotingScheduleSection(),
            const SizedBox(height: 18),
            _buildVotingDeadlineSection(),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitPoll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5B335),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        'Create $_templateName',
                        style: const TextStyle(
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
    );
  }

  Widget _buildTemplateCard({
    required PollTemplateType template,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedTemplate == template;

    return GestureDetector(
      onTap: () => _selectTemplate(template),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 108,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _accentSoftColor : _surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _accent : _borderColor,
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: const Color(0xFFF5B335).withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: isSelected ? _accent : _mutedTextColor),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: _colors.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _mutedTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionField() {
    return TextField(
      controller: _questionController,
      style: TextStyle(color: _colors.onSurface),
      cursorColor: _accent,
      enabled: !_isSubmitting,
      decoration: InputDecoration(
        labelText: 'Poll Question',
        labelStyle: TextStyle(color: _mutedTextColor, fontSize: 14),
        filled: true,
        fillColor: _fieldColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF5B335), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildOptionField(int index) {
    final isDateTemplate = _selectedTemplate == PollTemplateType.date;

    return TextField(
      controller: _optionControllers[index],
      style: TextStyle(color: _colors.onSurface),
      cursorColor: _accent,
      enabled: !_isSubmitting,
      readOnly: isDateTemplate,
      onTap: isDateTemplate ? () => _pickDateForOption(index) : null,
      decoration: InputDecoration(
        labelText: index < 2
            ? 'Option ${index + 1}'
            : 'Option ${index + 1} (Optional)',
        hintText: _optionHint(index),
        hintStyle: TextStyle(color: _mutedTextColor, fontSize: 14),
        prefixIcon: Icon(_optionIcon(), color: _mutedTextColor, size: 21),
        filled: true,
        fillColor: _fieldColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF5B335), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSwitchRow(String label, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _colors.onSurface,
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: const Color(0xFFF5B335),
            onChanged: _isSubmitting ? null : onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildVotingScheduleSection() {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _surfaceColor,
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Voting Schedule',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Voting starts immediately by default.',
            style: TextStyle(fontSize: 12, color: _mutedTextColor),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Schedule voting start',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _colors.onSurface,
                  ),
                ),
              ),
              Switch(
                value: _scheduleVotingStart,
                activeThumbColor: const Color(0xFFF5B335),
                onChanged: _isSubmitting ? null : _toggleScheduleVotingStart,
              ),
            ],
          ),
          if (_scheduleVotingStart) ...[
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _isSubmitting ? null : _pickVotingStartDateTime,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: _accentSoftColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF5B335), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 20,
                      color: Color(0xFFF5B335),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _votingStartsAt == null
                            ? 'Choose start time'
                            : _formatScheduleDateTime(_votingStartsAt!),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _colors.onSurface,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Color(0xFFF5B335)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVotingDeadlineSection() {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _surfaceColor,
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Voting Deadline',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Poll stays open until manually closed by default.',
            style: TextStyle(fontSize: 12, color: _mutedTextColor),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Set voting deadline',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _colors.onSurface,
                  ),
                ),
              ),
              Switch(
                value: _setVotingDeadline,
                activeThumbColor: const Color(0xFFF5B335),
                onChanged: _isSubmitting ? null : _toggleVotingDeadline,
              ),
            ],
          ),
          if (_setVotingDeadline) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _accentSoftColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF5B335), width: 1),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _deadlineChoice,
                  dropdownColor: _surfaceColor,
                  style: TextStyle(color: _colors.onSurface),
                  isExpanded: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xFFF5B335),
                  ),
                  items: const ['1 Day', '3 Days', '1 Week', 'Custom'].map((
                    value,
                  ) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                            color: Color(0xFFF5B335),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            value,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          if (value != null) {
                            _handleDeadlineChoiceChanged(value);
                          }
                        },
                ),
              ),
            ),
            if (_deadlineChoice == 'Custom') ...[
              const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _isSubmitting ? null : _pickVotingEndDateTime,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: _fieldColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _borderColor, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 20,
                        color: Color(0xFFF5B335),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _customVotingEndsAt == null
                              ? 'Choose custom deadline'
                              : _formatScheduleDateTime(_customVotingEndsAt!),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _colors.onSurface,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xFFF5B335)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
