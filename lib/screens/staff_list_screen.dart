import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/staff/staff_bloc.dart';
import '../bloc/staff/staff_event.dart';
import '../bloc/staff/staff_state.dart';
import '../core/app_colors.dart';
import '../models/user_model.dart';
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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StaffBloc, StaffState>(
      builder: (context, state) {
        final List<UserModel> allUsers = state is StaffLoaded
            ? state.staffList
            : [];

        final filteredUsers = allUsers.where((u) {
          final q = _searchQuery.toLowerCase();
          return u.name.toLowerCase().contains(q) ||
              u.employeeCode.toLowerCase().contains(q) ||
              u.role.toLowerCase().contains(q);
        }).toList();

        return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Directory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterStaffScreen()),
              );
            },
            tooltip: 'Enroll Staff',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search by name, ID or role...',
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

            // Staff List
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
                  : ListView.builder(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = filteredUsers[index];
                        final registeredDate =
                            DateFormat('MMM dd, yyyy').format(user.registeredAt);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              // Avatar
                              if (user.avatarBase64 != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Image.memory(
                                    base64Decode(user.avatarBase64!),
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.25),
                                  child: Text(
                                    user.name.substring(0, 1).toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.cyanAccent,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 14),

                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${user.employeeCode} • ${user.role} (${user.department})',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Enrolled: $registeredDate',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
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
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegisterStaffScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Enroll Staff', style: TextStyle(color: Colors.white)),
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
