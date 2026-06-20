// lib/features/profile/user_addresses_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:ohana_store/core/utils/app_notifications.dart';
import 'package:ohana_store/main.dart';
import 'package:ohana_store/models/user_address.dart';

class UserAddressesPage extends StatefulWidget {
  const UserAddressesPage({super.key});

  @override
  State<UserAddressesPage> createState() => _UserAddressesPageState();
}

class _UserAddressesPageState extends State<UserAddressesPage> {
  late Future<List<UserAddress>> _addressesFuture;

  @override
  void initState() {
    super.initState();
    _addressesFuture = _fetchAddresses();
  }

  Future<List<UserAddress>> _fetchAddresses() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final response = await supabase
          .from('user_addresses')
          .select()
          .eq('user_id', userId)
          .order('created_at');
      return (response as List)
          .map((addr) => UserAddress.fromJson(addr))
          .toList();
    } catch (e) {
      throw Exception('Не удалось загрузить адреса');
    }
  }

  // Универсальный метод для открытия диалога (и для создания, и для редактирования)
  Future<void> _openAddressDialog([UserAddress? address]) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _AddressFormDialog(address: address),
    );

    if (result != null && mounted) {
      try {
        final data = {
          'user_id': supabase.auth.currentUser!.id,
          'name': result['name'],
          'city': result['city'],
          'street': result['street'],
          'house': result['house'],
          'floor': result['floor'],
          'apartment': result['apartment'],
        };

        if (address == null) {
          // Создание
          await supabase.from('user_addresses').insert(data);
          AppNotifications.showSuccess(context, 'Адрес добавлен');
        } else {
          // Редактирование
          await supabase
              .from('user_addresses')
              .update(data)
              .eq('id', address.id);
          AppNotifications.showSuccess(context, 'Адрес обновлен');
        }

        setState(() {
          _addressesFuture = _fetchAddresses();
        });
      } catch (e) {
        AppNotifications.showError(context, 'Ошибка сохранения: $e');
      }
    }
  }

  Future<void> _deleteAddress(String addressId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удаление'),
        content: const Text('Удалить этот адрес?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('user_addresses').delete().eq('id', addressId);
      if (mounted) {
        AppNotifications.showSuccess(context, 'Адрес удален');
        setState(() {
          _addressesFuture = _fetchAddresses();
        });
      }
    } catch (e) {
      if (mounted) AppNotifications.showError(context, 'Ошибка при удалении');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'МОИ АДРЕСА',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: FutureBuilder<List<UserAddress>>(
        future: _addressesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.black),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }
          final addresses = snapshot.data!;

          if (addresses.isEmpty) {
            return const Center(
              child: Text(
                'СПИСОК ПУСТ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: addresses.length,
            itemBuilder: (context, index) {
              final address = addresses[index];
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.location_on_outlined,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  title: Text(
                    address.name?.toUpperCase() ?? 'БЕЗ НАЗВАНИЯ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                  subtitle: Text(
                    address.fullAddress,
                    style: const TextStyle(color: Colors.black87),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // КНОПКА РЕДАКТИРОВАНИЯ
                      IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: Colors.blue,
                        ),
                        onPressed: () => _openAddressDialog(address),
                      ),
                      // КНОПКА УДАЛЕНИЯ
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => _deleteAddress(address.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        onPressed: () => _openAddressDialog(), // Добавление
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AddressFormDialog extends StatefulWidget {
  final UserAddress? address;
  const _AddressFormDialog({this.address});

  @override
  State<_AddressFormDialog> createState() => __AddressFormDialogState();
}

class __AddressFormDialogState extends State<_AddressFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _cityController;
  late final TextEditingController _streetController;
  late final TextEditingController _houseController;
  late final TextEditingController _floorController;
  late final TextEditingController _aptController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.address?.name ?? 'Дом',
    );
    _cityController = TextEditingController(
      text: widget.address?.city ?? 'Казань',
    );
    _streetController = TextEditingController(
      text: widget.address?.street ?? '',
    );
    _houseController = TextEditingController(text: widget.address?.house ?? '');
    _floorController = TextEditingController(text: widget.address?.floor ?? '');
    _aptController = TextEditingController(
      text: widget.address?.apartment ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _streetController.dispose();
    _houseController.dispose();
    _floorController.dispose();
    _aptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450), // Для десктопа
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ЗАГОЛОВОК
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.address == null ? 'НОВЫЙ АДРЕС' : 'РЕДАКТИРОВАНИЕ',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ПОЛЕ: НАЗВАНИЕ (Дом/Работа)
                _buildModernField(
                  controller: _nameController,
                  label: 'Название',
                  hint: 'Например: Дом, Офис, Дача',
                  icon: Icons.bookmark_outline,
                  isRequired: true,
                ),
                const SizedBox(height: 16),

                // ПОЛЕ: ГОРОД
                _buildModernField(
                  controller: _cityController,
                  label: 'Город',
                  icon: Icons.location_city_outlined,
                  isRequired: true,
                ),
                const SizedBox(height: 16),

                // ПОЛЕ: УЛИЦА
                _buildModernField(
                  controller: _streetController,
                  label: 'Улица',
                  icon: Icons.add_location_outlined,
                  isRequired: true,
                ),
                const SizedBox(height: 16),

                // РЯД: ДОМ, ЭТАЖ, КВАРТИРА
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildModernField(
                        controller: _houseController,
                        label: 'Дом',
                        isRequired: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: _buildModernField(
                        controller: _floorController,
                        label: 'Этаж',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _buildModernField(
                        controller: _aptController,
                        label: 'Кв/Офис',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // КНОПКА СОХРАНЕНИЯ
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        Navigator.pop(context, {
                          'name': _nameController.text.trim(),
                          'city': _cityController.text.trim(),
                          'street': _streetController.text.trim(),
                          'house': _houseController.text.trim(),
                          'floor': _floorController.text.trim(),
                          'apartment': _aptController.text.trim(),
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'СОХРАНИТЬ АДРЕС',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // МЕТОД ДЛЯ СОЗДАНИЯ КРАСИВОГО ПОЛЯ
  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade500,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: isRequired ? (v) => v!.trim().isEmpty ? '!' : null : null,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.normal,
            ),
            prefixIcon: icon != null
                ? Icon(icon, size: 20, color: Colors.black87)
                : null,
            filled: true,
            fillColor: Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.black, width: 1.5),
            ),
            errorStyle: const TextStyle(
              height: 0,
            ), // Прячем текст ошибки, оставляем только красную рамку
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
