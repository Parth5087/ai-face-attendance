abstract class StaffEvent {}

class LoadStaffListEvent extends StaffEvent {}

class DeleteStaffEvent extends StaffEvent {
  final String staffId;

  DeleteStaffEvent({required this.staffId});
}

class UpdateStaffEvent extends StaffEvent {
  final String staffId;
  final String name;
  final String employeeCode;
  final String role;
  final String department;

  UpdateStaffEvent({
    required this.staffId,
    required this.name,
    required this.employeeCode,
    required this.role,
    required this.department,
  });
}
