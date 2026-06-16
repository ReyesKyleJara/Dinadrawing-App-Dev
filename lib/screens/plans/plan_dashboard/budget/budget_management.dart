part of 'budget_tab.dart';

// -----------------------------------------------------------------------------
// Budget Setup and Editing
// -----------------------------------------------------------------------------

enum _BudgetEditorMode { fullSetup, expensesOnly, sharesOnly }

class BudgetPlanEditorPage extends StatefulWidget {
  const BudgetPlanEditorPage({
    super.key,
    required this.planId,
    required this.initialBudget,
    required this.availableMembers,
    this.mode = _BudgetEditorMode.fullSetup,
    this.initialStep = 0,
  });

  final int planId;
  final Map<String, dynamic>? initialBudget;
  final List<Map<String, dynamic>> availableMembers;
  final _BudgetEditorMode mode;
  final int initialStep;

  @override
  State<BudgetPlanEditorPage> createState() => _BudgetPlanEditorPageState();
}

class _BudgetPlanEditorPageState extends State<BudgetPlanEditorPage> {
  late int _currentStep;

  bool _isSaving = false;

  String? _formError;

  String _splitType = 'equal';

  final List<_ExpenseDraft> _expenses = [];
  final List<_MemberAllocationDraft> _members = [];

  bool get _isEditing => widget.initialBudget != null;

  bool get _isSectionEditor {
    return widget.mode != _BudgetEditorMode.fullSetup;
  }

  String get _pageTitle {
    switch (widget.mode) {
      case _BudgetEditorMode.expensesOnly:
        return 'Edit Planned Expenses';
      case _BudgetEditorMode.sharesOnly:
        return 'Edit People & Shares';
      case _BudgetEditorMode.fullSetup:
        return _isEditing ? 'Edit Budget Plan' : 'Set Up Budget';
    }
  }

  int get _sectionStep {
    switch (widget.mode) {
      case _BudgetEditorMode.expensesOnly:
        return 0;
      case _BudgetEditorMode.sharesOnly:
        return 1;
      case _BudgetEditorMode.fullSetup:
        return _currentStep;
    }
  }

  @override
  void initState() {
    super.initState();

    _currentStep = switch (widget.mode) {
      _BudgetEditorMode.expensesOnly => 0,
      _BudgetEditorMode.sharesOnly => 1,
      _BudgetEditorMode.fullSetup => widget.initialStep.clamp(0, 2),
    };

    _initializeExpenses();
    _initializeMembers();
  }

  void _initializeExpenses() {
    final rawExpenses = _asMapList(widget.initialBudget?['expenses']);

    if (rawExpenses.isEmpty) {
      _expenses.add(_ExpenseDraft());
      return;
    }

    for (final expense in rawExpenses) {
      _expenses.add(
        _ExpenseDraft(
          name: expense['name']?.toString() ?? '',
          note: expense['note']?.toString() ?? '',
          amount: _asDouble(expense['estimated_amount']),
        ),
      );
    }
  }

