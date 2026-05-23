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
      return response.map((addr) => UserAddress.fromJson(addr)).toList();
    } catch (e) {
      throw Exception('Не удалось загрузить адреса: $e');
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
          'address_line': result['address'],
        });
        setState(() {
          _addressesFuture = _fetchAddresses();
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAddress(String addressId) async {
    try {
      await supabase.from('user_addresses').delete().eq('id', addressId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Адрес удален')));
        setState(() {
          _addressesFuture = _fetchAddresses();
        });
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.showError(context, 'Не удалось удалить адрес: $e');
        setState(() {
          _addressesFuture = _fetchAddresses();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мои адреса')),
      body: FutureBuilder<List<UserAddress>>(
        future: _addressesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final addresses = snapshot.data!;
          if (addresses.isEmpty) {
            return const Center(
              child: Text('У вас еще нет сохраненных адресов.'),
            );
          }

          return ListView.builder(
            itemCount: addresses.length,
            itemBuilder: (context, index) {
              final address = addresses[index];
              return ListTile(
                title: Text(address.name ?? 'Адрес ${index + 1}'),
                subtitle: Text(address.addressLine),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteAddress(address.id),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addAddress,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AddAddressDialog extends StatefulWidget {
  const _AddAddressDialog();

  @override
  State<_AddAddressDialog> createState() => _AddAddressDialogState();
}

class _AddAddressDialogState extends State<_AddAddressDialog> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новый адрес'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Название (напр., Дом)',
              ),
              validator: (v) => v!.isEmpty ? 'Это обязательное поле' : null,
            ),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Адрес'),
              validator: (v) => v!.isEmpty ? 'Это обязательное поле' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop({
                'name': _nameController.text,
                'address': _addressController.text,
              });
            }
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
