import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/attendance_record.dart';

class StorageService {
  static const String _usersKey = 'ai_face_registered_users_v1';
  static const String _attendanceKey = 'ai_face_attendance_records_v1';
  // Legacy migration keys
  static const String _legacyUsersKey = 'legacy_registered_users_v1';
  static const String _legacyAttendanceKey = 'legacy_attendance_records_v1';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // Migrate data from legacy keys if new keys are not yet populated
    if (!_prefs.containsKey(_usersKey) && _prefs.containsKey(_legacyUsersKey)) {
      final oldUsers = _prefs.getStringList(_legacyUsersKey);
      if (oldUsers != null) {
        await _prefs.setStringList(_usersKey, oldUsers);
      }
    }
    if (!_prefs.containsKey(_attendanceKey) && _prefs.containsKey(_legacyAttendanceKey)) {
      final oldRecords = _prefs.getStringList(_legacyAttendanceKey);
      if (oldRecords != null) {
        await _prefs.setStringList(_attendanceKey, oldRecords);
      }
    }
  }

  // --- Users / Staff Operations ---
  List<UserModel> getUsers() {
    final rawList = _prefs.getStringList(_usersKey) ?? [];
    return rawList.map((e) => UserModel.fromJson(e)).toList();
  }

  Future<void> saveUser(UserModel user) async {
    final users = getUsers();
    // Replace if exists, or append
    final index = users.indexWhere((u) => u.id == user.id);
    if (index >= 0) {
      users[index] = user;
    } else {
      users.add(user);
    }
    final rawList = users.map((u) => u.toJson()).toList();
    await _prefs.setStringList(_usersKey, rawList);
  }

  Future<void> deleteUser(String id) async {
    final users = getUsers();
    users.removeWhere((u) => u.id == id);
    final rawList = users.map((u) => u.toJson()).toList();
    await _prefs.setStringList(_usersKey, rawList);

    // Also cascade delete all attendance logs belonging to this user
    final records = getAttendanceRecords();
    records.removeWhere((r) => r.employeeId == id);
    final rawRecords = records.map((r) => r.toJson()).toList();
    await _prefs.setStringList(_attendanceKey, rawRecords);
  }

  // --- Attendance Records Operations ---
  List<AttendanceRecord> getAttendanceRecords() {
    final rawList = _prefs.getStringList(_attendanceKey) ?? [];
    final records = rawList.map((e) => AttendanceRecord.fromJson(e)).toList();
    // Sort descending by timestamp
    records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return records;
  }

  Future<void> saveAttendanceRecord(AttendanceRecord record) async {
    final records = getAttendanceRecords();
    records.insert(0, record);
    // Keep max 500 records in local storage
    if (records.length > 500) {
      records.removeLast();
    }
    final rawList = records.map((r) => r.toJson()).toList();
    await _prefs.setStringList(_attendanceKey, rawList);
  }

  Future<void> clearAttendanceRecords() async {
    await _prefs.remove(_attendanceKey);
  }
}
