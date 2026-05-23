import 'package:flutter/material.dart';
import 'package:ohana_store/features/catalog/catalog_provider.dart';
import 'package:ohana_store/widgets/filter_bottom_sheet.dart';
import 'package:ohana_store/widgets/product_card.dart';
import 'package:provider/provider.dart';

class CatalogPage extends StatelessWidget {
  const CatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CatalogProvider(),
      child: Consumer<CatalogProvider>(
        builder: (context, provider, child) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              elevation: 0,
              backgroundColor: Colors.white,
              toolbarHeight: 70,
              title: const Text(
                "Ohana Store",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              centerTitle: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.filter_list_rounded, size: 28),
                  onPressed: () => _showFilterSheet(context),
                  color: Colors.black,
                ),
              ],
            ),

            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchBar(context, provider),

                const SizedBox(height: 12),

                Expanded(child: _buildContent(context, provider)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, CatalogProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(18),
        ),
        child: TextField(
          onChanged: (query) => provider.onSearchQueryChanged(query),
          decoration: InputDecoration(
            hintText: 'Поискать обувь…',
            hintStyle: TextStyle(
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: const Icon(
              Icons.search,
              color: Colors.black87,
              size: 26,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return ChangeNotifierProvider.value(
          value: context.read<CatalogProvider>(),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: const FractionallySizedBox(
              heightFactor: 0.75,
              child: FilterBottomSheet(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, CatalogProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.error != null) {
      return Center(child: Text('Ошибка: ${provider.error}'));
    }
    if (provider.products.isEmpty) {
      return const Center(
        child: Text(
          'Заходите позже!',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: Colors.black,
      onRefresh: provider.fetchProducts,
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.60,
        ),
        itemCount: provider.products.length,
        itemBuilder: (context, index) {
          return AnimatedScale(
            scale: 1,
            duration: const Duration(milliseconds: 200),
            child: ProductCard(product: provider.products[index]),
          );
        },
      ),
    );
  }
}
