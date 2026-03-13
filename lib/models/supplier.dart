class Supplier {
  final String id;
  final String companyName;
  final String? contactName;
  final String? phone;
  final String? notes;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Supplier({
    required this.id,
    required this.companyName,
    this.contactName,
    this.phone,
    this.notes,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'] as String,
      companyName: json['company_name'] as String,
      contactName: json['contact_name'] as String?,
      phone: json['phone'] as String?,
      notes: json['notes'] as String?,
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
      'company_name': companyName,
      'contact_name': contactName,
      'phone': phone,
      'notes': notes,
      'created_by': createdBy,
      'updated_by': updatedBy,
    };
  }

  Supplier copyWith({
    String? id,
    String? companyName,
    String? contactName,
    String? phone,
    String? notes,
    String? createdBy,
    String? updatedBy,
  }) {
    return Supplier(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      contactName: contactName ?? this.contactName,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
