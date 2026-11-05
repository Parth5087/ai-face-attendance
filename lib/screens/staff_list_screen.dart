import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/staff/staff_bloc.dart';
import '../bloc/staff/staff_event.dart';
import '../bloc/staff/staff_state.dart';
import '../core/app_colors.dart';
import '../core/responsive.dart';
import '../models/user_model.dart';
import '../widgets/premium_back_button.dart';
import '../widgets/premium_search_bar.dart';
import '../widgets/premium_confirmation_dialog.dart';
import '../widgets/premium_empty_state.dart';
import 'registration/register_staff_screen.dart';

class StaffListScreen extends StatefulWidget {
  const StaffListScreen({super.key});

  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDepartmentFilter = 'All';

  // Tablet Master-Detail selection
  String? _selectedUserId;

  // Edit Console Form Controllers
  final _editNameController = TextEditingController();
  final _editCodeController = TextEditingController();
  String _editRole = 'Office Staff';
  String _editDepartment = 'Operations';

  final List<String> _roles = [
    'Office Staff',
    'Delivery Boy',
    'Warehouse',
    'Manager',
    'Admin'
  ];

  final List<String> _departments = [
    'Operations',
    'Logistics',
    'Sales',
    'Customer Support',
    'IT / Admin',
    'Office',
    'General'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _editNameController.dispose();
    _editCodeController.dispose();
    super.dispose();
  }

  void _syncEditForm(UserModel user) {
    _editNameController.text = user.name;
    _editCodeController.text = user.employeeCode;
    _editRole = _roles.contains(user.role) ? user.role : _roles.first;
    _editDepartment = _departments.contains(user.department)
        ? user.department
        : _departments.first;
  }

