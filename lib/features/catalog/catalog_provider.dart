// lib/features/catalog/catalog_provider.dart
import 'package:flutter/material.dart';
import 'package:ohana_store/main.dart';
import 'package:ohana_store/models/product.dart';
import 'dart:async';

enum SortOption { none, priceAsc, priceDesc }

class CatalogProvider extends ChangeNotifier {
  bool _isLoading = true;
  String? _error;
  List<Product> _products = [];
  Timer? _debounce;

  double _maxPriceLimit = 100000.0;
  RangeValues _selectedPriceRange = const RangeValues(0, 100000);
  List<Brand> _brands = [];
  List<ProductType> _productTypes = [];
  List<Style> _styles = [];
  List<MaterialModel> _materials = [];
  String _searchQuery = '';
  Set<String> _selectedBrandIds = {};
  Set<String> _selectedTypeIds = {};
  Set<String> _selectedGenders = {};
  Set<String> _selectedStyleIds = {};
  Set<String> _selectedMaterialIds = {};
  Set<int> _selectedSizes = {};
  SortOption _sortOption = SortOption.none;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Product> get products => _products;
  List<Brand> get brands => _brands;
  List<ProductType> get productTypes => _productTypes;
  List<Style> get styles => _styles;
  List<MaterialModel> get materials => _materials;

  Set<String> get selectedBrandIds => _selectedBrandIds;
  Set<String> get selectedTypeIds => _selectedTypeIds;
  Set<String> get selectedGenders => _selectedGenders;
  Set<String> get selectedStyleIds => _selectedStyleIds;
  Set<String> get selectedMaterialIds => _selectedMaterialIds;
  Set<int> get selectedSizes => _selectedSizes;

  SortOption get sortOption => _sortOption;
  double get maxPriceLimit => _maxPriceLimit;
  RangeValues get selectedPriceRange => _selectedPriceRange;

  CatalogProvider() {
    _init();
  }

  Future<void> _init() async {
    await _fetchFilterOptions();
    await fetchProducts();
  }

  Future<void> _fetchFilterOptions() async {
    try {
      final results = await Future.wait<dynamic>([
        supabase.from('brands').select(),
        supabase.from('product_types').select(),
        supabase.from('styles').select(),
        supabase.from('materials').select(),
        supabase
            .from('products')
            .select('price')
            .order('price', ascending: false)
            .limit(1)
            .maybeSingle(),
      ]);

      _brands = (results[0] as List).map((b) => Brand.fromJson(b)).toList();
      _productTypes = (results[1] as List)
          .map((t) => ProductType.fromJson(t))
          .toList();
      _styles = (results[2] as List).map((s) => Style.fromJson(s)).toList();
      _materials = (results[3] as List)
          .map((m) => MaterialModel.fromJson(m))
          .toList();

      if (results[4] != null) {
        final maxPriceData = results[4] as Map<String, dynamic>;
        _maxPriceLimit = (maxPriceData['price'] as num).toDouble();
        _selectedPriceRange = RangeValues(0, _maxPriceLimit);
      }
    } catch (e) {
      print('Ошибка загрузки опций фильтра: $e');
    }
  }

  Future<void> fetchProducts() async {
    _isLoading = true;
    notifyListeners();

    try {
      dynamic query = supabase.from('products').select('''
        *,
        brands(*),
        product_types(*),
        styles(*),
        materials(*),
        product_tags(tags(*)),
        product_variants(*, product_stock(*))
      ''');

      if (_searchQuery.isNotEmpty) {
        final searchTerms = _searchQuery
            .trim()
            .split(' ')
            .where((t) => t.isNotEmpty)
            .toList();
        if (searchTerms.isNotEmpty) {
          final parsedQuery = searchTerms.map((term) => '$term:*').join(' | ');
          query = query.textSearch('fts', parsedQuery, config: 'russian');
        }
      }

      if (_selectedBrandIds.isNotEmpty) {
        query = query.inFilter('brand_id', _selectedBrandIds.toList());
      }
      if (_selectedTypeIds.isNotEmpty) {
        query = query.inFilter('product_type_id', _selectedTypeIds.toList());
      }
      if (_selectedGenders.isNotEmpty) {
        query = query.inFilter('gender', _selectedGenders.toList());
      }
      if (_selectedStyleIds.isNotEmpty) {
        query = query.inFilter('style_id', _selectedStyleIds.toList());
      }
      if (_selectedMaterialIds.isNotEmpty) {
        query = query.inFilter('material_id', _selectedMaterialIds.toList());
      }

      if (_selectedSizes.isNotEmpty) {
        query = query.overlaps('available_sizes', _selectedSizes.toList());
      }

      query = query
          .gte('price', _selectedPriceRange.start)
          .lte('price', _selectedPriceRange.end);

      if (_sortOption == SortOption.priceAsc) {
        query = query.order('price', ascending: true);
      } else if (_sortOption == SortOption.priceDesc) {
        query = query.order('price', ascending: false);
      } else {
        query = query.order('created_at', ascending: false);
      }

      final response = await query;
      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(
        response,
      );
      _products = data.map((p) => Product.fromJson(p)).toList();
      _error = null;
    } catch (e) {
      _error = "Не удалось загрузить товары";
      print('!!! ОШИБКА КАТАЛОГА: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void onSearchQueryChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchQuery = query;
      fetchProducts();
    });
  }

  void applyFilters({
    required Set<String> brands,
    required Set<String> types,
    required Set<String> genders,
    required Set<String> styles,
    required Set<String> materials,
    required Set<int> sizes,
    required SortOption sort,
    required RangeValues priceRange,
  }) {
    _selectedBrandIds = brands;
    _selectedTypeIds = types;
    _selectedGenders = genders;
    _selectedStyleIds = styles;
    _selectedMaterialIds = materials;
    _selectedSizes = sizes;
    _sortOption = sort;
    _selectedPriceRange = priceRange;
    fetchProducts();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
