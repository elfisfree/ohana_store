// lib/features/catalog/product_detail_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
// ignore: unused_import
import 'package:ohana_store/core/admin_theme.dart';
import 'package:ohana_store/core/utils/app_notifications.dart';
import 'package:ohana_store/main.dart';
import 'package:ohana_store/models/product.dart';

class ReviewDisplay {
  final double rating;
  final String? text;
  final DateTime createdAt;
  final String? userName;

  ReviewDisplay({
    required this.rating,
    this.text,
    required this.createdAt,
    this.userName,
  });

  factory ReviewDisplay.fromJson(Map<String, dynamic> json) {
    return ReviewDisplay(
      rating: (json['rating'] as num).toDouble(),
      text: json['review_text'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      userName: json['user_full_name'] as String? ?? 'Аноним',
    );
  }
}

class ProductDetailPage extends StatefulWidget {
  final String productId;
  final bool isAdmin;

  const ProductDetailPage({
    super.key,
    required this.productId,
    this.isAdmin = false,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late final Future<(Product, List<ReviewDisplay>)> _dataFuture;
  int _selectedVariantIndex = 0;
  double? _selectedSize;
  int _currentPageIndex = 0;
  bool _isAddingToCart = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetchProductData();
  }

  Future<(Product, List<ReviewDisplay>)> _fetchProductData() async {
    try {
      final results = await Future.wait<dynamic>([
        supabase
            .from('products')
            .select('''
            *,
            brands(*),
            product_types(*),
            styles(*),
            materials(*),
            product_tags(tags(*)),
            product_variants(
              *,
              product_stock(*)
            )
          ''')
            .eq('id', widget.productId)
            .single(),

        supabase
            .from('reviews_with_users')
            .select()
            .eq('product_id', widget.productId)
            .eq('status', 'approved')
            .order('created_at', ascending: false),
      ]);

      final product = Product.fromJson(results[0] as Map<String, dynamic>);
      final reviews = (results[1] as List)
          .map((r) => ReviewDisplay.fromJson(r as Map<String, dynamic>))
          .toList();

      return (product, reviews);
    } catch (e) {
      print('Ошибка при загрузке данных товара: $e');
      throw Exception('Не удалось загрузить товар');
    }
  }

  Future<void> _addToCart(Product product) async {
    if (_selectedSize == null) {
      AppNotifications.showError(context, 'Пожалуйста, выберите размер');
      return;
    }

    final currentVariant = product.variants[_selectedVariantIndex];

    setState(() => _isAddingToCart = true);
    try {
      final userId = supabase.auth.currentUser!.id;

      await supabase.from('cart_items').insert({
        'user_id': userId,
        'product_id': product.id,
        'variant_id': currentVariant.id,
        'quantity': 1,
        'size': _selectedSize,
      });

      if (mounted) {
        AppNotifications.showSuccess(context, 'Товар добавлен в корзину!');
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.showError(context, 'Этот товар уже в вашей корзине');
      }
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: FutureBuilder<(Product, List<ReviewDisplay>)>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }

          final (product, reviews) = snapshot.data!;
          if (product.variants.isEmpty) {
            return const Center(
              child: Text('У товара нет доступных вариантов'),
            );
          }
          final currentVariant = product.variants[_selectedVariantIndex];

          final f = NumberFormat.currency(
            locale: 'ru_RU',
            symbol: '₽',
            decimalDigits: 0,
          );

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (currentVariant.imageUrls.isNotEmpty)
                        SizedBox(
                          height: 350,
                          child: PageView.builder(
                            key: ValueKey(currentVariant.id),
                            onPageChanged: (index) =>
                                setState(() => _currentPageIndex = index),
                            itemCount: currentVariant.imageUrls.length,
                            itemBuilder: (context, index) => Image.network(
                              currentVariant.imageUrls[index],
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      if (currentVariant.imageUrls.length > 1)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            currentVariant.imageUrls.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: 6,
                              width: _currentPageIndex == index ? 20 : 6,
                              decoration: BoxDecoration(
                                color: _currentPageIndex == index
                                    ? Colors.black
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 20),
                      if (product.variants.length > 1) ...[
                        const Text(
                          'ЦВЕТ',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 50,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: product.variants.length,
                            itemBuilder: (context, index) {
                              final variant = product.variants[index];
                              final bool isSelected =
                                  _selectedVariantIndex == index;
                              return GestureDetector(
                                onTap: () => setState(() {
                                  _selectedVariantIndex = index;
                                  _selectedSize = null;
                                  _currentPageIndex = 0;
                                }),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.black
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    variant.colorName.toUpperCase(),
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      Text(
                        product.brand?.name.toUpperCase() ?? '',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            f.format(product.price),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          if (product.reviewsCount > 0)
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${product.averageRating.toStringAsFixed(1)} (${product.reviewsCount})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      if (product.tags.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          children: product.tags
                              .map(
                                (tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '#${tag.name}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],

                      const Divider(height: 40),
                      const Text(
                        'ВЫБЕРИТЕ РАЗМЕР',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: currentVariant.stock.map((stockItem) {
                          final bool isSelected =
                              _selectedSize == stockItem.size;
                          final bool isOutOfStock = stockItem.quantity <= 0;

                          return ChoiceChip(
                            label: Text(
                              stockItem.size.toString().replaceAll('.0', ''),
                              style: TextStyle(
                                color: isOutOfStock
                                    ? Colors.grey
                                    : (isSelected
                                          ? Colors.white
                                          : Colors.black),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: isOutOfStock
                                ? null
                                : (selected) {
                                    setState(
                                      () => _selectedSize = selected
                                          ? stockItem.size
                                          : null,
                                    );
                                  },
                            showCheckmark: false,
                            selectedColor: Colors.black,
                            backgroundColor: Colors.white,
                            disabledColor: Colors.grey.shade100,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.black
                                    : (isOutOfStock
                                          ? Colors.transparent
                                          : Colors.grey.shade300),
                                width: 2,
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      if (currentVariant.stock.isEmpty)
                        const Text(
                          'Размеры отсутствуют',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),

                      const SizedBox(height: 30),
                      const Text(
                        'ХАРАКТЕРИСТИКИ',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _specRow(
                        'Материал',
                        product.material?.name ?? 'Не указан',
                      ),
                      _specRow('Стиль', product.style?.name ?? 'Не указан'),
                      _specRow(
                        'Пол',
                        product.gender == 'male'
                            ? 'Мужской'
                            : product.gender == 'female'
                            ? 'Женский'
                            : 'Унисекс',
                      ),

                      const SizedBox(height: 30),
                      const Text(
                        'ОПИСАНИЕ',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        product.description ?? 'Описание отсутствует.',
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Colors.black87,
                        ),
                      ),

                      const Divider(height: 60),
                      Text(
                        'ОТЗЫВЫ (${reviews.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (reviews.isEmpty)
                        const Text('Отзывов пока нет. Будьте первым!')
                      else
                        ...reviews.map(
                          (review) => Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      review.userName ?? 'Аноним',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      DateFormat(
                                        'dd.MM.yyyy',
                                      ).format(review.createdAt),
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                RatingBarIndicator(
                                  rating: review.rating,
                                  itemBuilder: (context, index) => const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                  ),
                                  itemCount: 5,
                                  itemSize: 14,
                                ),
                                if (review.text != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    review.text!,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              if (!widget.isAdmin)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isAddingToCart
                        ? null
                        : () => _addToCart(product),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: _isAddingToCart
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'ДОБАВИТЬ В КОРЗИНУ',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _specRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