  void _selectUser(UserModel user) {
    setState(() {
      _selectedUserId = user.id;
      _syncEditForm(user);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = context.bottomInset;
    final isTablet = context.isTablet;
    final horizontalPadding = isTablet ? 28.0 : 20.0;

    return BlocConsumer<StaffBloc, StaffState>(
      listener: (context, state) {
        if (state is StaffActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(state.message),
                ],
              ),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        } else if (state is StaffError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.roseError,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      },
      builder: (context, state) {
        final List<UserModel> allUsers =
            state is StaffLoaded ? state.staffList : [];

        // Build list of unique departments for filter chips
        final uniqueDepts = <String>{'All'};
        for (final u in allUsers) {
          if (u.department.isNotEmpty) uniqueDepts.add(u.department);
        }

        final filteredUsers = allUsers.where((u) {
          // Department filter
          if (_selectedDepartmentFilter != 'All' &&
              u.department.toLowerCase() != _selectedDepartmentFilter.toLowerCase()) {
            return false;
          }

          // Search query
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            return u.name.toLowerCase().contains(q) ||
                u.employeeCode.toLowerCase().contains(q) ||
                u.role.toLowerCase().contains(q) ||
                u.department.toLowerCase().contains(q);
          }
          return true;
        }).toList();

        // Ensure a user is selected on tablet if available among filtered results
        UserModel? selectedUser;
        if (isTablet) {
          if (filteredUsers.isNotEmpty) {
            final currentlySelected =
                filteredUsers.where((u) => u.id == _selectedUserId).firstOrNull;
            if (currentlySelected != null) {
              selectedUser = currentlySelected;
            } else {
              selectedUser = filteredUsers.first;
              _selectedUserId = selectedUser.id;
              _syncEditForm(selectedUser);
            }
          } else {
            // When search has 0 results, clear selection so no edit console is shown
            _selectedUserId = null;
            selectedUser = null;
          }
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Row(
                children: [
                  const PremiumBackButton(),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Staff Directory',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.bold,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterStaffScreen()),
                      );
                    },
                    icon: const Icon(Icons.person_add_rounded, size: 16),
                    label: const Text('Enroll Staff'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: AppFonts.bold,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: SafeArea(
            bottom: true,
            child: allUsers.isEmpty
                ? _buildEmptyState(context)
                : isTablet
                    ? _buildTabletLayout(
                        context,
                        allUsers: allUsers,
                        filteredUsers: filteredUsers,
                        uniqueDepts: uniqueDepts.toList(),
                        bottomInset: bottomInset,
                        selectedUser: selectedUser,
                      )
                    : _buildMobileLayout(
                        context,
                        allUsers: allUsers,
                        filteredUsers: filteredUsers,
                        uniqueDepts: uniqueDepts.toList(),
                        bottomInset: bottomInset,
                        horizontalPadding: horizontalPadding,
                      ),
          ),
          floatingActionButton: !isTablet && allUsers.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: FloatingActionButton.extended(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterStaffScreen()),
                      );
                    },
                    backgroundColor: AppColors.primary,
                    icon: const Icon(Icons.person_add_rounded, color: Colors.white),
                    label: const Text(
                      'Enroll Staff',
                      style: TextStyle(
                        fontFamily: AppFonts.bold,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  // --- 📱 MOBILE LAYOUT (<600px) ---
  Widget _buildMobileLayout(
    BuildContext context, {
    required List<UserModel> allUsers,
    required List<UserModel> filteredUsers,
    required List<String> uniqueDepts,
    required double bottomInset,
    required double horizontalPadding,
  }) {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 8),
          child: PremiumSearchBar(
            controller: _searchController,
            hintText: 'Search by name, ID, role, or dept...',
            counterBadge: '${filteredUsers.length} Enrolled',
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            onClear: () => setState(() => _searchQuery = ''),
          ),
        ),

        // Department Filter Chips
        if (uniqueDepts.length > 2)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 4),
            child: Row(
              children: uniqueDepts.map((dept) {
                final isSelected = _selectedDepartmentFilter.toLowerCase() == dept.toLowerCase();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      dept,
                      style: TextStyle(
                        fontFamily: isSelected ? AppFonts.bold : AppFonts.medium,
                        fontSize: 12,
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surfaceCard,
                    side: BorderSide(
                      color: isSelected ? AppColors.cyanAccent : AppColors.border,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedDepartmentFilter = dept);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

        // Count Row
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'ENROLLED MEMBERS',
                    style: TextStyle(
                      fontFamily: AppFonts.bold,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.cyanAccent.withValues(alpha: 0.12),
                      border: Border.all(
                        color: AppColors.cyanAccent.withValues(alpha: 0.30),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      '${filteredUsers.length}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.cyanAccent,
                        height: 1.0,
                      ),
                      textHeightBehavior: const TextHeightBehavior(
                        applyHeightToFirstAscent: false,
                        applyHeightToLastDescent: false,
                      ),
                    ),
                  ),
                ],
              ),
              if (_searchQuery.isNotEmpty || _selectedDepartmentFilter != 'All')
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDepartmentFilter = 'All';
                      _searchQuery = '';
                      _searchController.clear();
                    });
                  },
                  child: const Text(
                    'Reset Filters',
                    style: TextStyle(
                      fontFamily: AppFonts.bold,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.cyanAccent,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Staff List or In-Pane Empty Search
        Expanded(
          child: filteredUsers.isEmpty
              ? _buildInPaneEmptySearch()
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    4,
                    horizontalPadding,
                    bottomInset + 64,
                  ),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildStaffTile(
                        user: user,
                        isSelected: false,
                        onTap: () => _showMobileEditSheet(context, user),
                        onDelete: () => _showDeleteDialog(context, user.id, user.name),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- 📟 TABLET MASTER-DETAIL LAYOUT (>=600px) ---
  Widget _buildTabletLayout(
    BuildContext context, {
    required List<UserModel> allUsers,
    required List<UserModel> filteredUsers,
    required List<String> uniqueDepts,
    required double bottomInset,
    required UserModel? selectedUser,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Pane (Flex 5): Search, Filters, Enrolled List
          Expanded(
            flex: 5,
            child: _buildTabletMasterList(
              filteredUsers: filteredUsers,
              uniqueDepts: uniqueDepts,
              bottomInset: bottomInset,
            ),
          ),

          const SizedBox(width: 20),

          // Right Pane (Flex 6): "Staff Profile Information & Edit Console"
          Expanded(
            flex: 6,
            child: selectedUser != null
                ? _buildTabletEditConsole(selectedUser)
                : _buildSelectStaffPlaceholder(hasSearch: _searchQuery.isNotEmpty),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletMasterList({
    required List<UserModel> filteredUsers,
    required List<String> uniqueDepts,
    required double bottomInset,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: PremiumSearchBar(
              controller: _searchController,
              hintText: 'Search by name, ID, role...',
              counterBadge: '${filteredUsers.length} Found',
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              onClear: () => setState(() => _searchQuery = ''),
            ),
          ),

          // Department Filters
          if (uniqueDepts.length > 2)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(
                children: uniqueDepts.map((dept) {
                  final isSelected = _selectedDepartmentFilter.toLowerCase() == dept.toLowerCase();
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        dept,
                        style: TextStyle(
                          fontFamily: isSelected ? AppFonts.bold : AppFonts.medium,
                          fontSize: 11.5,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surfaceCardLight,
                      side: BorderSide(
                        color: isSelected ? AppColors.cyanAccent : AppColors.border,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedDepartmentFilter = dept);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

          // Enrolled Members Count Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'ENROLLED MEMBERS',
                      style: TextStyle(
                        fontFamily: AppFonts.bold,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.cyanAccent.withValues(alpha: 0.12),
                        border: Border.all(
                          color: AppColors.cyanAccent.withValues(alpha: 0.30),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        '${filteredUsers.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.cyanAccent,
                          height: 1.0,
                        ),
                        textHeightBehavior: const TextHeightBehavior(
                          applyHeightToFirstAscent: false,
                          applyHeightToLastDescent: false,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_searchQuery.isNotEmpty || _selectedDepartmentFilter != 'All')
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDepartmentFilter = 'All';
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                    child: const Text(
                      'Reset',
                      style: TextStyle(
                        fontFamily: AppFonts.bold,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.cyanAccent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Scrollable Staff Tiles or In-Pane Empty Search
          Expanded(
            child: filteredUsers.isEmpty
                ? _buildInPaneEmptySearch()
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      final isSelected = user.id == _selectedUserId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildStaffTile(
                          user: user,
                          isSelected: isSelected,
                          onTap: () => _selectUser(user),
                          onDelete: () => _showDeleteDialog(context, user.id, user.name),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- 📟 RIGHT PANE: STAFF PROFILE & EDIT CONSOLE ---
  Widget _buildTabletEditConsole(UserModel user) {
    final registeredDate = DateFormat('MMMM dd, yyyy').format(user.registeredAt);
    final avatarBytes = user.avatarBytes;
    final initial = user.name.isNotEmpty ? user.name.substring(0, 1).toUpperCase() : 'U';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.manage_accounts_rounded, size: 20, color: AppColors.cyanAccent),
                const SizedBox(width: 10),
                const Text(
                  'Staff Profile & Edit Console',
                  style: TextStyle(
                    fontFamily: AppFonts.bold,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Active Staff',
                    style: TextStyle(
                      fontFamily: AppFonts.bold,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.emeraldGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Form Body
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Avatar & Credentials Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        // Avatar (no outer clip antiAlias, inner ClipRRect)
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.cyanAccent.withValues(alpha: 0.6), width: 2.0),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.cyanAccent.withValues(alpha: 0.2),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(2.5),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: avatarBytes != null
                                ? Image.memory(
                                    avatarBytes,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                    filterQuality: FilterQuality.high,
                                    key: ValueKey('console_avatar_${user.id}'),
                                  )
                                : Container(
                                    color: AppColors.primary.withValues(alpha: 0.25),
                                    alignment: Alignment.center,
                                    child: Text(
                                      initial,
                                      style: const TextStyle(
                                        fontFamily: AppFonts.bold,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.cyanAccent,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Summary Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                style: const TextStyle(
                                  fontFamily: AppFonts.bold,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.cyanAccent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      user.employeeCode,
                                      style: const TextStyle(
                                        fontFamily: AppFonts.bold,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.cyanAccent,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    user.role,
                                    style: const TextStyle(
                                      fontFamily: AppFonts.medium,
                                      fontSize: 12.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Enrolled: $registeredDate',
                                style: const TextStyle(
                                  fontFamily: AppFonts.medium,
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 2. Form Inputs
                  const Text(
                    'EDIT CREDENTIALS',
                    style: TextStyle(
                      fontFamily: AppFonts.bold,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Name Field
                  TextField(
                    controller: _editNameController,
                    style: const TextStyle(fontFamily: AppFonts.medium, fontSize: 14),
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Employee Code Field
                  TextField(
                    controller: _editCodeController,
                    style: const TextStyle(fontFamily: AppFonts.medium, fontSize: 14),
                    decoration: const InputDecoration(
                      labelText: 'Employee ID / Code',
                      prefixIcon: Icon(Icons.badge_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Role Dropdown
                  DropdownButtonFormField<String>(
                    key: ValueKey('role_${user.id}_$_editRole'),
                    initialValue: _roles.contains(_editRole) ? _editRole : _roles.first,
                    decoration: const InputDecoration(
                      labelText: 'Designation / Role',
                      prefixIcon: Icon(Icons.work_outline_rounded, size: 20),
                    ),
                    items: _roles.map((r) {
                      return DropdownMenuItem(value: r, child: Text(r));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _editRole = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Department Dropdown
                  DropdownButtonFormField<String>(
                    key: ValueKey('dept_${user.id}_$_editDepartment'),
                    initialValue: _departments.contains(_editDepartment)
                        ? _editDepartment
                        : _departments.first,
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      prefixIcon: Icon(Icons.domain_rounded, size: 20),
                    ),
                    items: _departments.map((d) {
                      return DropdownMenuItem(value: d, child: Text(d));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _editDepartment = val);
                    },
                  ),

                  const SizedBox(height: 24),

                  // 3. Action Buttons
                  Row(
                    children: [
                      // Save Changes
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final name = _editNameController.text.trim();
                            final code = _editCodeController.text.trim().toUpperCase();
                            if (name.isEmpty || code.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Name and Employee Code cannot be empty'),
                                  backgroundColor: AppColors.amberWarning,
                                ),
                              );
                              return;
                            }
                            context.read<StaffBloc>().add(
                                  UpdateStaffEvent(
                                    staffId: user.id,
                                    name: name,
                                    employeeCode: code,
                                    role: _editRole,
                                    department: _editDepartment,
                                  ),
                                );
                            HapticFeedback.lightImpact();
                          },
                          icon: const Icon(Icons.save_rounded, size: 18),
                          label: const Text('Save Changes'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Reset
                      OutlinedButton(
                        onPressed: () => setState(() => _syncEditForm(user)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Reset'),
                      ),
                      const SizedBox(width: 10),

                      // Delete Staff Member
                      IconButton(
                        onPressed: () => _showDeleteDialog(context, user.id, user.name),
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.roseError),
                        tooltip: 'Delete Staff Member',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.roseError.withValues(alpha: 0.12),
                          padding: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: AppColors.roseError.withValues(alpha: 0.25)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 🎨 REUSABLE STAFF TILE ---
  Widget _buildStaffTile({
    required UserModel user,
    required bool isSelected,
    required VoidCallback onTap,
    required VoidCallback onDelete,
  }) {
    final avatarBytes = user.avatarBytes;
    final initial = user.name.isNotEmpty ? user.name.substring(0, 1).toUpperCase() : 'U';

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? AppColors.cyanAccent.withValues(alpha: 0.08) : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.cyanAccent : AppColors.border,
          width: isSelected ? 1.6 : 1.0,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar (outer container padding 2.5, inner ClipRRect)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppColors.cyanAccent : AppColors.border,
                      width: 1.2,
                    ),
                  ),
                  padding: const EdgeInsets.all(2.5),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: avatarBytes != null
                        ? Image.memory(
                            avatarBytes,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            filterQuality: FilterQuality.medium,
                            key: ValueKey('tile_staff_avatar_${user.id}'),
                          )
                        : Container(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            alignment: Alignment.center,
                            child: Text(
                              initial,
                              style: const TextStyle(
                                fontFamily: AppFonts.bold,
                                fontWeight: FontWeight.w700,
                                color: AppColors.cyanAccent,
                                fontSize: 17,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name & Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontFamily: AppFonts.bold,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.cyanAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              user.employeeCode,
                              style: const TextStyle(
                                fontFamily: AppFonts.bold,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.cyanAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${user.role} • ${user.department}',
                              style: const TextStyle(
                                fontFamily: AppFonts.medium,
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 📱 MOBILE EDIT BOTTOM SHEET ---
  void _showMobileEditSheet(BuildContext context, UserModel user) {
    _syncEditForm(user);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final registeredDate = DateFormat('MMM dd, yyyy').format(user.registeredAt);
            final avatarBytes = user.avatarBytes;
            final initial = user.name.isNotEmpty ? user.name.substring(0, 1).toUpperCase() : 'U';

            return Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 580,
                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                ),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    border: Border.all(color: AppColors.border, width: 1.0),
                    boxShadow: AppColors.softShadow,
                  ),
                  child: SafeArea(
                    top: false,
                    bottom: true,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Handle & Close
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const SizedBox(width: 36),
                              Container(
                                width: 44,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: AppColors.border,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => Navigator.pop(sheetContext),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceCardLight,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Profile Header
                          Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.cyanAccent, width: 1.8),
                                ),
                                padding: const EdgeInsets.all(2.5),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: avatarBytes != null
                                      ? Image.memory(
                                          avatarBytes,
                                          fit: BoxFit.cover,
                                          gaplessPlayback: true,
                                          filterQuality: FilterQuality.high,
                                          key: ValueKey('sheet_user_avatar_${user.id}'),
                                        )
                                      : Container(
                                          color: AppColors.primary.withValues(alpha: 0.25),
                                          alignment: Alignment.center,
                                          child: Text(
                                            initial,
                                            style: const TextStyle(
                                              fontFamily: AppFonts.bold,
                                              fontSize: 22,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.cyanAccent,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.name,
                                      style: const TextStyle(
                                        fontFamily: AppFonts.bold,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${user.employeeCode} • ${user.role}',
                                      style: const TextStyle(
                                        fontFamily: AppFonts.medium,
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      'Enrolled: $registeredDate',
                                      style: const TextStyle(
                                        fontFamily: AppFonts.medium,
                                        fontSize: 10.5,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const Divider(height: 1, color: AppColors.border),
                          const SizedBox(height: 16),

                          // Form
                          TextField(
                            controller: _editNameController,
                            style: const TextStyle(fontFamily: AppFonts.medium, fontSize: 14),
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                            ),
                          ),
                          const SizedBox(height: 12),

                          TextField(
                            controller: _editCodeController,
                            style: const TextStyle(fontFamily: AppFonts.medium, fontSize: 14),
                            decoration: const InputDecoration(
                              labelText: 'Employee Code / ID',
                              prefixIcon: Icon(Icons.badge_outlined, size: 20),
                            ),
                          ),
                          const SizedBox(height: 12),

                          DropdownButtonFormField<String>(
                            key: ValueKey('sheet_role_${user.id}_$_editRole'),
                            initialValue: _roles.contains(_editRole) ? _editRole : _roles.first,
                            decoration: const InputDecoration(
                              labelText: 'Designation / Role',
                              prefixIcon: Icon(Icons.work_outline_rounded, size: 20),
                            ),
                            items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                            onChanged: (val) {
                              if (val != null) setSheetState(() => _editRole = val);
                            },
                          ),
                          const SizedBox(height: 12),

                          DropdownButtonFormField<String>(
                            key: ValueKey('sheet_dept_${user.id}_$_editDepartment'),
                            initialValue: _departments.contains(_editDepartment)
                                ? _editDepartment
                                : _departments.first,
                            decoration: const InputDecoration(
                              labelText: 'Department',
                              prefixIcon: Icon(Icons.domain_rounded, size: 20),
                            ),
                            items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                            onChanged: (val) {
                              if (val != null) setSheetState(() => _editDepartment = val);
                            },
                          ),
                          const SizedBox(height: 20),

                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    final name = _editNameController.text.trim();
                                    final code = _editCodeController.text.trim().toUpperCase();
                                    if (name.isEmpty || code.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Name and Employee Code cannot be empty'),
                                          backgroundColor: AppColors.amberWarning,
                                        ),
                                      );
                                      return;
                                    }
                                    Navigator.pop(sheetContext);
                                    context.read<StaffBloc>().add(
                                          UpdateStaffEvent(
                                            staffId: user.id,
                                            name: name,
                                            employeeCode: code,
                                            role: _editRole,
                                            department: _editDepartment,
                                          ),
                                        );
                                  },
                                  icon: const Icon(Icons.save_rounded, size: 18),
                                  label: const Text('Save Changes'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                onPressed: () {
                                  Navigator.pop(sheetContext);
                                  _showDeleteDialog(context, user.id, user.name);
                                },
                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.roseError),
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.roseError.withValues(alpha: 0.12),
                                  padding: const EdgeInsets.all(14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: AppColors.roseError.withValues(alpha: 0.25)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- 🔍 IN-PANE EMPTY SEARCH STATE (Soft Keyboard Safe) ---
  Widget _buildInPaneEmptySearch() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cyanAccent.withValues(alpha: 0.10),
                border: Border.all(color: AppColors.cyanAccent.withValues(alpha: 0.20)),
              ),
              child: const Icon(
                Icons.person_search_rounded,
                size: 26,
                color: AppColors.cyanAccent,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No Matching Staff',
              style: TextStyle(
                fontFamily: AppFonts.bold,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No employees match "$_searchQuery".'
                  : 'No employees found in department "$_selectedDepartmentFilter".',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppFonts.medium,
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                  _selectedDepartmentFilter = 'All';
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.cyanAccent,
                side: const BorderSide(color: AppColors.cyanAccent),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Reset Search & Filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectStaffPlaceholder({bool hasSearch = false}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (hasSearch ? AppColors.amberWarning : AppColors.cyanAccent)
                      .withValues(alpha: 0.10),
                  border: Border.all(
                    color: (hasSearch ? AppColors.amberWarning : AppColors.cyanAccent)
                        .withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  hasSearch ? Icons.search_off_rounded : Icons.touch_app_rounded,
                  size: 30,
                  color: hasSearch ? AppColors.amberWarning : AppColors.cyanAccent,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                hasSearch ? 'No Staff Found' : 'Select a Staff Member',
                style: const TextStyle(
                  fontFamily: AppFonts.bold,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                hasSearch
                    ? (_searchQuery.isNotEmpty
                        ? 'No employee profiles match "$_searchQuery". Reset or refine your search to select a staff member.'
                        : 'No employee profiles match the selected department filter.')
                    : 'Choose an employee from the directory on the left to review their credentials, edit designation, or update profile info.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppFonts.medium,
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              if (hasSearch) ...[
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedDepartmentFilter = 'All';
                      _searchQuery = '';
                      _searchController.clear();
                    });
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Reset Search & Filters'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.cyanAccent,
                    backgroundColor: AppColors.cyanAccent.withValues(alpha: 0.10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return PremiumEmptyState(
      icon: Icons.group_add_rounded,
      title: 'No Staff Enrolled Yet',
      message: 'Enroll your team members with facial biometrics to start tracking attendance automatically.',
      actionText: 'Enroll First Employee',
      iconColor: AppColors.cyanAccent,
      onAction: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RegisterStaffScreen()),
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, String id, String name) {
    final staffBloc = context.read<StaffBloc>();
    PremiumConfirmationDialog.show(
      context: context,
      title: 'Delete Staff Member',
      message:
          'Are you sure you want to remove "$name"?\n\nThis will permanently remove their profile, face biometrics, and all associated attendance history logs.',
      confirmText: 'Delete Staff',
      cancelText: 'Keep Staff',
      icon: Icons.person_remove_rounded,
      iconColor: AppColors.roseError,
      isDestructive: true,
    ).then((confirmed) {
      if (confirmed == true) {
        staffBloc.add(DeleteStaffEvent(staffId: id));
        HapticFeedback.mediumImpact();
      }
    });
  }
}
