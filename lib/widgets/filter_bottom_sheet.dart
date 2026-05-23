// lib/widgets/filter_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ohana_store/features/catalog/catalog_provider.dart';
import 'package:provider/provider.dart';

class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late Set<String> _tempSelectedBrands;
  late Set<String> _tempSelectedTypes;
  late Set<String> _tempSelectedGenders;
  late Set<String> _tempSelectedStyles;
  late Set<String> _tempSelectedMaterials;
  late Set<int> _tempSelectedSizes;
  late SortOption _tempSortOption;
  late RangeValues _tempPriceRange;

  @override
  void initState() {
    super.initState();
    final provider = context.read<CatalogProvider>();
    _tempSelectedBrands = Set.from(provider.selectedBrandIds);
    _tempSelectedTypes = Set.from(provider.selectedTypeIds);
    _tempSelectedGenders = Set.from(provider.selectedGenders);
    _tempSelectedStyles = Set.from(provider.selectedStyleIds);
    _tempSelectedMaterials = Set.from(provider.selectedMaterialIds);
    _tempSelectedSizes = Set.from(provider.selectedSizes);
    _tempSortOption = provider.sortOption;
    _tempPriceRange = provider.selectedPriceRange;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CatalogProvider>();
    final f = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₽',
      decimalDigits: 0,
    );

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Фильтры',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              children: [
                _sectionTitle('Сортировка'),
                _buildSortSection(),
                const Divider(),
                _sectionTitle('Цена'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(f.format(_tempPriceRange.start)),
                    Text(f.format(_tempPriceRange.end)),
                  ],
                ),
                RangeSlider(
                  values: _tempPriceRange,
                  min: 0,
                  max: provider.maxPriceLimit > 0
                      ? provider.maxPriceLimit
                      : 1.0,
                  divisions: 50,
                  activeColor: Theme.of(context).primaryColor,
                  onChanged: (val) => setState(() => _tempPriceRange = val),
                ),
                const Divider(),
                _sectionTitle('Пол'),
                _buildGenderSection(),
                const Divider(),
                _sectionTitle('Размеры'),
                _buildSizeSection(),
                const Divider(),
                _sectionTitle('Бренды'),
                _buildFilterSection(
                  provider.brands.map((e) => FilterItem(e.id, e.name)).toList(),
                  _tempSelectedBrands,
                ),
                const Divider(),
                _sectionTitle('Тип обуви'),
                _buildFilterSection(
                  provider.productTypes
                      .map((e) => FilterItem(e.id, e.name))
                      .toList(),
                  _tempSelectedTypes,
                ),
                const Divider(),
                _sectionTitle('Стиль'),
                _buildFilterSection(
                  provider.styles.map((e) => FilterItem(e.id, e.name)).toList(),
                  _tempSelectedStyles,
                ),
                const Divider(),
                _sectionTitle('Материал'),
                _buildFilterSection(
                  provider.materials
                      .map((e) => FilterItem(e.id, e.name))
                      .toList(),
                  _tempSelectedMaterials,
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _resetFilters,
                  child: const Text('Сбросить'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _applyFilters,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Применить'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      t,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
  );

  Widget _buildSortSection() {
    return Column(
      children: [
        _sortRadio('По умолчанию', SortOption.none),
        _sortRadio('Сначала дешевле', SortOption.priceAsc),
        _sortRadio('Сначала дороже', SortOption.priceDesc),
      ],
    );
  }

  Widget _sortRadio(String t, SortOption v) => RadioListTile<SortOption>(
    title: Text(t),
    value: v,
    groupValue: _tempSortOption,
    onChanged: (val) => setState(() => _tempSortOption = val!),
    contentPadding: EdgeInsets.zero,
    dense: true,
  );

  Widget _buildGenderSection() {
    final gMap = {'male': 'Мужской', 'female': 'Женский', 'unisex': 'Унисекс'};
    return Wrap(
      spacing: 8,
      children: gMap.entries
          .map(
            (e) => FilterChip(
              label: Text(e.value),
              selected: _tempSelectedGenders.contains(e.key),
              onSelected: (s) => setState(
                () => s
                    ? _tempSelectedGenders.add(e.key)
                    : _tempSelectedGenders.remove(e.key),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSizeSection() {
    final allSizes = [35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46];
    return Wrap(
      spacing: 8,
      children: allSizes
          .map(
            (sz) => FilterChip(
              label: Text(sz.toString()),
              selected: _tempSelectedSizes.contains(sz),
              onSelected: (s) => setState(
                () => s
                    ? _tempSelectedSizes.add(sz)
                    : _tempSelectedSizes.remove(sz),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildFilterSection(List<FilterItem> items, Set<String> selected) {
    return Wrap(
      spacing: 8,
      children: items
          .map(
            (i) => FilterChip(
              label: Text(i.name),
              selected: selected.contains(i.id),
              onSelected: (s) => setState(
                () => s ? selected.add(i.id) : selected.remove(i.id),
              ),
            ),
          )
          .toList(),
    );
  }

  void _resetFilters() {
    final p = context.read<CatalogProvider>();
    setState(() {
      _tempSelectedBrands.clear();
      _tempSelectedTypes.clear();
      _tempSelectedGenders.clear();
      _tempSelectedStyles.clear();
      _tempSelectedMaterials.clear();
      _tempSelectedSizes.clear();
      _tempSortOption = SortOption.none;
      _tempPriceRange = RangeValues(0, p.maxPriceLimit);
    });
  }

  void _applyFilters() {
    context.read<CatalogProvider>().applyFilters(
      brands: _tempSelectedBrands,
      types: _tempSelectedTypes,
      genders: _tempSelectedGenders,
      styles: _tempSelectedStyles,
      materials: _tempSelectedMaterials,
      sizes: _tempSelectedSizes,
      sort: _tempSortOption,
      priceRange: _tempPriceRange,
    );
    Navigator.pop(context);
  }
}

class FilterItem {
  final String id;
  final String name;
  FilterItem(this.id, this.name);
}
