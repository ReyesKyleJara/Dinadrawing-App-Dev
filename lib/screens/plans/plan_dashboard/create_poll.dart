import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/plan_service.dart';

enum PollTemplateType {
  blank,
  date,
  location,
}

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
  final TextEditingController _questionController = TextEditingController();

  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  PollTemplateType _selectedTemplate = PollTemplateType.blank;

  bool _allowMultiple = false;
  bool _anonymous = true;
  bool _allowMembersAdd = false;
  bool _isSubmitting = false;

  String _endsOn = '1 Week';

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

  void _applyTemplate(
    PollTemplateType template, {
    bool clearOptions = false,
  }) {
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
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFF5B335),
              onPrimary: Colors.black,
              onSurface: Colors.black,
            ),
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

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await PlanService.createPollPost(
        planId: widget.planId,
        question: question,
        options: options,
        allowMultiple: _allowMultiple,
        anonymous: _anonymous,
        allowMembersAddOptions: _allowMembersAdd,
        endsOn: _endsOn,
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection error: $e')),
      );
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 100,
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
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.only(left: 24),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create Poll',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Start a poll and collect member feedback',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Start from a template',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black,
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
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTemplateCard(
                    template: PollTemplateType.date,
                    icon: Icons.calendar_month_outlined,
                    title: 'Date Poll',
                    subtitle: 'Pick the best date',
                  ),
                ),
                const SizedBox(width: 12),
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
            Divider(color: Colors.grey.shade300),
            const SizedBox(height: 22),
            _buildQuestionField(),
            const SizedBox(height: 16),
            ...List.generate(_optionControllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildOptionField(index),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed:
                          _isSubmitting ? null : () => _removeOption(index),
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
              icon: const Icon(
                Icons.add,
                size: 20,
                color: Color(0xFFF5B335),
              ),
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
            const Text(
              'Poll Settings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            _buildSwitchRow(
              'Allow multiple votes',
              _allowMultiple,
              (value) {
                setState(() => _allowMultiple = value);
              },
            ),
            _buildSwitchRow(
              'Anonymous voting',
              _anonymous,
              (value) {
                setState(() => _anonymous = value);
              },
            ),
            _buildSwitchRow(
              'Allow members to add options',
              _allowMembersAdd,
              (value) {
                setState(() => _allowMembersAdd = value);
              },
            ),
            const SizedBox(height: 22),
            const Text(
              'Ends on',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
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
                  value: _endsOn,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xFFF5B335),
                  ),
                  items: const [
                    '1 Day',
                    '3 Days',
                    '1 Week',
                    '2 Weeks',
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
                            style: const TextStyle(fontSize: 15),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _endsOn = value);
                          }
                        },
                ),
              ),
            ),
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
                    ? const SizedBox(
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
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 112,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFFFF8E8)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFF5B335)
                    : Colors.grey.shade300,
                width: isSelected ? 1.4 : 1,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: const Color(0xFFF5B335).withValues(alpha: 0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 30,
                  color: isSelected
                      ? const Color(0xFFF5B335)
                      : Colors.grey.shade500,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.black : Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            Positioned(
              top: -9,
              right: -6,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: Color(0xFFF5B335),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 17,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionField() {
    return TextField(
      controller: _questionController,
      enabled: !_isSubmitting,
      decoration: InputDecoration(
        labelText: 'Poll Question',
        labelStyle: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFF5B335),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildOptionField(int index) {
    final isDateTemplate = _selectedTemplate == PollTemplateType.date;

    return TextField(
      controller: _optionControllers[index],
      enabled: !_isSubmitting,
      readOnly: isDateTemplate,
      onTap: isDateTemplate ? () => _pickDateForOption(index) : null,
      decoration: InputDecoration(
        labelText: index < 2 ? 'Option ${index + 1}' : 'Option ${index + 1} (Optional)',
        hintText: _optionHint(index),
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 14,
        ),
        prefixIcon: Icon(
          _optionIcon(),
          color: Colors.grey.shade500,
          size: 21,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFF5B335),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchRow(
    String label,
    bool value,
    Function(bool) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: _isSubmitting ? null : onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFFF5B335),
          ),
        ],
      ),
    );
  }
}