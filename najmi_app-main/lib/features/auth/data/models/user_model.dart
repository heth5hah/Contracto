enum UserType { individual, company }

class UserModel {
  final String id;
  final String name;
  final String mobile;
  final String? email;
  final String? pan; // Required for company, optional for individual
  final String? gstNumber; // Required for company, optional for individual
  final UserType userType;
  final String? companyName; // Required for company users
  final bool isGstRegistered;
  final String role;
  final double creditLimit;
  final String status;
  final DateTime createdAt;

  // Business KYC details fields
  final String? companyAddress;
  final String? companyPhone;
  final String? pocName;
  final String? pocPhone;

  UserModel({
    required this.id,
    required this.name,
    required this.mobile,
    this.email,
    this.pan,
    this.gstNumber,
    this.userType = UserType.individual,
    this.companyName,
    this.isGstRegistered = false,
    required this.role,
    required this.creditLimit,
    required this.status,
    required this.createdAt,
    this.companyAddress,
    this.companyPhone,
    this.pocName,
    this.pocPhone,
  });

  // Helper getters
  bool get isCompany => userType == UserType.company;
  bool get isIndividual => userType == UserType.individual;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'] ?? '',
      mobile: json['mobile'] ?? '',
      email: json['email'],
      pan: json['pan_number'], // Using 'pan_number' column from database
      gstNumber: json['gst_number'],
      userType: json['user_type'] == 'company'
          ? UserType.company
          : UserType.individual,
      companyName: json['company_name'],
      isGstRegistered: json['is_gst_registered'] ?? false,
      role: json['role'] ?? 'customer',
      creditLimit: (json['credit_limit'] ?? 0).toDouble(),
      status: json['status'] ?? 'active',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      companyAddress: json['company_address'],
      companyPhone: json['company_phone'],
      pocName: json['poc_name'],
      pocPhone: json['poc_phone'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mobile': mobile,
      'email': email,
      'pan_number': pan,
      'gst_number': gstNumber,
      'user_type': userType == UserType.company ? 'company' : 'individual',
      'company_name': companyName,
      'is_gst_registered': isGstRegistered,
      'role': role,
      'credit_limit': creditLimit,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'company_address': companyAddress,
      'company_phone': companyPhone,
      'poc_name': pocName,
      'poc_phone': pocPhone,
    };
  }

  // Helper method to create a new user for registration
  Map<String, dynamic> toCreateJson({required String passwordHash}) {
    return {
      'name': name,
      'mobile': mobile,
      'email': email,
      'pan_number': pan,
      'gst_number': gstNumber,
      'user_type': userType == UserType.company ? 'company' : 'individual',
      'company_name': companyName,
      'is_gst_registered': gstNumber != null && gstNumber!.isNotEmpty,
      'password_hash': passwordHash,
      'role': role,
      'credit_limit': creditLimit,
      'status': status,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? mobile,
    String? email,
    String? pan,
    String? gstNumber,
    UserType? userType,
    String? companyName,
    bool? isGstRegistered,
    String? role,
    double? creditLimit,
    String? status,
    DateTime? createdAt,
    String? companyAddress,
    String? companyPhone,
    String? pocName,
    String? pocPhone,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      pan: pan ?? this.pan,
      gstNumber: gstNumber ?? this.gstNumber,
      userType: userType ?? this.userType,
      companyName: companyName ?? this.companyName,
      isGstRegistered: isGstRegistered ?? this.isGstRegistered,
      role: role ?? this.role,
      creditLimit: creditLimit ?? this.creditLimit,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      companyAddress: companyAddress ?? this.companyAddress,
      companyPhone: companyPhone ?? this.companyPhone,
      pocName: pocName ?? this.pocName,
      pocPhone: pocPhone ?? this.pocPhone,
    );
  }

  bool get isAdmin => role == 'admin';
  bool get isCustomer => role == 'customer';
  bool get isActive => status == 'active';
}
