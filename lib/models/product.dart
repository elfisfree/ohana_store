// lib/models/product.dart

class Style {
  final String id;
  final String name;
  Style({required this.id, required this.name});
  factory Style.fromJson(Map<String, dynamic> json) =>
      Style(id: json['id'], name: json['name']);
}

class MaterialModel {
  // Назвал так, чтобы не путать с Material в Flutter
  final String id;
  final String name;
  MaterialModel({required this.id, required this.name});
  factory MaterialModel.fromJson(Map<String, dynamic> json) =>
      MaterialModel(id: json['id'], name: json['name']);
}

class Tag {
  final String id;
  final String name;
  Tag({required this.id, required this.name});
  factory Tag.fromJson(Map<String, dynamic> json) =>
      Tag(id: json['id'], name: json['name']);
}

class Brand {
  final String id;
  final String name;

  Brand({required this.id, required this.name});

  factory Brand.fromJson(Map<String, dynamic> json) {
    return Brand(id: json['id'] as String, name: json['name'] as String);
  }
}

class ProductType {
  final String id;
  final String name;

  ProductType({required this.id, required this.name});

  factory ProductType.fromJson(Map<String, dynamic> json) {
    return ProductType(id: json['id'] as String, name: json['name'] as String);
  }
}

class Product {
  final String id;
  final String name;
  final String? description;
  final double price;
  final List<String> imageUrls;
  final List<int> availableSizes;
  final String? gender;
  final Brand? brand;
  final ProductType? productType;
  final double averageRating;
  final int reviewsCount;
  final Style? style;
  final MaterialModel? material;
  final List<Tag> tags;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.imageUrls,
    required this.availableSizes,
    this.gender,
    this.brand,
    this.productType,
    this.style,
    this.material,
    this.tags = const [],
    required this.averageRating,
    required this.reviewsCount,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      imageUrls: List<String>.from(json['image_urls'] ?? []),
      availableSizes: List<int>.from(
        (json['available_sizes'] as List<dynamic>?)?.map(
              (e) => e is int ? e : int.parse(e.toString()),
            ) ??
            [],
      ),
      gender: json['gender'] as String?,
      brand: json['brands'] != null ? Brand.fromJson(json['brands']) : null,
      productType: json['product_types'] != null
          ? ProductType.fromJson(json['product_types'])
          : null,
      averageRating: (json['average_rating'] as num).toDouble(),
      reviewsCount: json['reviews_count'] as int,
      style: json['styles'] != null ? Style.fromJson(json['styles']) : null,
      material: json['materials'] != null
          ? MaterialModel.fromJson(json['materials'])
          : null,
      tags:
          (json['product_tags'] as List?)
              ?.map((t) => Tag.fromJson(t['tags']))
              .toList() ??
          [],
    );
  }
}
