import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/plan_service.dart';

class PlanSettingsPage extends StatefulWidget {
  final int planId;

  const PlanSettingsPage({super.key, required this.planId});

  @override
  State<PlanSettingsPage> createState() => _PlanSettingsPageState();
}

class _PlanSettingsPageState extends State<PlanSettingsPage> {
  final TextEditingController _planNameController = TextEditingController();
  final TextEditingController _planDescriptionController =
      TextEditingController();
  final TextEditingController _planDateController = TextEditingController();
  final TextEditingController _planLocationController = TextEditingController();

  String _selectedStatus = 'Plan Ongoing';
  Color? _bannerColor;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isLeaving = false;

  int? _currentUserId;
  int? _adminId;

  List<Map<String, dynamic>> _members = [];

  bool get _isAdmin {
    return _currentUserId != null && _adminId == _currentUserId;
  }

  List<Map<String, dynamic>> get _transferableMembers {
    return _members.where((member) {
      final memberId = _parseInt(member['id']);
      final pivot = _asMap(member['pivot']);
      final role = pivot?['role']?.toString().toLowerCase();

      return memberId != null &&
          memberId != _currentUserId &&
          role != 'admin';
    }).toList();
  }

  final List<_PlanStatus> _statusOptions = const [
    _PlanStatus(label: 'Plan Ongoing', color: Color(0xFFEAB308)),
    _PlanStatus(label: 'Plan Postponed', color: Color(0xFF3B82F6)),
    _PlanStatus(label: 'Plan Canceled', color: Color(0xFFEF4444)),
    _PlanStatus(label: 'Planned', color: Color(0xFF22C55E)),
    _PlanStatus(label: 'Completed', color: Color(0xFF16A34A)),
  ];

  final List<Color> _solidColors = const [
    Color(0xFFFF8243),
    Color(0xFFFFC0CB),
    Color(0xFFFCE883),
    Color(0xFF069494),
    Color(0xFFFF4F79),
    Color(0xFF00C2A8),
    Color(0xFFFFD166),
    Color(0xFF2F80ED),
    Color(0xFFF7F7FF),
  ];

  @override
  void initState() {
    super.initState();
    _loadPlanDetails();
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  String _memberDisplayName(Map<String, dynamic> member) {
    final name = member['name']?.toString().trim();
    final username = member['username']?.toString().trim();
    final email = member['email']?.toString().trim();

    if (name != null && name.isNotEmpty) return name;
    if (username != null && username.isNotEmpty) return username;
    if (email != null && email.isNotEmpty) return email;

    return 'Member';
  }

  String _memberSubtitle(Map<String, dynamic> member) {
    final email = member['email']?.toString().trim();
    final username = member['username']?.toString().trim();

    if (email != null && email.isNotEmpty) return email;
    if (username != null && username.isNotEmpty) return '@$username';

    return 'Plan member';
  }

  Future<void> _loadPlanDetails() async {
    try {
      final user = await AuthService.getCurrentUser();
      final result = await PlanService.getPlanById(widget.planId);

      if (!mounted) return;

      final plan = _asMap(result['plan']);

      if (plan == null) {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Plan not found.')),
        );
        return;
      }

      final userMap = _asMap(user);
      final currentUser = _asMap(userMap?['user']) ?? userMap;
      final admin = _asMap(plan['admin']);

      final rawMembers = plan['members'];

      setState(() {
        _currentUserId = _parseInt(currentUser?['id']);
        _adminId = _parseInt(
          plan['admin_id'] ?? admin?['id'],
        );

        _members = rawMembers is List
            ? rawMembers
                .whereType<Map>()
                .map((member) => Map<String, dynamic>.from(member))
                .toList()
            : <Map<String, dynamic>>[];

        _planNameController.text = plan['title']?.toString() ?? '';
        _planDescriptionController.text =
            plan['description']?.toString() ?? '';
        _planDateController.text = plan['plan_date']?.toString() ?? '';
        _planLocationController.text = plan['location']?.toString() ?? '';
        _selectedStatus = plan['status']?.toString() ?? 'Plan Ongoing';

        if (plan['banner_color'] != null) {
          String hex = plan['banner_color'].toString().replaceAll('#', '');
          if (hex.length == 6) hex = 'FF$hex';
          _bannerColor = Color(int.parse(hex, radix: 16));
        } else {
          _bannerColor = const Color(0xFF2F80ED);
        }

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading plan: $e');

      if (mounted) {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading plan: $e')),
        );
      }
    }
  }

  Future<void> _deletePlan() async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the plan admin can delete this plan.'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: const Text(
          'Delete Plan?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        content: const Text(
          'This will move the plan to Deleted Plans. You can restore it later from the Deleted Plans page.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);

    try {
      final result = await PlanService.deletePlan(widget.planId);

      if (!mounted) return;

      if (result['success'] == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to delete plan.')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Plan moved to Deleted Plans.'),
        ),
      );

