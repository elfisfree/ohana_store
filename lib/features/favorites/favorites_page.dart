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
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            foregroundColor: Colors.black,
            centerTitle: true,
            title: const Text(
              'ИЗБРАННОЕ',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
                fontSize: 18,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
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
      return const Center(
        child: CircularProgressIndicator(color: Colors.black),
      );
    }

    final favoriteProducts = provider.favoriteProducts;
    if (favoriteProducts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.favorite_border_rounded,
                  size: 60,
                  color: Colors.black12,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'ПУСТО',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Сохраняйте товары, которые вам понравились, чтобы вернуться к ним позже.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: provider.fetchFavorites,
      color: Colors.black,
      child: GridView.builder(
        padding: const EdgeInsets.all(16.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.65,
        ),
        itemCount: favoriteProducts.length,
        itemBuilder: (context, index) {
          return ProductCard(product: favoriteProducts[index]);
        },
      ),
    );
  }
}
