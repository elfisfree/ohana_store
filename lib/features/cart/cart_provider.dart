// lib/features/cart/cart_provider.dart
import 'package:flutter/material.dart';
import 'package:ohana_store/main.dart';
import 'package:ohana_store/models/cart_item.dart';
import 'dart:async';

class CartProvider extends ChangeNotifier {
  // 1. ОБЪЯВЛЯЕМ СПИСОК (то чего не хватало)
  List<CartItem> _items = [];
  final Set<String> _selectedItemIds = {};
  bool _isLoading = true;
  String? _error;

  // Геттеры для UI
  List<CartItem> get items => _items;
  Set<String> get selectedItemIds => _selectedItemIds;
  bool get isLoading => _isLoading;
  String? get error => _error;

  CartProvider() {
    fetchCartItems();
  }

  // Расчет итоговой суммы
  double get selectedItemsTotalPrice {
    double total = 0.0;
    for (var item in _items) {
      if (_selectedItemIds.contains(item.id)) {
        total += item.product.price * item.quantity;
      }
    }
    return total;
  }

  // Загрузка корзины из Supabase
  Future<void> fetchCartItems() async {
    _isLoading = true;
    notifyListeners();

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        _items = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Загружаем связанные данные: товар, бренд и вариант цвета (для фото)
      final response = await supabase
          .from('cart_items')
          .select(
            '*, products(*, brands(*)), product_variants(*, product_stock(*))',
          )
          .eq('user_id', userId);

      _items = (response as List)
          .map((item) => CartItem.fromJson(item))
          .toList();
      _error = null;
    } catch (e) {
      _error = 'Не удалось загрузить корзину';
      print('Ошибка загрузки корзины: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- МЕТОД ОБНОВЛЕНИЯ КОЛИЧЕСТВА ---
  Future<void> updateQuantity(String cartItemId, int newQuantity) async {
    if (newQuantity < 1) return;

    try {
      // 1. Находим товар в локальном списке
      final index = _items.indexWhere((item) => item.id == cartItemId);
      if (index != -1) {
        // Создаем новый объект с измененным количеством
        final oldItem = _items[index];
        _items[index] = CartItem(
          id: oldItem.id,
          quantity: newQuantity,
          size: oldItem.size,
          product: oldItem.product,
          variant: oldItem.variant,
        );
        notifyListeners(); // Мгновенно обновляем UI
      }

      // 2. Отправляем обновление в базу
      await supabase
          .from('cart_items')
          .update({'quantity': newQuantity})
          .eq('id', cartItemId);
    } catch (e) {
      print('Ошибка обновления количества: $e');
      fetchCartItems(); // В случае ошибки перекачиваем данные из базы
    }
  }

  void toggleItemSelection(String cartItemId) {
    if (_selectedItemIds.contains(cartItemId)) {
      _selectedItemIds.remove(cartItemId);
    } else {
      _selectedItemIds.add(cartItemId);
    }
    notifyListeners();
  }

  Future<void> removeFromCart(String cartItemId) async {
    try {
      _items.removeWhere((item) => item.id == cartItemId);
      _selectedItemIds.remove(cartItemId);
      notifyListeners();
      await supabase.from('cart_items').delete().eq('id', cartItemId);
    } catch (e) {
      print('Ошибка удаления: $e');
      fetchCartItems();
    }
  }
}
