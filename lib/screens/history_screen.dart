import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/responsive.dart';
import '../services/attendance_service.dart';
import '../widgets/attendance_tile.dart';
import '../widgets/attendance_detail_sheet.dart';
import '../widgets/premium_back_button.dart';
import '../widgets/premium_search_bar.dart';
import '../widgets/premium_confirmation_dialog.dart';
import '../widgets/premium_empty_state.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _selectedFilter = 'ALL'; // 'ALL', 'TODAY', 'ON_TIME', 'LATE'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  AttendanceService _resolveAttendanceService(BuildContext context) {
    try {
      return context.watch<AttendanceService>();
    } catch (_) {
      return AttendanceService.instance;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attendanceService = _resolveAttendanceService(context);
    final allRecords = attendanceService.records;
    final now = DateTime.now();

    final todayRecords = allRecords.where((r) {
      return r.timestamp.year == now.year &&
          r.timestamp.month == now.month &&
          r.timestamp.day == now.day;
    }).toList();

    final onTimeCount = allRecords.where((r) => r.status != 'LATE').length;
    final lateCount = allRecords.where((r) => r.status == 'LATE').length;

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

    final isTablet = context.isTablet;
    final horizontalPadding = isTablet ? 28.0 : 20.0;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

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
                  'Attendance Logs',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (allRecords.isNotEmpty)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _confirmClearHistory(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.roseError.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.roseError.withValues(alpha: 0.25),
                          width: 1.0,
                        ),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.roseError,
                        size: 18,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // KPI Metric Tiles
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                6,
                horizontalPadding,
                12,
              ),
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

            // Modern Premium Search Bar
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
              ),
              child: PremiumSearchBar(
                controller: _searchController,
                hintText: 'Search by name or code...',
                counterBadge: '${filteredRecords.length} ${filteredRecords.length == 1 ? 'Log' : 'Logs'}',
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim());
                },
                onClear: () => setState(() => _searchQuery = ''),
              ),
            ),

            // Filter Chips (Edge-to-Edge full width scroll with aligned padding)
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                ),
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

            // Header Count & Reset
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 6,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'RECORDS FOUND',
                        style: TextStyle(
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
                          '${filteredRecords.length}',
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
                          fontWeight: FontWeight.w700,
                          color: AppColors.cyanAccent,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Record List / Grid
            Expanded(
              child: filteredRecords.isEmpty
                  ? PremiumEmptyState(
                      icon: _searchQuery.isNotEmpty
                          ? Icons.search_off_rounded
                          : Icons.history_toggle_off_rounded,
                      title: _searchQuery.isNotEmpty
                          ? 'No Matching Logs Found'
                          : 'No Attendance Logs Recorded',
                      message: _searchQuery.isNotEmpty
                          ? 'We couldn\'t find any records matching "$_searchQuery". Try resetting the filter.'
                          : 'Employee attendance entries captured via mobile or kiosk scanner will appear here.',
                      actionText: (_searchQuery.isNotEmpty || _selectedFilter != 'ALL')
                          ? 'Reset Filters'
                          : null,
                      onAction: (_searchQuery.isNotEmpty || _selectedFilter != 'ALL')
                          ? () {
                              setState(() {
                                _selectedFilter = 'ALL';
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            }
                          : null,
                    )
                  : isTablet
                      // 📟 Tablet Kiosk Mode: 2-Column Responsive Grid
                      ? GridView.builder(
                          physics: const ClampingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            4,
                            horizontalPadding,
                            bottomPadding + 28,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 12,
                            childAspectRatio: 3.8,
                          ),
                          itemCount: filteredRecords.length,
                          itemBuilder: (ctx, idx) {
                            final record = filteredRecords[idx];
                            return AttendanceTile(
                              record: record,
                              onTap: () =>
                                  AttendanceDetailSheet.show(context, record),
                            );
                          },
                        )
                      // 📱 Mobile Mode: Clean Vertical List
                      : ListView.builder(
                          physics: const ClampingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            4,
                            horizontalPadding,
                            bottomPadding + 28,
                          ),
                          itemCount: filteredRecords.length,
                          itemBuilder: (ctx, idx) {
                            final record = filteredRecords[idx];
                            return AttendanceTile(
                              record: record,
                              onTap: () =>
                                  AttendanceDetailSheet.show(context, record),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(icon, color: color, size: 15),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            title,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String key, int count) {
    final isSelected = _selectedFilter == key;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = key);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(13, 7, 9, 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppColors.cyanAccent : AppColors.border,
            width: 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.cyanAccent.withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : AppColors.cardShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 7),
            // Perfectly Centered Round Circle Badge
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : AppColors.surfaceCardLight,
              ),
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
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
      ),
    );
  }

  void _confirmClearHistory() {
    PremiumConfirmationDialog.show(
      context: context,
      title: 'Clear Attendance History',
      message:
          'Are you sure you want to permanently clear all attendance check-in records?\n\nThis will wipe all historical punch timestamps across mobile and kiosk devices. This action cannot be undone.',
      confirmText: 'Clear All Logs',
      cancelText: 'Keep Logs',
      icon: Icons.delete_sweep_rounded,
      iconColor: AppColors.roseError,
      isDestructive: true,
    ).then((confirmed) async {
      if (confirmed == true) {
        final service = AttendanceService.instance;
        await service.clearHistory();
        if (mounted) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Attendance history cleared.'),
              backgroundColor: AppColors.roseError,
            ),
          );
        }
      }
    });
  }
}
