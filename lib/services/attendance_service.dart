import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../models/user_model.dart';
import '../models/attendance_record.dart';
import 'storage_service.dart';
import 'ml_service.dart';
import 'face_detector_service.dart';
import 'anti_spoofing_service.dart';

enum PunchStatus {
  success,
  alreadyCheckedIn,
  alreadyCheckedOut,
  noCheckInFound,
  cooldownActive,
  noMatch,
  error,
}

class PunchResult {
  final PunchStatus status;
  final AttendanceRecord? record;
  final UserModel? user;
  final double confidenceScore;
  final String? message;

  const PunchResult({
    required this.status,
    this.record,
    this.user,
    this.confidenceScore = 0.0,
    this.message,
  });

  bool get isSuccess => status == PunchStatus.success;
  bool get isAlreadyCheckedIn => status == PunchStatus.alreadyCheckedIn;
  bool get isAlreadyCheckedOut => status == PunchStatus.alreadyCheckedOut;
  bool get isNoCheckInFound => status == PunchStatus.noCheckInFound;
  bool get isCooldown => status == PunchStatus.cooldownActive;
  bool get isNoMatch => status == PunchStatus.noMatch;
}

class AttendanceService extends ChangeNotifier {
  static AttendanceService? _instance;
  static AttendanceService get instance => _instance ??= AttendanceService();

  final StorageService storageService;
  final MLService mlService;
  final FaceDetectorService faceDetectorService;
  final AntiSpoofingService antiSpoofingService;

  List<UserModel> _users = [];
  List<AttendanceRecord> _records = [];

  // Cooldown tracker to prevent duplicate check-ins within 60 seconds
  final Map<String, DateTime> _recentPunchCooldown = {};

  bool _isReady = false;
  bool _isKioskModeActive = false;

  AttendanceService({
    StorageService? storageService,
    MLService? mlService,
    FaceDetectorService? faceDetectorService,
    AntiSpoofingService? antiSpoofingService,
  })  : storageService = storageService ?? StorageService(),
        mlService = mlService ?? MLService(),
        faceDetectorService = faceDetectorService ?? FaceDetectorService(),
        antiSpoofingService = antiSpoofingService ?? AntiSpoofingService() {
    _instance = this;
  }

  bool get isReady => _isReady;
  bool get isKioskModeActive => _isKioskModeActive;

  Future<void> setKioskModeActive(bool active) async {
    _isKioskModeActive = active;
    notifyListeners();
  }

  List<UserModel> get users => List.unmodifiable(_users);
  List<AttendanceRecord> get records => List.unmodifiable(_records);

  int get totalStaffCount => _users.length;

  int get todayCheckInCount {
    final now = DateTime.now();
    return _records.where((r) {
      return r.timestamp.year == now.year &&
          r.timestamp.month == now.month &&
          r.timestamp.day == now.day &&
          r.checkType == 'IN';
    }).length;
  }

  List<AttendanceRecord> get todayRecords {
    final now = DateTime.now();
    return _records.where((r) {
      return r.timestamp.year == now.year &&
          r.timestamp.month == now.month &&
          r.timestamp.day == now.day;
    }).toList();
  }

  void reloadFromStorage() {
    _users = storageService.getUsers();
    _records = storageService.getAttendanceRecords();
    _isReady = true;
    notifyListeners();
  }

  Future<void> initialize({void Function(String message, double progress)? onProgress}) async {
    // Idempotency guard: prevent duplicate initialization
    if (_isReady) {
      onProgress?.call('System Ready', 1.0);
      return;
    }

    onProgress?.call('Initializing Secure Storage...', 0.2);
    await storageService.init();

    onProgress?.call('Loading Face Recognition Engine...', 0.5);
    await mlService.initialize();

    onProgress?.call('Loading Anti-Spoofing AI...', 0.75);
    await antiSpoofingService.initialize();

    onProgress?.call('Calibrating Biometrics...', 0.9);
    faceDetectorService.initialize();

    reloadFromStorage();

    onProgress?.call('System Ready', 1.0);
  }

