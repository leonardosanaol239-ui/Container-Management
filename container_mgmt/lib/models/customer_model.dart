class CustomerModel {
  final int customerId;
  final int userId;
  final String firstName;
  final String lastName;
  final String? middleInitial;
  final String? contactNo;

  CustomerModel({
    required this.customerId,
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.middleInitial,
    this.contactNo,
  });

  String get fullName {
    final mi = (middleInitial != null && middleInitial!.isNotEmpty)
        ? ' ${middleInitial!}. '
        : ' ';
    return '$firstName$mi$lastName';
  }

  factory CustomerModel.fromJson(Map<String, dynamic> json) => CustomerModel(
    customerId: json['customerId'] ?? json['CustomerId'],
    userId: json['userId'] ?? json['UserId'],
    firstName: json['firstName'] ?? json['FirstName'] ?? '',
    lastName: json['lastName'] ?? json['LastName'] ?? '',
    middleInitial: json['middleInitial'] ?? json['MiddleInitial'],
    contactNo: json['contactNo'] ?? json['ContactNo'],
  );
}
