abstract class StaffEvent {}

class LoadStaffListEvent extends StaffEvent {}

class DeleteStaffEvent extends StaffEvent {
  final String staffId;

  DeleteStaffEvent({required this.staffId});
}
