// lib/features/admin/upsert_promocode_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ohana_store/core/admin_theme.dart';
import 'package:ohana_store/core/utils/app_notifications.dart';
import 'package:ohana_store/features/admin/promocodes_provider.dart';
import 'package:ohana_store/main.dart';
import 'package:ohana_store/models/product.dart';
import 'package:ohana_store/models/promocode.dart';
import 'package:provider/provider.dart';

class UpsertPromocodePage extends StatefulWidget {
  final Promocode? promocode;
  const UpsertPromocodePage({super.key, this.promocode});

  @override
  State<UpsertPromocodePage> createState() => _UpsertPromocodePageState();
}

class _UpsertPromocodePageState extends State<UpsertPromocodePage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _codeController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _discountController;
  late final TextEditingController _minAmountController;
  late final TextEditingController _usageLimitController;
  late final TextEditingController _validToController;

  bool _isActive = true;
  Set<String> _selectedProductTypeIds = {};
  DateTime? _validToDate;
  List<ProductType> _productTypes = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.promocode;
    _codeController = TextEditingController(text: p?.code ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _discountController = TextEditingController(
      text: p?.discountPercentage.toString() ?? '',
    );
    _minAmountController = TextEditingController(
      text: p?.minOrderAmount?.toString() ?? '',
    );
    _usageLimitController = TextEditingController(
      text: p?.usageLimit?.toString() ?? '',
    );

    if (p != null) {
      _isActive = p.isActive;
      _selectedProductTypeIds = p.applicableProductTypes
          .map((pt) => pt.id)
          .toSet();
      _validToDate = p.validTo;
    }

    _validToController = TextEditingController(
      text: _validToDate != null
          ? DateFormat('dd.MM.yyyy').format(_validToDate!)
          : '',
    );

    _fetchDropdownData();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _descriptionController.dispose();
    _discountController.dispose();
    _minAmountController.dispose();
    _usageLimitController.dispose();
    _validToController.dispose();
    super.dispose();
  }

  Future<void> _fetchDropdownData() async {
    try {
      final typesResponse = await supabase.from('product_types').select();
      setState(() {
        _productTypes = typesResponse
            .map((t) => ProductType.fromJson(t))
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

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _validToDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AdminColors.accentBlue,
              onPrimary: Colors.white,
              surface: AdminColors.card,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _validToDate = picked;
        _validToController.text = DateFormat('dd.MM.yyyy').format(picked);
      });
    }
  }

  Future<void> _savePromocode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final isEditing = widget.promocode != null;
      final promocodeData = {
        'code': _codeController.text.trim().toUpperCase(),
        'description': _descriptionController.text.trim(),
        'discount_percentage': double.parse(_discountController.text),
        'min_order_amount': _minAmountController.text.isEmpty
            ? null
            : double.parse(_minAmountController.text),
        'usage_limit': _usageLimitController.text.isEmpty
            ? null
            : int.parse(_usageLimitController.text),
        'is_active': _isActive,
        'valid_to': _validToDate?.toIso8601String(),
      };

      String promocodeId;
      if (isEditing) {
        final response = await supabase
            .from('promocodes')
            .update(promocodeData)
            .eq('id', widget.promocode!.id)
            .select()
            .single();
        promocodeId = response['id'];
      } else {
        final response = await supabase
            .from('promocodes')
            .insert(promocodeData)
            .select()
            .single();
        promocodeId = response['id'];
      }

      await supabase
          .from('promocode_product_types')
          .delete()
          .eq('promocode_id', promocodeId);
      if (_selectedProductTypeIds.isNotEmpty) {
        final newLinks = _selectedProductTypeIds
            .map(
              (typeId) => {
                'promocode_id': promocodeId,
                'product_type_id': typeId,
              },
            )
            .toList();
        await supabase.from('promocode_product_types').insert(newLinks);
      }

      if (mounted) {
        AppNotifications.showSuccess(context, 'Данные сохранены');

        // --- ГЛАВНОЕ ОБНОВЛЕНИЕ ЧЕРЕЗ ПРОВАЙДЕР ---
        context.read<PromocodesProvider>().fetchPromocodes();

        context.pop(); // Просто закрываем страницу
      }
    } catch (e) {
      if (mounted) AppNotifications.showError(context, 'Ошибка: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.promocode != null;

    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          isEditing ? 'РЕДАКТИРОВАНИЕ ПРОМОКОДА' : 'СОЗДАНИЕ ПРОМОКОДА',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _savePromocode,
              icon: const Icon(Icons.check_rounded),
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
                    Expanded(
                      flex: 1,
                      child: _buildAdminCard('ОСНОВНЫЕ ПАРАМЕТРЫ', [
                        _adminField(
                          _codeController,
                          'Код промокода',
                          hint: 'Напр: SUMMER2024',
                        ),
                        const SizedBox(height: 20),
                        _adminField(
                          _discountController,
                          'Размер скидки (%)',
                          isNumber: true,
                        ),
                        const SizedBox(height: 20),
                        _adminField(
                          _descriptionController,
                          'Внутреннее описание',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 20),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Статус промокода',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            _isActive ? 'Активен и доступен' : 'Отключен',
                            style: const TextStyle(color: Colors.white38),
                          ),
                          value: _isActive,
                          activeColor: AdminColors.accentBlue,
                          onChanged: (val) => setState(() => _isActive = val),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 30),
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          _buildAdminCard('ОГРАНИЧЕНИЯ', [
                            _adminField(
                              _minAmountController,
                              'Минимальная сумма заказа (₽)',
                              isNumber: true,
                            ),
                            const SizedBox(height: 20),
                            _adminField(
                              _validToController,
                              'Срок действия до',
                              readOnly: true,
                              icon: Icons.calendar_today,
                              onTap: _selectDate,
                            ),
                          ]),
                          const SizedBox(height: 30),
                          _buildAdminCard('КАТЕГОРИИ ТОВАРОВ', [
                            const Text(
                              'Выберите типы товаров, на которые действует скидка:',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 15),
                            ..._productTypes.map(
                              (type) => Theme(
                                data: ThemeData.dark(),
                                child: CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    type.name,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  value: _selectedProductTypeIds.contains(
                                    type.id,
                                  ),
                                  activeColor: AdminColors.accentBlue,
                                  onChanged: (isSelected) {
                                    setState(() {
                                      if (isSelected == true) {
                                        _selectedProductTypeIds.add(type.id);
                                      } else {
                                        _selectedProductTypeIds.remove(type.id);
                                      }
                                    });
                                  },
                                ),
                              ),
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
    bool readOnly = false,
    IconData? icon,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white10),
        prefixIcon: icon != null
            ? Icon(icon, color: Colors.white38, size: 20)
            : null,
        filled: true,
        fillColor: AdminColors.sidebar,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      validator: (v) => !readOnly && v!.trim().isEmpty ? 'Обязательно' : null,
    );
  }
}
