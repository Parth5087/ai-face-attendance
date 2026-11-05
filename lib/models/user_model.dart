import 'dart:convert';
import 'dart:typed_data';

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

  Uint8List? _cachedAvatarBytes;

  /// Memoized getter that decodes base64 only once and caches it in memory.
  Uint8List? get avatarBytes {
    if (_cachedAvatarBytes != null) return _cachedAvatarBytes;
    if (avatarBase64 != null && avatarBase64!.isNotEmpty) {
      try {
        _cachedAvatarBytes = base64Decode(avatarBase64!);
        return _cachedAvatarBytes;
      } catch (_) {}
    }
    return null;
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? employeeCode,
    String? role,
    String? department,
    List<double>? faceEmbedding,
    List<List<double>>? multiAngleEmbeddings,
    DateTime? registeredAt,
    String? avatarBase64,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      employeeCode: employeeCode ?? this.employeeCode,
      role: role ?? this.role,
      department: department ?? this.department,
      faceEmbedding: faceEmbedding ?? this.faceEmbedding,
      multiAngleEmbeddings: multiAngleEmbeddings ?? this.multiAngleEmbeddings,
      registeredAt: registeredAt ?? this.registeredAt,
      avatarBase64: avatarBase64 ?? this.avatarBase64,
    );
  }

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