  /// Register a new staff member with their cropped face image(s)
  Future<bool> registerStaff({
    required String name,
    required String employeeCode,
    required String role,
    String department = 'Office',
    required img.Image faceImage,
    List<img.Image>? multiAngleFaces,
    List<List<double>>? precomputedAngleEmbeddings,
  }) async {
    try {
      final embedding = mlService.predict(faceImage);
      if (embedding == null) {
        debugPrint('Failed to extract primary face embedding');
        return false;
      }

      final List<List<double>> allAngleEmbeddings = [];
      if (precomputedAngleEmbeddings != null && precomputedAngleEmbeddings.isNotEmpty) {
        allAngleEmbeddings.addAll(precomputedAngleEmbeddings);
      } else {
        allAngleEmbeddings.add(embedding);
        if (multiAngleFaces != null && multiAngleFaces.isNotEmpty) {
          for (final angleFace in multiAngleFaces) {
            final angleVec = mlService.predict(angleFace);
            if (angleVec != null) {
              allAngleEmbeddings.add(angleVec);
            }
          }
        }
      }

      // Convert high-definition thumbnail to base64 for crisp avatar display on tablet & retina screens
      final thumb = img.copyResize(faceImage, width: 256, height: 256);
      final thumbJpg = img.encodeJpg(thumb, quality: 88);
      final avatarBase64 = base64Encode(thumbJpg);

      final newUser = UserModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name.trim(),
        employeeCode: employeeCode.trim().toUpperCase(),
        role: role.trim(),
        department: department.trim(),
        faceEmbedding: embedding,
        multiAngleEmbeddings: allAngleEmbeddings,
        registeredAt: DateTime.now(),
        avatarBase64: avatarBase64,
      );

      await storageService.saveUser(newUser);
      _users = storageService.getUsers();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error registering staff: $e');
      return false;
    }
  }

  /// Delete a staff member and all their associated attendance history
  Future<void> deleteStaff(String id) async {
    await storageService.deleteUser(id);
    _recentPunchCooldown.remove(id);
    _users = storageService.getUsers();
    _records = storageService.getAttendanceRecords();
    notifyListeners();
  }

  /// Update staff member information
  Future<void> updateStaffInfo({
    required String staffId,
    required String name,
    required String employeeCode,
    required String role,
    required String department,
  }) async {
    final userIndex = _users.indexWhere((u) => u.id == staffId);
    if (userIndex == -1) return;
    final old = _users[userIndex];
    final updated = old.copyWith(
      name: name.trim(),
      employeeCode: employeeCode.trim().toUpperCase(),
      role: role.trim(),
      department: department.trim(),
    );
    _users[userIndex] = updated;
    await storageService.saveUsers(_users);
    notifyListeners();
  }

  /// Find today's check-in record for a specific employee
  AttendanceRecord? getTodayCheckIn(String employeeId) {
    final now = DateTime.now();
    AttendanceRecord? firstTodayPunch;
    for (final r in _records) {
      if (r.employeeId == employeeId &&
          r.checkType == 'IN' &&
          r.timestamp.year == now.year &&
          r.timestamp.month == now.month &&
          r.timestamp.day == now.day) {
        firstTodayPunch = r;
      }
    }
    return firstTodayPunch;
  }

  /// Find today's check-out record for a specific employee
  AttendanceRecord? getTodayCheckOut(String employeeId) {
    final now = DateTime.now();
    AttendanceRecord? lastCheckOut;
    for (final r in _records) {
      if (r.employeeId == employeeId &&
          r.checkType == 'OUT' &&
          r.timestamp.year == now.year &&
          r.timestamp.month == now.month &&
          r.timestamp.day == now.day) {
        lastCheckOut = r;
      }
    }
    return lastCheckOut;
  }

  /// Calculate work duration between check-in and check-out
  String calculateWorkDuration(DateTime checkInTime, DateTime checkOutTime) {
    final diff = checkOutTime.difference(checkInTime);
    if (diff.isNegative) return '0h 00m';
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }

  /// Verify and punch attendance from face scanner (Check-In or Check-Out)
  Future<PunchResult> punchAttendance({
    required img.Image faceImage,
    String checkType = 'IN',
  }) async {
    if (_users.isEmpty) {
      return const PunchResult(
        status: PunchStatus.noMatch,
        message: 'No registered employees in system',
      );
    }

    final probeEmbedding = mlService.predict(faceImage);
    if (probeEmbedding == null) {
      debugPrint('[SCANNER_DEBUG] ❌ Face embedding extraction failed');
      return const PunchResult(
        status: PunchStatus.error,
        message: 'Failed to extract face embedding',
      );
    }

    final result = mlService.matchFace(probeEmbedding, _users);

    if (!result.isMatch || result.user == null) {
      debugPrint(
        '[SCANNER_DEBUG] ❌ Face not recognized! '
        'Closest candidate: "${result.closestCandidate?.name ?? 'Unknown'}" '
        '(${result.closestCandidate?.employeeCode ?? '-'}) '
        'with similarity ${(result.similarity * 100).toStringAsFixed(1)}% '
        '(Required: ${(MLService.similarityThreshold * 100).toStringAsFixed(1)}%)',
      );
      return PunchResult(
        status: PunchStatus.noMatch,
        user: result.closestCandidate,
        confidenceScore: result.similarity,
        message: 'Face not recognized',
      );
    }

    final user = result.user!;
    final now = DateTime.now();

    // 1. Cooldown Check: Ignore rapid repeat scans within 5 seconds while person steps away
    final lastPunch = _recentPunchCooldown[user.id];
    if (lastPunch != null && now.difference(lastPunch).inSeconds < 5) {
      debugPrint('[SCANNER_DEBUG] ⏳ Cooldown active for "${user.name}" (<5s elapsed). Skipping re-trigger.');
      return PunchResult(
        status: PunchStatus.cooldownActive,
        user: user,
        confidenceScore: result.similarity,
        message: 'Cooldown active',
      );
    }

    // 2. Mode Check: CHECK-IN vs CHECK-OUT rules
    if (checkType == 'IN') {
      final existingTodayCheckIn = getTodayCheckIn(user.id);
      if (existingTodayCheckIn != null) {
        _recentPunchCooldown[user.id] = now;
        return PunchResult(
          status: PunchStatus.alreadyCheckedIn,
          record: existingTodayCheckIn,
          user: user,
          confidenceScore: result.similarity,
          message: 'Already checked in today',
        );
      }
    } else if (checkType == 'OUT') {
      final todayCheckIn = getTodayCheckIn(user.id);
      if (todayCheckIn == null) {
        _recentPunchCooldown[user.id] = now;
        return PunchResult(
          status: PunchStatus.noCheckInFound,
          user: user,
          confidenceScore: result.similarity,
          message: 'No Check-In found for today',
        );
      }

      final existingTodayCheckOut = getTodayCheckOut(user.id);
      if (existingTodayCheckOut != null) {
        _recentPunchCooldown[user.id] = now;
        return PunchResult(
          status: PunchStatus.alreadyCheckedOut,
          record: existingTodayCheckOut,
          user: user,
          confidenceScore: result.similarity,
          message: 'Already checked out today',
        );
      }
    }

    // 3. New Fresh Check-in / Check-out for today!
    _recentPunchCooldown[user.id] = now;

    // Generate an optimized lightweight thumbnail of the live cropped face (150x150 JPEG, ~10-12 KB)
    String? punchImageBase64;
    try {
      final thumb = img.copyResize(faceImage, width: 150, height: 150);
      final thumbJpg = img.encodeJpg(thumb, quality: 75);
      punchImageBase64 = base64Encode(thumbJpg);
    } catch (e) {
      debugPrint('Error generating punch thumbnail: $e');
    }

    final record = AttendanceRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      employeeId: user.id,
      employeeName: user.name,
      employeeCode: user.employeeCode,
      role: user.role,
      timestamp: now,
      checkType: checkType,
      confidenceScore: result.similarity,
      status: checkType == 'OUT' ? 'CHECKED OUT' : _determineStatus(now),
      punchImage: punchImageBase64,
    );

    await storageService.saveAttendanceRecord(record);
    _records = storageService.getAttendanceRecords();
    notifyListeners();

    return PunchResult(
      status: PunchStatus.success,
      record: record,
      user: user,
      confidenceScore: result.similarity,
      message: checkType == 'OUT'
          ? 'Check-out recorded successfully'
          : 'Attendance recorded successfully',
    );
  }

  String _determineStatus(DateTime timestamp) {
    // Office hours: 09:30 AM threshold
    final cutoff = DateTime(timestamp.year, timestamp.month, timestamp.day, 9, 30);
    if (timestamp.isBefore(cutoff) || timestamp.isAtSameMomentAs(cutoff)) {
      return 'ON TIME';
    } else {
      return 'LATE';
    }
  }

  Future<void> clearHistory() async {
    await storageService.clearAttendanceRecords();
    _records = [];
    notifyListeners();
  }
}
