// lib/models/product.dart

class Brand {
  final String id;
  final String name;
  Brand({required this.id, required this.name});
  factory Brand.fromJson(Map<String, dynamic> json) =>
      Brand(id: json['id'] as String, name: json['name'] as String);
}

class ProductType {
  final String id;
  final String name;
  ProductType({required this.id, required this.name});
  factory ProductType.fromJson(Map<String, dynamic> json) =>
      ProductType(id: json['id'] as String, name: json['name'] as String);
}

class Style {
  final String id;
  final String name;
  Style({required this.id, required this.name});
  factory Style.fromJson(Map<String, dynamic> json) =>
      Style(id: json['id'] as String, name: json['name'] as String);
}

class MaterialModel {
  final String id;
  final String name;
  MaterialModel({required this.id, required this.name});
  factory MaterialModel.fromJson(Map<String, dynamic> json) =>
      MaterialModel(id: json['id'] as String, name: json['name'] as String);
}

class Tag {
  final String id;
  final String name;
  Tag({required this.id, required this.name});
  factory Tag.fromJson(Map<String, dynamic> json) =>
      Tag(id: json['id'] as String, name: json['name'] as String);
}

class StockItem {
  final String id;
  final double size;
  final int quantity;
  StockItem({required this.id, required this.size, required this.quantity});
  factory StockItem.fromJson(Map<String, dynamic> json) => StockItem(
    id: json['id'] as String,
    size: (json['size'] as num).toDouble(),
    quantity: json['quantity'] as int,
  );
}

class ProductVariant {
  final String id;
  final String colorName;
  final String? colorCode;
  final List<String> imageUrls;
  final List<StockItem> stock;

  ProductVariant({
    required this.id,
    required this.colorName,
    this.colorCode,
    required this.imageUrls,
    required this.stock,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'] as String,
      colorName: json['color_name'] as String,
      colorCode: json['color_code'] as String?,
      imageUrls: List<String>.from(json['image_urls'] ?? []),
      stock:
          (json['product_stock'] as List?)
              ?.map((s) => StockItem.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class Product {
  final String id;
  final String name;
  final String? description;
  final double price;
  final String? gender;
  final Brand? brand;
  final ProductType? productType;
  final Style? style;
  final MaterialModel? material;
  final List<Tag> tags;
  final double averageRating;
  final int reviewsCount;
  final List<ProductVariant> variants;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.gender,
    this.brand,
    this.productType,
    this.style,
    this.material,
    this.tags = const [],
    required this.averageRating,
    required this.reviewsCount,
    this.variants = const [],
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      gender: json['gender'] as String?,
      averageRating: (json['average_rating'] as num).toDouble(),
      reviewsCount: json['reviews_count'] as int,
      brand: json['brands'] != null ? Brand.fromJson(json['brands']) : null,
      productType: json['product_types'] != null
          ? ProductType.fromJson(json['product_types'])
          : null,
      style: json['styles'] != null ? Style.fromJson(json['styles']) : null,
      material: json['materials'] != null
          ? MaterialModel.fromJson(json['materials'])
          : null,
      tags:
          (json['product_tags'] as List?)
              ?.map((t) => Tag.fromJson(t['tags'] as Map<String, dynamic>))
              .toList() ??
          [],
      variants:
          (json['product_variants'] as List?)
              ?.map((v) => ProductVariant.fromJson(v as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
