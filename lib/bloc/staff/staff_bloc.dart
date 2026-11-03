import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/attendance_service.dart';
import 'staff_event.dart';
import 'staff_state.dart';

class StaffBloc extends Bloc<StaffEvent, StaffState> {
  final AttendanceService attendanceService;
  late final void Function() _attendanceListener;

  StaffBloc({required this.attendanceService}) : super(StaffInitial()) {
    on<LoadStaffListEvent>(_onLoadStaffList);
    on<DeleteStaffEvent>(_onDeleteStaff);

    _attendanceListener = () {
      add(LoadStaffListEvent());
    };
    attendanceService.addListener(_attendanceListener);
  }

  void _onLoadStaffList(
    LoadStaffListEvent event,
    Emitter<StaffState> emit,
  ) {
    emit(StaffLoaded(staffList: attendanceService.users));
  }

  Future<void> _onDeleteStaff(
    DeleteStaffEvent event,
    Emitter<StaffState> emit,
  ) async {
    try {
      await attendanceService.deleteStaff(event.staffId);
      emit(StaffActionSuccess(message: 'Staff member deleted successfully'));
      emit(StaffLoaded(staffList: attendanceService.users));
    } catch (e) {
      emit(StaffError(message: 'Failed to delete staff: $e'));
    }
  }

  @override
  Future<void> close() {
    attendanceService.removeListener(_attendanceListener);
    return super.close();
  }
}