      Navigator.pop(context, 'deleted');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _leavePlan() async {
    if (_isAdmin) {
      await _transferAdminAndLeave();
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: const Text(
          'Leave Plan?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        content: const Text(
          'You will lose access to this plan and it will be removed from your Plans with Me.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Leave',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLeaving = true);

    try {
      final result = await PlanService.leavePlan(widget.planId);

      if (!mounted) return;

      if (result['success'] == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to leave plan.')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'You left the plan successfully.'),
        ),
      );

      Navigator.pop(context, 'left');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLeaving = false);
      }
    }
  }

  Future<void> _transferAdminAndLeave() async {
    final candidates = _transferableMembers;

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You need at least one member before transferring admin role.',
          ),
        ),
      );
      return;
    }

    final selectedAdminId = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose New Plan Admin',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Select a member who will manage this plan after you leave.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: candidates.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final member = candidates[index];
                      final memberId = _parseInt(member['id']);
                      final displayName = _memberDisplayName(member);

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.grey.shade200,
                          ),
                        ),
                        leading: CircleAvatar(
                          backgroundColor:
                              const Color(0xFFF2B73F).withValues(alpha: 0.18),
                          child: Text(
                            displayName[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          _memberSubtitle(member),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.admin_panel_settings_outlined,
                          color: Colors.black87,
                        ),
                        onTap: () {
                          if (memberId != null) {
                            Navigator.pop(context, memberId);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedAdminId == null) return;

    final selectedMember = candidates.firstWhere(
      (member) => _parseInt(member['id']) == selectedAdminId,
    );

    final selectedName = _memberDisplayName(selectedMember);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: const Text(
          'Transfer Admin & Leave?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        content: Text(
          '$selectedName will become the new Plan Admin. You will lose access to this plan after leaving.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Transfer & Leave',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLeaving = true);

    try {
      final result = await PlanService.leavePlan(
        widget.planId,
        newAdminId: selectedAdminId,
      );

      if (!mounted) return;

      if (result['success'] == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? 'Failed to transfer admin role.',
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message'] ??
                'Admin role transferred and you left the plan successfully.',
          ),
        ),
      );

      Navigator.pop(context, 'left');
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLeaving = false);
      }
    }
  }

  Future<void> _saveChanges() async {
    if (_planNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan Name is required!')),
      );
      return;
    }

    if (_bannerColor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a banner color.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    String hexColor =
        '#${_bannerColor!.value.toRadixString(16).substring(2).toUpperCase()}';

    try {
      final result = await PlanService.updatePlan(
        planId: widget.planId,
        title: _planNameController.text.trim(),
        description: _planDescriptionController.text.trim(),
        planDate: _planDateController.text.trim(),
        location: _planLocationController.text.trim(),
        status: _selectedStatus,
        bannerColor: hexColor,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Settings saved!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error saving plan: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving plan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showBannerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  "Change Banner Color",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: _solidColors.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _bannerColor = _solidColors[index];
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 50,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: _solidColors[index],
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _planNameController.dispose();
    _planDescriptionController.dispose();
    _planDateController.dispose();
    _planLocationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFAFAFA),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFF2B73F)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 24.0,
            vertical: 20.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Row(
                  children: [
                    Icon(Icons.arrow_back, color: Color(0xFFF2B73F), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Back',
                      style: TextStyle(color: Colors.black87, fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Plan Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              _buildFieldLabel('Plan Header'),
              const SizedBox(height: 8),
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: _bannerColor,
                ),
                alignment: Alignment.bottomRight,
                padding: const EdgeInsets.all(12),
                child: GestureDetector(
                  onTap: _showBannerPicker,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, color: Colors.white, size: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildFieldLabel('Plan Name'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _planNameController,
                hint: 'Plan Name',
              ),
              const SizedBox(height: 16),
              _buildFieldLabel('Plan Description'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _planDescriptionController,
                hint: 'Type Plan Description...',
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              _buildFieldLabel('Plan Date & Time'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _planDateController,
                hint: 'YYYY-MM-DD',
                suffixIcon: const Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              _buildFieldLabel('Plan Location'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _planLocationController,
                hint: 'Location',
                suffixIcon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Plan Status',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              _buildFieldLabel('Current Status'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedStatus,
                    isExpanded: true,
                    icon: const Padding(
                      padding: EdgeInsets.only(right: 12.0),
                      child: Icon(Icons.arrow_drop_down, color: Colors.black),
                    ),
                    items: _statusOptions.map((status) {
                      return DropdownMenuItem<String>(
                        value: status.label,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: status.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                status.label,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedStatus = value);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF2B73F),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
              _buildPlanAccessSection(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanAccessSection() {
    final title = _isAdmin ? 'Admin Controls' : 'Plan Access';
    final description = _isAdmin
        ? 'As the plan admin, you can transfer admin rights before leaving or move this plan to Deleted Plans.'
        : 'You are a member of this plan. You can leave this plan anytime.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _isAdmin
                      ? Colors.red.withValues(alpha: 0.10)
                      : const Color(0xFFF2B73F).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isAdmin
                      ? Icons.admin_panel_settings_outlined
                      : Icons.logout,
                  color: _isAdmin
                      ? Colors.red.shade400
                      : const Color(0xFFF2B73F),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          if (_isAdmin)
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLeaving ? null : _transferAdminAndLeave,
                    icon: _isLeaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.black87,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.swap_horiz_outlined,
                            color: Colors.black87,
                          ),
                    label: Text(
                      _isLeaving ? 'Leaving...' : 'Transfer Admin & Leave',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isDeleting ? null : _deletePlan,
                    icon: _isDeleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.delete_outline, color: Colors.white),
                    label: Text(
                      _isDeleting ? 'Deleting...' : 'Move to Deleted Plans',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLeaving ? null : _leavePlan,
                icon: _isLeaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.black87,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.logout, color: Colors.black87),
                label: Text(
                  _isLeaving ? 'Leaving...' : 'Leave Plan',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) => Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Colors.black,
        ),
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, color: Colors.black54),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: Color(0xFFF2B73F),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _PlanStatus {
  final String label;
  final Color color;

  const _PlanStatus({required this.label, required this.color});
}