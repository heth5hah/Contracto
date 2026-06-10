class EnquiryModel {
  final String id;
  final String userId;
  final String productName;
  final String? category;
  final String message;
  final String? contactEmail;
  final String? contactPhone;
  final String status; // 'pending', 'contacted', 'resolved', 'closed'
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  EnquiryModel({
    required this.id,
    required this.userId,
    required this.productName,
    this.category,
    required this.message,
    this.contactEmail,
    this.contactPhone,
    this.status = 'pending',
    this.adminNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  // Helper getters
  bool get isPending => status == 'pending';
  bool get isContacted => status == 'contacted';
  bool get isResolved => status == 'resolved';
  bool get isClosed => status == 'closed';

  factory EnquiryModel.fromJson(Map<String, dynamic> json) {
    return EnquiryModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      productName: json['product_name'] as String,
      category: json['category'] as String?,
      message: json['message'] as String,
      contactEmail: json['contact_email'] as String?,
      contactPhone: json['contact_phone'] as String?,
      status: json['status'] as String? ?? 'pending',
      adminNotes: json['admin_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'product_name': productName,
      'category': category,
      'message': message,
      'contact_email': contactEmail,
      'contact_phone': contactPhone,
      'status': status,
      'admin_notes': adminNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Helper method for creating new enquiry (without id and timestamps)
  Map<String, dynamic> toCreateJson() {
    return {
      'user_id': userId,
      'product_name': productName,
      'category': category,
      'message': message,
      'contact_email': contactEmail,
      'contact_phone': contactPhone,
      'status': 'pending',
    };
  }

  EnquiryModel copyWith({
    String? id,
    String? userId,
    String? productName,
    String? category,
    String? message,
    String? contactEmail,
    String? contactPhone,
    String? status,
    String? adminNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EnquiryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      productName: productName ?? this.productName,
      category: category ?? this.category,
      message: message ?? this.message,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      status: status ?? this.status,
      adminNotes: adminNotes ?? this.adminNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EnquiryModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
