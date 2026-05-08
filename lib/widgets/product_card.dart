// lib/widgets/product_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ohana_store/features/favorites/favorites_provider.dart';
import 'package:ohana_store/models/product.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  // Вспомогательный виджет для очень компактного отображения размеров
  Widget _buildSizes() {
    final sortedSizes = List<int>.from(product.availableSizes)..sort();
    // Показываем только первые 4 размера, чтобы не раздувать карточку
    final displaySizes = sortedSizes.take(4).toList();

    return Wrap(
      spacing: 4,
      children: displaySizes
          .map(
            (size) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                size.toString(),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₽',
      decimalDigits: 0,
    );

    return GestureDetector(
      onTap: () => context.push('/product/${product.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- БЛОК С ИЗОБРАЖЕНИЕМ ---
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: AspectRatio(
                    aspectRatio: 1, // Квадратное фото
                    child: product.imageUrls.isNotEmpty
                        ? Image.network(
                            product.imageUrls.first,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.hide_image_outlined),
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.hide_image_outlined),
                          ),
                  ),
                ),
                // Кнопка избранного
                Positioned(
                  top: 8,
                  right: 8,
                  child: Consumer<FavoritesProvider>(
                    builder: (context, favoritesProvider, child) {
                      final isFav = favoritesProvider.isFavorite(product.id);
                      return Container(
                        height: 36,
                        width: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            color: isFav ? Colors.red : Colors.black87,
                            size: 20,
                          ),
                          onPressed: () => favoritesProvider.toggleFavorite(
                            product.id,
                            product,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            // --- ИНФОРМАЦИОННЫЙ БЛОК ---
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.brand != null)
                    Text(
                      product.brand!.name.toUpperCase(),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 9,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Рейтинг
                  if (product.reviewsCount > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        RatingBarIndicator(
                          rating: product.averageRating,
                          itemBuilder: (context, index) => const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                          ),
                          itemCount: 5,
                          itemSize: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${product.reviewsCount})',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // ТЕГИ (Максимум 3)
                  if (product.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 4,
                        children: product.tags
                            .take(3)
                            .map(
                              (tag) => Text(
                                '#${tag.name}',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),

                  const SizedBox(height: 8),

                  // РАЗМЕРЫ (Компактные)
                  if (product.availableSizes.isNotEmpty) _buildSizes(),

                  const SizedBox(height: 10),

                  // ЦЕНА
                  Text(
                    currencyFormatter.format(product.price),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
