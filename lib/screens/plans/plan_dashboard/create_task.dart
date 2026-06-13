import 'package:flutter/material.dart';

enum PlanListTemplateType {
  personBased,
  roleTaskBased,
  custom,
}

enum PlanListMode {
  personBased,
  roleTaskBased,
}

class PersonDraft {
  final TextEditingController nameController;
  int? userId;
  bool isManual;
  String contribution;

  PersonDraft({
    String name = '',
    this.userId,
    this.isManual = true,
    this.contribution = '',
  }) : nameController = TextEditingController(text: name);

  void dispose() {
    nameController.dispose();
  }
}

class SelectedPerson {
  final String name;
  final int? userId;
  final bool isManual;

  SelectedPerson({
    required this.name,
    this.userId,
    this.isManual = true,
  });

  Map<String, dynamic> toJson({
    String status = 'pending',
    String source = 'preassigned',
  }) {
    return {
      'name': name,
      'userId': userId,
      'isManual': isManual,
      'status': status,
      'source': source,
    };
  }
}

class RoleTaskDraft {
  final TextEditingController titleController;
  int slots;
  final List<SelectedPerson> preAssignedPeople;

  RoleTaskDraft({
    String title = '',
    this.slots = 1,
    List<SelectedPerson>? preAssignedPeople,
  })  : titleController = TextEditingController(text: title),
        preAssignedPeople = preAssignedPeople ?? [];

  void dispose() {
    titleController.dispose();
  }
}

