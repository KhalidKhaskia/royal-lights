class OrderItem {
  final String? id;
  final String? orderId;
  final String? itemNumber; // 1. Item Number (Barcode)
  final String name; // 2. Name
  final String? imageUrl; // 3. Image
  final int quantity; // 4. Quantity
  final String? extras; // 5. Extras
  final String? notes; // 6. Notes
  final double price; // 7. Price
  final bool assemblyRequired; // 8. Assembly Required
  final String? roomId; // 9. Room
  final String? supplierId; // 10. Supplier
  final bool existingInStore; // 11. Existing In Store
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
    this.assemblyRequired = false,
    this.roomId,
    this.supplierId,
    this.existingInStore = true,
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
      assemblyRequired: json['assembly_required'] as bool? ?? false,
      roomId: json['room_id'] as String?,
      supplierId: json['supplier_id'] as String?,
      existingInStore: json['existing_in_store'] as bool? ?? true,
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
    return {
      if (orderId != null) 'order_id': orderId,
      'item_number': itemNumber,
      'name': name,
      'image_url': imageUrl,
      'quantity': quantity,
      'extras': extras,
      'notes': notes,
      'price': price,
      'assembly_required': assemblyRequired,
      'room_id': roomId,
      'supplier_id': supplierId,
      'existing_in_store': existingInStore,
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
    bool? assemblyRequired,
    String? roomId,
    String? supplierId,
    bool? existingInStore,
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
      assemblyRequired: assemblyRequired ?? this.assemblyRequired,
      roomId: roomId ?? this.roomId,
      supplierId: supplierId ?? this.supplierId,
      existingInStore: existingInStore ?? this.existingInStore,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
