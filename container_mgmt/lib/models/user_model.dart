// Maps role display names ↔ UserTypeId in dbo.UserTypes
const _roleToTypeId = {'Admin': 1, 'Port Manager': 2, 'Driver': 3};
const _typeIdToRole = {1: 'Admin', 2: 'Port Manager', 3: 'Driver'};

// User status values from dbo.Status
const userStatusActive = 3;
const userStatusInactive = 4;
const userStatusDeleted = 5;

const _statusLabel = {
  userStatusActive: 'Active',
  userStatusInactive: 'Inactive',
  userStatusDeleted: 'Deleted',
};

class UserModel {
  final int? userId;
  final String firstName;
  final String middleInitial;
  final String lastName;
  final String userCode;
  final String role; // 'Admin' | 'Port Manager' | 'Driver'
  final int userTypeId; // 1 | 2 | 3
  final String? password;
  final String? contactNumber; // DB: ContactNo
  final int? assignedPortId; // DB: PortId
  final String? assignedPortName;
  final int statusId; // 3=Active, 4=Inactive, 5=Deleted

  UserModel({
    this.userId,
    required this.firstName,
    this.middleInitial = '',
    required this.lastName,
    required this.userCode,
    required this.role,
    int? userTypeId,
    this.password,
    this.contactNumber,
    this.assignedPortId,
    this.assignedPortName,
    this.statusId = userStatusActive,
  }) : userTypeId = userTypeId ?? _roleToTypeId[role] ?? 3;

  String get name {
    final mi = middleInitial.trim();
    if (mi.isEmpty) return '${firstName.trim()} ${lastName.trim()}';
    final dot = mi.endsWith('.') ? mi : '$mi.';
    return '${firstName.trim()} $dot ${lastName.trim()}';
  }

  String get statusLabel => _statusLabel[statusId] ?? 'Unknown';
  bool get isActive => statusId == userStatusActive;
  bool get isInactive => statusId == userStatusInactive;
  bool get isDeleted => statusId == userStatusDeleted;

  /// Handles both camelCase (Flutter convention) and PascalCase (.NET API responses)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    int? _int(String camel, String pascal) =>
        (json[camel] ?? json[pascal]) as int?;
    String _str(String camel, String pascal) =>
        ((json[camel] ?? json[pascal]) as String?) ?? '';

    final typeId = _int('userTypeId', 'UserTypeId') ?? 3;
    return UserModel(
      userId: _int('userId', 'UserId'),
      firstName: _str('firstName', 'FirstName'),
      middleInitial: _str('middleInitial', 'MiddleInitial'),
      lastName: _str('lastName', 'LastName'),
      userCode: _str('userCode', 'UserCode'),
      role: _typeIdToRole[typeId] ?? 'Driver',
      userTypeId: typeId,
      // password intentionally not read back
      contactNumber: _str('contactNo', 'ContactNo').isEmpty
          ? null
          : _str('contactNo', 'ContactNo'),
      assignedPortId: _int('portId', 'PortId'),
      assignedPortName: _str('portDesc', 'PortDesc').isEmpty
          ? null
          : _str('portDesc', 'PortDesc'),
      statusId: _int('statusId', 'StatusId') ?? userStatusActive,
    );
  }

  /// Payload sent to the API — exact field names expected by the backend DTO
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'userCode': userCode,
      'userTypeId': userTypeId,
      'firstName': firstName,
      'middleInitial': middleInitial,
      'lastName': lastName,
      'contactNo': contactNumber ?? '',
      'statusId': statusId,
    };
    if (userId != null) map['userId'] = userId;
    if (password != null && password!.isNotEmpty) map['password'] = password;
    // Only include portId for Port Managers and Drivers — never send null portId for Admin
    if (role == 'Port Manager' || role == 'Driver')
      map['portId'] = assignedPortId;
    return map;
  }

  UserModel copyWith({
    int? userId,
    String? firstName,
    String? middleInitial,
    String? lastName,
    String? userCode,
    String? role,
    int? userTypeId,
    String? password,
    String? contactNumber,
    int? assignedPortId,
    String? assignedPortName,
    int? statusId,
  }) => UserModel(
    userId: userId ?? this.userId,
    firstName: firstName ?? this.firstName,
    middleInitial: middleInitial ?? this.middleInitial,
    lastName: lastName ?? this.lastName,
    userCode: userCode ?? this.userCode,
    role: role ?? this.role,
    userTypeId: userTypeId ?? this.userTypeId,
    password: password ?? this.password,
    contactNumber: contactNumber ?? this.contactNumber,
    assignedPortId: assignedPortId ?? this.assignedPortId,
    assignedPortName: assignedPortName ?? this.assignedPortName,
    statusId: statusId ?? this.statusId,
  );
}
