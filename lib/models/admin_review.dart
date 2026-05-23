// lib/models/admin_review.dart
class AdminReview {
  final String id;
  final String reviewText;
  final String productName;
  final String productId;
  final DateTime createdAt;

  final String orderId;
  final double orderTotal;
  final String orderStatus;
  final int orderedSize;
  final String materialName;

  AdminReview({
    required this.id,
    required this.reviewText,
    required this.productName,
    required this.productId,
    required this.createdAt,
    required this.orderId,
    required this.orderTotal,
    required this.orderStatus,
    required this.orderedSize,
    required this.materialName,
  });

  factory AdminReview.fromJson(Map<String, dynamic> json) {
    final product = json['products'];
    final orderItem = json['order_items'];
    final order = orderItem['orders'];

    return AdminReview(
      id: json['id'],
      reviewText: json['review_text'] ?? '',
      productName: product['name'] ?? 'Неизвестный товар',
      productId: product['id'],
      createdAt: DateTime.parse(json['created_at']),
      orderId: order['id'],
      orderTotal: (order['final_price'] as num).toDouble(),
      orderStatus: order['status'],
      orderedSize: (orderItem['size'] as num).toInt(),
      materialName: product['materials']?['name'] ?? 'Не указан',
    );
  }
}
