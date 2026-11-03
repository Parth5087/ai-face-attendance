import '../../models/attendance_record.dart';

abstract class DashboardState {}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final int totalStaff;
  final int todayCheckins;
  final List<AttendanceRecord> recentRecords;

  DashboardLoaded({
    required this.totalStaff,
    required this.todayCheckins,
    required this.recentRecords,
  });
}

class DashboardError extends DashboardState {
  final String message;

  DashboardError({required this.message});
}
