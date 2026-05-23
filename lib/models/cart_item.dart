// lib/models/cart_item.dart
import 'package:ohana_store/models/product.dart';

class CartItem {
  final String id;
  final int quantity;
  final double size;
  final Product product;
  final ProductVariant? variant;

  CartItem({
    required this.id,
    required this.quantity,
    required this.size,
    required this.product,
    this.variant,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] as String,
      quantity: json['quantity'] as int,
      size: (json['size'] as num).toDouble(),
      product: Product.fromJson(json['products'] as Map<String, dynamic>),
      variant: json['product_variants'] != null
          ? ProductVariant.fromJson(
              json['product_variants'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}
