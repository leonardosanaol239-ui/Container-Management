// Maps role display names ↔ UserTypeId in dbo.UserTypes
const _roleToTypeId = {
  'Admin': 1,
  'Port Manager': 2,
  'Driver': 3,
  'Customer': 4,
  'Checker': 5,
};
const _typeIdToRole = {
  1: 'Admin',
  2: 'Port Manager',
  3: 'Driver',
  4: 'Customer',
  5: 'Checker',
};

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
  final String role;
  final int userTypeId;
  final String? password;
  final String? contactNumber;
  // Multiple port support
  final List<int> assignedPortIds;
  final List<String> assignedPortNames;
  final int statusId;

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
    this.assignedPortIds = const [],
    this.assignedPortNames = const [],
    this.statusId = userStatusActive,
  }) : userTypeId = userTypeId ?? _roleToTypeId[role] ?? 3;

  // Convenience getters for single-port backward compat
  int? get assignedPortId =>
      assignedPortIds.isNotEmpty ? assignedPortIds.first : null;
  String? get assignedPortName =>
      assignedPortNames.isNotEmpty ? assignedPortNames.first : null;

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

  factory UserModel.fromJson(Map<String, dynamic> json) {
    int? _int(String a, String b) => (json[a] ?? json[b]) as int?;
    String _str(String a, String b) => ((json[a] ?? json[b]) as String?) ?? '';

    final typeId = _int('userTypeId', 'UserTypeId') ?? 3;

    // Parse portIds list from API
    final rawPortIds = json['portIds'] ?? json['PortIds'];
    final List<int> portIds = rawPortIds is List
        ? rawPortIds.whereType<int>().toList()
        : (_int('portId', 'PortId') != null ? [_int('portId', 'PortId')!] : []);

    final rawPortDescs = json['portDescs'] ?? json['PortDescs'];
    final List<String> portDescs = rawPortDescs is List
        ? rawPortDescs.whereType<String>().toList()
        : (_str('portDesc', 'PortDesc').isNotEmpty
              ? [_str('portDesc', 'PortDesc')]
              : []);

    return UserModel(
      userId: _int('userId', 'UserId'),
      firstName: _str('firstName', 'FirstName'),
      middleInitial: _str('middleInitial', 'MiddleInitial'),
      lastName: _str('lastName', 'LastName'),
      userCode: _str('userCode', 'UserCode'),
      role: _typeIdToRole[typeId] ?? 'Driver',
      userTypeId: typeId,
      contactNumber: _str('contactNo', 'ContactNo').isEmpty
          ? null
          : _str('contactNo', 'ContactNo'),
      assignedPortIds: portIds,
      assignedPortNames: portDescs,
      statusId: _int('statusId', 'StatusId') ?? userStatusActive,
    );
  }

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
    if (role == 'Port Manager' || role == 'Driver') {
      map['portIds'] = assignedPortIds;
      map['portId'] = assignedPortIds.isNotEmpty ? assignedPortIds.first : null;
    }
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
    List<int>? assignedPortIds,
    List<String>? assignedPortNames,
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
    assignedPortIds: assignedPortIds ?? this.assignedPortIds,
    assignedPortNames: assignedPortNames ?? this.assignedPortNames,
    statusId: statusId ?? this.statusId,
  );
}
