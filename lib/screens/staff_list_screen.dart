import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/staff/staff_bloc.dart';
import '../bloc/staff/staff_event.dart';
import '../bloc/staff/staff_state.dart';
import '../core/app_colors.dart';
import '../core/responsive.dart';
import '../models/user_model.dart';
import '../widgets/premium_back_button.dart';
import 'register_staff_screen.dart';

class StaffListScreen extends StatefulWidget {
  const StaffListScreen({super.key});

  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildStaffCard(UserModel user) {
    final registeredDate = DateFormat('MMM dd, yyyy').format(user.registeredAt);
    final avatarBytes = user.avatarBytes;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar (Standard Nested Container to prevent border cut-off)
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF0E1726),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: AppColors.cyanAccent.withValues(alpha: 0.5),
                width: 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cyanAccent.withValues(alpha: 0.15),
                  blurRadius: 8,
                ),
              ],
            ),
            padding: const EdgeInsets.all(2.5),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: avatarBytes != null
                  ? Image.memory(
                      avatarBytes,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      key: ValueKey('staff_avatar_${user.id}'),
                    )
                  : Container(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      child: Center(
                        child: Text(
                          user.name.isNotEmpty
                              ? user.name.substring(0, 1).toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.cyanAccent,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${user.employeeCode} • ${user.role}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Dept: ${user.department} | Enrolled: $registeredDate',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Delete Button
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.roseError),
            onPressed: () {
              _showDeleteDialog(context, user.id, user.name);
            },
            tooltip: 'Delete Staff',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = context.bottomInset;
    final isTablet = context.isTablet;

    return BlocBuilder<StaffBloc, StaffState>(
      builder: (context, state) {
        final List<UserModel> allUsers = state is StaffLoaded
            ? state.staffList
            : [];

        final filteredUsers = allUsers.where((u) {
          final q = _searchQuery.toLowerCase();
          return u.name.toLowerCase().contains(q) ||
              u.employeeCode.toLowerCase().contains(q) ||
              u.role.toLowerCase().contains(q) ||
              u.department.toLowerCase().contains(q);
        }).toList();

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: Padding(
              padding: EdgeInsets.symmetric(horizontal: isTablet ? 28.0 : 20.0),
              child: Row(
                children: [
                  const PremiumBackButton(),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Staff Directory',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterStaffScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.cyanAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.cyanAccent.withValues(alpha: 0.25),
                            width: 1.0,
                          ),
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1_outlined,
                          color: AppColors.cyanAccent,
                          size: 19,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: SafeArea(
            bottom: true,
            child: Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Search by name, ID, role, or department...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.cyanAccent),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: AppColors.textMuted),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),

                // Staff Count
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ENROLLED MEMBERS (${filteredUsers.length})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Staff List / Grid (Mobile: List | Tablet: 2-3 Column Grid)
                Expanded(
                  child: filteredUsers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.person_search_outlined,
                                  size: 48, color: AppColors.textMuted),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'No staff enrolled yet'
                                    : 'No matching staff found',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Tap the button below to enroll a new face.',
                                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        )
                      : isTablet
                          ? GridView.builder(
                              physics: const ClampingScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + 80),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: context.screenWidth >= 900 ? 3 : 2,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                childAspectRatio: 3.2,
                              ),
                              itemCount: filteredUsers.length,
                              itemBuilder: (context, index) {
                                return _buildStaffCard(filteredUsers[index]);
                              },
                            )
                          : ListView.builder(
                              physics: const ClampingScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + 80),
                              itemCount: filteredUsers.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildStaffCard(filteredUsers[index]),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
          floatingActionButton: Padding(
            padding: EdgeInsets.only(bottom: bottomInset > 0 ? 8 : 0),
            child: FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterStaffScreen()),
                );
              },
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.person_add_rounded, color: Colors.white),
              label: const Text('Enroll Staff', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, String id, String name) {
    final staffBloc = context.read<StaffBloc>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Delete Staff Member'),
          content: Text(
            'Are you sure you want to remove "$name"?\n\nThis will permanently delete their profile, face biometrics, and all their attendance history records.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                staffBloc.add(DeleteStaffEvent(staffId: id));
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Staff "$name" and all attendance history deleted.'),
                    backgroundColor: AppColors.roseError,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.roseError),
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );
  }
}
