// lib/features/admin/admin_products_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ohana_store/core/admin_theme.dart'; // Импортируем ваши цвета
import 'package:ohana_store/core/utils/app_notifications.dart';
import 'package:ohana_store/features/catalog/catalog_provider.dart';
import 'package:ohana_store/main.dart';
import 'package:ohana_store/widgets/filter_bottom_sheet.dart';
import 'package:provider/provider.dart';

class AdminProductsPage extends StatelessWidget {
  const AdminProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CatalogProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: Colors.transparent, // Фон задан в AdminDesktopShell
          body: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- ВЕРХНЯЯ ПАНЕЛЬ: ЗАГОЛОВОК И КНОПКА ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'СПИСОК ТОВАРОВ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/admin/products/new'),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('ДОБАВИТЬ ТОВАР'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminColors.accentBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),

                // --- ПАНЕЛЬ ИНСТРУМЕНТОВ: ПОИСК И ФИЛЬТРЫ ---
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (query) =>
                            provider.onSearchQueryChanged(query),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Поиск по названию или артикулу...',
                          hintStyle: const TextStyle(color: Colors.white24),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: AdminColors.accentBlue,
                          ),
                          filled: true,
                          fillColor: AdminColors.card,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Container(
                      decoration: BoxDecoration(
                        color: AdminColors.card,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.tune_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => _showFilterSheet(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),

                // --- ОСНОВНОЙ КОНТЕНТ (СЕТКА) ---
                Expanded(child: _buildContent(context, provider)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, CatalogProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AdminColors.accentBlue),
      );
    }
    if (provider.error != null) {
      return Center(
        child: Text(
          'Ошибка: ${provider.error}',
          style: const TextStyle(color: Colors.white),
        ),
      );
    }
    if (provider.products.isEmpty) {
      return const Center(
        child: Text(
          'Товары не найдены',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.fetchProducts,
      child: GridView.builder(
        itemCount: provider.products.length,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 300,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          childAspectRatio: 0.75,
        ),
        itemBuilder: (context, index) {
          final product = provider.products[index];
          return Container(
            decoration: BoxDecoration(
              color: AdminColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Изображение
                Expanded(
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        child: product.imageUrls.isNotEmpty
                            ? Image.network(
                                product.imageUrls.first,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: Colors.black26,
                                child: const Center(
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: Colors.white10,
                                  ),
                                ),
                              ),
                      ),
                      // Безопасное удаление (иконка в углу)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: IconButton(
                          icon: const CircleAvatar(
                            backgroundColor: Colors.black45,
                            child: Icon(
                              Icons.delete_sweep_rounded,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                          ),
                          onPressed: () => _confirmDelete(context, product),
                        ),
                      ),
                    ],
                  ),
                ),
                // Инфо
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.brand?.name.toUpperCase() ?? 'БЕЗ БРЕНДА',
                        style: const TextStyle(
                          color: AdminColors.accentBlue,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${product.price.toInt()} ₽',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => context.push(
                              '/admin/products/edit/${product.id}',
                              extra: product,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.05,
                              ),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              minimumSize: const Size(40, 40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Icon(
                              Icons.edit_note_rounded,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, dynamic product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AdminColors.card,
        title: const Text(
          'Удаление товара',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Вы уверены, что хотите удалить "${product.name}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ОТМЕНА'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('УДАЛИТЬ'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('products').delete().eq('id', product.id);
        AppNotifications.showSuccess(context, 'Товар удален из базы');
        context.read<CatalogProvider>().fetchProducts();
      } catch (e) {
        AppNotifications.showError(context, 'Ошибка удаления: $e');
      }
    }
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return ChangeNotifierProvider.value(
          value: context.read<CatalogProvider>(),
          child: const FractionallySizedBox(
            heightFactor: 0.85,
            child: FilterBottomSheet(),
          ),
        );
      },
    );
  }
}
