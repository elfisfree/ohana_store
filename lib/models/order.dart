// lib/models/order.dart
import 'package:ohana_store/models/product.dart';

class OrderItem {
  final String id;
  final int quantity;
  final double size;
  final double priceAtPurchase;
  final Product product;
  final ProductVariant? variant;

  OrderItem({
    required this.id,
    required this.quantity,
    required this.size,
    required this.priceAtPurchase,
    required this.product,
    this.variant,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      quantity: json['quantity'] as int,
      size: (json['size'] as num).toDouble(),
      priceAtPurchase: (json['price_at_purchase'] as num).toDouble(),
      product: Product.fromJson(json['products'] as Map<String, dynamic>),
      variant: json['product_variants'] != null
          ? ProductVariant.fromJson(
              json['product_variants'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class Order {
  final String id;
  final DateTime createdAt;
  final double totalPrice;
  final String status;
  final String deliveryMethod;
  final String? shippingAddress;
  final double deliveryCost;
  final List<OrderItem> items;
  final double discountAmount;
  final double finalPrice;
  final String paymentStatus;
  final DateTime? expiresAt;
  final DateTime? deliveredAt;

  Order({
    required this.id,
    required this.createdAt,
    required this.totalPrice,
    required this.status,
    required this.deliveryMethod,
    this.shippingAddress,
    required this.deliveryCost,
    this.items = const [],
    required this.discountAmount,
    required this.finalPrice,
    required this.paymentStatus,
    this.expiresAt,
    this.deliveredAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      totalPrice: (json['total_price'] as num).toDouble(),
      status: json['status'] as String,
      deliveryMethod: json['delivery_method'] as String,
      shippingAddress: json['shipping_address'] as String?,
      deliveryCost: (json['delivery_cost'] as num).toDouble(),
      items:
          (json['order_items'] as List<dynamic>?)
              ?.map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      discountAmount: (json['discount_amount'] as num).toDouble(),
      finalPrice: (json['final_price'] as num).toDouble(),
      paymentStatus: json['payment_status'] ?? 'pending',
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'])
          : null,
    );
  }
}
