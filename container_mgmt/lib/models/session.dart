/// Holds the currently logged-in user's info for the session.
class Session {
  final int userId;
  final String userCode;
  final String fullName;
  final String role; // 'Admin' | 'Port Manager' | 'Driver'
  final int userTypeId; // 1 | 2 | 3
  final int? portId;
  final String? portDesc;

  const Session({
    required this.userId,
    required this.userCode,
    required this.fullName,
    required this.role,
    required this.userTypeId,
    this.portId,
    this.portDesc,
  });

  bool get isAdmin => userTypeId == 1;
  bool get isPortManager => userTypeId == 2;
  bool get isDriver => userTypeId == 3;

  factory Session.fromJson(Map<String, dynamic> json) => Session(
    userId: json['userId'] as int,
    userCode: json['userCode'] as String,
    fullName: json['fullName'] as String,
    role: json['role'] as String,
    userTypeId: json['userTypeId'] as int,
    portId: json['portId'] as int?,
    portDesc: json['portDesc'] as String?,
  );
}
