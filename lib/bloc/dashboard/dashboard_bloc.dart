import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/attendance_service.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final AttendanceService attendanceService;
  late final void Function() _attendanceListener;

  DashboardBloc({required this.attendanceService}) : super(DashboardInitial()) {
    on<LoadDashboardDataEvent>(_onLoadDashboardData);
    on<RefreshDashboardDataEvent>(_onRefreshDashboardData);

    // Listen to changes in AttendanceService (e.g. punches, enrolled staff)
    _attendanceListener = () {
      add(RefreshDashboardDataEvent());
    };
    attendanceService.addListener(_attendanceListener);
  }

  void _onLoadDashboardData(
    LoadDashboardDataEvent event,
    Emitter<DashboardState> emit,
  ) {
    emit(_getLoadedState());
  }

  void _onRefreshDashboardData(
    RefreshDashboardDataEvent event,
    Emitter<DashboardState> emit,
  ) {
    emit(_getLoadedState());
  }

  DashboardLoaded _getLoadedState() {
    return DashboardLoaded(
      totalStaff: attendanceService.totalStaffCount,
      todayCheckins: attendanceService.todayCheckInCount,
      recentRecords: attendanceService.records.take(5).toList(),
    );
  }

  @override
  Future<void> close() {
    attendanceService.removeListener(_attendanceListener);
    return super.close();
  }
}
