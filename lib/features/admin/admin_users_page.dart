// lib/features/admin/admin_users_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ohana_store/core/admin_theme.dart'; // Используем AdminColors
import 'package:ohana_store/main.dart';
import 'package:ohana_store/models/admin_user_model.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  List<AdminUser> _allUsers = [];
  List<AdminUser> _filteredUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _isFilterVisible =
      true; // По умолчанию на десктопе лучше держать открытыми

  String _selectedRole = 'all';
  RangeValues _ageRange = const RangeValues(0, 100);

  final double _minYear = 2024; // Исправил на 2024 для реалистичности
  final double _maxYear = DateTime.now().year.toDouble();
  late RangeValues _yearRange;

  @override
  void initState() {
    super.initState();
    _yearRange = RangeValues(_minYear, _maxYear);
    _fetchUsers();
  }

  int _calculateAge(DateTime? birthDate) {
    if (birthDate == null) return -1;
    DateTime today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  void _applyFilters() {
    setState(() {
      _filteredUsers = _allUsers.where((user) {
        final matchesSearch = '${user.firstName} ${user.lastName} ${user.email}'
            .toLowerCase()
            .contains(_searchQuery.toLowerCase());
        final matchesRole =
            _selectedRole == 'all' || user.role == _selectedRole;

        int age = _calculateAge(user.dateOfBirth);
        bool matchesAge =
            age == -1 || (age >= _ageRange.start && age <= _ageRange.end);

        int regYear = user.createdAt.year;
        final matchesYear =
            regYear >= _yearRange.start && regYear <= _yearRange.end;

        return matchesSearch && matchesRole && matchesAge && matchesYear;
      }).toList();
    });
  }

  Future<void> _fetchUsers() async {
    try {
      final response = await supabase.from('admin_users_view').select();
      final users = (response as List)
          .map((u) => AdminUser.fromJson(u))
          .toList();
      setState(() {
        _allUsers = users;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      print('Error fetching users: $e');
    }
  }

  Future<void> _changeRole(AdminUser user, String newRole) async {
    try {
      await supabase
          .from('profiles')
          .update({'role': newRole})
          .eq('id', user.id);
      _fetchUsers();
    } catch (e) {
      print('Error changing role: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- ЗАГОЛОВОК И СЧЕТЧИК ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'БАЗА КЛИЕНТОВ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Всего найдено: ${_filteredUsers.length}',
                      style: const TextStyle(
                        color: AdminColors.accentBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    _isFilterVisible
                        ? Icons.filter_list_off
                        : Icons.filter_list,
                    color: Colors.white,
                  ),
                  onPressed: () =>
                      setState(() => _isFilterVisible = !_isFilterVisible),
                ),
              ],
            ),
            const SizedBox(height: 25),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- ЛЕВАЯ КОЛОНКА: СПИСОК ---
                Expanded(
                  flex: 2,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) =>
                              _buildUserCard(_filteredUsers[index]),
                        ),
                ),

                // --- ПРАВАЯ КОЛОНКА: ФИЛЬТРЫ ---
                if (_isFilterVisible) ...[
                  const SizedBox(width: 30),
                  SizedBox(
                    width: 300,
                    child: Column(children: [_buildFilterCard()]),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ПОИСК И ФИЛЬТРЫ',
            style: TextStyle(
              color: AdminColors.accentBlue,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            onChanged: (val) {
              _searchQuery = val;
              _applyFilters();
            },
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Имя или email...',
              hintStyle: const TextStyle(color: Colors.white24),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              filled: true,
              fillColor: AdminColors.sidebar,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            'РОЛЬ',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _roleChip('Все', 'all'),
              _roleChip('Клиент', 'user'),
              _roleChip('Админ', 'admin'),
            ],
          ),
          const SizedBox(height: 25),
          _buildSliderLabel(
            'ВОЗРАСТ',
            '${_ageRange.start.toInt()} - ${_ageRange.end.toInt()}',
          ),
          RangeSlider(
            values: _ageRange,
            min: 0,
            max: 100,
            activeColor: AdminColors.accentBlue,
            onChanged: (val) {
              setState(() => _ageRange = val);
              _applyFilters();
            },
          ),
          const SizedBox(height: 20),
          _buildSliderLabel(
            'ГОД РЕГИСТРАЦИИ',
            '${_yearRange.start.toInt()} - ${_yearRange.end.toInt()}',
          ),
          RangeSlider(
            values: _yearRange,
            min: _minYear,
            max: _maxYear,
            activeColor: AdminColors.accentBlue,
            onChanged: (val) {
              setState(() => _yearRange = val);
              _applyFilters();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(AdminUser user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        onTap: () => context.push('/admin/users/${user.id}', extra: user),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: AdminColors.sidebar,
          backgroundImage:
              (user.avatarUrl != null && user.avatarUrl!.startsWith('http'))
              ? NetworkImage(user.avatarUrl!)
              : null,
          child: (user.avatarUrl == null || !user.avatarUrl!.startsWith('http'))
              ? const Icon(Icons.person, color: Colors.white24)
              : null,
        ),
        title: Text(
          '${user.firstName} ${user.lastName}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          user.email,
          style: const TextStyle(color: Colors.white38, fontSize: 13),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AdminColors.sidebar,
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: user.role,
            dropdownColor: AdminColors.card,
            underline: const SizedBox(),
            style: const TextStyle(
              color: AdminColors.accentBlue,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            items: const [
              DropdownMenuItem(value: 'user', child: Text('ПОКУПАТЕЛЬ')),
              DropdownMenuItem(value: 'admin', child: Text('АДМИН')),
              DropdownMenuItem(
                value: 'collector',
                child: Text('СБОРЩИК'),
              ), // <-- Новое
              DropdownMenuItem(value: 'courier', child: Text('КУРЬЕР')),
            ],
            onChanged: (val) => _changeRole(user, val!),
          ),
        ),
      ),
    );
  }

  Widget _buildSliderLabel(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _roleChip(String label, String value) {
    final bool isSelected = _selectedRole == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() => _selectedRole = value);
          _applyFilters();
        }
      },
      selectedColor: AdminColors.accentBlue,
      backgroundColor: AdminColors.sidebar,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white38,
        fontWeight: FontWeight.bold,
      ),
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
