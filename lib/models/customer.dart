class Customer {
  final String id;
  final String cardName;
  final String customerName;
  final List<String> phones;
  final String? location;
  final String? notes;
  final double remainingDebt;
  final String? imageUrl;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Customer({
    required this.id,
    required this.cardName,
    required this.customerName,
    this.phones = const [],
    this.location,
    this.notes,
    this.remainingDebt = 0,
    this.imageUrl,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      cardName: json['card_name'] as String,
      customerName: json['customer_name'] as String,
      phones: (json['phones'] as List<dynamic>?)?.cast<String>() ?? [],
      location: json['location'] as String?,
      notes: json['notes'] as String?,
      remainingDebt: 0,
      imageUrl: json['image_url'] as String?,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'card_name': cardName,
      'customer_name': customerName,
      'phones': phones,
      'location': location,
      'notes': notes,
      'image_url': imageUrl,
      'created_by': createdBy,
      'updated_by': updatedBy,
    };
  }

  Customer copyWith({
    String? id,
    String? cardName,
    String? customerName,
    List<String>? phones,
    String? location,
    String? notes,
    double? remainingDebt,
    String? imageUrl,
    String? createdBy,
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      cardName: cardName ?? this.cardName,
      customerName: customerName ?? this.customerName,
      phones: phones ?? this.phones,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      remainingDebt: remainingDebt ?? this.remainingDebt,
      imageUrl: imageUrl ?? this.imageUrl,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
