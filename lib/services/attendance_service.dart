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
  bool get isCooldown => status == PunchStatus.cooldownActive;
  bool get isNoMatch => status == PunchStatus.noMatch;
}

class AttendanceService extends ChangeNotifier {
  final StorageService storageService;
  final MLService mlService;
  final FaceDetectorService faceDetectorService;
  final AntiSpoofingService antiSpoofingService;

  List<UserModel> _users = [];
  List<AttendanceRecord> _records = [];

  // Cooldown tracker to prevent duplicate check-ins within 60 seconds
  final Map<String, DateTime> _recentPunchCooldown = {};

  bool _isReady = false;

  AttendanceService({
    required this.storageService,
    required this.mlService,
    required this.faceDetectorService,
    required this.antiSpoofingService,
  });

  bool get isReady => _isReady;
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

      // Convert small thumbnail to base64 for avatar display
      final thumb = img.copyResize(faceImage, width: 80, height: 80);
      final thumbJpg = img.encodeJpg(thumb, quality: 75);
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

  /// Verify and punch attendance from face scanner (Option 1: Single Daily Check-in)
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

    // 2. Option 1 Check: Has this employee ALREADY checked in TODAY?
    if (checkType == 'IN') {
      final existingTodayCheckIn = getTodayCheckIn(user.id);
      if (existingTodayCheckIn != null) {
        // Update cooldown so dialog doesn't re-trigger immediately
        _recentPunchCooldown[user.id] = now;

        // DO NOT save duplicate entry to database!
        return PunchResult(
          status: PunchStatus.alreadyCheckedIn,
          record: existingTodayCheckIn,
          user: user,
          confidenceScore: result.similarity,
          message: 'Already checked in today',
        );
      }
    }

    // 3. New Fresh Check-in for today!
    _recentPunchCooldown[user.id] = now;

    final record = AttendanceRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      employeeId: user.id,
      employeeName: user.name,
      employeeCode: user.employeeCode,
      role: user.role,
      timestamp: now,
      checkType: checkType,
      confidenceScore: result.similarity,
      status: _determineStatus(now),
    );

    await storageService.saveAttendanceRecord(record);
    _records = storageService.getAttendanceRecords();
    notifyListeners();

    return PunchResult(
      status: PunchStatus.success,
      record: record,
      user: user,
      confidenceScore: result.similarity,
      message: 'Attendance recorded successfully',
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
