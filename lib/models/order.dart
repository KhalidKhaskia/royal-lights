import 'order_item.dart';

enum OrderStatus {
  active,
  preparing,
  inAssembly,
  awaitingShipping,
  handled,
  delivered,
  canceled,
}

extension OrderStatusExtension on OrderStatus {
  String get dbValue {
    switch (this) {
      case OrderStatus.active:
        return 'Active';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.inAssembly:
        return 'In Assembly';
      case OrderStatus.awaitingShipping:
        return 'Awaiting Shipping';
      case OrderStatus.handled:
        return 'Handled';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.canceled:
        return 'Canceled';
    }
  }

  static OrderStatus fromString(String value) {
    switch (value) {
      case 'Active':
        return OrderStatus.active;
      case 'Preparing':
        return OrderStatus.preparing;
      case 'In Assembly':
        return OrderStatus.inAssembly;
      case 'Awaiting Shipping':
        return OrderStatus.awaitingShipping;
      case 'Handled':
        return OrderStatus.handled;
      case 'Delivered':
        return OrderStatus.delivered;
      case 'Canceled':
        return OrderStatus.canceled;
      default:
        return OrderStatus.active;
    }
  }

  /// All statuses in display order (for filters and status change menu).
  static List<OrderStatus> get all => [
        OrderStatus.active,
        OrderStatus.preparing,
        OrderStatus.inAssembly,
        OrderStatus.awaitingShipping,
        OrderStatus.handled,
        OrderStatus.delivered,
        OrderStatus.canceled,
      ];
}

class Order {
  final String id;
  final String customerId;
  final int? orderNumber;
  final bool assemblyRequired;
  final DateTime? assemblyDate;
  final OrderStatus status;
  final double totalPrice;
  final String? notes;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined data
  final String? cardName;
  final String? customerName;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.customerId,
    this.orderNumber,
    this.assemblyRequired = false,
    this.assemblyDate,
    this.status = OrderStatus.active,
    this.totalPrice = 0,
    this.notes,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    this.cardName,
    this.customerName,
    this.items = const [],
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      orderNumber: json['order_number'] as int?,
      assemblyRequired: json['assembly_required'] as bool? ?? false,
      assemblyDate: json['assembly_date'] != null
          ? DateTime.parse(json['assembly_date'])
          : null,
      status: OrderStatusExtension.fromString(
        json['status'] as String? ?? 'Active',
      ),
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      cardName: json['customers'] != null
          ? json['customers']['card_name'] as String?
          : null,
      customerName: json['customers'] != null
          ? json['customers']['customer_name'] as String?
          : null,
      items: json['order_items'] != null
          ? (json['order_items'] as List)
                .map((e) => OrderItem.fromJson(e))
                .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customer_id': customerId,
      'assembly_required': assemblyRequired,
      'assembly_date': assemblyDate?.toIso8601String().split('T').first,
      'status': status.dbValue,
      'total_price': totalPrice,
      'notes': notes,
      'created_by': createdBy,
      'updated_by': updatedBy,
    };
  }

  Order copyWith({
    String? id,
    String? customerId,
    int? orderNumber,
    bool? assemblyRequired,
    DateTime? assemblyDate,
    OrderStatus? status,
    double? totalPrice,
    String? notes,
    String? createdBy,
    String? updatedBy,
    String? cardName,
    String? customerName,
    List<OrderItem>? items,
  }) {
    return Order(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      orderNumber: orderNumber ?? this.orderNumber,
      assemblyRequired: assemblyRequired ?? this.assemblyRequired,
      assemblyDate: assemblyDate ?? this.assemblyDate,
      status: status ?? this.status,
      totalPrice: totalPrice ?? this.totalPrice,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      cardName: cardName ?? this.cardName,
      customerName: customerName ?? this.customerName,
      items: items ?? this.items,
    );
  }
}
