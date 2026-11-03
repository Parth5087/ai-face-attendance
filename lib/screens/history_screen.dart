import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../services/attendance_service.dart';
import '../widgets/attendance_tile.dart';
import '../widgets/attendance_detail_sheet.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _selectedFilter = 'ALL'; // 'ALL', 'TODAY', 'ON_TIME', 'LATE'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attendanceService = context.watch<AttendanceService>();
    final allRecords = attendanceService.records;

    final now = DateTime.now();

    // Counts for filter chips
    final todayRecords = allRecords.where((r) {
      return r.timestamp.year == now.year &&
          r.timestamp.month == now.month &&
          r.timestamp.day == now.day;
    }).toList();

    final onTimeCount = allRecords.where((r) => r.status != 'LATE').length;
    final lateCount = allRecords.where((r) => r.status == 'LATE').length;

    // Filter by category & search query
    final filteredRecords = allRecords.where((r) {
      if (_selectedFilter == 'TODAY') {
        final isToday = r.timestamp.year == now.year &&
            r.timestamp.month == now.month &&
            r.timestamp.day == now.day;
        if (!isToday) return false;
      } else if (_selectedFilter == 'ON_TIME') {
        if (r.status == 'LATE') return false;
      } else if (_selectedFilter == 'LATE') {
        if (r.status != 'LATE') return false;
      }

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchName = r.employeeName.toLowerCase().contains(query);
        final matchCode = r.employeeCode.toLowerCase().contains(query);
        final matchRole = r.role.toLowerCase().contains(query);
        if (!matchName && !matchCode && !matchRole) return false;
      }

      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Attendance Logs',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          if (allRecords.isNotEmpty)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.roseError.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.roseError.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.roseError,
                  size: 18,
                ),
              ),
              onPressed: () => _confirmClearHistory(context),
              tooltip: 'Clear All Logs',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // KPI Summary Row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      title: 'Total Logs',
                      value: '${allRecords.length}',
                      color: AppColors.cyanAccent,
                      icon: Icons.list_alt_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile(
                      title: 'On-Time',
                      value: '$onTimeCount',
                      color: AppColors.emeraldGreen,
                      icon: Icons.verified_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile(
                      title: 'Late',
                      value: '$lateCount',
                      color: AppColors.amberWarning,
                      icon: Icons.access_time_filled_rounded,
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF141E30),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim());
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by employee name or code...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.cyanAccent,
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear_rounded,
                              size: 18,
                              color: AppColors.textMuted,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                  ),
                ),
              ),
            ),

            // Filter Chips
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildFilterChip('All Logs', 'ALL', allRecords.length),
                    const SizedBox(width: 8),
                    _buildFilterChip('Today Only', 'TODAY', todayRecords.length),
                    const SizedBox(width: 8),
                    _buildFilterChip('On Time', 'ON_TIME', onTimeCount),
                    const SizedBox(width: 8),
                    _buildFilterChip('Late', 'LATE', lateCount),
                  ],
                ),
              ),
            ),

            // Header Count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RECORDS FOUND (${filteredRecords.length})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                      letterSpacing: 1.1,
                    ),
                  ),
                  if (_searchQuery.isNotEmpty || _selectedFilter != 'ALL')
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedFilter = 'ALL';
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                      child: const Text(
                        'Reset Filters',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.cyanAccent,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Records List
            Expanded(
              child: filteredRecords.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF141E30),
                                border: Border.all(
                                  color: AppColors.border,
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.history_toggle_off_rounded,
                                size: 32,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No matching attendance logs',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Try adjusting your search query or switching active filter chips.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textMuted,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: filteredRecords.length,
                      itemBuilder: (context, index) {
                        final record = filteredRecords[index];
                        return AttendanceTile(
                          record: record,
                          onTap: () => AttendanceDetailSheet.show(context, record),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141E30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Icon(icon, size: 14, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = _selectedFilter == value;
    final color = isSelected ? AppColors.cyanAccent : AppColors.textSecondary;

    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFF141E30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.cyanAccent : AppColors.border,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.black.withValues(alpha: 0.25)
                    : AppColors.surfaceCardLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearHistory(BuildContext context) {
    final attendanceService = context.read<AttendanceService>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AlertDialog(
              backgroundColor: const Color(0xFF131D31).withValues(alpha: 0.95),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: AppColors.roseError.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.roseError, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Clear Attendance Logs',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              content: const Text(
                'Are you sure you want to delete all local attendance logs? This action is permanent and cannot be undone.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await attendanceService.clearHistory();
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('All attendance logs cleared.'),
                        backgroundColor: AppColors.roseError,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.roseError,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Clear All'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
