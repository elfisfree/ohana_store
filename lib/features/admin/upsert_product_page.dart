// lib/features/admin/upsert_product_page.dart
// ignore_for_file: unused_import, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ohana_store/core/admin_theme.dart'; // Используем ваши AdminColors
import 'package:ohana_store/core/utils/app_notifications.dart';
import 'package:ohana_store/main.dart';
import 'package:ohana_store/models/product.dart';

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
  late final TextEditingController _sizesController;
  late final TextEditingController _tagsController;

  String? _selectedBrandId;
  String? _selectedTypeId;
  String? _selectedStyleId;
  String? _selectedMaterialId;
  String? _selectedGender;

  List<Brand> _brands = [];
  List<ProductType> _productTypes = [];
  List<Style> _styles = [];
  List<MaterialModel> _materials = [];

  List<String> _imageUrls = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _priceController = TextEditingController(text: p?.price.toString() ?? '');
    _sizesController = TextEditingController(
      text: p?.availableSizes.join(', ') ?? '',
    );
    _tagsController = TextEditingController(
      text: p?.tags.map((t) => t.name).join(', ') ?? '',
    );

    _selectedBrandId = p?.brand?.id;
    _selectedTypeId = p?.productType?.id;
    _selectedStyleId = p?.style?.id;
    _selectedMaterialId = p?.material?.id;
    _selectedGender = p?.gender;

    if (p != null) {
      _imageUrls = List.from(p.imageUrls);
    }
    _fetchDropdownData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _sizesController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _fetchDropdownData() async {
    try {
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
    } catch (e) {
      if (mounted) {
        AppNotifications.showError(context, 'Ошибка загрузки данных: $e');
      }
      setState(() => _isLoading = false);
    }
  }

  Future<dynamic> _showAddEntityDialog(
    String title,
    String tableName,
    String entityName,
  ) async {
    final controller = TextEditingController();
    return await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.card,
        title: Text(
          'Добавить $entityName',
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Название $entityName',
            labelStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: AdminColors.sidebar,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ОТМЕНА'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              final res = await supabase
                  .from(tableName)
                  .insert({'name': controller.text.trim()})
                  .select()
                  .single();
              Navigator.pop(ctx, res);
            },
            child: const Text('СОХРАНИТЬ'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final sizes = _sizesController.text
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .toList();
      final data = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text),
        'available_sizes': sizes,
        'brand_id': _selectedBrandId,
        'product_type_id': _selectedTypeId,
        'style_id': _selectedStyleId,
        'material_id': _selectedMaterialId,
        'gender': _selectedGender,
        'image_urls': _imageUrls,
      };

      late String productId;
      if (widget.product != null) {
        productId = widget.product!.id;
        await supabase.from('products').update(data).eq('id', productId);
      } else {
        final res = await supabase
            .from('products')
            .insert(data)
            .select()
            .single();
        productId = res['id'];
      }

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

      if (mounted) {
        AppNotifications.showSuccess(context, 'Товар успешно сохранен');
        context.pop();
      }
    } catch (e) {
      if (mounted) AppNotifications.showError(context, 'Ошибка сохранения: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
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
      setState(() => _imageUrls.add(imageUrl));
    } catch (e) {
      if (mounted) AppNotifications.showError(context, 'Ошибка загрузки: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          isEditing ? 'РЕДАКТИРОВАНИЕ ТОВАРА' : 'ДОБАВЛЕНИЕ ТОВАРА',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveProduct,
              icon: const Icon(Icons.save_rounded),
              label: const Text('СОХРАНИТЬ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.accentBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(30),
              child: Form(
                key: _formKey,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- ЛЕВАЯ КОЛОНКА: ОСНОВНОЕ ---
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          _buildAdminCard('ОСНОВНАЯ ИНФОРМАЦИЯ', [
                            _adminField(_nameController, 'Название товара'),
                            const SizedBox(height: 20),
                            _adminField(
                              _descriptionController,
                              'Описание товара',
                              maxLines: 5,
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: _adminField(
                                    _priceController,
                                    'Цена (₽)',
                                    isNumber: true,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: _adminField(
                                    _sizesController,
                                    'Размеры (через запятую)',
                                    hint: '40, 41, 42',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _adminField(
                              _tagsController,
                              'Теги (через запятую)',
                              hint: 'лето, кожа, хит',
                            ),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(width: 30),

                    // --- ПРАВАЯ КОЛОНКА: МЕДИА И КАТЕГОРИИ ---
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          _buildAdminCard('ИЗОБРАЖЕНИЯ', [
                            _buildImageSection(),
                          ]),
                          const SizedBox(height: 30),
                          _buildAdminCard('КАТЕГОРИИ', [
                            _adminDropdown(
                              'Бренд',
                              _selectedBrandId,
                              _brands
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e.id,
                                      child: Text(e.name),
                                    ),
                                  )
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
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e.id,
                                      child: Text(e.name),
                                    ),
                                  )
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
                                      _productTypes.add(
                                        ProductType.fromJson(res),
                                      );
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
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e.id,
                                      child: Text(e.name),
                                    ),
                                  )
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
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e.id,
                                      child: Text(e.name),
                                    ),
                                  )
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
                                      _materials.add(
                                        MaterialModel.fromJson(res),
                                      );
                                      _selectedMaterialId = res['id'];
                                    });
                                  }
                                } else {
                                  setState(() => _selectedMaterialId = val);
                                }
                              },
                            ),
                            DropdownButtonFormField<String>(
                              value: _selectedGender,
                              dropdownColor: AdminColors.card,
                              style: const TextStyle(color: Colors.white),
                              decoration: _adminInputDecoration('Пол'),
                              items: const [
                                DropdownMenuItem(
                                  value: 'male',
                                  child: Text('Мужской'),
                                ),
                                DropdownMenuItem(
                                  value: 'female',
                                  child: Text('Женский'),
                                ),
                                DropdownMenuItem(
                                  value: 'unisex',
                                  child: Text('Унисекс'),
                                ),
                              ],
                              onChanged: (val) =>
                                  setState(() => _selectedGender = val),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // --- ПОДСЕКЦИИ ---

  Widget _buildImageSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          shrinkWrap: true, // Позволяет GridView находиться внутри ListView
          physics:
              const NeverScrollableScrollPhysics(), // Отключаем внутреннюю прокрутку
          itemCount: _imageUrls.length + 1, // +1 для кнопки добавления
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent:
                180, // МАКСИМАЛЬНАЯ ШИРИНА ОДНОЙ КАРТИНКИ (теперь они крупные)
            mainAxisSpacing: 15,
            crossAxisSpacing: 15,
            childAspectRatio: 1, // Делаем их квадратными
          ),
          itemBuilder: (context, index) {
            // Если это последний элемент — рисуем кнопку добавления
            if (index == _imageUrls.length) {
              return InkWell(
                onTap: _pickAndUploadImage,
                child: Container(
                  decoration: BoxDecoration(
                    color: AdminColors.sidebar,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 2,
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        color: Colors.white38,
                        size: 40,
                      ),
                      SizedBox(height: 8),
                      Text(
                        "ДОБАВИТЬ",
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Иначе рисуем саму картинку
            return Stack(
              clipBehavior:
                  Clip.none, // Чтобы кнопка удаления могла выходить за границы
              children: [
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(
                      _imageUrls[index],
                      fit: BoxFit.cover,
                      // Заглушка на время загрузки
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                          ? child
                          : const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                    ),
                  ),
                ),
                // Кнопка удаления (крестик в кружочке)
                Positioned(
                  top: -5,
                  right: -5,
                  child: GestureDetector(
                    onTap: () => setState(() => _imageUrls.removeAt(index)),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.redAccent,
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAdminCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AdminColors.accentBlue,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 25),
          ...children,
        ],
      ),
    );
  }

  Widget _adminField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    bool isNumber = false,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: _adminInputDecoration(label).copyWith(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white10),
      ),
      validator: (v) => v!.trim().isEmpty ? 'Обязательно' : null,
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
      padding: const EdgeInsets.only(bottom: 20),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        dropdownColor: AdminColors.card,
        style: const TextStyle(color: Colors.white),
        decoration: _adminInputDecoration(label),
        items: [
          ...items,
          DropdownMenuItem(
            value: addValue,
            child: Text(
              '+ Добавить $label...',
              style: const TextStyle(
                color: AdminColors.accentBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        onChanged: onChanged,
        validator: (v) => v == null ? 'Выберите $label' : null,
      ),
    );
  }

  InputDecoration _adminInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 14),
      filled: true,
      fillColor: AdminColors.sidebar,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AdminColors.accentBlue, width: 1.5),
      ),
    );
  }
}
