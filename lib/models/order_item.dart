int _warrantyYearsFromJson(dynamic value) {
  final n = (value as num?)?.toInt();
  if (n == 3) return 3;
  if (n == 5) return 5;
  return 0;
}

class OrderItem {
  final String? id;
  final String? orderId;
  final String? itemNumber; // 1. Item Number (Barcode)
  final String name; // 2. Name
  final String? imageUrl; // 3. Image
  final int quantity; // 4. Quantity
  final String? extras; // 5. Extras
  final String? notes; // 6. Notes (optional; order form may omit)
  final double price; // 7. Unit price
  /// Add-ons price per unit (scales with quantity).
  final double extrasPrice;
  final bool assemblyRequired; // 8. Assembly Required
  final String? roomId; // 9. Room (legacy FK; optional when room_name is set)
  /// Persisted free-text room (column `room_name`).
  final String? roomLabel;
  final String? supplierId; // 10. Supplier
  /// Planned or actual delivery / shipping date for this line.
  final DateTime? deliveryDate;
  final bool existingInStore; // 11. Existing In Store
  /// Confirmed received from supplier (partial order fulfillment).
  final bool supplierReceived;
  /// 0 = none, 3 = three-year, 5 = five-year warranty.
  final int warrantyYears;
  /// When warranty starts counting (usually delivery date once it begins).
  final DateTime? warrantyStartDate;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined data (not persisted)
  final String? roomName;
  final String? supplierName;
  final String? supplierPhone;

  OrderItem({
    this.id,
    this.orderId,
    this.itemNumber,
    required this.name,
    this.imageUrl,
    this.quantity = 1,
    this.extras,
    this.notes,
    this.price = 0,
    this.extrasPrice = 0,
    this.assemblyRequired = false,
    this.roomId,
    this.roomLabel,
    this.supplierId,
    this.deliveryDate,
    this.existingInStore = false,
    this.supplierReceived = false,
    this.warrantyYears = 0,
    this.warrantyStartDate,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    this.roomName,
    this.supplierName,
    this.supplierPhone,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String?,
      orderId: json['order_id'] as String?,
      itemNumber: json['item_number'] as String?,
      name: json['name'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      quantity: json['quantity'] as int? ?? 1,
      extras: json['extras'] as String?,
      notes: json['notes'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      extrasPrice: (json['extras_price'] as num?)?.toDouble() ?? 0,
      assemblyRequired: json['assembly_required'] as bool? ?? false,
      roomId: json['room_id'] as String?,
      roomLabel: json['room_name'] as String?,
      supplierId: json['supplier_id'] as String?,
      deliveryDate: json['delivery_date'] != null
          ? DateTime.parse(json['delivery_date'] as String)
          : null,
      existingInStore: json['existing_in_store'] as bool? ?? false,
      supplierReceived: json['supplier_received'] as bool? ?? false,
      warrantyYears: _warrantyYearsFromJson(json['warranty_years']),
      warrantyStartDate: json['warranty_start_date'] != null
          ? DateTime.parse(json['warranty_start_date'] as String)
          : null,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      roomName: json['rooms'] != null ? json['rooms']['name'] as String? : null,
      supplierName: json['suppliers'] != null
          ? json['suppliers']['company_name'] as String?
          : null,
      supplierPhone: json['suppliers'] != null
          ? json['suppliers']['phone'] as String?
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final roomLabelTrimmed = roomLabel?.trim();
    return {
      if (orderId != null) 'order_id': orderId,
      'item_number': itemNumber,
      'name': name,
      'image_url': imageUrl,
      'quantity': quantity,
      'extras': extras,
      'notes': notes,
      'price': price,
      'extras_price': extrasPrice,
      'assembly_required': assemblyRequired,
      'room_id': roomId,
      'room_name':
          (roomLabelTrimmed != null && roomLabelTrimmed.isNotEmpty)
              ? roomLabelTrimmed
              : null,
      'supplier_id': supplierId,
      'delivery_date': deliveryDate?.toIso8601String().split('T').first,
      'existing_in_store': existingInStore,
      'supplier_received': supplierReceived || existingInStore,
      'warranty_years': warrantyYears,
      'warranty_start_date': warrantyStartDate?.toIso8601String().split('T').first,
      'created_by': createdBy,
      'updated_by': updatedBy,
    };
  }

  OrderItem copyWith({
    String? id,
    String? orderId,
    String? itemNumber,
    String? name,
    String? imageUrl,
    int? quantity,
    String? extras,
    String? notes,
    double? price,
    double? extrasPrice,
    bool? assemblyRequired,
    String? roomId,
    String? roomLabel,
    String? supplierId,
    DateTime? deliveryDate,
    bool? existingInStore,
    bool? supplierReceived,
    int? warrantyYears,
    DateTime? warrantyStartDate,
    String? createdBy,
    String? updatedBy,
  }) {
    return OrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      itemNumber: itemNumber ?? this.itemNumber,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      quantity: quantity ?? this.quantity,
      extras: extras ?? this.extras,
      notes: notes ?? this.notes,
      price: price ?? this.price,
      extrasPrice: extrasPrice ?? this.extrasPrice,
      assemblyRequired: assemblyRequired ?? this.assemblyRequired,
      roomId: roomId ?? this.roomId,
      roomLabel: roomLabel ?? this.roomLabel,
      supplierId: supplierId ?? this.supplierId,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      existingInStore: existingInStore ?? this.existingInStore,
      supplierReceived: supplierReceived ?? this.supplierReceived,
      warrantyYears: warrantyYears ?? this.warrantyYears,
      warrantyStartDate: warrantyStartDate ?? this.warrantyStartDate,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
