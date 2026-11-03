import 'dart:convert';

class UserModel {
  final String id;
  final String name;
  final String employeeCode;
  final String role;
  final String department;
  final List<double> faceEmbedding; // Primary front embedding
  final List<List<double>>? multiAngleEmbeddings; // [Front, Left, Right] embeddings
  final DateTime registeredAt;
  final String? avatarBase64;

  UserModel({
    required this.id,
    required this.name,
    required this.employeeCode,
    required this.role,
    this.department = 'General',
    required this.faceEmbedding,
    this.multiAngleEmbeddings,
    required this.registeredAt,
    this.avatarBase64,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'employeeCode': employeeCode,
      'role': role,
      'department': department,
      'faceEmbedding': faceEmbedding,
      'multiAngleEmbeddings': multiAngleEmbeddings,
      'registeredAt': registeredAt.toIso8601String(),
      'avatarBase64': avatarBase64,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    List<List<double>>? angles;
    if (map['multiAngleEmbeddings'] != null) {
      angles = (map['multiAngleEmbeddings'] as List<dynamic>)
          .map((list) => (list as List<dynamic>).map((e) => (e as num).toDouble()).toList())
          .toList();
    }

    return UserModel(
      id: map['id'] as String,
      name: map['name'] as String,
      employeeCode: map['employeeCode'] as String,
      role: map['role'] as String,
      department: map['department'] as String? ?? 'General',
      faceEmbedding: (map['faceEmbedding'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
      multiAngleEmbeddings: angles,
      registeredAt: DateTime.parse(map['registeredAt'] as String),
      avatarBase64: map['avatarBase64'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory UserModel.fromJson(String source) =>
      UserModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
