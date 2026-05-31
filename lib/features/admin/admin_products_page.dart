// lib/features/admin/admin_products_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ohana_store/core/admin_theme.dart';
import 'package:ohana_store/core/utils/app_notifications.dart';
import 'package:ohana_store/features/catalog/catalog_provider.dart';
import 'package:ohana_store/main.dart';
import 'package:ohana_store/models/product.dart';
import 'package:ohana_store/widgets/filter_bottom_sheet.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class AdminProductsPage extends StatelessWidget {
  const AdminProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CatalogProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'УПРАВЛЕНИЕ АССОРТИМЕНТОМ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Всего позиций: ${provider.products.length}',
                          style: const TextStyle(
                            color: AdminColors.accentBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/admin/products/new'),
                      icon: const Icon(Icons.add_box_rounded),
                      label: const Text('НОВЫЙ ТОВАР'),
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
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (query) =>
                            provider.onSearchQueryChanged(query),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Поиск по названию, бренду или тегу...',
                          hintStyle: const TextStyle(color: Colors.white24),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.white38,
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
                    _toolButton(
                      Icons.tune_rounded,
                      () => _showFilterSheet(context),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                Expanded(
                  child: provider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : GridView.builder(
                          itemCount: provider.products.length,
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 320,
                                mainAxisSpacing: 25,
                                crossAxisSpacing: 25,
                                childAspectRatio: 0.55, //длина
                              ),
                          itemBuilder: (context, index) =>
                              _buildAdminProductCard(
                                context,
                                provider.products[index],
                                provider,
                              ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdminProductCard(
    BuildContext context,
    Product product,
    CatalogProvider provider,
  ) {
    final f = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₽',
      decimalDigits: 0,
    );
    String? previewUrl;
    if (product.variants.isNotEmpty &&
        product.variants.first.imageUrls.isNotEmpty) {
      previewUrl = product.variants.first.imageUrls.first;
    }

    return Container(
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.2,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  child: previewUrl != null
                      ? Image.network(
                          previewUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: Colors.black26,
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.white10,
                            size: 40,
                          ),
                        ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: () => _confirmDelete(context, product, provider),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.black54,
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.brand?.name.toUpperCase() ?? 'БЕЗ БРЕНДА',
                    style: const TextStyle(
                      color: AdminColors.accentBlue,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),

                  const SizedBox(height: 15),

                  const Text(
                    'ОСТАТКИ НА СКЛАДЕ:',
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.only(right: 4),
                      child: SingleChildScrollView(
                        primary: false,
                        child: product.variants.isEmpty
                            ? const Text(
                                'Нет вариантов',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 11,
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: product.variants.map((variant) {
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 12.0,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          variant.colorName.toUpperCase(),
                                          style: TextStyle(
                                            color: AdminColors.accentBlue
                                                .withValues(alpha: 0.7),
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: variant.stock.map((s) {
                                            final bool isLow = s.quantity < 3;
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isLow
                                                    ? Colors.redAccent
                                                          .withValues(
                                                            alpha: 0.1,
                                                          )
                                                    : AdminColors.sidebar,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: isLow
                                                      ? Colors.redAccent
                                                            .withValues(
                                                              alpha: 0.3,
                                                            )
                                                      : Colors.white.withValues(
                                                          alpha: 0.05,
                                                        ),
                                                ),
                                              ),
                                              child: Text(
                                                '${s.size.toInt()}: ${s.quantity}шт',
                                                style: TextStyle(
                                                  color: isLow
                                                      ? Colors.redAccent
                                                      : Colors.white70,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        f.format(product.price),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: AdminColors.accentBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          onPressed: () => context.push(
                            '/admin/products/edit/${product.id}',
                            extra: product,
                          ),
                          icon: const Icon(
                            Icons.edit_note_rounded,
                            color: AdminColors.accentBlue,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(15),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onTap,
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    dynamic product,
    CatalogProvider provider,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.card,
        title: const Text(
          'УДАЛЕНИЕ',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Удалить "${product.name}" из базы?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ОТМЕНА', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('УДАЛИТЬ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await supabase.from('products').delete().eq('id', product.id);
      AppNotifications.showSuccess(context, 'Товар удален');
      provider.fetchProducts();
    }
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<CatalogProvider>(),
        child: const FractionallySizedBox(
          heightFactor: 0.85,
          child: FilterBottomSheet(),
        ),
      ),
    );
  }
}