  void _initializeMembers() {
    _splitType = widget.initialBudget?['split_type']?.toString() == 'custom'
        ? 'custom'
        : 'equal';

    final rawAllocations = _asMapList(widget.initialBudget?['allocations']);

    if (widget.initialBudget == null) {
      for (final member in widget.availableMembers) {
        final userId = _asInt(member['id']);

        if (userId == null) {
          continue;
        }

        _members.add(
          _MemberAllocationDraft(
            userId: userId,
            name: member['name']?.toString() ?? 'Plan Member',
            username: member['username']?.toString(),
            profilePhotoUrl: member['profile_photo_url']?.toString(),
            isPlanAdmin: _asBool(member['is_plan_admin']),
            isManual: false,
            isIncluded: true,
            plannedShare: 0,
          ),
        );
      }
    } else {
      final availableMembersById = {
        for (final member in widget.availableMembers)
          if (_asInt(member['id']) != null) _asInt(member['id'])!: member,
      };

      for (final allocation in rawAllocations) {
        if (_asBool(allocation['is_former_member']) ||
            !_asBool(allocation['is_included'])) {
          continue;
        }

        final allocationId = _asInt(allocation['id']);
        final userId = _asInt(allocation['user_id']);

        if (userId != null) {
          final member = availableMembersById[userId];

          if (member == null) {
            continue;
          }

          _members.add(
            _MemberAllocationDraft(
              allocationId: allocationId,
              userId: userId,
              name:
                  member['name']?.toString() ??
                  allocation['name']?.toString() ??
                  'Plan Member',
              username:
                  member['username']?.toString() ??
                  allocation['username']?.toString(),
              profilePhotoUrl:
                  member['profile_photo_url']?.toString() ??
                  allocation['profile_photo_url']?.toString(),
              isPlanAdmin: _asBool(member['is_plan_admin']),
              isManual: false,
              isIncluded: true,
              plannedShare: _asDouble(allocation['planned_share']),
            ),
          );

          continue;
        }

        final manualName =
            allocation['manual_name']?.toString().trim().isNotEmpty == true
            ? allocation['manual_name'].toString().trim()
            : allocation['name']?.toString().trim() ?? '';

        if (manualName.isEmpty) {
          continue;
        }

        _members.add(
          _MemberAllocationDraft(
            allocationId: allocationId,
            userId: null,
            name: manualName,
            username: null,
            profilePhotoUrl: null,
            isPlanAdmin: false,
            isManual: true,
            isIncluded: true,
            plannedShare: _asDouble(allocation['planned_share']),
          ),
        );
      }
    }

    if (_splitType == 'custom' && widget.initialBudget == null) {
      _applyEqualSharesToCustomInputs();
    }
  }

  @override
  void dispose() {
    for (final expense in _expenses) {
      expense.dispose();
    }

    for (final member in _members) {
      member.dispose();
    }

    super.dispose();
  }

  int get _totalEstimatedCents {
    return _expenses.fold<int>(
      0,
      (sum, expense) =>
          sum + _toCents(_parseAmount(expense.amountController.text)),
    );
  }

  List<_MemberAllocationDraft> get _includedMembers {
    return _members.where((member) => member.isIncluded).toList();
  }

  Map<String, int> get _equalShareCentsByPerson {
    final included = _includedMembers;

    if (included.isEmpty) {
      return {};
    }

    final base = _totalEstimatedCents ~/ included.length;
    final remainder = _totalEstimatedCents % included.length;
    final result = <String, int>{};

    for (var index = 0; index < included.length; index++) {
      result[included[index].identityKey] = base + (index < remainder ? 1 : 0);
    }

    return result;
  }

  int get _allocatedCents {
    if (_splitType == 'equal') {
      return _includedMembers.isEmpty ? 0 : _totalEstimatedCents;
    }

    return _includedMembers.fold<int>(
      0,
      (sum, member) =>
          sum + _toCents(_parseAmount(member.shareController.text)),
    );
  }

  int get _unallocatedCents {
    return _totalEstimatedCents - _allocatedCents;
  }

  void _applyEqualSharesToCustomInputs() {
    final shares = _equalShareCentsByPerson;

    for (final member in _members) {
      final cents = member.isIncluded ? shares[member.identityKey] ?? 0 : 0;

      member.shareController.text = _fromCents(cents).toStringAsFixed(2);
    }
  }

  void _changeSplitType(String value) {
    if (value == _splitType) {
      return;
    }

    setState(() {
      _splitType = value;
      _formError = null;

      if (_splitType == 'custom') {
        _applyEqualSharesToCustomInputs();
      }
    });
  }

  void _addExpense() {
    setState(() {
      _expenses.add(_ExpenseDraft());

      _formError = null;
    });
  }

