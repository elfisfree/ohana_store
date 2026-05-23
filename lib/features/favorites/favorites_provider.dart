// lib/features/favorites/favorites_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ohana_store/main.dart';
import 'package:ohana_store/models/product.dart';

class FavoritesProvider extends ChangeNotifier {
  Set<String> _favoriteProductIds = {};
  List<Product> _favoriteProducts = [];
  bool _isLoading = true;

  Set<String> get favoriteProductIds => _favoriteProductIds;
  List<Product> get favoriteProducts => _favoriteProducts;
  bool get isLoading => _isLoading;

  FavoritesProvider() {
    _init();
  }

  void _init() {
    supabase.auth.onAuthStateChange.listen((data) {
      fetchFavorites();
    });
    fetchFavorites();
  }

  bool isFavorite(String productId) {
    return _favoriteProductIds.contains(productId);
  }

  Future<void> fetchFavorites() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      _favoriteProductIds = {};
      _favoriteProducts = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await supabase
          .from('favorites')
          .select('''
            product_id, 
            products(
              *, 
              brands(*), 
              product_types(*), 
              styles(*), 
              materials(*), 
              product_tags(tags(*)),
              product_variants(*, product_stock(*))
            )
          ''')
          .eq('user_id', user.id);

      final List<dynamic> data = response as List;
      _favoriteProductIds = data
          .map<String>((item) => item['product_id'] as String)
          .toSet();
      _favoriteProducts = data
          .where((item) => item['products'] != null)
          .map<Product>((item) => Product.fromJson(item['products']))
          .toList();

      _isLoading = false;
    } catch (e) {
      print('Ошибка загрузки избранного: $e');
      _isLoading = false;
    } finally {
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(String productId, Product? productData) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    if (productData == null && _favoriteProductIds.contains(productId)) {
      productData = _favoriteProducts.firstWhere((p) => p.id == productId);
    }

    if (productData == null) return;

    final isCurrentlyFavorite = isFavorite(productId);
    if (isCurrentlyFavorite) {
      _favoriteProductIds.remove(productId);
      _favoriteProducts.removeWhere((p) => p.id == productId);
    } else {
      _favoriteProductIds.add(productId);
      _favoriteProducts.insert(0, productData);
    }
    notifyListeners();

    try {
      if (isCurrentlyFavorite) {
        await supabase.from('favorites').delete().match({
          'user_id': user.id,
          'product_id': productId,
        });
      } else {
        await supabase.from('favorites').insert({
          'user_id': user.id,
          'product_id': productId,
        });
      }
    } catch (e) {
      print('Ошибка при изменении избранного в БД: $e');
      fetchFavorites();
    }
  }
}
