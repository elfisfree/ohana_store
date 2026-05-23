// lib/features/admin/upsert_product_page.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ohana_store/core/admin_theme.dart';
import 'package:ohana_store/core/utils/app_notifications.dart';
import 'package:ohana_store/main.dart';
import 'package:ohana_store/models/product.dart';

class VariantInput {
  final TextEditingController colorNameController;
  final TextEditingController colorCodeController;
  List<String> imageUrls;
  List<Map<String, dynamic>> stockData;
  String? id;

  VariantInput({
    required String colorName,
    required String colorCode,
    required this.imageUrls,
    required this.stockData,
    this.id,
  }) : colorNameController = TextEditingController(text: colorName),
       colorCodeController = TextEditingController(text: colorCode);

  void dispose() {
    colorNameController.dispose();
    colorCodeController.dispose();
  }
}

const String _addNewBrandValue = 'ADD_NEW_BRAND';
const String _addNewTypeValue = 'ADD_NEW_TYPE';
const String _addNewStyleValue = 'ADD_NEW_STYLE';
const String _addNewMaterialValue = 'ADD_NEW_MATERIAL';

class UpsertProductPage extends StatefulWidget {
  final Product? product;
  const UpsertProductPage({super.key, this.product});

  @override
  State<UpsertProductPage> createState() => _UpsertProductPageState();
}

