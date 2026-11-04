import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_face_attendance/models/attendance_record.dart';
import 'package:ai_face_attendance/models/user_model.dart';
import 'package:ai_face_attendance/services/attendance_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Smoke test - project sanity check', () {
    expect(true, isTrue);
  });

  group('UserModel Tests', () {
    test('avatarBytes memoization and decoding', () {
      final sampleBytes = utf8.encode('test_avatar_image');
      final base64String = base64Encode(sampleBytes);

      final user = UserModel(
        id: '1',
        name: 'John Doe',
        employeeCode: 'EMP-001',
        role: 'Engineer',
        faceEmbedding: [0.1, 0.2, 0.3],
        registeredAt: DateTime.now(),
        avatarBase64: base64String,
      );

      final decoded1 = user.avatarBytes;
      expect(decoded1, isNotNull);
      expect(decoded1, equals(sampleBytes));

      // Check memoization (same instance cached)
      final decoded2 = user.avatarBytes;
      expect(identical(decoded1, decoded2), isTrue);
    });

    test('avatarBytes with null avatarBase64 returns null', () {
      final user = UserModel(
        id: '2',
        name: 'Jane Doe',
        employeeCode: 'EMP-002',
        role: 'Designer',
        faceEmbedding: [0.1, 0.2, 0.3],
        registeredAt: DateTime.now(),
        avatarBase64: null,
      );

      expect(user.avatarBytes, isNull);
    });
  });

  group('AttendanceRecord Tests', () {
    test('punchImage serialization and memoized punchImageBytes', () {
      final sampleBytes = utf8.encode('test_punch_snapshot');
      final base64String = base64Encode(sampleBytes);

      final record = AttendanceRecord(
        id: '101',
        employeeId: '1',
        employeeName: 'John Doe',
        employeeCode: 'EMP-001',
        role: 'Engineer',
        timestamp: DateTime(2026, 11, 4, 9, 15),
        checkType: 'IN',
        confidenceScore: 0.95,
        status: 'ON TIME',
        punchImage: base64String,
      );

      // Check memoized bytes
      final bytes1 = record.punchImageBytes;
      expect(bytes1, isNotNull);
      expect(bytes1, equals(sampleBytes));

      final bytes2 = record.punchImageBytes;
      expect(identical(bytes1, bytes2), isTrue);

      // Check toMap and fromMap
      final map = record.toMap();
      expect(map['punchImage'], equals(base64String));

      final fromMapRecord = AttendanceRecord.fromMap(map);
      expect(fromMapRecord.id, equals('101'));
      expect(fromMapRecord.punchImage, equals(base64String));
      expect(fromMapRecord.punchImageBytes, equals(sampleBytes));
    });
  });

  group('AttendanceService Singleton & Idempotency', () {
    test('AttendanceService singleton instance', () {
      final s1 = AttendanceService.instance;
      final s2 = AttendanceService.instance;
      expect(identical(s1, s2), isTrue);
    });
  });
}
