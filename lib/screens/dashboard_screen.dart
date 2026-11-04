import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/dashboard/dashboard_bloc.dart';
import '../bloc/dashboard/dashboard_state.dart';
import '../core/app_colors.dart';
import '../core/responsive.dart';
import '../models/attendance_record.dart';
import '../services/attendance_service.dart';
import '../widgets/dashboard_clock_banner.dart';
import '../widgets/stat_card.dart';
import '../widgets/action_hero_card.dart';
import '../widgets/attendance_tile.dart';
import '../widgets/attendance_detail_sheet.dart';
import 'attendance_scanner_screen.dart';
import 'register_staff_screen.dart';
import 'staff_list_screen.dart';
import 'history_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  AttendanceService _resolveAttendanceService(BuildContext context) {
    try {
      return context.read<AttendanceService>();
    } catch (_) {
      return AttendanceService.instance;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = context.topInset;
    final bottomInset = context.bottomInset;
    final isTablet = context.isTablet;
    final attendanceService = _resolveAttendanceService(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          final int totalStaff = state is DashboardLoaded ? state.totalStaff : 0;
          final int todayCheckins = state is DashboardLoaded ? state.todayCheckins : 0;
          final List<AttendanceRecord> recentRecords =
              state is DashboardLoaded ? state.recentRecords : [];

          final todayRecords = attendanceService.todayRecords;
          final onTimeToday = todayRecords.where((r) => r.status != 'LATE').length;
          final lateToday = todayRecords.where((r) => r.status == 'LATE').length;

          return CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              // 1. App Bar / Top Header (respecting status bar top inset)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.face_retouching_natural_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'AI FACE',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.cyanAccent,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              Text(
                                'Smart Biometric Attendance',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const StaffListScreen()),
                            );
                          },
                          borderRadius: BorderRadius.circular(13),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141E30),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: AppColors.cyanAccent.withValues(alpha: 0.20),
                              ),
                            ),
                            child: const Icon(
                              Icons.people_alt_outlined,
                              color: AppColors.cyanAccent,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Live Digital Clock Banner
              const SliverToBoxAdapter(
                child: DashboardClockBanner(),
              ),

              // 3. Quick Stats (Mobile: 2 Columns | Tablet Kiosk: 4-Column Grid)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: isTablet
                      ? Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                title: 'Total Enrolled',
                                value: '$totalStaff',
                                icon: Icons.badge_outlined,
                                accentColor: AppColors.cyanAccent,
                                subtitle: 'Active Profiles',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: StatCard(
                                title: 'Present Today',
                                value: '$todayCheckins',
                                icon: Icons.how_to_reg_outlined,
                                accentColor: AppColors.emeraldGreen,
                                subtitle: totalStaff > 0
                                    ? '${((todayCheckins / totalStaff) * 100).toInt()}% On-Duty'
                                    : '0% On-Duty',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: StatCard(
                                title: 'On-Time',
                                value: '$onTimeToday',
                                icon: Icons.check_circle_outline_rounded,
                                accentColor: const Color(0xFF38BDF8),
                                subtitle: 'Punctual Check-ins',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: StatCard(
                                title: 'Late Punches',
                                value: '$lateToday',
                                icon: Icons.access_time_rounded,
                                accentColor: AppColors.amberWarning,
                                subtitle: 'After 09:30 AM',
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                title: 'Total Enrolled',
                                value: '$totalStaff',
                                icon: Icons.badge_outlined,
                                accentColor: AppColors.cyanAccent,
                                subtitle: 'Active Staff',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: StatCard(
                                title: 'Present Today',
                                value: '$todayCheckins',
                                icon: Icons.how_to_reg_outlined,
                                accentColor: AppColors.emeraldGreen,
                                subtitle: totalStaff > 0
                                    ? '${((todayCheckins / totalStaff) * 100).toInt()}% On-Duty'
                                    : '0% On-Duty',
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              // 4. Quick Actions Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: const Text(
                    'QUICK ACTIONS',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),

              // 5. Action Hero Cards (Mobile: Column | Tablet: Side-by-side Row)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: isTablet
                      ? Row(
                          children: [
                            Expanded(
                              child: ActionHeroCard(
                                title: 'Face Attendance Scanner',
                                subtitle: 'Instant biometric scan & touchless punch',
                                icon: Icons.camera_front_rounded,
                                isPrimary: true,
                                onTap: () => _openScanner(context, totalStaff),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: ActionHeroCard(
                                title: 'Enroll New Employee',
                                subtitle: 'Register face biometrics & profile',
                                icon: Icons.person_add_alt_1_rounded,
                                isPrimary: false,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const RegisterStaffScreen()),
                                  );
                                },
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            ActionHeroCard(
                              title: 'Face Attendance Scanner',
                              subtitle: 'Instant biometric scan & touchless punch',
                              icon: Icons.camera_front_rounded,
                              isPrimary: true,
                              onTap: () => _openScanner(context, totalStaff),
                            ),
                            const SizedBox(height: 10),
                            ActionHeroCard(
                              title: 'Enroll New Employee',
                              subtitle: 'Register face biometrics & profile',
                              icon: Icons.person_add_alt_1_rounded,
                              isPrimary: false,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const RegisterStaffScreen()),
                                );
                              },
                            ),
                          ],
                        ),
                ),
              ),

              // 6. Recent Logs Section Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'RECENT ATTENDANCE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textMuted,
                              letterSpacing: 1.1,
                            ),
                          ),
                          if (recentRecords.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppColors.cyanAccent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.cyanAccent.withValues(alpha: 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                '${recentRecords.length}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.cyanAccent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (recentRecords.isNotEmpty)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const HistoryScreen()),
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'View All',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.cyanAccent,
                                    ),
                                  ),
                                  SizedBox(width: 3),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 14,
                                    color: AppColors.cyanAccent,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // 7. Recent Logs List or Empty State (Responsive for Mobile vs Tablet)
              if (recentRecords.isEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF141E30), Color(0xFF0F1726)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.8),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.cyanAccent.withValues(alpha: 0.1),
                            border: Border.all(
                              color: AppColors.cyanAccent.withValues(alpha: 0.25),
                              width: 1.2,
                            ),
                          ),
                          child: const Icon(
                            Icons.face_retouching_natural_rounded,
                            size: 26,
                            color: AppColors.cyanAccent,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Touchless Scans Ready',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Start the scanner to log employee check-ins in real-time.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.camera_front_rounded, size: 16),
                          label: const Text('Open Scanner'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.cyanAccent,
                            side: BorderSide(
                              color: AppColors.cyanAccent.withValues(alpha: 0.4),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          onPressed: () => _openScanner(context, totalStaff),
                        ),
                      ],
                    ),
                  ),
                )
              else if (isTablet)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 14,
                      childAspectRatio: 3.8,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final record = recentRecords[index];
                        return AttendanceTile(
                          record: record,
                          onTap: () => AttendanceDetailSheet.show(context, record),
                        );
                      },
                      childCount: recentRecords.length,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final record = recentRecords[index];
                        return AttendanceTile(
                          record: record,
                          onTap: () => AttendanceDetailSheet.show(context, record),
                        );
                      },
                      childCount: recentRecords.length,
                    ),
                  ),
                ),

              // Bottom Inset Spacing to prevent cutting off on 3-button navigation
              SliverToBoxAdapter(
                child: SizedBox(height: bottomInset + 32),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openScanner(BuildContext context, int totalStaff) {
    if (totalStaff == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enroll at least one employee first.'),
          backgroundColor: AppColors.amberWarning,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AttendanceScannerScreen()),
    );
  }
}