class _UpsertProductPageState extends State<UpsertProductPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _tagsController;

  List<VariantInput> _variants = [];
  String? _selectedBrandId;
  String? _selectedTypeId;
  String? _selectedStyleId;
  String? _selectedMaterialId;
  String? _selectedGender;

  List<Brand> _brands = [];
  List<ProductType> _productTypes = [];
  List<Style> _styles = [];
  List<MaterialModel> _materials = [];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;

    _nameController = TextEditingController(text: p?.name ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _priceController = TextEditingController(text: p?.price.toString() ?? '');
    _tagsController = TextEditingController(
      text: p?.tags.map((t) => t.name).join(', ') ?? '',
    );

    _selectedBrandId = p?.brand?.id;
    _selectedTypeId = p?.productType?.id;
    _selectedStyleId = p?.style?.id;
    _selectedMaterialId = p?.material?.id;
    _selectedGender = p?.gender;
    if (p != null && p.variants.isNotEmpty) {
      _variants = p.variants
          .map(
            (v) => VariantInput(
              id: v.id,
              colorName: v.colorName,
              colorCode: v.colorCode ?? '#',
              imageUrls: List.from(v.imageUrls),
              stockData: v.stock
                  .map((s) => {'size': s.size, 'qty': s.quantity})
                  .toList(),
            ),
          )
          .toList();
    } else {
      _variants.add(
        VariantInput(
          colorName: '',
          colorCode: '#',
          imageUrls: [],
          stockData: [
            {'size': 40.0, 'qty': 0},
          ],
        ),
      );
    }

    _fetchDropdownData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _tagsController.dispose();
    for (var v in _variants) {
      v.dispose();
    }
    super.dispose();
  }

  Future<dynamic> _showAddEntityDialog(
    String title,
    String tableName,
    String entityName,
  ) async {
    final controller = TextEditingController();
    final fKey = GlobalKey<FormState>();

    return await showDialog(
      context: context,
      builder: (ctx) {
        bool innerSaving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AdminColors.card,
              title: Text(
                'Добавить $entityName',
                style: const TextStyle(color: Colors.white),
              ),
              content: Form(
                key: fKey,
                child: TextFormField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Название $entityName',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: AdminColors.sidebar,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (v) =>
                      v!.trim().isEmpty ? 'Введите название' : null,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: innerSaving
                      ? null
                      : () async {
                          if (fKey.currentState!.validate()) {
                            setDialogState(() => innerSaving = true);
                            try {
                              final res = await supabase
                                  .from(tableName)
                                  .insert({'name': controller.text.trim()})
                                  .select()
                                  .single();
                              Navigator.pop(ctx, res);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Ошибка: $e')),
                              );
                              setDialogState(() => innerSaving = false);
                            }
                          }
                        },
                  child: innerSaving
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    for (var v in _variants) {
      if (v.imageUrls.isEmpty) {
        AppNotifications.showError(
          context,
          'У варианта "${v.colorNameController.text}" нет фото',
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final productData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text),
        'brand_id': _selectedBrandId,
        'product_type_id': _selectedTypeId,
        'style_id': _selectedStyleId,
        'material_id': _selectedMaterialId,
        'gender': _selectedGender,
      };

      late String productId;
      if (widget.product != null) {
        productId = widget.product!.id;
        await supabase.from('products').update(productData).eq('id', productId);
      } else {
        final res = await supabase
            .from('products')
            .insert(productData)
            .select()
            .single();
        productId = res['id'];
      }
      if (widget.product != null) {
        await supabase
            .from('product_variants')
            .delete()
            .eq('product_id', productId);
      }

      for (var variantInput in _variants) {
        final vRes = await supabase
            .from('product_variants')
            .insert({
              'product_id': productId,
              'color_name': variantInput.colorNameController.text.trim(),
              'color_code': variantInput.colorCodeController.text.trim(),
              'image_urls': variantInput.imageUrls,
            })
            .select()
            .single();

        final String variantId = vRes['id'];
        final List<Map<String, dynamic>> stockToInsert = variantInput.stockData
            .map(
              (s) => {
                'variant_id': variantId,
                'size': s['size'],
                'quantity': s['qty'],
              },
            )
            .toList();
        await supabase.from('product_stock').insert(stockToInsert);
      }
      await _handleTags(productId);

      AppNotifications.showSuccess(
        context,
        'Товарная матрица успешно сохранена',
      );
      context.pop();
    } catch (e) {
      AppNotifications.showError(context, 'Ошибка сохранения: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleTags(String productId) async {
    final tagNames = _tagsController.text
        .split(',')
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toSet();
    await supabase.from('product_tags').delete().eq('product_id', productId);
    for (var name in tagNames) {
      final existingTag = await supabase
          .from('tags')
          .select()
          .eq('name', name)
          .maybeSingle();
      late String tagId;
      if (existingTag == null) {
        final newTag = await supabase
            .from('tags')
            .insert({'name': name})
            .select()
            .single();
        tagId = newTag['id'];
      } else {
        tagId = existingTag['id'];
      }
      await supabase.from('product_tags').insert({
        'product_id': productId,
        'tag_id': tagId,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'УПРАВЛЕНИЕ ТОВАРНОЙ МАТРИЦЕЙ',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveProduct,
              icon: const Icon(Icons.done_all_rounded),
              label: const Text('СОХРАНИТЬ ВСЁ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.accentBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _buildAdminCard('БАЗОВАЯ ИНФОРМАЦИЯ', [
                      _adminField(_nameController, 'Название модели'),
                      const SizedBox(height: 20),
                      _adminField(
                        _descriptionController,
                        'Описание',
                        maxLines: 4,
                      ),
                      const SizedBox(height: 20),
                      _adminField(
                        _priceController,
                        'Базовая цена (₽)',
                        isNumber: true,
                      ),
                      const SizedBox(height: 20),
                      _adminField(_tagsController, 'Теги (через запятую)'),
                    ]),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ЦВЕТОВЫЕ РЕШЕНИЯ',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(
                            () => _variants.add(
                              VariantInput(
                                colorName: '',
                                colorCode: '#',
                                imageUrls: [],
                                stockData: [
                                  {'size': 40.0, 'qty': 0},
                                ],
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('ДОБАВИТЬ ЦВЕТ'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    ..._variants.asMap().entries.map(
                      (entry) => _buildVariantCard(entry.key, entry.value),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 30),
              Expanded(
                flex: 1,
                child: _buildAdminCard('КАТЕГОРИЗАЦИЯ', [_buildDropdowns()]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVariantCard(int index, VariantInput variant) {
    return Container(
      margin: const EdgeInsets.only(bottom: 30),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AdminColors.accentBlue,
                radius: 15,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _adminField(
                  variant.colorNameController,
                  'Название цвета (напр: Розовая пудра)',
                ),
              ),
              const SizedBox(width: 15),
              SizedBox(
                width: 150,
                child: _adminField(variant.colorCodeController, 'HEX Код'),
              ),
              IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                onPressed: () => setState(() => _variants.removeAt(index)),
              ),
            ],
          ),
          const Divider(height: 40, color: Colors.white10),
          const Text(
            'ФОТОГРАФИИ ЭТОГО ЦВЕТА',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          _buildImageGrid(variant),
          const Divider(height: 40, color: Colors.white10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ТАБЛИЦА РАЗМЕРОВ',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => setState(
                  () => variant.stockData.add({'size': 40.0, 'qty': 0}),
                ),
                child: const Text('+ РАЗМЕР'),
              ),
            ],
          ),
          ...variant.stockData.asMap().entries.map(
            (sEntry) => _buildStockRow(variant, sEntry.key),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid(VariantInput variant) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ...variant.imageUrls.asMap().entries.map(
          (img) => Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  img.value,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: -5,
                right: -5,
                child: IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                  onPressed: () =>
                      setState(() => variant.imageUrls.removeAt(img.key)),
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () => _pickAndUploadImage(variant),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AdminColors.sidebar,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.add_a_photo_outlined,
              color: Colors.white24,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStockRow(VariantInput variant, int sIndex) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: _adminFieldSmall(
              label: 'Размер',
              initialValue: variant.stockData[sIndex]['size'].toString(),
              onChanged: (v) =>
                  variant.stockData[sIndex]['size'] = double.tryParse(v) ?? 0.0,
            ),
          ),
          const SizedBox(width: 15),
          SizedBox(
            width: 100,
            child: _adminFieldSmall(
              label: 'Кол-во',
              initialValue: variant.stockData[sIndex]['qty'].toString(),
              onChanged: (v) =>
                  variant.stockData[sIndex]['qty'] = int.tryParse(v) ?? 0,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.remove_circle_outline,
              size: 18,
              color: Colors.white24,
            ),
            onPressed: () => setState(() => variant.stockData.removeAt(sIndex)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadImage(VariantInput variant) async {
    final picker = ImagePicker();
    final imageFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (imageFile == null) return;
    setState(() => _isSaving = true);
    try {
      final file = File(imageFile.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage.from('product-images').upload(fileName, file);
      final imageUrl = supabase.storage
          .from('product-images')
          .getPublicUrl(fileName);
      setState(() => variant.imageUrls.add(imageUrl));
    } catch (e) {
      AppNotifications.showError(context, 'Ошибка загрузки: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildDropdowns() {
    return Column(
      children: [
        _adminDropdown(
          'Бренд',
          _selectedBrandId,
          _brands
              .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
              .toList(),
          _addNewBrandValue,
          (val) async {
            if (val == _addNewBrandValue) {
              final res = await _showAddEntityDialog(
                'бренды',
                'brands',
                'бренд',
              );
              if (res != null) {
                setState(() {
                  _brands.add(Brand.fromJson(res));
                  _selectedBrandId = res['id'];
                });
              }
            } else {
              setState(() => _selectedBrandId = val);
            }
          },
        ),
        _adminDropdown(
          'Тип товара',
          _selectedTypeId,
          _productTypes
              .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
              .toList(),
          _addNewTypeValue,
          (val) async {
            if (val == _addNewTypeValue) {
              final res = await _showAddEntityDialog(
                'типы',
                'product_types',
                'тип',
              );
              if (res != null) {
                setState(() {
                  _productTypes.add(ProductType.fromJson(res));
                  _selectedTypeId = res['id'];
                });
              }
            } else {
              setState(() => _selectedTypeId = val);
            }
          },
        ),
        _adminDropdown(
          'Стиль',
          _selectedStyleId,
          _styles
              .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
              .toList(),
          _addNewStyleValue,
          (val) async {
            if (val == _addNewStyleValue) {
              final res = await _showAddEntityDialog(
                'стили',
                'styles',
                'стиль',
              );
              if (res != null) {
                setState(() {
                  _styles.add(Style.fromJson(res));
                  _selectedStyleId = res['id'];
                });
              }
            } else {
              setState(() => _selectedStyleId = val);
            }
          },
        ),
        _adminDropdown(
          'Материал',
          _selectedMaterialId,
          _materials
              .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
              .toList(),
          _addNewMaterialValue,
          (val) async {
            if (val == _addNewMaterialValue) {
              final res = await _showAddEntityDialog(
                'материалы',
                'materials',
                'материал',
              );
              if (res != null) {
                setState(() {
                  _materials.add(MaterialModel.fromJson(res));
                  _selectedMaterialId = res['id'];
                });
              }
            } else {
              setState(() => _selectedMaterialId = val);
            }
          },
        ),
        _adminDropdown(
          'Гендер',
          _selectedGender,
          const [
            DropdownMenuItem(value: 'male', child: Text('Мужской')),
            DropdownMenuItem(value: 'female', child: Text('Женский')),
            DropdownMenuItem(value: 'unisex', child: Text('Унисекс')),
          ],
          '',
          (val) => setState(() => _selectedGender = val),
        ),
      ],
    );
  }

  Widget _adminField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    bool isNumber = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: AdminColors.sidebar,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      validator: (v) => v!.isEmpty ? 'Обязательно' : null,
    );
  }

  Widget _adminFieldSmall({
    required String label,
    required String initialValue,
    required Function(String) onChanged,
  }) {
    return TextFormField(
      initialValue: initialValue,
      onChanged: onChanged,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 10),
        filled: true,
        fillColor: AdminColors.sidebar,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      ),
    );
  }

  Widget _adminDropdown(
    String label,
    String? value,
    List<DropdownMenuItem<String>> items,
    String addValue,
    Function(String?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        dropdownColor: AdminColors.card,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white38),
          filled: true,
          fillColor: AdminColors.sidebar,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        items: [
          ...items,
          DropdownMenuItem(
            value: addValue,
            child: Text(
              '+ Добавить...',
              style: const TextStyle(color: AdminColors.accentBlue),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildAdminCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AdminColors.accentBlue,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 25),
          ...children,
        ],
      ),
    );
  }

  Future<void> _fetchDropdownData() async {
    final results = await Future.wait<dynamic>([
      supabase.from('brands').select(),
      supabase.from('product_types').select(),
      supabase.from('styles').select(),
      supabase.from('materials').select(),
    ]);
    setState(() {
      _brands = (results[0] as List).map((b) => Brand.fromJson(b)).toList();
      _productTypes = (results[1] as List)
          .map((t) => ProductType.fromJson(t))
          .toList();
      _styles = (results[2] as List).map((s) => Style.fromJson(s)).toList();
      _materials = (results[3] as List)
          .map((m) => MaterialModel.fromJson(m))
          .toList();
      _isLoading = false;
    });
  }
}
