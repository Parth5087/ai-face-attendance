import '../../models/user_model.dart';

abstract class StaffState {}

class StaffInitial extends StaffState {}

class StaffLoading extends StaffState {}

class StaffLoaded extends StaffState {
  final List<UserModel> staffList;

  StaffLoaded({required this.staffList});
}

class StaffActionSuccess extends StaffState {
  final String message;

  StaffActionSuccess({required this.message});
}

class StaffError extends StaffState {
  final String message;

  StaffError({required this.message});
}
