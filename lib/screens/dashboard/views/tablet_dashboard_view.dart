import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';
import '../../../models/attendance_record.dart';
import '../../../widgets/action_hero_card.dart';
import '../../../widgets/attendance_tile.dart';
import '../../../widgets/dashboard_clock_banner.dart';
import '../../../widgets/stat_card.dart';

/// 📟 TABLET DASHBOARD VIEW (>= 600px - Multi-Card Grid Terminal Layout)
class TabletDashboardView extends StatelessWidget {
  final Widget topHeader;
  final int totalStaff;
  final int todayCheckins;
  final int onTimeCount;
  final int attendancePercent;
  final List<AttendanceRecord> recentRecords;
  final double bottomPadding;
  final VoidCallback onLaunchKiosk;
  final VoidCallback onEnrollStaff;
  final VoidCallback onViewAllHistory;
  final VoidCallback onOpenScanner;

  const TabletDashboardView({
    super.key,
    required this.topHeader,
    required this.totalStaff,
    required this.todayCheckins,
    required this.onTimeCount,
    required this.attendancePercent,
    required this.recentRecords,
    required this.bottomPadding,
    required this.onLaunchKiosk,
    required this.onEnrollStaff,
    required this.onViewAllHistory,
    required this.onOpenScanner,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = (totalStaff - todayCheckins).clamp(0, 9999);

    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        // Top Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 16, 28, 8),
            child: topHeader,
          ),
        ),

        // 4-Column Metric Grid on Top
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
            child: Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Total Enrolled',
                    value: '$totalStaff',
                    icon: Icons.badge_outlined,
                    accentColor: AppColors.cyanAccent,
                    subtitle: 'Registered Profiles',
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: StatCard(
                    title: 'Present Today',
                    value: '$todayCheckins',
                    icon: Icons.how_to_reg_outlined,
                    accentColor: AppColors.emeraldGreen,
                    subtitle: 'Recorded Check-ins',
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: StatCard(
                    title: 'On-Time Punctual',
                    value: '$onTimeCount',
                    icon: Icons.verified_user_outlined,
                    accentColor: AppColors.primary,
                    subtitle: 'Punctual Records',
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: StatCard(
                    title: 'Pending In',
                    value: '$remaining',
                    icon: Icons.pending_actions_outlined,
                    accentColor: AppColors.amberWarning,
                    subtitle: '$attendancePercent% Checked-in',
                  ),
                ),
              ],
            ),
          ),
        ),

        // Dual-Column Main Terminal Area
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Clock Banner + Action Hero Cards
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DashboardClockBanner(margin: EdgeInsets.zero),
                      const SizedBox(height: 12),
                      if (totalStaff >= 1) ...[
                        ActionHeroCard(
                          title: 'Launch Attendance Kiosk',
                          subtitle: 'High-speed face recognition terminal',
                          icon: Icons.camera_front_rounded,
                          isPrimary: true,
                          badgeText: 'READY',
                          onTap: onLaunchKiosk,
                        ),
                        const SizedBox(height: 12),
                        ActionHeroCard(
                          title: 'Enroll New Employee',
                          subtitle: 'Register biometric profile & details',
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
                          badgeText: 'REQUIRED',
                          onTap: onEnrollStaff,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Right Column: Wide Card with Recent Attendance List
                Expanded(
                  flex: 6,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildRecentHeader(),
                        const SizedBox(height: 14),
                        if (recentRecords.isEmpty)
                          _buildEmptyState()
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: recentRecords.length.clamp(0, 6),
                            itemBuilder: (context, index) {
                              final record = recentRecords[index];
                              return AttendanceTile(
                                record: record,
                                enableTap: false,
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Safe Bottom Inset
        SliverToBoxAdapter(
          child: SizedBox(height: bottomPadding + 36),
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
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 1.0,
              ),
            ),
            if (recentRecords.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.18),
                ),
                child: Text(
                  '${recentRecords.length}',
                  style: const TextStyle(
                    fontFamily: AppFonts.bold,
                    fontSize: 10.5,
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
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View All',
                    style: TextStyle(
                      fontFamily: AppFonts.bold,
                      fontSize: 12.5,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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
    );
  }
}
