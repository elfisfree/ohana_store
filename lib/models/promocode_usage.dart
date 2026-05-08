// lib/models/promocode_usage.dart
class PromocodeUsage {
  final String orderId;
  final String? customerName;
  final DateTime usedAt;

  PromocodeUsage({
    required this.orderId,
    this.customerName,
    required this.usedAt,
  });

  factory PromocodeUsage.fromJson(Map<String, dynamic> json) {
    return PromocodeUsage(
      orderId: json['order_id'],
      customerName: json['customer_name'] ?? 'Неизвестный',
      usedAt: DateTime.parse(json['used_at']),
    );
  }
}
