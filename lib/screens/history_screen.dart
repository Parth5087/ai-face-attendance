import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/responsive.dart';
import '../models/attendance_record.dart';
import '../services/attendance_service.dart';
import '../widgets/attendance_detail_sheet.dart';
import '../widgets/attendance_tile.dart';
import '../widgets/premium_back_button.dart';
import '../widgets/premium_confirmation_dialog.dart';
import '../widgets/premium_empty_state.dart';
import '../widgets/premium_search_bar.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _selectedFilter = 'ALL'; // 'ALL', 'TODAY', 'ON_TIME', 'LATE'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedRecordId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  AttendanceService _resolveAttendanceService(BuildContext context) {
    try {
      return context.watch<AttendanceService>();
    } catch (_) {
      return AttendanceService.instance;
    }
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

    // Ensure selected record is valid for tablet split view
    if (filteredRecords.isNotEmpty) {
      if (_selectedRecordId == null ||
          !filteredRecords.any((r) => r.id == _selectedRecordId)) {
        _selectedRecordId = filteredRecords.first.id;
      }
    } else {
      _selectedRecordId = null;
    }

    AttendanceRecord? selectedRecord;
    if (_selectedRecordId != null) {
      try {
        selectedRecord =
            filteredRecords.firstWhere((r) => r.id == _selectedRecordId);
      } catch (_) {
        selectedRecord = null;
      }
    }

    final isTablet = context.isTablet;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: isTablet
            ? _buildTabletLayout(
                context,
                allRecords,
                filteredRecords,
                todayRecords,
                onTimeCount,
                lateCount,
                selectedRecord,
                attendanceService,
              )
            : _buildMobileLayout(
                context,
                allRecords,
                filteredRecords,
                todayRecords,
                onTimeCount,
                lateCount,
                bottomPadding,
              ),
      ),
    );
  }

  // =========================================================================
  // 📟 TABLET LAYOUT (>= 600px - Dual-Pane Master-Detail Audit Console)
  // =========================================================================
  Widget _buildTabletLayout(
    BuildContext context,
    List<AttendanceRecord> allRecords,
    List<AttendanceRecord> filteredRecords,
    List<AttendanceRecord> todayRecords,
    int onTimeCount,
    int lateCount,
    AttendanceRecord? selectedRecord,
    AttendanceService attendanceService,
  ) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width >= 850;

    return Column(
      children: [
        // Top Enterprise Header
        _buildTabletHeader(context, allRecords.isNotEmpty),

        // Main Dual-Pane Workspace Area
        Expanded(
          child: allRecords.isEmpty
              ? _buildEmptyState()
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Master List Pane (Flex 4 or 5)
                    Expanded(
                      flex: isLandscape ? 4 : 5,
                      child: _buildTabletMasterList(
                        context,
                        allRecords,
                        filteredRecords,
                        todayRecords,
                        onTimeCount,
                        lateCount,
                        attendanceService,
                      ),
                    ),

                    // Clean Vertical Border
                    Container(
                      width: 1,
                      color: AppColors.border,
                    ),

                    // Right Detailed Audit & Verification Console
                    Expanded(
                      flex: 6,
                      child: _buildTabletAuditPane(
                        context,
                        selectedRecord,
                        attendanceService,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildTabletHeader(BuildContext context, bool hasRecords) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const PremiumBackButton(),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Attendance Logs',
              style: TextStyle(
                fontFamily: AppFonts.bold,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: AppColors.textPrimary,
                letterSpacing: 0.3,
                height: 1.0,
              ),
            ),
          ),
          if (hasRecords)
            OutlinedButton.icon(
              onPressed: () => _confirmClearHistory(context),
              icon: const Icon(
                Icons.delete_sweep_rounded,
                color: AppColors.roseError,
                size: 18,
              ),
              label: const Text(
                'Clear History',
                style: TextStyle(
                  fontFamily: AppFonts.bold,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.roseError,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: AppColors.roseError.withValues(alpha: 0.35),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Tablet Master List Pane (Left Column)
  Widget _buildTabletMasterList(
    BuildContext context,
    List<AttendanceRecord> allRecords,
    List<AttendanceRecord> filteredRecords,
    List<AttendanceRecord> todayRecords,
    int onTimeCount,
    int lateCount,
    AttendanceService attendanceService,
  ) {
    return Container(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 3 Compact Metric Tiles in a Row
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 4, 16, 10),
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
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    title: 'On-Time',
                    value: '$onTimeCount',
                    color: AppColors.emeraldGreen,
                    icon: Icons.verified_rounded,
                  ),
                ),
                const SizedBox(width: 8),
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
            padding: const EdgeInsets.fromLTRB(28, 0, 16, 4),
            child: PremiumSearchBar(
              controller: _searchController,
              hintText: 'Search by name or code...',
              counterBadge:
                  '${filteredRecords.length} ${filteredRecords.length == 1 ? 'Log' : 'Logs'}',
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              onClear: () => setState(() => _searchQuery = ''),
            ),
          ),

          // Filter Chips Row
          Container(
            height: 34,
            margin: const EdgeInsets.symmetric(vertical: 10),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 28),
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

          // Header Count & Clear Link
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 4, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'RECORDS FOUND',
                      style: TextStyle(
                        fontFamily: AppFonts.bold,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 6),
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
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.cyanAccent,
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
                        fontFamily: AppFonts.bold,
                        fontSize: 11,
                        color: AppColors.cyanAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Scrollable Punch Log Tiles or In-Pane Empty Search
          Expanded(
            child: filteredRecords.isEmpty
                ? _buildInPaneEmptySearch(
                    query: _searchQuery,
                    entityName: 'attendance logs',
                    onReset: () {
                      setState(() {
                        _selectedFilter = 'ALL';
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(28, 2, 16, 24),
                    itemCount: filteredRecords.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final record = filteredRecords[index];
                      final isSelected = record.id == _selectedRecordId;
                      return _buildTabletRecordTile(
                        record,
                        isSelected,
                        attendanceService,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletRecordTile(
    AttendanceRecord record,
    bool isSelected,
    AttendanceService attendanceService,
  ) {
    final user = attendanceService.users
        .where((u) => u.id == record.employeeId)
        .firstOrNull;
    final photoBytes = record.punchImageBytes ?? user?.avatarBytes;
    final isLate = record.status == 'LATE';
    final timeStr = DateFormat('hh:mm a').format(record.timestamp);
    final dateStr = DateFormat('dd MMM').format(record.timestamp);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedRecordId = record.id);
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.18)
                : AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.cyanAccent : AppColors.border,
              width: isSelected ? 1.6 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.cyanAccent.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : AppColors.cardShadow,
          ),
          child: Row(
            children: [
              // Avatar / Punch Photo Thumbnail
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCardLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isLate
                            ? AppColors.amberWarning.withValues(alpha: 0.5)
                            : AppColors.emeraldGreen.withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                    ),
                    padding: const EdgeInsets.all(2.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: photoBytes != null
                          ? Image.memory(
                              photoBytes,
                              key: ValueKey('tablet_tile_avatar_${record.id}'),
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.medium,
                            )
                          : Container(
                              color: AppColors.primary.withValues(alpha: 0.20),
                              alignment: Alignment.center,
                              child: Text(
                                record.employeeName.isNotEmpty
                                    ? record.employeeName
                                        .substring(0, 1)
                                        .toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontFamily: AppFonts.bold,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.cyanAccent,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                    ),
                  ),
                  if (record.punchImageBytes != null)
                    Positioned(
                      right: -3,
                      bottom: -3,
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surface, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 9,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.employeeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppFonts.bold,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? AppColors.cyanAccent
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.cyanAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.cyanAccent.withValues(alpha: 0.25),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              record.employeeCode,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: AppFonts.bold,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.cyanAccent,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${record.role} • ${(record.confidenceScore * 100).toInt()}% match',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.medium,
                        fontSize: 11,
                        color: isLate
                            ? AppColors.amberWarning
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dateStr • $timeStr',
                      style: const TextStyle(
                        fontFamily: AppFonts.medium,
                        fontSize: 10.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              // Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: isLate
                      ? AppColors.amberWarning.withValues(alpha: 0.15)
                      : AppColors.emeraldGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  record.status,
                  style: TextStyle(
                    fontFamily: AppFonts.bold,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isLate
                        ? AppColors.amberWarning
                        : AppColors.emeraldGreen,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: isSelected
                    ? AppColors.cyanAccent
                    : AppColors.textMuted.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Tablet Right Pane (Photographic Biometric Verification & Audit Console)
  Widget _buildTabletAuditPane(
    BuildContext context,
    AttendanceRecord? record,
    AttendanceService attendanceService,
  ) {
    if (record == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fingerprint_rounded,
              size: 64,
              color: AppColors.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'Select an attendance log to inspect audit details',
              style: TextStyle(
                fontFamily: AppFonts.medium,
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final isLate = record.status == 'LATE';
    final matchPercent = (record.confidenceScore * 100).toStringAsFixed(1);
    final timeStr = DateFormat('hh:mm:ss a').format(record.timestamp);
    final dateStr = DateFormat('EEEE, dd MMMM yyyy').format(record.timestamp);

    // Look up registered user for side-by-side photo comparison
    final user = attendanceService.users
        .where((u) => u.id == record.employeeId)
        .firstOrNull;
    final Uint8List? registeredAvatarBytes = user?.avatarBytes;
    final Uint8List? livePunchBytes = record.punchImageBytes;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 28, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Employee Header & Verification Status Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.employeeName,
                        style: const TextStyle(
                          fontFamily: AppFonts.bold,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.cyanAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.cyanAccent.withValues(alpha: 0.30),
                              ),
                            ),
                            child: Text(
                              record.employeeCode,
                              style: const TextStyle(
                                fontFamily: AppFonts.bold,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.cyanAccent,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceCardLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              record.role,
                              style: const TextStyle(
                                fontFamily: AppFonts.medium,
                                fontSize: 11.5,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: (record.checkType == 'OUT'
                                      ? const Color(0xFFEA580C)
                                      : const Color(0xFF0284C7))
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: (record.checkType == 'OUT'
                                        ? const Color(0xFFEA580C)
                                        : const Color(0xFF0284C7))
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              'Punch Type: ${record.checkType}',
                              style: TextStyle(
                                fontFamily: AppFonts.bold,
                                fontSize: 11.5,
                                color: record.checkType == 'OUT'
                                    ? const Color(0xFFEA580C)
                                    : const Color(0xFF38BDF8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontFamily: AppFonts.medium,
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Large Punctuality Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isLate
                        ? AppColors.amberWarning.withValues(alpha: 0.14)
                        : AppColors.emeraldGreen.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isLate
                          ? AppColors.amberWarning.withValues(alpha: 0.40)
                          : AppColors.emeraldGreen.withValues(alpha: 0.40),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isLate
                            ? Icons.schedule_rounded
                            : Icons.verified_rounded,
                        color: isLate
                            ? AppColors.amberWarning
                            : AppColors.emeraldGreen,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isLate ? 'LATE PUNCH' : 'ON TIME',
                        style: TextStyle(
                          fontFamily: AppFonts.bold,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isLate
                              ? AppColors.amberWarning
                              : AppColors.emeraldGreen,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Dual Biometric Photographic Verification Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.face_retouching_natural_rounded,
                          color: AppColors.cyanAccent,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Face Match Verification',
                          style: TextStyle(
                            fontFamily: AppFonts.bold,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isLate
                            ? AppColors.amberWarning.withValues(alpha: 0.15)
                            : AppColors.emeraldGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isLate
                              ? AppColors.amberWarning.withValues(alpha: 0.35)
                              : AppColors.emeraldGreen.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        '$matchPercent% Face Match',
                        style: TextStyle(
                          fontFamily: AppFonts.bold,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isLate
                              ? AppColors.amberWarning
                              : AppColors.emeraldGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Dual Photo Comparison Row
                Row(
                  children: [
                    // Registered Face Profile Frame
                    Expanded(
                      child: _buildPhotoComparisonCard(
                        title: 'REGISTERED PHOTO',
                        subtitle: 'Staff Profile Picture',
                        photoBytes: registeredAvatarBytes,
                        icon: Icons.person_rounded,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Live Camera Punch Snapshot Frame
                    Expanded(
                      child: _buildPhotoComparisonCard(
                        title: 'LIVE PUNCH PHOTO',
                        subtitle: 'Captured at Kiosk',
                        photoBytes: livePunchBytes,
                        icon: Icons.camera_alt_rounded,
                        isCameraSnapshot: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Match Score Progress Indicator Bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Face Similarity Match',
                          style: TextStyle(
                            fontFamily: AppFonts.medium,
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '$matchPercent% Match',
                          style: TextStyle(
                            fontFamily: AppFonts.bold,
                            fontSize: 11.5,
                            color: isLate
                                ? AppColors.amberWarning
                                : AppColors.emeraldGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: record.confidenceScore.clamp(0.0, 1.0),
                        backgroundColor: AppColors.surfaceCardLight,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isLate
                              ? AppColors.amberWarning
                              : AppColors.emeraldGreen,
                        ),
                        minHeight: 7,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Row(
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          size: 13,
                          color: AppColors.emeraldGreen,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Real Face Verified (Anti-Spoofing Passed)',
                          style: TextStyle(
                            fontFamily: AppFonts.bold,
                            fontSize: 10.5,
                            color: AppColors.emeraldGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Attendance Punch Details Bento
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      color: AppColors.cyanAccent,
                      size: 19,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Attendance Punch Details',
                      style: TextStyle(
                        fontFamily: AppFonts.bold,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildAuditInfoRow(
                  label: 'Punch Time',
                  value: timeStr,
                  icon: Icons.access_time_rounded,
                ),
                const Divider(height: 16, color: AppColors.borderLight),
                _buildAuditInfoRow(
                  label: 'Date',
                  value: dateStr,
                  icon: Icons.calendar_today_rounded,
                ),
                const Divider(height: 16, color: AppColors.borderLight),
                _buildAuditInfoRow(
                  label: 'Shift Status',
                  value: isLate
                      ? 'Late Entry (After 09:30 AM)'
                      : 'On Time Entry',
                  icon: isLate
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline_rounded,
                  valueColor: isLate
                      ? AppColors.amberWarning
                      : AppColors.emeraldGreen,
                  valueWidget: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: (isLate
                                ? AppColors.amberWarning
                                : AppColors.emeraldGreen)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (isLate
                                  ? AppColors.amberWarning
                                  : AppColors.emeraldGreen)
                              .withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isLate
                                ? Icons.schedule_rounded
                                : Icons.verified_rounded,
                            size: 13,
                            color: isLate
                                ? AppColors.amberWarning
                                : AppColors.emeraldGreen,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              isLate
                                  ? 'Late Entry (After 09:30 AM)'
                                  : 'On Time Entry',
                              style: TextStyle(
                                fontFamily: AppFonts.bold,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isLate
                                    ? AppColors.amberWarning
                                    : AppColors.emeraldGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Divider(height: 16, color: AppColors.borderLight),
                _buildAuditInfoRow(
                  label: 'Punch Device',
                  value: 'Office Kiosk Tablet',
                  icon: Icons.tablet_mac_rounded,
                  valueWidget: const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Office Kiosk Tablet',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: AppFonts.bold,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
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

  Widget _buildPhotoComparisonCard({
    required String title,
    required String subtitle,
    required Uint8List? photoBytes,
    required IconData icon,
    bool isCameraSnapshot = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCameraSnapshot
                    ? Icons.camera_alt_outlined
                    : Icons.badge_outlined,
                size: 13,
                color: AppColors.cyanAccent,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.bold,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isCameraSnapshot
                      ? AppColors.cyanAccent.withValues(alpha: 0.5)
                      : AppColors.primaryLight.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: AppColors.cardShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: photoBytes != null
                    ? Image.memory(
                        photoBytes,
                        key: ValueKey('audit_compare_${isCameraSnapshot ? "live" : "enrolled"}_${photoBytes.hashCode}'),
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.high,
                      )
                    : Icon(
                        icon,
                        size: 48,
                        color: AppColors.textMuted.withValues(alpha: 0.4),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              subtitle,
              style: const TextStyle(
                fontFamily: AppFonts.medium,
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditInfoRow({
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
    Widget? valueWidget,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.cyanAccent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: AppColors.cyanAccent),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 145,
            child: Padding(
              padding: const EdgeInsets.only(top: 3.5),
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: AppFonts.medium,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2.5),
              child: valueWidget ??
                  Text(
                    value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: AppFonts.bold,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 📱 MOBILE LAYOUT (< 600px - Vertical List & Bottom Sheet)
  // =========================================================================
  Widget _buildMobileLayout(
    BuildContext context,
    List<AttendanceRecord> allRecords,
    List<AttendanceRecord> filteredRecords,
    List<AttendanceRecord> todayRecords,
    int onTimeCount,
    int lateCount,
    double bottomPadding,
  ) {
    const horizontalPadding = 20.0;

    return Column(
      children: [
        // Mobile AppBar
        AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Row(
              children: [
                const PremiumBackButton(),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Attendance Logs',
                    style: TextStyle(
                      fontFamily: AppFonts.bold,
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
                      onTap: () => _confirmClearHistory(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.roseError.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
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

        // KPI Metric Tiles
        Padding(
          padding: const EdgeInsets.fromLTRB(
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
          padding: const EdgeInsets.symmetric(
            horizontal: horizontalPadding,
          ),
          child: PremiumSearchBar(
            controller: _searchController,
            hintText: 'Search by name or code...',
            counterBadge:
                '${filteredRecords.length} ${filteredRecords.length == 1 ? 'Log' : 'Logs'}',
            onChanged: (val) {
              setState(() => _searchQuery = val.trim());
            },
            onClear: () => setState(() => _searchQuery = ''),
          ),
        ),

        // Filter Chips (Horizontal Scroll)
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
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
          padding: const EdgeInsets.symmetric(
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
        const SizedBox(height: 6),

        // Mobile Vertical List
        Expanded(
          child: filteredRecords.isEmpty
              ? _buildEmptyState()
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
                  fontFamily: AppFonts.bold,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontFamily: AppFonts.medium,
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterKey, int count) {
    final isSelected = _selectedFilter == filterKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filterKey;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.cyanAccent : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
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
                fontFamily: AppFonts.bold,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? const Color(0xFF0A0E1A) : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? Colors.black.withValues(alpha: 0.20)
                    : AppColors.surfaceCardLight,
              ),
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? const Color(0xFF0A0E1A) : AppColors.cyanAccent,
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

  Widget _buildInPaneEmptySearch({
    required String query,
    required VoidCallback onReset,
    String entityName = 'logs',
  }) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.cyanAccent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 22,
                color: AppColors.cyanAccent,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'No $entityName found',
              style: const TextStyle(
                fontFamily: AppFonts.bold,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              query.isNotEmpty
                  ? 'No results matching "$query"'
                  : 'No records match the selected filter',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppFonts.medium,
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Reset Search'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.cyanAccent,
                textStyle: const TextStyle(
                  fontFamily: AppFonts.bold,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                backgroundColor: AppColors.cyanAccent.withValues(alpha: 0.10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return PremiumEmptyState(
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
    );
  }

  void _confirmClearHistory(BuildContext context) {
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
          ScaffoldMessenger.of(this.context).showSnackBar(
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
