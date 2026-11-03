import 'dart:convert';

class AttendanceRecord {
  final String id;
  final String employeeId;
  final String employeeName;
  final String employeeCode;
  final String role;
  final DateTime timestamp;
  final String checkType; // 'IN' or 'OUT'
  final double confidenceScore; // 0.0 to 1.0 (Similarity %)
  final String status; // 'VERIFIED', 'ON TIME', 'LATE'

  AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeeCode,
    required this.role,
    required this.timestamp,
    required this.checkType,
    required this.confidenceScore,
    this.status = 'VERIFIED',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'employeeCode': employeeCode,
      'role': role,
      'timestamp': timestamp.toIso8601String(),
      'checkType': checkType,
      'confidenceScore': confidenceScore,
      'status': status,
    };
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'] as String,
      employeeId: map['employeeId'] as String,
      employeeName: map['employeeName'] as String,
      employeeCode: map['employeeCode'] as String,
      role: map['role'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      checkType: map['checkType'] as String,
      confidenceScore: (map['confidenceScore'] as num).toDouble(),
      status: map['status'] as String? ?? 'VERIFIED',
    );
  }

  String toJson() => json.encode(toMap());

  factory AttendanceRecord.fromJson(String source) =>
      AttendanceRecord.fromMap(json.decode(source) as Map<String, dynamic>);
}
