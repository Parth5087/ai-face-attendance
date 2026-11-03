import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/dashboard/dashboard_bloc.dart';
import '../bloc/dashboard/dashboard_state.dart';
import '../core/app_colors.dart';
import '../models/attendance_record.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocBuilder<DashboardBloc, DashboardState>(
          builder: (context, state) {
            final int totalStaff = state is DashboardLoaded ? state.totalStaff : 0;
            final int todayCheckins = state is DashboardLoaded ? state.todayCheckins : 0;
            final List<AttendanceRecord> recentRecords =
                state is DashboardLoaded ? state.recentRecords : [];

            return CustomScrollView(
              physics: const ClampingScrollPhysics(),
              slivers: [
                // App Bar / Top Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
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
                            size: 23,
                          ),
                        ),
                        const SizedBox(width: 12),
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
                              'Smart Face Attendance',
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
                          padding: const EdgeInsets.all(9),
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
                            size: 19,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Live Digital Clock Banner (Self-updating isolated widget, zero parent rebuilds!)
            const SliverToBoxAdapter(
              child: DashboardClockBanner(),
            ),

            // Compact Quick Stats Row
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
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

            // Quick Actions Header
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

            // Compact Action Hero Cards
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Start Face Scanner Card
                    ActionHeroCard(
                      title: 'Face Attendance Scanner',
                      subtitle: 'Instant biometric scan & touchless punch',
                      icon: Icons.camera_front_rounded,
                      isPrimary: true,
                      onTap: () {
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
                      },
                    ),
                    const SizedBox(height: 10),

                    // Enroll New Employee Card
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

            // Recent Logs Section Header
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

            // Recent Logs List or Modern Empty State
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
                        onPressed: () {
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
                        },
                      ),
                    ],
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

            const SliverToBoxAdapter(
              child: SizedBox(height: 32),
            ),
          ],
        );
      },
    ),
  ),
);
  }
}
