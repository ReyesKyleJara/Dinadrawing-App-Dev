import 'package:flutter/material.dart';

import 'plan_model.dart';

class ArchivePlansPage extends StatefulWidget {
  const ArchivePlansPage({
    super.key,
    required this.plansByMe,
    required this.plansWithMe,
    required this.onRestore,
    required this.onDelete,
  });

  final List<Plan> plansByMe;
  final List<Plan> plansWithMe;
  final void Function(String sectionId, Plan plan) onRestore;
  final void Function(String sectionId, Plan plan) onDelete;

  @override
  State<ArchivePlansPage> createState() => _ArchivePlansPageState();
}

class _ArchivePlansPageState extends State<ArchivePlansPage> {
  final Set<String> _selectedKeys = <String>{};
  final Map<String, GlobalKey<_SwipeablePlanCardState>> _cardKeys = {};

  List<_PlanEntry> get _archivedPlans => [
        ...widget.plansByMe.map((plan) => _PlanEntry('plansByMe', 'Plans by Me', plan)),
        ...widget.plansWithMe.map((plan) => _PlanEntry('plansWithMe', 'Plans with Me', plan)),
      ];

  String _keyFor(_PlanEntry entry) => '${entry.sectionId}:${entry.plan.title}:${entry.plan.date}';

  bool _isSelected(_PlanEntry entry) => _selectedKeys.contains(_keyFor(entry));

  void _toggleSelection(_PlanEntry entry) {
    setState(() {
      final key = _keyFor(entry);
      if (_selectedKeys.contains(key)) {
        _selectedKeys.remove(key);
      } else {
        _selectedKeys.add(key);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedKeys
        ..clear()
        ..addAll(_archivedPlans.map(_keyFor));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedKeys.clear();
    });
    for (final key in _cardKeys.values) {
      key.currentState?.reset();
    }
  }

  Future<void> _restoreSelected() async {
    final selectedEntries = _archivedPlans.where((e) => _selectedKeys.contains(_keyFor(e))).toList();
    if (selectedEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one plan')),
      );
      return;
    }

    final confirmed = await _showCustomDialog(
      context,
      title: 'Restore Plan',
      content: 'Are you sure you want to bring this plan back?',
      cancelText: 'Cancel',
      confirmText: 'Confirm Restore',
      confirmColor: const Color(0xFFF2B73F),
    );

    if (confirmed == true && mounted) {
      for (final entry in selectedEntries) {
        widget.onRestore(entry.sectionId, entry.plan);
      }
      _clearSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${selectedEntries.length} plan(s) restored')),
      );
    }
  }

  Future<void> _deleteSelected() async {
    final selectedEntries = _archivedPlans.where((e) => _selectedKeys.contains(_keyFor(e))).toList();
    if (selectedEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one plan')),
      );
      return;
    }

    final confirmed = await _showCustomDialog(
      context,
      title: 'Delete Plan Permanently',
      content: 'This plan will be deleted permanently and cannot be restored.',
      cancelText: 'Cancel',
      confirmText: 'Delete Permanently',
      confirmColor: Colors.red.shade400,
    );

    if (confirmed == true && mounted) {
      for (final entry in selectedEntries) {
        widget.onDelete(entry.sectionId, entry.plan);
      }
      _clearSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${selectedEntries.length} plan(s) deleted')),
      );
    }
  }

  Future<bool?> _showCustomDialog(
    BuildContext context, {
    required String title,
    required String content,
    required String cancelText,
    required String confirmText,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                content,
                style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        backgroundColor: Colors.grey.shade100,
                      ),
                      child: Text(
                        cancelText,
                        style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: confirmColor,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: Text(
                        confirmText,
                        style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final archivedPlans = _archivedPlans;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.arrow_back_ios, size: 16),
                    color: const Color(0xFFF2B73F),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 6),
                  const Text('Back', style: TextStyle(fontSize: 14, color: Colors.black54)),
                  const Spacer(),
                  const CircleAvatar(
                    radius: 14,
                    backgroundImage: AssetImage('images/user-avatar.png'),
                    backgroundColor: Colors.transparent,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Archived Plans',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Slide right to select plans.',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  if (archivedPlans.isNotEmpty)
                    PopupMenuButton<String>(
                      icon: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.more_vert, size: 18),
                      ),
                      onSelected: (value) {
                        if (value == 'selectAll') {
                          _selectAll();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'selectAll', child: Text('Select All')),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: archivedPlans.isEmpty
                  ? const Center(child: Text('No archived plans yet.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: archivedPlans.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final entry = archivedPlans[index];
                        final entryKey = _keyFor(entry);
                        _cardKeys.putIfAbsent(entryKey, () => GlobalKey<_SwipeablePlanCardState>());
                        return _SwipeablePlanCard(
                          key: _cardKeys[entryKey],
                          plan: entry.plan,
                          subtitle: 'Archived ${entry.sectionLabel}',
                          isSelected: _isSelected(entry),
                          onToggle: () => _toggleSelection(entry),
                        );
                      },
                    ),
            ),
            if (_selectedKeys.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _restoreSelected,
                        icon: const Icon(Icons.restore, color: Colors.white),
                        label: const Text('Restore', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF2B73F),
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _deleteSelected,
                        icon: const Icon(Icons.delete_outline, color: Colors.black),
                        label: const Text('Delete', style: TextStyle(color: Colors.black)),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey.shade300),
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
  }
}

class _SwipeablePlanCard extends StatefulWidget {
  const _SwipeablePlanCard({
    super.key,
    required this.plan,
    required this.subtitle,
    required this.isSelected,
    required this.onToggle,
  });

  final Plan plan;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onToggle;

  @override
  State<_SwipeablePlanCard> createState() => _SwipeablePlanCardState();
}

class _SwipeablePlanCardState extends State<_SwipeablePlanCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.15, 0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void reset() {
    _controller.reverse();
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (details.primaryVelocity! > 500) {
      _controller.forward();
    } else if (details.primaryVelocity! < -500) {
      _controller.reverse();
    } else {
      if (_controller.value > 0.5) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: SlideTransition(
        position: _offsetAnimation,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final showCheckbox = _controller.value > 0.02;
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.isSelected ? const Color(0xFFF2B73F) : Colors.grey.shade300,
                ),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
              ),
              child: Row(
                children: [
                  AnimatedOpacity(
                    opacity: showCheckbox ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: SizedBox(
                      width: 24,
                      child: Checkbox(
                        value: widget.isSelected,
                        activeColor: const Color(0xFFF2B73F),
                        onChanged: showCheckbox ? (_) => widget.onToggle() : null,
                      ),
                    ),
                  ),
                  if (showCheckbox) const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.plan.title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.plan.date}${widget.plan.location.isEmpty ? '' : ' • ${widget.plan.location}'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Text(widget.subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PlanEntry {
  _PlanEntry(this.sectionId, this.sectionLabel, this.plan);

  final String sectionId;
  final String sectionLabel;
  final Plan plan;
}
