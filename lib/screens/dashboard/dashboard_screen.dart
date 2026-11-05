import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/dashboard/dashboard_bloc.dart';
import '../../bloc/dashboard/dashboard_state.dart';
import '../../bloc/staff/staff_bloc.dart';
import '../../core/app_colors.dart';
import '../../core/responsive.dart';
import '../../models/attendance_record.dart';
import '../../services/attendance_service.dart';
import '../../widgets/premium_confirmation_dialog.dart';
import '../history_screen.dart';
import '../registration/register_staff_screen.dart';
import '../scanner/attendance_scanner_screen.dart';
import '../staff_list_screen.dart';
import 'views/mobile_dashboard_view.dart';
import 'views/tablet_dashboard_view.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isTablet = context.isTablet;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<DashboardBloc, DashboardState>(
          builder: (context, state) {
            final int totalStaff = state is DashboardLoaded ? state.totalStaff : 0;
            final int todayCheckins = state is DashboardLoaded ? state.todayCheckins : 0;
            final List<AttendanceRecord> recentRecords =
                state is DashboardLoaded ? state.recentRecords : [];

            final onTimeCount = recentRecords.where((r) => r.status != 'LATE').length;
            final attendancePercent =
                totalStaff > 0 ? ((todayCheckins / totalStaff) * 100).toInt() : 0;

            final topHeader = _buildTopHeader(context, isTablet: isTablet);

            return isTablet
                ? TabletDashboardView(
                    topHeader: topHeader,
                    totalStaff: totalStaff,
                    todayCheckins: todayCheckins,
                    onTimeCount: onTimeCount,
                    attendancePercent: attendancePercent,
                    recentRecords: recentRecords,
                    bottomPadding: bottomPadding,
                    onLaunchKiosk: () => _launchKioskMode(context, totalStaff),
                    onEnrollStaff: () => _navigateToRegister(context),
                    onViewAllHistory: () => _navigateToHistory(context),
                    onOpenScanner: () => _launchKioskMode(context, totalStaff),
                  )
                : MobileDashboardView(
                    topHeader: topHeader,
                    totalStaff: totalStaff,
                    todayCheckins: todayCheckins,
                    recentRecords: recentRecords,
                    bottomPadding: bottomPadding,
                    onLaunchKiosk: () => _launchKioskMode(context, totalStaff),
                    onEnrollStaff: () => _navigateToRegister(context),
                    onViewAllHistory: () => _navigateToHistory(context),
                    onOpenScanner: () => _launchKioskMode(context, totalStaff),
                  );
          },
        ),
      ),
    );
  }

  void _navigateToRegister(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RegisterStaffScreen(),
      ),
    );
  }

  void _navigateToHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );
  }

  Widget _buildTopHeader(BuildContext context, {required bool isTablet}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.face_retouching_natural_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI FACE',
                  style: TextStyle(
                    fontFamily: AppFonts.bold,
                    fontSize: isTablet ? 20 : 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  isTablet
                      ? 'Smart Biometric Workforce Management'
                      : 'Smart Biometric Attendance',
                  style: const TextStyle(
                    fontFamily: AppFonts.medium,
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),

        // Header Actions: Staff List
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<StaffBloc>(),
                    child: const StaffListScreen(),
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow,
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
    );
  }

  Future<void> _launchKioskMode(BuildContext context, int totalStaff) async {
    if (totalStaff == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enroll at least one employee first to activate the kiosk.'),
          backgroundColor: AppColors.amberWarning,
        ),
      );
      return;
    }

    final confirmed = await PremiumConfirmationDialog.show(
      context: context,
      title: 'Start Attendance Mode?',
      message:
          'This will start full-screen attendance check-in for your employees.\n\n'
          '• Touchless Punch: Employees can clock in seamlessly using face recognition.\n'
          '• Check-In & Check-Out: Switch between modes easily with the top sliding pill.\n'
          '• Easy Return: You can return to the Dashboard anytime by tapping the exit button.',
      confirmText: 'Start Attendance',
      cancelText: 'Cancel',
      icon: Icons.devices_rounded,
      iconColor: AppColors.primary,
      isDestructive: false,
    );

    if (confirmed == true) {
      await AttendanceService.instance.setKioskModeActive(true);
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AttendanceScannerScreen()),
      );
    }
  }
}
