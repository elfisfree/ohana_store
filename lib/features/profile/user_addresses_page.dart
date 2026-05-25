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

  Future<void> _addAddress() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const _AddAddressDialog(),
    );

    if (result != null && mounted) {
      try {
        await supabase.from('user_addresses').insert({
          'user_id': supabase.auth.currentUser!.id,
          'name': result['name'],
          'city': result['city'],
          'street': result['street'],
          'house': result['house'],
          'floor': result['floor'],
          'apartment': result['apartment'],
        });

        AppNotifications.showSuccess(context, 'Адрес успешно сохранен');

        // --- ГЛАВНОЕ ИСПРАВЛЕНИЕ: Используем { } вместо => ---
        setState(() {
          _addressesFuture = _fetchAddresses();
        });
        // ---------------------------------------------------
      } catch (e) {
        AppNotifications.showError(context, 'Не удалось добавить адрес');
      }
    }
  }

  Future<void> _deleteAddress(String addressId) async {
    try {
      await supabase.from('user_addresses').delete().eq('id', addressId);

      if (mounted) {
        AppNotifications.showSuccess(context, 'Адрес удален');

        // --- ГЛАВНОЕ ИСПРАВЛЕНИЕ: Используем { } вместо => ---
        setState(() {
          _addressesFuture = _fetchAddresses();
        });
        // ---------------------------------------------------
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.showError(context, 'Ошибка при удалении');
      }
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.home_work_outlined,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'СПИСОК ПУСТ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ],
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
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      address.fullAddress,
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => _deleteAddress(address.id),
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
        onPressed: _addAddress,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AddAddressDialog extends StatefulWidget {
  const _AddAddressDialog();
  @override
  State<_AddAddressDialog> createState() => __AddAddressDialogState();
}

class __AddAddressDialogState extends State<_AddAddressDialog> {
  final _nameController = TextEditingController(text: 'Дом');
  final _cityController = TextEditingController(text: 'Казань');
  final _streetController = TextEditingController();
  final _houseController = TextEditingController();
  final _floorController = TextEditingController();
  final _aptController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'НОВЫЙ АДРЕС',
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          // Чтобы не вылетало на маленьких окнах
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildField(
                _nameController,
                'Название (напр: Работа)',
                isRequired: true,
              ),
              const SizedBox(height: 12),
              _buildField(_cityController, 'Город', isRequired: true),
              const SizedBox(height: 12),
              _buildField(_streetController, 'Улица', isRequired: true),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildField(
                      _houseController,
                      'Дом',
                      isRequired: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: _buildField(_floorController, 'Эт'),
                  ), // Поле этажа
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: _buildField(_aptController, 'Кв/Офис'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ОТМЕНА'),
        ),
        ElevatedButton(
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
          child: const Text('СОХРАНИТЬ'),
        ),
      ],
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label, {
    bool isRequired = false,
  }) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      validator: isRequired ? (v) => v!.isEmpty ? 'Заполните' : null : null,
    );
  }
}
