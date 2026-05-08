// lib/models/cart_item.dart
import 'package:ohana_store/models/product.dart';

class CartItem {
  final String id;
  final int quantity;
  final int size;
  final Product product;

  CartItem({
    required this.id,
    required this.quantity,
    required this.size,
    required this.product,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] as String,
      quantity: json['quantity'] as int,
      size: (json['size'] as num).toInt(),
      product: Product.fromJson(json['products']),
    );
  }
}
