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
  // Временные переменные для хранения выбора в шторке
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
    // При открытии копируем текущие значения из провайдера
    final provider = context.read<CatalogProvider>();
    _tempSelectedBrands = Set.from(provider.selectedBrandIds);
    _tempSelectedTypes = Set.from(provider.selectedTypeIds);
    _tempSelectedGenders = Set.from(provider.selectedGenders);
    _tempSelectedStyles = Set.from(provider.selectedStyleIds);
    _tempSelectedMaterials = Set.from(provider.selectedMaterialIds);
    _tempSortOption = provider.sortOption;
    _tempPriceRange = provider.selectedPriceRange;
    _tempSelectedSizes = Set.from(provider.selectedSizes);
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
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              children: [
                // --- СОРТИРОВКА ---
                _sectionTitle('Сортировка'),
                _buildSortSection(),
                const Divider(),

                // --- ЦЕНА ---
                _sectionTitle('Цена'),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      f.format(_tempPriceRange.start),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      f.format(_tempPriceRange.end),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
                  onChanged: (values) =>
                      setState(() => _tempPriceRange = values),
                ),
                const Divider(),

                // --- ПОЛ ---
                _sectionTitle('Пол'),
                _buildGenderSection(),
                const Divider(),

                _sectionTitle('Размеры'),
                _buildSizeSection(),
                const Divider(),

                // --- БРЕНДЫ ---
                _sectionTitle('Бренды'),
                _buildFilterSection(
                  items: provider.brands
                      .map((b) => FilterItem(b.id, b.name))
                      .toList(),
                  selectedItems: _tempSelectedBrands,
                ),
                const Divider(),

                // --- ТИП ОБУВИ ---
                _sectionTitle('Тип обуви'),
                _buildFilterSection(
                  items: provider.productTypes
                      .map((t) => FilterItem(t.id, t.name))
                      .toList(),
                  selectedItems: _tempSelectedTypes,
                ),
                const Divider(),

                // --- СТИЛЬ ---
                _sectionTitle('Стиль'),
                _buildFilterSection(
                  items: provider.styles
                      .map((s) => FilterItem(s.id, s.name))
                      .toList(),
                  selectedItems: _tempSelectedStyles,
                ),
                const Divider(),

                // --- МАТЕРИАЛ ---
                _sectionTitle('Материал'),
                _buildFilterSection(
                  items: provider.materials
                      .map((m) => FilterItem(m.id, m.name))
                      .toList(),
                  selectedItems: _tempSelectedMaterials,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // --- КНОПКИ ДЕЙСТВИЯ ---
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetFilters,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: const Text('Сбросить'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _applyFilters,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Применить'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ СЕКЦИЙ ---

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSortSection() {
    return Column(
      children: [
        _sortRadio('По умолчанию', SortOption.none),
        _sortRadio('Сначала дешевле', SortOption.priceAsc),
        _sortRadio('Сначала дороже', SortOption.priceDesc),
      ],
    );
  }

  Widget _sortRadio(String title, SortOption value) {
    return RadioListTile<SortOption>(
      title: Text(title),
      value: value,
      groupValue: _tempSortOption,
      onChanged: (val) => setState(() => _tempSortOption = val!),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildGenderSection() {
    final genders = {
      'male': 'Мужской',
      'female': 'Женский',
      'unisex': 'Унисекс',
    };
    return Wrap(
      spacing: 8.0,
      children: genders.entries.map((entry) {
        return FilterChip(
          label: Text(entry.value),
          selected: _tempSelectedGenders.contains(entry.key),
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _tempSelectedGenders.add(entry.key);
              } else {
                _tempSelectedGenders.remove(entry.key);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildFilterSection({
    required List<FilterItem> items,
    required Set<String> selectedItems,
  }) {
    if (items.isEmpty) {
      return const Text(
        'Нет доступных вариантов',
        style: TextStyle(color: Colors.grey),
      );
    }
    return Wrap(
      spacing: 8.0,
      runSpacing: 0.0,
      children: items.map((item) {
        return FilterChip(
          label: Text(item.name),
          selected: selectedItems.contains(item.id),
          onSelected: (selected) {
            setState(() {
              if (selected) {
                selectedItems.add(item.id);
              } else {
                selectedItems.remove(item.id);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildSizeSection() {
    // Список стандартных размеров обуви
    final List<int> allSizes = [35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46];

    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: allSizes.map((size) {
        final isSelected = _tempSelectedSizes.contains(size);
        return FilterChip(
          label: Text(size.toString()),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _tempSelectedSizes.add(size);
              } else {
                _tempSelectedSizes.remove(size);
              }
            });
          },
        );
      }).toList(),
    );
  }
  // --- ЛОГИКА КНОПОК ---

  void _resetFilters() {
    final provider = context.read<CatalogProvider>();
    setState(() {
      _tempSelectedBrands.clear();
      _tempSelectedTypes.clear();
      _tempSelectedGenders.clear();
      _tempSelectedStyles.clear();
      _tempSelectedMaterials.clear();
      _tempSelectedSizes.clear();
      _tempSortOption = SortOption.none;
      _tempPriceRange = RangeValues(0, provider.maxPriceLimit);
    });
  }

  void _applyFilters() {
    context.read<CatalogProvider>().applyFilters(
      brands: _tempSelectedBrands,
      types: _tempSelectedTypes,
      genders: _tempSelectedGenders,
      styles: _tempSelectedStyles,
      materials: _tempSelectedMaterials,
      sort: _tempSortOption,
      sizes: _tempSelectedSizes,
      priceRange: _tempPriceRange,
    );
    Navigator.of(context).pop();
  }
}

class FilterItem {
  final String id;
  final String name;
  FilterItem(this.id, this.name);
}