class CreateTask extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  final List<Map<String, dynamic>> planMembers;
  final int? currentUserId;

  const CreateTask({
    super.key,
    this.initialData,
    this.planMembers = const [],
    this.currentUserId,
  });

  @override
  State<CreateTask> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTask> {
  static const Color brandYellow = Color(0xFFF5B335);
  static const Color brandYellowDark = Color(0xFFB87500);
  static const Color brandCream = Color(0xFFFFF8E8);
  static const Color brandCreamLight = Color(0xFFFFFCF4);

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _addPersonController = TextEditingController();

  final List<PersonDraft> _people = [];
  final List<RoleTaskDraft> _roleTasks = [];

  PlanListTemplateType _selectedTemplate = PlanListTemplateType.personBased;
  PlanListMode _customMode = PlanListMode.roleTaskBased;

  bool _allowMembersAddItems = true;
  bool _showProgress = true;
  bool _isSubmitting = false;

  bool get _isEditing => widget.initialData != null;

  PlanListMode get _activeMode {
    if (_selectedTemplate == PlanListTemplateType.custom) {
      return _customMode;
    }

    if (_selectedTemplate == PlanListTemplateType.personBased) {
      return PlanListMode.personBased;
    }

    return PlanListMode.roleTaskBased;
  }

  String get _pageTitle {
    return _isEditing ? 'Edit Plan List' : 'Decide Who Does What';
  }

  String get _templateLabel {
    switch (_selectedTemplate) {
      case PlanListTemplateType.personBased:
        return 'By Person';
      case PlanListTemplateType.roleTaskBased:
        return 'By Role/Task';
      case PlanListTemplateType.custom:
        return 'Custom';
    }
  }

  String get _templateDescription {
    switch (_selectedTemplate) {
      case PlanListTemplateType.personBased:
        return 'Start with people, then fill what each person will bring, share, or do.';
      case PlanListTemplateType.roleTaskBased:
        return 'Start with roles or tasks, then let people claim, accept, or decline.';
      case PlanListTemplateType.custom:
        return 'Choose your own setup for this list.';
    }
  }

  String get _buttonText {
    if (_isEditing) return 'Save Changes';

    if (_activeMode == PlanListMode.personBased) {
      return 'Create By Person List';
    }

    if (_selectedTemplate == PlanListTemplateType.custom) {
      return 'Create Custom List';
    }

    return 'Create By Role/Task List';
  }

  @override
  void initState() {
    super.initState();

    if (widget.initialData != null) {
      _loadInitialData(widget.initialData!);
    } else {
      _selectTemplate(
        PlanListTemplateType.personBased,
        shouldSetState: false,
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _addPersonController.dispose();

    for (final person in _people) {
      person.dispose();
    }

    for (final item in _roleTasks) {
      item.dispose();
    }

    super.dispose();
  }

  bool _parseBool(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is int) return value == 1;

    final text = value.toString().toLowerCase();

    return text == 'true' || text == '1';
  }

  int _parseInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? fallback;
  }

  int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  String _memberName(Map<String, dynamic> member) {
    final name = member['name']?.toString();
    final username = member['username']?.toString();
    final email = member['email']?.toString();

    if (name != null && name.trim().isNotEmpty) return name.trim();
    if (username != null && username.trim().isNotEmpty) {
      return username.trim();
    }
    if (email != null && email.trim().isNotEmpty) return email.trim();

    return 'Member';
  }

  int? _memberId(Map<String, dynamic> member) {
    return _parseNullableInt(member['id']);
  }

  bool _isCurrentUserId(int? id) {
    return id != null && widget.currentUserId != null && id == widget.currentUserId;
  }

  String _defaultTitleFor(PlanListTemplateType template) {
    switch (template) {
      case PlanListTemplateType.personBased:
        return 'By Person List';
      case PlanListTemplateType.roleTaskBased:
        return 'By Role/Task List';
      case PlanListTemplateType.custom:
        return 'Custom List';
    }
  }

  IconData _templateIcon(PlanListTemplateType template) {
    switch (template) {
      case PlanListTemplateType.personBased:
        return Icons.groups_rounded;
      case PlanListTemplateType.roleTaskBased:
        return Icons.assignment_ind_rounded;
      case PlanListTemplateType.custom:
        return Icons.tune_rounded;
    }
  }

  String _templateTitle(PlanListTemplateType template) {
    switch (template) {
      case PlanListTemplateType.personBased:
        return 'By Person';
      case PlanListTemplateType.roleTaskBased:
        return 'By Role/Task';
      case PlanListTemplateType.custom:
        return 'Custom';
    }
  }

  String _templateSubtitle(PlanListTemplateType template) {
    switch (template) {
      case PlanListTemplateType.personBased:
        return 'People first';
      case PlanListTemplateType.roleTaskBased:
        return 'Roles or tasks first';
      case PlanListTemplateType.custom:
        return 'Choose setup';
    }
  }

  List<PersonDraft> _defaultPeopleFromMembers() {
    if (widget.planMembers.isEmpty) {
      return [
        PersonDraft(
          name: 'You',
          userId: widget.currentUserId,
          isManual: false,
        ),
      ];
    }

    final members = widget.planMembers.map((member) {
      return PersonDraft(
        name: _memberName(member),
        userId: _memberId(member),
        isManual: false,
      );
    }).toList();

    members.sort((a, b) {
      final aIsYou = _isCurrentUserId(a.userId);
      final bIsYou = _isCurrentUserId(b.userId);

      if (aIsYou && !bIsYou) return -1;
      if (!aIsYou && bIsYou) return 1;

      return a.nameController.text.compareTo(b.nameController.text);
    });

    return members;
  }

  List<RoleTaskDraft> _defaultRoleTasks() {
    return [
      RoleTaskDraft(title: 'Leader / Coordinator', slots: 1),
      RoleTaskDraft(title: 'Research & Content', slots: 2),
      RoleTaskDraft(title: 'Design / Layout', slots: 2),
      RoleTaskDraft(title: 'Presenter', slots: 1),
    ];
  }

  void _clearPeople() {
    for (final person in _people) {
      person.dispose();
    }

    _people.clear();
  }

  void _clearRoleTasks() {
    for (final item in _roleTasks) {
      item.dispose();
    }

    _roleTasks.clear();
  }

  void _selectTemplate(
    PlanListTemplateType template, {
    bool shouldSetState = true,
  }) {
    void update() {
      _selectedTemplate = template;
      _titleController.text = _defaultTitleFor(template);
      _allowMembersAddItems = true;

      if (template == PlanListTemplateType.personBased) {
        _clearRoleTasks();
        _clearPeople();
        _people.addAll(_defaultPeopleFromMembers());
      } else if (template == PlanListTemplateType.roleTaskBased) {
        _clearPeople();
        _clearRoleTasks();
        _roleTasks.addAll(_defaultRoleTasks());
      } else {
        if (_customMode == PlanListMode.personBased) {
          _clearRoleTasks();
          _clearPeople();
          _people.addAll(_defaultPeopleFromMembers());
        } else {
          _clearPeople();
          _clearRoleTasks();
          _roleTasks.addAll([
            RoleTaskDraft(),
            RoleTaskDraft(),
          ]);
        }
      }
    }

    if (shouldSetState) {
      setState(update);
    } else {
      update();
    }
  }

  void _changeCustomMode(PlanListMode mode) {
    setState(() {
      _customMode = mode;

      if (mode == PlanListMode.personBased) {
        _clearRoleTasks();
        _clearPeople();
        _people.addAll(_defaultPeopleFromMembers());
      } else {
        _clearPeople();
        _clearRoleTasks();
        _roleTasks.addAll([
          RoleTaskDraft(),
          RoleTaskDraft(),
        ]);
      }
    });
  }

  void _loadInitialData(Map<String, dynamic> data) {
    final template = data['taskTemplate']?.toString() ?? '';
    final mode = data['taskMode']?.toString() ?? 'role_task_based';

    if (template == PlanListTemplateType.roleTaskBased.name) {
      _selectedTemplate = PlanListTemplateType.roleTaskBased;
    } else if (template == PlanListTemplateType.custom.name) {
      _selectedTemplate = PlanListTemplateType.custom;
    } else {
      _selectedTemplate = PlanListTemplateType.personBased;
    }

    _customMode = mode == 'person_based'
        ? PlanListMode.personBased
        : PlanListMode.roleTaskBased;

    _titleController.text =
        data['title']?.toString() ?? _defaultTitleFor(_selectedTemplate);

    _allowMembersAddItems = _parseBool(
      data['allowMembersAddItems'],
      fallback: true,
    );

    _showProgress = _parseBool(
      data['showProgress'],
      fallback: true,
    );

    final rawDetails = data['taskDetails'];

    if (_customMode == PlanListMode.personBased ||
        _selectedTemplate == PlanListTemplateType.personBased) {
      _clearRoleTasks();

      if (rawDetails is List) {
        for (final item in rawDetails) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);

            _people.add(
              PersonDraft(
                name: map['task']?.toString() ?? '',
                userId: _parseNullableInt(map['userId']),
                isManual: _parseBool(map['isManual'], fallback: true),
                contribution: map['contribution']?.toString() ?? '',
              ),
            );
          }
        }
      }

      if (_people.isEmpty) {
        _people.addAll(_defaultPeopleFromMembers());
      }

      return;
    }

    _clearPeople();

    if (rawDetails is List) {
      for (final item in rawDetails) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final claimedBy = map['claimedBy'];

          final preAssigned = <SelectedPerson>[];

          if (claimedBy is List) {
            for (final person in claimedBy) {
              if (person is Map) {
                final personMap = Map<String, dynamic>.from(person);
                final source = personMap['source']?.toString() ?? '';
                final name = personMap['name']?.toString() ?? '';

                if (source == 'preassigned' && name.trim().isNotEmpty) {
                  preAssigned.add(
                    SelectedPerson(
                      name: name,
                      userId: _parseNullableInt(personMap['userId']),
                      isManual: _parseBool(
                        personMap['isManual'],
                        fallback: true,
                      ),
                    ),
                  );
                }
              }
            }
          }

          _roleTasks.add(
            RoleTaskDraft(
              title: map['task']?.toString() ?? '',
              slots: _parseInt(map['slots'], fallback: 1),
              preAssignedPeople: preAssigned,
            ),
          );
        }
      }
    }

    if (_roleTasks.isEmpty) {
      _roleTasks.addAll(_defaultRoleTasks());
    }
  }

  bool _personAlreadyInList({
    required String name,
    int? userId,
  }) {
    return _people.any((person) {
      if (userId != null && person.userId != null) {
        return person.userId == userId;
      }

      return person.nameController.text.trim().toLowerCase() ==
          name.trim().toLowerCase();
    });
  }

  List<Map<String, dynamic>> _availableMemberSuggestions(String query) {
    final cleanQuery = query.trim().toLowerCase();

    return widget.planMembers.where((member) {
      final name = _memberName(member);
      final id = _memberId(member);

      final alreadyAdded = _personAlreadyInList(
        name: name,
        userId: id,
      );

      if (alreadyAdded) return false;

      if (cleanQuery.isEmpty) return true;

      return name.toLowerCase().contains(cleanQuery);
    }).toList();
  }

  void _addManualPerson() {
    final name = _addPersonController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name.')),
      );
      return;
    }

    if (_personAlreadyInList(name: name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This person is already in the list.')),
      );
      return;
    }

    setState(() {
      _people.add(
        PersonDraft(
          name: name,
          isManual: true,
        ),
      );

      _addPersonController.clear();
    });
  }

  void _addMemberToPeopleList(Map<String, dynamic> member) {
    final name = _memberName(member);
    final id = _memberId(member);

    if (_personAlreadyInList(name: name, userId: id)) return;

    setState(() {
      _people.add(
        PersonDraft(
          name: name,
          userId: id,
          isManual: false,
        ),
      );

      _addPersonController.clear();
    });
  }

  void _removePerson(int index) {
    final person = _people[index];

    setState(() {
      _people.removeAt(index);
    });

    person.dispose();
  }

  void _addRoleTask() {
    setState(() {
      _roleTasks.add(RoleTaskDraft());
    });
  }

  void _removeRoleTask(int index) {
    final item = _roleTasks[index];

    setState(() {
      _roleTasks.removeAt(index);
    });

    item.dispose();
  }

  void _increaseSlots(int index) {
    setState(() {
      _roleTasks[index].slots++;
    });
  }

  void _decreaseSlots(int index) {
    final item = _roleTasks[index];
    final minimum = item.preAssignedPeople.isEmpty
        ? 1
        : item.preAssignedPeople.length;

    if (item.slots <= minimum) return;

    setState(() {
      item.slots--;
    });
  }

  Future<void> _openPreAssignDialog(int roleTaskIndex) async {
    final item = _roleTasks[roleTaskIndex];
    final controller = TextEditingController();

    String query = '';

    final selected = await showDialog<SelectedPerson>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final cleanQuery = query.trim().toLowerCase();

            final suggestions = widget.planMembers.where((member) {
              final name = _memberName(member);
              final id = _memberId(member);

              final alreadyAssigned = item.preAssignedPeople.any((person) {
                if (person.userId != null && id != null) {
                  return person.userId == id;
                }

                return person.name.trim().toLowerCase() ==
                    name.trim().toLowerCase();
              });

              if (alreadyAssigned) return false;

              if (cleanQuery.isEmpty) return true;

              return name.toLowerCase().contains(cleanQuery);
            }).toList();

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Pre-assign person',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      onChanged: (value) {
                        setDialogState(() {
                          query = value;
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: 'Search member or type a name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (suggestions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: suggestions.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final member = suggestions[index];
                            final name = _memberName(member);
                            final id = _memberId(member);
                            final isYou = _isCurrentUserId(id);

                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                radius: 15,
                                backgroundColor: brandCream,
                                child: Icon(
                                  Icons.person,
                                  size: 16,
                                  color: brandYellowDark,
                                ),
                              ),
                              title: Text(
                                isYou ? '$name (You)' : name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: const Text(
                                'Plan member',
                                style: TextStyle(fontSize: 11),
                              ),
                              onTap: () {
                                Navigator.of(dialogContext).pop(
                                  SelectedPerson(
                                    name: name,
                                    userId: id,
                                    isManual: false,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                    if (query.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.of(dialogContext).pop(
                            SelectedPerson(
                              name: query.trim(),
                              isManual: true,
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: brandCream,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFF2D999),
                            ),
                          ),
                          child: Text(
                            'Add "$query" as manual person',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: brandYellowDark,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = controller.text.trim();

                    if (name.isEmpty) {
                      Navigator.of(dialogContext).pop();
                      return;
                    }

                    Navigator.of(dialogContext).pop(
                      SelectedPerson(
                        name: name,
                        isManual: true,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandYellow,
                    foregroundColor: Colors.black,
                    elevation: 0,
                  ),
                  child: const Text(
                    'Add',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (selected == null || selected.name.trim().isEmpty) return;

    final alreadyAssigned = item.preAssignedPeople.any((person) {
      if (selected.userId != null && person.userId != null) {
        return person.userId == selected.userId;
      }

      return person.name.trim().toLowerCase() ==
          selected.name.trim().toLowerCase();
    });

    if (alreadyAssigned) return;

    setState(() {
      item.preAssignedPeople.add(selected);

      if (item.slots < item.preAssignedPeople.length) {
        item.slots = item.preAssignedPeople.length;
      }
    });
  }

  void _removePreAssignedPerson(int roleTaskIndex, SelectedPerson person) {
    setState(() {
      _roleTasks[roleTaskIndex].preAssignedPeople.remove(person);
    });
  }

  void _submitList() {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a list title.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    if (_activeMode == PlanListMode.personBased) {
      final details = _people
          .map((person) {
            final name = person.nameController.text.trim();

            return {
              'task': name,
              'userId': person.userId,
              'isManual': person.isManual,
              'contribution': person.contribution,
              'slots': 1,
              'claimedBy': <Map<String, dynamic>>[],
              'isDone': false,
            };
          })
          .where((item) => item['task'].toString().trim().isNotEmpty)
          .toList();

      if (details.isEmpty) {
        setState(() {
          _isSubmitting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one person.')),
        );
        return;
      }

      Navigator.pop(context, {
        'type': 'task',
        'title': title,
        'taskTemplate': _selectedTemplate.name,
        'taskMode': 'person_based',
        'templateLabel': _templateLabel,
        'templateDescription': _templateDescription,
        'tasks': details.map((item) => item['task'].toString()).toList(),
        'taskDetails': details,
        'allowMembersAddItems': _allowMembersAddItems,
        'showProgress': _showProgress,
        'isFinalized': widget.initialData?['isFinalized'] == true,
      });

      return;
    }

    final details = _roleTasks
        .map((item) {
          final itemTitle = item.titleController.text.trim();

          return {
            'task': itemTitle,
            'slots': item.slots,
            'contribution': '',
            'isDone': false,
            'claimedBy': item.preAssignedPeople.map((person) {
              return person.toJson(
                status: 'pending',
                source: 'preassigned',
              );
            }).toList(),
          };
        })
        .where((item) => item['task'].toString().trim().isNotEmpty)
        .toList();

    if (details.isEmpty) {
      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one role or task.')),
      );
      return;
    }

    Navigator.pop(context, {
      'type': 'task',
      'title': title,
      'taskTemplate': _selectedTemplate.name,
      'taskMode': 'role_task_based',
      'templateLabel': _templateLabel,
      'templateDescription': _templateDescription,
      'tasks': details.map((item) => item['task'].toString()).toList(),
      'taskDetails': details,
      'allowMembersAddItems': _allowMembersAddItems,
      'showProgress': _showProgress,
      'isFinalized': widget.initialData?['isFinalized'] == true,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPersonBased = _activeMode == PlanListMode.personBased;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 110,
        leading: TextButton.icon(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios,
            size: 14,
            color: brandYellow,
          ),
          label: const Text(
            'Back',
            style: TextStyle(
              color: brandYellow,
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
              _pageTitle,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose how your group will organize people, roles, or tasks.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Choose list style',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 14),
            _buildTemplateGrid(),
            if (_selectedTemplate == PlanListTemplateType.custom) ...[
              const SizedBox(height: 16),
              _buildCustomModeSection(),
            ],
            const SizedBox(height: 24),
            Divider(color: Colors.grey.shade300),
            const SizedBox(height: 22),
            _buildTitleField(),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isPersonBased ? 'People' : 'Roles or Tasks',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: brandCream,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFFF2D999),
                    ),
                  ),
                  child: Text(
                    isPersonBased
                        ? '${_people.length} people'
                        : '${_roleTasks.length} items',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: brandYellowDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isPersonBased
                  ? 'Plan members are added automatically. You can remove them, re-add them from suggestions, or type manual names.'
                  : 'Add roles or tasks, set slots, and optionally pre-assign people. They can accept or decline later.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            if (isPersonBased)
              _buildPersonBasedSection()
            else
              _buildRoleTaskBasedSection(),
            const SizedBox(height: 26),
            _buildSettingsSection(),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitList,
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandYellow,
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
                        _buttonText,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
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

  Widget _buildTemplateGrid() {
    final templates = [
      PlanListTemplateType.personBased,
      PlanListTemplateType.roleTaskBased,
      PlanListTemplateType.custom,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 10) / 2;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: templates.map((template) {
            return SizedBox(
              width: itemWidth,
              child: _buildTemplateCard(template),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildTemplateCard(PlanListTemplateType template) {
    final isSelected = _selectedTemplate == template;

    return GestureDetector(
      onTap: () => _selectTemplate(template),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 108,
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected ? brandCream : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? brandYellow : Colors.grey.shade300,
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: brandYellow.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _templateIcon(template),
              size: 28,
              color: isSelected ? brandYellow : Colors.grey.shade500,
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _templateTitle(template),
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? Colors.black : Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _templateSubtitle(template),
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomModeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brandCreamLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF2D999),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How should this list work?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          _buildModeChoice(
            mode: PlanListMode.personBased,
            title: 'Start with people',
            subtitle: 'Fill what each person will bring, share, or do',
          ),
          _buildModeChoice(
            mode: PlanListMode.roleTaskBased,
            title: 'Start with roles or tasks',
            subtitle: 'Let people claim, accept, or decline',
          ),
        ],
      ),
    );
  }

  Widget _buildModeChoice({
    required PlanListMode mode,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _customMode == mode;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _changeCustomMode(mode),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? brandCream : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? brandYellow : Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 20,
                color: isSelected ? brandYellow : Colors.grey.shade500,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return TextField(
      controller: _titleController,
      enabled: !_isSubmitting,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: 'List Title',
        hintText: 'e.g., Capstone Plan List',
        labelStyle: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 14,
        ),
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
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
            color: brandYellow,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildPersonBasedSection() {
    final suggestions = _availableMemberSuggestions(_addPersonController.text);

    return Column(
      children: [
        if (_people.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: brandCreamLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFF2D999),
              ),
            ),
            child: const Text(
              'No people added yet. Add a plan member or manual name below.',
              style: TextStyle(
                fontSize: 13,
                color: brandYellowDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else
          ...List.generate(_people.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildPersonCard(index),
            );
          }),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add person',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _addPersonController,
                enabled: !_isSubmitting,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Search member or type a name',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.person_add_alt_1_outlined,
                    color: Colors.grey.shade500,
                    size: 20,
                  ),
                  suffixIcon: IconButton(
                    onPressed: _isSubmitting ? null : _addManualPerson,
                    icon: const Icon(
                      Icons.add_circle,
                      color: brandYellow,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: brandYellow,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: suggestions.take(8).map((member) {
                    final name = _memberName(member);
                    final id = _memberId(member);
                    final isYou = _isCurrentUserId(id);

                    return InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => _addMemberToPeopleList(member),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: brandCream,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xFFF2D999),
                          ),
                        ),
                        child: Text(
                          isYou ? '$name (You)' : name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: brandYellowDark,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPersonCard(int index) {
    final person = _people[index];
    final isYou = _isCurrentUserId(person.userId);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brandCreamLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF2D999),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFFFE8A3),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: brandYellowDark,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: person.nameController,
              enabled: !_isSubmitting,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: person.isManual
                    ? 'Manual name'
                    : isYou
                        ? 'Plan member • You'
                        : 'Plan member',
                hintText: 'Person name',
                labelStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
                suffixIcon: isYou
                    ? const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            '(You)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: brandYellowDark,
                            ),
                          ),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: brandYellow,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isSubmitting ? null : () => _removePerson(index),
            icon: const Icon(
              Icons.close,
              color: Colors.redAccent,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleTaskBasedSection() {
    return Column(
      children: [
        if (_roleTasks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: brandCreamLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFF2D999),
              ),
            ),
            child: const Text(
              'No roles or tasks yet. Add one below.',
              style: TextStyle(
                fontSize: 13,
                color: brandYellowDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else
          ...List.generate(_roleTasks.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildRoleTaskCard(index),
            );
          }),
        TextButton.icon(
          onPressed: _isSubmitting ? null : _addRoleTask,
          icon: const Icon(
            Icons.add,
            size: 20,
            color: brandYellow,
          ),
          label: const Text(
            'Add role or task',
            style: TextStyle(
              color: brandYellow,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleTaskCard(int index) {
    final item = _roleTasks[index];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brandCreamLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF2D999),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE8A3),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: brandYellowDark,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Role / Task ${index + 1}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
              IconButton(
                onPressed: _isSubmitting ? null : () => _removeRoleTask(index),
                icon: const Icon(
                  Icons.close,
                  color: Colors.redAccent,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: item.titleController,
            enabled: !_isSubmitting,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Role or task',
              hintText: 'e.g., Presenter, Buy materials',
              labelStyle: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13,
              ),
              prefixIcon: Icon(
                Icons.assignment_ind_outlined,
                color: Colors.grey.shade500,
                size: 20,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: brandYellow,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildSlotStepper(index),
          const SizedBox(height: 12),
          _buildPreAssignedSection(index),
        ],
      ),
    );
  }

  Widget _buildSlotStepper(int index) {
    final item = _roleTasks[index];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.groups_rounded,
            size: 20,
            color: brandYellowDark,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Available slots',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
          ),
          IconButton(
            onPressed: _isSubmitting ? null : () => _decreaseSlots(index),
            icon: const Icon(Icons.remove_circle_outline),
            color: brandYellowDark,
          ),
          Text(
            '${item.slots}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          IconButton(
            onPressed: _isSubmitting ? null : () => _increaseSlots(index),
            icon: const Icon(Icons.add_circle_outline),
            color: brandYellowDark,
          ),
        ],
      ),
    );
  }

  Widget _buildPreAssignedSection(int index) {
    final item = _roleTasks[index];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pre-assigned people',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'They can accept or decline later.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          if (item.preAssignedPeople.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: item.preAssignedPeople.map((person) {
                final isYou = _isCurrentUserId(person.userId);

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: brandCream,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFFF2D999),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.person_rounded,
                        size: 14,
                        color: brandYellowDark,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isYou ? '${person.name} (You)' : person.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: brandYellowDark,
                        ),
                      ),
                      const SizedBox(width: 5),
                      GestureDetector(
                        onTap: _isSubmitting
                            ? null
                            : () => _removePreAssignedPerson(index, person),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: brandYellowDark,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _isSubmitting ? null : () => _openPreAssignDialog(index),
            icon: const Icon(
              Icons.person_add_alt_1_rounded,
              size: 17,
              color: brandYellow,
            ),
            label: const Text(
              'Add pre-assigned person',
              style: TextStyle(
                color: brandYellow,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'List Settings',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Keep it flexible for plan members and manual names.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 14),
          _buildSwitchRow(
            label: _activeMode == PlanListMode.personBased
                ? 'Allow more names to be added'
                : 'Allow members to add roles or tasks',
            value: _allowMembersAddItems,
            onChanged: (value) {
              setState(() {
                _allowMembersAddItems = value;
              });
            },
          ),
          _buildSwitchRow(
            label: 'Show progress tracker',
            value: _showProgress,
            onChanged: (value) {
              setState(() {
                _showProgress = value;
              });
            },
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: brandCream,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFF2D999),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 18,
                  color: brandYellowDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _activeMode == PlanListMode.personBased
                        ? 'You can include non-app people by typing their names manually.'
                        : 'Pre-assigned people will still have the right to accept or decline.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: brandYellowDark,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow({
    required String label,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: brandYellow,
            onChanged: _isSubmitting ? null : onChanged,
          ),
        ],
      ),
    );
  }
}