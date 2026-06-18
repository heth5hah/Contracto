class AdminUser {
  final String id;
  final String email;
  final String? role;
  final DateTime createdAt;

  final String? name;
  final String? phone;
  final String? companyName;
  final String userType; // 'business' or 'individual' or 'company'
  final int ordersCount;
  final double totalSpent;
  final String status; // 'active' or 'inactive'
  final bool isEnabled;
  
  // Credit fields for business users
  final double? creditLimit;
  final double? availableCredit;
  final double? usedCredit;
  final String? kycStatus;
  final String? creditAccountStatus;

  // KYC details
  final String? companyAddress;
  final String? companyPhone;
  final String? pocName;
  final String? pocPhone;
  final String? gstNumber;
  final String? panNumber;
  final bool isGstRegistered;

  AdminUser({
    required this.id,
    required this.email,
    this.role,
    required this.createdAt,
    this.name,
    this.phone,
    this.companyName,
    this.userType = 'individual',
    this.ordersCount = 0,
    this.totalSpent = 0.0,
    this.status = 'active',
    this.isEnabled = true,
    this.creditLimit,
    this.availableCredit,
    this.usedCredit,
    this.kycStatus,
    this.creditAccountStatus,
    this.companyAddress,
    this.companyPhone,
    this.pocName,
    this.pocPhone,
    this.gstNumber,
    this.panNumber,
    this.isGstRegistered = false,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    final userType = json['user_type']?.toString().toLowerCase() ?? 'individual';
    final companyName = json['company_name']?.toString();
    final isBusiness = userType == 'business' || 
                      userType == 'company' || 
                      (companyName != null && companyName.trim().isNotEmpty) ||
                      json['is_business'] == true;
    
    // Parse credit data from joined business_credit_accounts
    final creditData = json['business_credit_accounts'];
    double? creditLimit;
    double? availableCredit;
    double? usedCredit;
    String? kycStatus;
    String? creditAccountStatus;
    
    if (creditData != null) {
      if (creditData is List && creditData.isNotEmpty) {
        final credit = creditData.first;
        creditLimit = (credit['credit_limit'] as num?)?.toDouble();
        availableCredit = (credit['available_credit'] as num?)?.toDouble();
        usedCredit = (credit['used_credit'] as num?)?.toDouble();
        kycStatus = credit['kyc_status']?.toString();
        creditAccountStatus = credit['status']?.toString();
      } else if (creditData is Map) {
        creditLimit = (creditData['credit_limit'] as num?)?.toDouble();
        availableCredit = (creditData['available_credit'] as num?)?.toDouble();
        usedCredit = (creditData['used_credit'] as num?)?.toDouble();
        kycStatus = creditData['kyc_status']?.toString();
        creditAccountStatus = creditData['status']?.toString();
      }
    }
    
    return AdminUser(
      id: json['id'],
      email: json['email'] ?? '',
      role: json['role'] ?? 'customer',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      name: json['name'] ?? json['full_name'] ?? json['email']?.toString().split('@')[0] ?? 'Unknown',
      phone: json['phone'] ?? json['mobile'],
      companyName: json['company_name'],
      userType: isBusiness ? 'business' : 'individual',
      ordersCount: json['orders_count'] ?? 0,
      totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString().toLowerCase() ?? 'active',
      isEnabled: json['is_enabled'] ?? json['status']?.toString().toLowerCase() == 'active',
      creditLimit: creditLimit,
      availableCredit: availableCredit,
      usedCredit: usedCredit,
      kycStatus: kycStatus,
      creditAccountStatus: creditAccountStatus,
      companyAddress: json['company_address']?.toString(),
      companyPhone: json['company_phone']?.toString(),
      pocName: json['poc_name']?.toString(),
      pocPhone: json['poc_phone']?.toString(),
      gstNumber: json['gst_number']?.toString(),
      panNumber: json['pan_number']?.toString() ?? json['pan']?.toString(),
      isGstRegistered: json['is_gst_registered'] ?? false,
    );
  }

  bool get isBusiness => userType == 'business' || userType == 'company';
}
