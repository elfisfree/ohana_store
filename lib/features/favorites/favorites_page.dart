// lib/features/favorites/favorites_page.dart
import 'package:flutter/material.dart';
import 'package:ohana_store/widgets/product_card.dart';
import 'package:provider/provider.dart';
import 'package:ohana_store/features/favorites/favorites_provider.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesProvider>(
      builder: (context, favoritesProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Избранное'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => favoritesProvider.fetchFavorites(),
              ),
            ],
          ),
          body: _buildContent(context, favoritesProvider),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, FavoritesProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final favoriteProducts = provider.favoriteProducts;

    if (favoriteProducts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'У вас пока нет избранных товаров',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.6,
      ),
      itemCount: favoriteProducts.length,
      itemBuilder: (context, index) {
        return ProductCard(product: favoriteProducts[index]);
      },
    );
  }
}
