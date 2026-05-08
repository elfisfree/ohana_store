import 'package:ohana_store/models/product.dart';

class Promocode {
  final String id;
  final String code;
  final String? description;
  final double discountPercentage;
  final double? minOrderAmount;
  final DateTime validFrom;
  final DateTime? validTo;
  final bool isActive;
  final int? usageLimit;
  final List<ProductType> applicableProductTypes;

  Promocode({
    required this.id,
    required this.code,
    this.description,
    required this.discountPercentage,
    this.minOrderAmount,
    required this.validFrom,
    this.validTo,
    required this.isActive,
    this.usageLimit,
    this.applicableProductTypes = const [],
  });

  factory Promocode.fromJson(Map<String, dynamic> json) {
    return Promocode(
      id: json['id'],
      code: json['code'],
      description: json['description'],
      discountPercentage: (json['discount_percentage'] as num).toDouble(),
      minOrderAmount: (json['min_order_amount'] as num?)?.toDouble(),
      validFrom: DateTime.parse(json['valid_from']),
      validTo: json['valid_to'] != null
          ? DateTime.parse(json['valid_to'])
          : null,
      isActive: json['is_active'],
      usageLimit: json['usage_limit'],
      applicableProductTypes:
          (json['product_types'] as List<dynamic>?)
              ?.map((pt) => ProductType.fromJson(pt))
              .toList() ??
          [],
    );
  }
}
