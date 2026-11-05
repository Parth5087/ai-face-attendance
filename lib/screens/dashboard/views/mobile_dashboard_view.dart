import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';
import '../../../models/attendance_record.dart';
import '../../../widgets/action_hero_card.dart';
import '../../../widgets/attendance_tile.dart';
import '../../../widgets/dashboard_clock_banner.dart';
import '../../../widgets/stat_card.dart';

/// 📱 MOBILE DASHBOARD VIEW (< 600px - Single Column Handheld Layout)
class MobileDashboardView extends StatelessWidget {
  final Widget topHeader;
  final int totalStaff;
  final int todayCheckins;
  final List<AttendanceRecord> recentRecords;
  final double bottomPadding;
  final VoidCallback onLaunchKiosk;
  final VoidCallback onEnrollStaff;
  final VoidCallback onViewAllHistory;
  final VoidCallback onOpenScanner;

  const MobileDashboardView({
    super.key,
    required this.topHeader,
    required this.totalStaff,
    required this.todayCheckins,
    required this.recentRecords,
    required this.bottomPadding,
    required this.onLaunchKiosk,
    required this.onEnrollStaff,
    required this.onViewAllHistory,
    required this.onOpenScanner,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        // App Bar / Top Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: topHeader,
          ),
        ),

        // Live Digital Clock Banner
        const SliverToBoxAdapter(
          child: DashboardClockBanner(),
        ),

        // 2-Column Quick Stats Row
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
              ],
            ),
          ),
        ),

        // Quick Actions Section Header
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              'QUICK ACTIONS',
              style: TextStyle(
                fontFamily: AppFonts.bold,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ),

        // Action Hero Cards
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                if (totalStaff >= 1) ...[
                  ActionHeroCard(
                    title: 'Launch Attendance Kiosk',
                    subtitle: 'Touchless facial recognition for employee check-ins',
                    icon: Icons.camera_front_rounded,
                    isPrimary: true,
                    onTap: onLaunchKiosk,
                  ),
                  const SizedBox(height: 10),
                  ActionHeroCard(
                    title: 'Enroll New Employee',
                    subtitle: 'Register face biometrics & profile',
                    icon: Icons.person_add_alt_1_rounded,
                    isPrimary: false,
                    onTap: onEnrollStaff,
                  ),
                ] else ...[
                  ActionHeroCard(
                    title: 'Enroll Employee to Activate Kiosk',
                    subtitle: 'Register your first employee to start attendance check-ins',
                    icon: Icons.person_add_alt_1_rounded,
                    isPrimary: true,
                    onTap: onEnrollStaff,
                  ),
                ],
              ],
            ),
          ),
        ),

        // Recent Logs Section Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
            child: _buildRecentHeader(),
          ),
        ),

        // Recent Attendance Records / Empty State
        if (recentRecords.isEmpty)
          SliverToBoxAdapter(
            child: _buildEmptyState(),
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
                    enableTap: false,
                  );
                },
                childCount: recentRecords.length,
              ),
            ),
          ),

        // Safe Bottom Padding
        SliverToBoxAdapter(
          child: SizedBox(height: bottomPadding + 32),
        ),
      ],
    );
  }

  Widget _buildRecentHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Text(
              'RECENT ATTENDANCE',
              style: TextStyle(
                fontFamily: AppFonts.bold,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 1.0,
              ),
            ),
            if (recentRecords.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.18),
                ),
                child: Text(
                  '${recentRecords.length}',
                  style: const TextStyle(
                    fontFamily: AppFonts.bold,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cyanAccent,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (recentRecords.isNotEmpty)
          InkWell(
            onTap: onViewAllHistory,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View All',
                    style: TextStyle(
                      fontFamily: AppFonts.bold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.cyanAccent,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.cyanAccent,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_today_outlined,
                color: AppColors.cyanAccent,
                size: 26,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No Punches Today',
              style: TextStyle(
                fontFamily: AppFonts.bold,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Touchless attendance punches will appear here in real time as employees check in.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.medium,
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
