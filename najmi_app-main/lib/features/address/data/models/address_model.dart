class AddressModel {
  final String id;
  final String userId;
  final String fullAddress;
  final String label; // Home, Office, etc.
  final String streetAddress;
  final String landmark;
  final String city;
  final String state;
  final String pincode;
  final String? buildingName;
  final String? flatNumber;
  final String? floorNumber;
  final bool isDefault;
  final DateTime createdAt;

  AddressModel({
    required this.id,
    required this.userId,
    required this.fullAddress,
    required this.label,
    required this.streetAddress,
    required this.landmark,
    required this.city,
    required this.state,
    required this.pincode,
    this.buildingName,
    this.flatNumber,
    this.floorNumber,
    required this.isDefault,
    required this.createdAt,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id'],
      userId: json['user_id'],
      fullAddress: json['address'],
      label: json['label'] ?? 'Other',
      streetAddress: json['street_address'] ?? '',
      landmark: json['landmark'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      pincode: json['pincode'] ?? '',
      buildingName: json['building_name'],
      flatNumber: json['flat_number'],
      floorNumber: json['floor_number'],
      isDefault: json['is_default'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'address': fullAddress,
      'label': label,
      'is_default': isDefault,
      'created_at': createdAt.toIso8601String(),
    };
  }

  AddressModel copyWith({
    String? id,
    String? userId,
    String? fullAddress,
    String? label,
    String? streetAddress,
    String? landmark,
    String? city,
    String? state,
    String? pincode,
    String? buildingName,
    String? flatNumber,
    String? floorNumber,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return AddressModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullAddress: fullAddress ?? this.fullAddress,
      label: label ?? this.label,
      streetAddress: streetAddress ?? this.streetAddress,
      landmark: landmark ?? this.landmark,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      buildingName: buildingName ?? this.buildingName,
      flatNumber: flatNumber ?? this.flatNumber,
      floorNumber: floorNumber ?? this.floorNumber,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