  void _removeExpense(int index) {
    if (_expenses.length == 1) {
      _expenses[index].nameController.clear();
      _expenses[index].noteController.clear();
      _expenses[index].amountController.clear();

      setState(() {
        _formError = null;
      });

      return;
    }

    final removed = _expenses.removeAt(index);

    removed.dispose();

    setState(() {
      _formError = null;
    });
  }

  void _removeBudgetPerson(_MemberAllocationDraft member) {
    setState(() {
      _members.remove(member);
      member.dispose();
      _formError = null;
    });
  }

  bool _manualNameAlreadyAdded(String name) {
    final cleanName = name.trim().toLowerCase();

    return _members.any(
      (member) =>
          member.isManual && member.name.trim().toLowerCase() == cleanName,
    );
  }

  Future<void> _showAddMorePeopleSheet() async {
    final addedUserIds = _members
        .map((member) => member.userId)
        .whereType<int>()
        .toSet();

    final availableToAdd =
        widget.availableMembers
            .where((member) {
              final id = _asInt(member['id']);

              return id != null && !addedUserIds.contains(id);
            })
            .map((member) => Map<String, dynamic>.from(member))
            .toList()
          ..sort((first, second) {
            final firstName = first['name']?.toString().toLowerCase() ?? '';
            final secondName = second['name']?.toString().toLowerCase() ?? '';

            return firstName.compareTo(secondName);
          });

    final manualController = TextEditingController();
    String? manualError;

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            final colors = theme.colorScheme;
            final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

            void addManualPerson() {
              final name = manualController.text.trim();

              if (name.isEmpty) {
                setSheetState(() {
                  manualError = 'Enter the person’s name.';
                });

                return;
              }

              if (_manualNameAlreadyAdded(name)) {
                setSheetState(() {
                  manualError = '$name is already in the budget.';
                });

                return;
              }

              Navigator.pop(sheetContext, {'type': 'manual', 'name': name});
            }

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.82,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(26),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: colors.outlineVariant,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          const SizedBox(height: 19),
                          Text(
                            'Add More People',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: colors.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Add a plan member back to the budget, or enter someone who is not part of the plan.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        children: [
                          Text(
                            'PLAN MEMBERS',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.55,
                            ),
                          ),
                          const SizedBox(height: 9),
                          if (availableToAdd.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerHighest
                                    .withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                'All current plan members are already in the budget.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                            )
                          else
                            ...availableToAdd.map((member) {
                              final name =
                                  member['name']?.toString() ?? 'Plan Member';
                              final username = member['username']
                                  ?.toString()
                                  .trim();
                              final photo = member['profile_photo_url']
                                  ?.toString()
                                  .trim();

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.pop(sheetContext, {
                                        'type': 'member',
                                        'member': member,
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: colors.outlineVariant,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          _buildPickerAvatar(
                                            name: name,
                                            profilePhotoUrl: photo,
                                          ),
                                          const SizedBox(width: 11),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  name,
                                                  style: theme
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: colors.onSurface,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  username != null &&
                                                          username.isNotEmpty
                                                      ? (username.startsWith(
                                                              '@',
                                                            )
                                                            ? username
                                                            : '@$username')
                                                      : 'Plan member',
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: colors
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(
                                            Icons.add_circle_outline_rounded,
                                            color: _budgetYellowDark,
                                            size: 22,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          const SizedBox(height: 18),
                          Divider(color: colors.outlineVariant),
                          const SizedBox(height: 18),
                          Text(
                            'OTHER PERSON',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.55,
                            ),
                          ),
                          const SizedBox(height: 9),
                          TextField(
                            controller: manualController,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.done,
                            onChanged: (_) {
                              if (manualError != null) {
                                setSheetState(() {
                                  manualError = null;
                                });
                              }
                            },
                            onSubmitted: (_) {
                              addManualPerson();
                            },
                            decoration: _tableInputDecoration(
                              context,
                              hint: 'Enter a name',
                              prefixIcon: Icons.person_add_alt_1_rounded,
                            ).copyWith(errorText: manualError),
                          ),
                          const SizedBox(height: 11),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: addManualPerson,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _budgetYellow,
                                foregroundColor: Colors.black,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text(
                                'Add Person',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
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
      },
    );

    manualController.dispose();

    if (selected == null || !mounted) {
      return;
    }

    final type = selected['type']?.toString();

    if (type == 'member' && selected['member'] is Map) {
      final member = Map<String, dynamic>.from(selected['member'] as Map);
      final userId = _asInt(member['id']);

      if (userId == null) {
        return;
      }

      setState(() {
        _members.add(
          _MemberAllocationDraft(
            userId: userId,
            name: member['name']?.toString() ?? 'Plan Member',
            username: member['username']?.toString(),
            profilePhotoUrl: member['profile_photo_url']?.toString(),
            isPlanAdmin: _asBool(member['is_plan_admin']),
            isManual: false,
            isIncluded: true,
            plannedShare: 0,
          ),
        );
        _formError = null;

        if (_splitType == 'custom') {
          _applyEqualSharesToCustomInputs();
        }
      });

      return;
    }

    final manualName = selected['name']?.toString().trim() ?? '';

    if (type == 'manual' && manualName.isNotEmpty) {
      setState(() {
        _members.add(
          _MemberAllocationDraft(
            userId: null,
            name: manualName,
            username: null,
            profilePhotoUrl: null,
            isPlanAdmin: false,
            isManual: true,
            isIncluded: true,
            plannedShare: 0,
          ),
        );
        _formError = null;

        if (_splitType == 'custom') {
          _applyEqualSharesToCustomInputs();
        }
      });
    }
  }

  Widget _buildPickerAvatar({required String name, String? profilePhotoUrl}) {
    final colors = Theme.of(context).colorScheme;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return CircleAvatar(
      radius: 19,
      backgroundColor: colors.surfaceContainerHighest,
      foregroundImage: profilePhotoUrl != null && profilePhotoUrl.isNotEmpty
          ? NetworkImage(profilePhotoUrl)
          : null,
      child: Text(
        initial,
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  bool _validateStep(int step) {
    if (step == 0) {
      for (var index = 0; index < _expenses.length; index++) {
        final expense = _expenses[index];

        if (expense.nameController.text.trim().isEmpty) {
          setState(() {
            _formError = 'Enter a name for expense ${index + 1}.';
          });

          return false;
        }

        final amount = _parseAmount(expense.amountController.text);

        if (amount <= 0) {
          setState(() {
            _formError =
                'Enter an amount greater than zero for ${expense.nameController.text.trim()}.';
          });

          return false;
        }
      }
    }

    if (step == 1) {
      if (_includedMembers.isEmpty) {
        setState(() {
          _formError = 'Add at least one person to the budget.';
        });

        return false;
      }

      if (_splitType == 'custom' && _unallocatedCents < 0) {
        setState(() {
          _formError =
              'Member shares exceed the budget by ${_formatPeso(_fromCents(_unallocatedCents.abs()))}.';
        });

        return false;
      }
    }

    setState(() {
      _formError = null;
    });

    return true;
  }

  void _goNext() {
    if (!_validateStep(_currentStep)) {
      return;
    }

    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _goBack() {
    if (_isSectionEditor) {
      Navigator.pop(context);
      return;
    }

    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _formError = null;
      });
      return;
    }

    Navigator.pop(context);
  }

  Future<void> _saveBudget() async {
    if (!_validateStep(0) || !_validateStep(1)) {
      return;
    }

    setState(() {
      _isSaving = true;
      _formError = null;
    });

    final expenses = _expenses.map((expense) {
      return BudgetExpenseInput(
        name: expense.nameController.text.trim(),
        note: expense.noteController.text.trim(),
        estimatedAmount: _parseAmount(expense.amountController.text),
      );
    }).toList();

    final equalShares = _equalShareCentsByPerson;

    final allocations = _members.map((member) {
      final plannedShare = !member.isIncluded
          ? 0.0
          : _splitType == 'equal'
          ? _fromCents(equalShares[member.identityKey] ?? 0)
          : _parseAmount(member.shareController.text);

      return BudgetAllocationInput(
        allocationId: member.allocationId,
        userId: member.userId,
        manualName: member.isManual ? member.name : null,
        isIncluded: member.isIncluded,
        plannedShare: plannedShare,
      );
    }).toList();

    final result = _isEditing
        ? await BudgetService.updateBudget(
            planId: widget.planId,
            splitType: _splitType,
            expenses: expenses,
            allocations: allocations,
          )
        : await BudgetService.createBudget(
            planId: widget.planId,
            splitType: _splitType,
            expenses: expenses,
            allocations: allocations,
          );

    if (!mounted) {
      return;
    }

    if (result['success'] != true) {
      setState(() {
        _isSaving = false;
        _formError = BudgetService.errorMessage(
          result,
          fallback: _isEditing
              ? 'Unable to update the budget.'
              : 'Unable to create the budget.',
        );
      });

      return;
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: _isSaving ? null : _goBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        title: Text(
          _pageTitle,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (!_isSectionEditor) _buildStepIndicator(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_formError != null) ...[
                      _buildEditorError(_formError!),
                      const SizedBox(height: 18),
                    ],
                    if (_sectionStep == 0)
                      _buildExpenseStep()
                    else if (_sectionStep == 1)
                      _buildAllocationStep()
                    else
                      _buildReviewStep(),
                  ],
                ),
              ),
            ),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    const labels = ['Expenses', 'Shares', 'Review'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Container(
        height: 56,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(labels.length, (index) {
            final isActive = index == _currentStep;

            final isCompleted = index < _currentStep;

            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? _budgetYellow
                      : isCompleted
                      ? _budgetYellow.withValues(alpha: 0.16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.black.withValues(alpha: 0.08)
                            : isCompleted
                            ? _budgetYellow.withValues(alpha: 0.22)
                            : colors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: isCompleted
                          ? const Icon(
                              Icons.check_rounded,
                              size: 15,
                              color: _budgetYellowDark,
                            )
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isActive
                                    ? Colors.black
                                    : colors.onSurfaceVariant,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        labels[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: isActive
                              ? Colors.black
                              : isCompleted
                              ? _budgetYellowDark
                              : colors.onSurfaceVariant,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildExpenseStep() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.mode == _BudgetEditorMode.expensesOnly
              ? 'Edit Planned Expenses'
              : 'Add Planned Expenses',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: colors.onSurface,
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'List the expected expenses so every member can see where the estimated budget comes from.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 22),
        _buildExpenseTable(),
      ],
    );
  }

  Widget _buildExpenseTable() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final amountWidth = constraints.maxWidth < 390 ? 108.0 : 135.0;

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                color: colors.surfaceContainerHighest.withValues(alpha: 0.62),
                child: Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: Text(
                        '#',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'EXPENSE',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: amountWidth,
                      child: Text(
                        'ESTIMATED COST',
                        textAlign: TextAlign.left,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 36),
                  ],
                ),
              ),

              ...List.generate(_expenses.length, (index) {
                return _buildExpenseTableRow(
                  index: index,
                  amountWidth: amountWidth,
                );
              }),

              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _addExpense,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_rounded,
                          size: 19,
                          color: _budgetYellowDark,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'Add Expense',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _budgetYellowDark,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: _budgetYellow.withValues(alpha: 0.12),
                  border: Border(top: BorderSide(color: colors.outlineVariant)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Estimated Budget',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      _formatPeso(_fromCents(_totalEstimatedCents)),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpenseTableRow({
    required int index,
    required double amountWidth,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final expense = _expenses[index];

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  '${index + 1}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              Expanded(
                child: TextField(
                  controller: expense.nameController,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) {
                    setState(() {
                      _formError = null;
                    });
                  },
                  decoration: _tableInputDecoration(
                    context,
                    hint: 'Expense name',
                  ),
                ),
              ),

              const SizedBox(width: 8),

              SizedBox(
                width: amountWidth,
                child: TextField(
                  controller: expense.amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: const [MoneyTextInputFormatter()],
                  onChanged: (_) {
                    setState(() {
                      _formError = null;
                    });
                  },
                  onTapOutside: (_) {
                    _normalizeMoneyController(expense.amountController);

                    setState(() {});
                  },
                  decoration: _tableInputDecoration(
                    context,
                    hint: '0.00',
                    prefixText: '₱ ',
                  ),
                ),
              ),

              SizedBox(
                width: 36,
                child: IconButton(
                  tooltip: 'Remove expense',
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    _removeExpense(index);
                  },
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 19,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.only(left: 34, right: 36),
            child: TextField(
              controller: expense.noteController,
              minLines: 1,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                setState(() {});
              },
              decoration: _tableInputDecoration(
                context,
                hint: 'Optional note',
                prefixIcon: Icons.notes_rounded,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllocationStep() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.mode == _BudgetEditorMode.sharesOnly
              ? 'Edit People & Shares'
              : 'Plan the People & Shares',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: colors.onSurface,
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Choose who is part of this budget. You can remove plan members, add them back later, or add another person by name.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 22),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'equal',
              label: Text('Split Equally'),
              icon: Icon(Icons.balance_rounded),
            ),
            ButtonSegment(
              value: 'custom',
              label: Text('Custom'),
              icon: Icon(Icons.tune_rounded),
            ),
          ],
          selected: {_splitType},
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            _changeSplitType(selection.first);
          },
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return _budgetYellow.withValues(alpha: 0.23);
              }

              return colors.surface;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return colors.onSurface;
              }

              return colors.onSurfaceVariant;
            }),
          ),
        ),
        const SizedBox(height: 20),
        if (_members.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.group_add_outlined,
                  color: colors.onSurfaceVariant,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  'No people added yet',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add at least one person before publishing the budget.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          ..._members.map(_buildAllocationMemberCard),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          height: 47,
          child: OutlinedButton.icon(
            onPressed: _showAddMorePeopleSheet,
            style: OutlinedButton.styleFrom(
              foregroundColor: _budgetYellowDark,
              side: BorderSide(color: _budgetYellow.withValues(alpha: 0.8)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text(
              'Add More People',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildAllocationSummary(),
      ],
    );
  }

  Widget _buildAllocationMemberCard(_MemberAllocationDraft member) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final equalShare = _fromCents(
      _equalShareCentsByPerson[member.identityKey] ?? 0,
    );

    final subtitle = member.isManual
        ? 'Added manually'
        : member.username != null && member.username!.trim().isNotEmpty
        ? (member.username!.startsWith('@')
              ? member.username!
              : '@${member.username}')
        : 'Plan member';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _editorAvatar(member),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (member.isPlanAdmin) ...[
                          const SizedBox(width: 5),
                          Icon(
                            Icons.edit_note_rounded,
                            color: colors.onSurfaceVariant,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (_splitType == 'equal') ...[
                const SizedBox(width: 8),
                Text(
                  _formatPeso(equalShare),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Remove from budget',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  _removeBudgetPerson(member);
                },
                icon: Icon(
                  Icons.close_rounded,
                  color: colors.onSurfaceVariant,
                  size: 20,
                ),
              ),
            ],
          ),
          if (_splitType == 'custom') ...[
            const SizedBox(height: 12),
            TextField(
              controller: member.shareController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [MoneyTextInputFormatter()],
              onChanged: (_) {
                setState(() {
                  _formError = null;
                });
              },
              onTapOutside: (_) {
                _normalizeMoneyController(member.shareController);
              },
              decoration: _tableInputDecoration(
                context,
                hint: '0.00',
                prefixText: '₱ ',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _editorAvatar(_MemberAllocationDraft member) {
    final colors = Theme.of(context).colorScheme;
    final initial = member.name.trim().isEmpty
        ? '?'
        : member.name.trim()[0].toUpperCase();

    return CircleAvatar(
      radius: 19,
      backgroundColor: member.isManual
          ? _budgetYellow.withValues(alpha: 0.16)
          : colors.surfaceContainerHighest,
      foregroundImage:
          !member.isManual &&
              member.profilePhotoUrl != null &&
              member.profilePhotoUrl!.trim().isNotEmpty
          ? NetworkImage(member.profilePhotoUrl!)
          : null,
      child: Text(
        initial,
        style: TextStyle(
          color: member.isManual ? _budgetYellowDark : colors.onSurfaceVariant,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildAllocationSummary() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final unallocated = _unallocatedCents;

    final balanced = unallocated == 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: balanced ? colors.outlineVariant : _budgetYellow,
        ),
      ),
      child: Column(
        children: [
          _buildAllocationSummaryRow(
            label: 'Estimated Budget',
            amount: _totalEstimatedCents,
          ),
          const SizedBox(height: 11),
          _buildAllocationSummaryRow(
            label: 'Allocated Amount',
            amount: _allocatedCents,
          ),
          const SizedBox(height: 11),
          Divider(color: colors.outlineVariant, height: 1),
          const SizedBox(height: 11),
          _buildAllocationSummaryRow(
            label: unallocated < 0 ? 'Overallocated' : 'Unallocated Amount',
            amount: unallocated.abs(),
            emphasize: !balanced,
          ),
        ],
      ),
    );
  }

  Widget _buildAllocationSummaryRow({
    required String label,
    required int amount,
    bool emphasize = false,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: emphasize ? _budgetYellowDark : colors.onSurfaceVariant,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
        Text(
          _formatPeso(_fromCents(amount)),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: emphasize ? _budgetYellowDark : colors.onSurface,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final included = _includedMembers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review Budget Plan',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: colors.onSurface,
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Check the expense breakdown and planned member shares before publishing.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        _buildReviewCard(
          title: 'Planned Expenses',
          children: [
            ..._expenses.map((expense) {
              return _reviewRow(
                expense.nameController.text.trim(),
                _formatPeso(_parseAmount(expense.amountController.text)),
              );
            }),
            Divider(color: colors.outlineVariant),
            _reviewRow(
              'Estimated Budget',
              _formatPeso(_fromCents(_totalEstimatedCents)),
              bold: true,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildReviewCard(
          title: 'Contribution Plan',
          children: [
            _reviewRow(
              'Method',
              _splitType == 'equal' ? 'Split Equally' : 'Custom Allocation',
            ),
            _reviewRow('People Included', '${included.length}'),
            if (_members.any((member) => member.isManual))
              _reviewRow(
                'Added Manually',
                '${_members.where((member) => member.isManual).length}',
              ),
            _reviewRow(
              'Allocated Amount',
              _formatPeso(_fromCents(_allocatedCents)),
            ),
            _reviewRow(
              'Unallocated Amount',
              _formatPeso(
                _fromCents(_unallocatedCents < 0 ? 0 : _unallocatedCents),
              ),
            ),
            Divider(color: colors.outlineVariant),
            ..._members.map((member) {
              final share = _splitType == 'equal'
                  ? _fromCents(
                      _equalShareCentsByPerson[member.identityKey] ?? 0,
                    )
                  : _parseAmount(member.shareController.text);

              return _reviewRow(
                member.isManual
                    ? '${member.name} (Added manually)'
                    : member.name,
                _formatPeso(share),
              );
            }),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _budgetYellow.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.visibility_outlined,
                color: _budgetYellowDark,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'The published budget breakdown and member shares will be visible to all plan members.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard({
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 13),
          ...children,
        ],
      ),
    );
  }

  Widget _reviewRow(String label, String value, {bool bold = false}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: bold ? colors.onSurface : colors.onSurfaceVariant,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorError(String message) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: colors.onErrorContainer,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onErrorContainer,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    final colors = Theme.of(context).colorScheme;

    final primaryAction = _isSectionEditor
        ? _saveBudget
        : _currentStep == 2
        ? _saveBudget
        : _goNext;

    final primaryLabel = _isSectionEditor
        ? 'Save Changes'
        : _currentStep == 2
        ? _isEditing
              ? 'Save Changes'
              : 'Publish Budget'
        : 'Next';

    final secondaryLabel = _isSectionEditor
        ? 'Cancel'
        : _currentStep == 0
        ? 'Cancel'
        : 'Back';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSaving ? null : _goBack,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: colors.onSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: Text(secondaryLabel),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isSaving ? null : primaryAction,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: _budgetYellow,
                foregroundColor: Colors.black,
                disabledBackgroundColor: colors.surfaceContainerHighest,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : Text(
                      primaryLabel,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Contribution Tracking Settings
// -----------------------------------------------------------------------------

class ContributionTrackingSheet extends StatefulWidget {
  const ContributionTrackingSheet({
    super.key,
    required this.planId,
    required this.budget,
  });

  final int planId;
  final Map<String, dynamic> budget;

  @override
  State<ContributionTrackingSheet> createState() =>
      _ContributionTrackingSheetState();
}

class _ContributionTrackingSheetState extends State<ContributionTrackingSheet> {
  late bool _enabled;
  late bool _allowMemberMarkPaid;
  late bool _showStatusToMembers;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _enabled = _asBool(widget.budget['contribution_tracking_enabled']);

    _allowMemberMarkPaid = _asBool(widget.budget['allow_member_mark_paid']);

    _showStatusToMembers = _asBool(widget.budget['show_status_to_members']);
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final result = await BudgetService.updateContributionSettings(
      planId: widget.planId,
      contributionTrackingEnabled: _enabled,
      allowMemberMarkPaid: _allowMemberMarkPaid,
      showStatusToMembers: _showStatusToMembers,
    );

    if (!mounted) {
      return;
    }

    if (result['success'] != true) {
      setState(() {
        _isSaving = false;
        _errorMessage = BudgetService.errorMessage(
          result,
          fallback: 'Unable to save contribution settings.',
        );
      });

      return;
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Contribution Tracking',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Paid and Unpaid statuses are optional and can be enabled or disabled without deleting the budget plan.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),

            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onErrorContainer,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            _buildSettingsTile(
              icon: Icons.payments_outlined,
              title: 'Enable contribution tracking',
              subtitle: 'Show Paid, Unpaid, Collected, and Not Yet Collected.',
              value: _enabled,
              onChanged: (value) {
                setState(() {
                  _enabled = value;
                });
              },
            ),
            const SizedBox(height: 10),
            _buildSettingsTile(
              icon: Icons.check_circle_outline,
              title: 'Members can mark their own share as paid',
              subtitle:
                  'Each included member can update only their own contribution.',
              value: _allowMemberMarkPaid,
              enabled: _enabled,
              onChanged: (value) {
                setState(() {
                  _allowMemberMarkPaid = value;
                });
              },
            ),
            const SizedBox(height: 10),
            _buildSettingsTile(
              icon: Icons.visibility_outlined,
              title: 'Show statuses to all members',
              subtitle: 'Members can see who is Paid or Unpaid.',
              value: _showStatusToMembers,
              enabled: _enabled,
              onChanged: (value) {
                setState(() {
                  _showStatusToMembers = value;
                });
              },
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Turning tracking off only hides the statuses. Existing Paid and Unpaid records remain saved and will return if tracking is enabled again.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving
                        ? null
                        : () {
                            Navigator.pop(context);
                          },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveSettings,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: _budgetYellow,
                      foregroundColor: Colors.black,
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            'Save Settings',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Opacity(
      opacity: enabled ? 1 : 0.52,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _budgetYellow.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _budgetYellowDark, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              activeThumbColor: _budgetYellow,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}
